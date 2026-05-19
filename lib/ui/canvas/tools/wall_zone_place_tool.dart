import 'dart:math' show sqrt;

import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/wall_segment.dart';
import '../painters/interaction_data.dart';
import 'create_zone_command.dart';
import 'tool_base.dart';
import 'undo_redo_service.dart';

/// Tool for placing wall heating zones by clicking on a wall segment.
///
/// Interaction flow (UI/UX §5.3 wall zone adaptation):
///  1. User hovers over the canvas; the in-room wall segment nearest
///     to the cursor within [_hitThresholdMm] is highlighted in amber.
///  2. Clicking a highlighted wall creates a [HeatingZone] with
///     [ZoneType.wallHeating]:
///     - [HeatingZone.wallSegmentId] references the clicked wall.
///     - [HeatingZone.polygon] is a derived 200 mm thick rectangle
///       along the wall (same visual thickness as [WallPainter]).
///     - [HeatingZone.heightMm] is null (uses floor height as default).
///  3. The zone is committed and auto-selected so the properties
///     panel opens immediately for [HeatingZone.heightMm] editing.
///  4. Escape clears the hover highlight.
class WallZonePlaceTool extends CanvasTool {
  /// Creates a [WallZonePlaceTool].
  WallZonePlaceTool({
    required super.callbacks,
    required super.onStateChanged,
    required this.undoRedo,
  });

  /// Undo/redo service. Wall zones are committed through a
  /// [CreateZoneCommand] so creation is revertible (ADR-014).
  final UndoRedoService undoRedo;

  /// World-space distance threshold for wall hit-detection (mm).
  ///
  /// Set to one visual wall-thickness so the cursor only needs to
  /// touch the drawn wall rectangle, not just its centreline.
  static const double _hitThresholdMm = 200.0;

  WallSegment? _hoveredWall;
  Point2D? _current;

  @override
  String get name => 'Place Wall Zone';

  @override
  void onPointerMove(Point2D worldPoint) {
    _current = worldPoint;
    final wall = _nearestWall(worldPoint);
    if (wall?.id != _hoveredWall?.id) {
      _hoveredWall = wall;
      onStateChanged();
    } else if (wall == null) {
      // Cursor moved but still no wall — repaint to update indicator position.
      onStateChanged();
    }
  }

  @override
  void onTap(Point2D worldPoint, PointerDeviceKind deviceKind) {
    final wall = _hoveredWall ?? _nearestWall(worldPoint);
    if (wall == null) return;

    if (wall.roomId.isEmpty) {
      callbacks.showToast('Wall must belong to a room.');
      return;
    }

    // Derived display polygon: 200 mm thick rectangle along wall.
    final polygon = _wallBandPolygon(wall.startPoint, wall.endPoint);

    final zone = HeatingZone(
      id: IdGenerator.newId(),
      roomId: wall.roomId,
      zoneType: ZoneType.wallHeating,
      polygon: polygon,
      tubeSpacingMm: 150,
      tubeTypeId: callbacks.defaultTubeTypeId,
      flooringMaterialId: callbacks.defaultFlooringMaterialId,
      borderDistanceMm: 100,
      layoutPattern: LayoutPattern.meander,
      wallSegmentId: wall.id,
      // heightMm left null → properties panel shows floor height default.
    );

    // ADR-014: wall-zone creation is undoable via the shared command.
    undoRedo.execute(CreateZoneCommand(
      zone: zone,
      add: callbacks.commitZone,
      remove: callbacks.removeZone,
      label: callbacks.l10n.undo_createWallZone,
    ));
    callbacks.selectElement('zone', zone.id);
    _hoveredWall = null;
    onStateChanged();
  }

  @override
  void cancel() {
    _hoveredWall = null;
    _current = null;
    onStateChanged();
  }

  @override
  InteractionData? getInteractionData() {
    if (_hoveredWall == null) {
      if (_current == null) return null;
      return WallZoneNoHoverData(cursorPosition: _current!);
    }
    return WallZoneHoverData(
      wallStart: _hoveredWall!.startPoint,
      wallEnd: _hoveredWall!.endPoint,
    );
  }

  // ── Private helpers ─────────────────────────────────────────────

  /// Returns the closest in-room wall within [_hitThresholdMm],
  /// or null if no wall is nearby.
  WallSegment? _nearestWall(Point2D point) {
    WallSegment? nearest;
    var minDist = double.infinity;
    for (final wall in callbacks.currentWalls) {
      if (wall.roomId.isEmpty) continue;
      final d = _distanceToSegmentMm(
        point,
        wall.startPoint,
        wall.endPoint,
      );
      if (d < _hitThresholdMm && d < minDist) {
        minDist = d;
        nearest = wall;
      }
    }
    return nearest;
  }

  /// Perpendicular distance from [p] to segment [a]→[b] (mm).
  static double _distanceToSegmentMm(
    Point2D p,
    Point2D a,
    Point2D b,
  ) {
    final abx = b.x - a.x;
    final aby = b.y - a.y;
    final len2 = abx * abx + aby * aby;
    if (len2 < 1e-9) return GeometryEngine.distanceMm(p, a);
    final t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2;
    final ct = t.clamp(0.0, 1.0);
    final closest = Point2D(x: a.x + ct * abx, y: a.y + ct * aby);
    return GeometryEngine.distanceMm(p, closest);
  }

  /// Derives a 4-vertex display polygon for the wall zone.
  ///
  /// The polygon is a rectangle 200 mm wide centred on the wall
  /// centreline, matching [WallPainter]'s visual wall thickness.
  /// Vertex order: [outer-start, outer-end, inner-end, inner-start].
  static List<Point2D> _wallBandPolygon(
    Point2D start,
    Point2D end,
  ) {
    const halfThickness = 100.0; // half of 200 mm visual wall width
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return [start, end, end, start];

    // Perpendicular unit vector (rotate wall direction 90° CW).
    final px = (-dy / len) * halfThickness;
    final py = (dx / len) * halfThickness;

    return [
      Point2D(x: start.x - px, y: start.y - py),
      Point2D(x: end.x - px, y: end.y - py),
      Point2D(x: end.x + px, y: end.y + py),
      Point2D(x: start.x + px, y: start.y + py),
    ];
  }
}
