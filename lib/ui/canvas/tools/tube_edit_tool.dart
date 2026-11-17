import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../calculation/engines/pipe_layout_engine.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../painters/interaction_data.dart';
import 'modifier_draw_tool.dart';
import 'tool_base.dart';
import 'tube_path_command.dart';
import 'undo_redo_service.dart';

/// Tool for correcting the tube inside a floor heating zone (ADR-046).
///
/// Click a floor zone to edit its tube. Its corners get handles:
///
/// - **Drag a corner** to move it. With snapping on it lines up with its
///   neighbours (so the segments stay square) or snaps to the grid.
/// - **Drag a run** (press on the tube between two corners) to move it
///   as a whole; its neighbours stretch. With snapping on a row moves
///   only across itself, in whole tube spacings from the nearest row.
/// - **Double-click a run** to add a corner there.
/// - **Click a handle, then Delete / Backspace** to remove that corner.
/// - **Alt** places freely for the current drag.
/// - **Escape** cancels a drag in progress.
///
/// The two ends of the tube follow the connection pipes and carry no
/// handle. The first change to an automatically laid out zone stores
/// the layout as [HeatingZone.manualTubePath] (freeze & edit); undoing
/// that change makes the zone automatic again. Every committed change is
/// one undo step.
class TubeEditTool extends CanvasTool with ModifierDrawTool {
  /// Creates a [TubeEditTool].
  TubeEditTool({
    required super.callbacks,
    required super.onStateChanged,
    required this.undoRedo,
    required this.tubeCorners,
    required this.snapEnabled,
  });

  /// Undo/redo stack — every committed change is one entry.
  final UndoRedoService undoRedo;

  /// Corner polyline of the tube currently drawn in a zone, by zone id
  /// (`zoneTubeCornersProvider`); null for an unknown zone.
  final List<Point2D>? Function(String zoneId) tubeCorners;

  /// Whether snapping is on (the panel toggle). Alt overrides it.
  final bool Function() snapEnabled;

  /// Zone whose tube is being edited, or null.
  String? zoneId;

  /// Corner index (into the tube path) Delete would remove, or null.
  int? _selectedCorner;

  HeatingZone? _dragOriginal;
  List<Point2D>? _dragBase;
  int? _dragCorner;
  int? _dragSegment;
  Point2D? _dragAnchor;
  bool _dragMoved = false;

  DateTime? _lastTapTime;
  Point2D? _lastTapPos;

  static const double _handleHitRadiusPx = 10.0;
  static const double _segmentHitRadiusPx = 8.0;
  static const double _doubleTapDistanceMm = 200.0;
  static const Duration _doubleTapWindow = Duration(milliseconds: 300);

  @override
  String get name => 'Edit Tube';

  /// The zone being edited, if it is still a floor zone on this floor.
  HeatingZone? get _zone {
    final id = zoneId;
    if (id == null) return null;
    return callbacks.currentZones
        .where((z) => z.id == id && z.zoneType == ZoneType.floorHeating)
        .firstOrNull;
  }

  List<Point2D> _corners(HeatingZone zone) => tubeCorners(zone.id) ?? const [];

  double get _handleMm {
    final zoom = callbacks.currentZoom;
    return zoom > 0 ? _handleHitRadiusPx / zoom : 30.0;
  }

  double get _segmentMm {
    final zoom = callbacks.currentZoom;
    return zoom > 0 ? _segmentHitRadiusPx / zoom : 50.0;
  }

  bool get _snapOn => snapEnabled() && !freePlacement;

  /// Index of the corner handle at [point], or null. Ends excluded.
  int? _cornerAt(List<Point2D> corners, Point2D point) {
    int? best;
    var bestD = _handleMm;
    for (var i = 1; i < corners.length - 1; i++) {
      final d = GeometryEngine.distanceMm(point, corners[i]);
      if (d <= bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// Index of the segment of [corners] at [point], or null.
  int? _segmentAt(List<Point2D> corners, Point2D point) {
    int? best;
    var bestD = _segmentMm;
    for (var i = 0; i + 1 < corners.length; i++) {
      final d = _distanceToSegmentMm(point, corners[i], corners[i + 1]);
      if (d <= bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  @override
  void onPointerMove(Point2D worldPoint) {}

  @override
  void onPointerDown(Point2D worldPoint, int buttons) {
    if (buttons & kPrimaryButton == 0) return;
    syncModifiersFromHardware();
    final zone = _zone;
    if (zone == null) return;
    final corners = _corners(zone);
    if (corners.length < 2) return;
    _clearDrag();
    final corner = _cornerAt(corners, worldPoint);
    if (corner != null) {
      _dragCorner = corner;
    } else {
      final segment = _segmentAt(corners, worldPoint);
      if (segment == null) return;
      _dragSegment = segment;
    }
    _dragOriginal = zone;
    _dragBase = corners;
    _dragAnchor = worldPoint;
  }

  @override
  void onDragUpdate(Point2D worldPoint) {
    final original = _dragOriginal;
    final base = _dragBase;
    final anchor = _dragAnchor;
    if (original == null || base == null || anchor == null) return;
    _dragMoved = true;
    final spacing = original.tubeSpacingMm.toDouble();
    final List<Point2D> path;
    final corner = _dragCorner;
    if (corner != null) {
      final point = _snapOn
          ? PipeLayoutEngine.snapTubeCorner(
              path: base,
              index: corner,
              raw: worldPoint,
              captureMm: spacing / 3,
              gridMm: callbacks.currentGridSpacingMm,
            )
          : worldPoint;
      path = PipeLayoutEngine.moveTubeCorner(base, corner, point);
    } else {
      var dx = worldPoint.x - anchor.x;
      var dy = worldPoint.y - anchor.y;
      if (_snapOn) {
        final o = PipeLayoutEngine.snapTubeRunOffset(
          path: base,
          segment: _dragSegment!,
          dx: dx,
          dy: dy,
          spacingMm: spacing,
        );
        dx = o.dx;
        dy = o.dy;
      }
      path = PipeLayoutEngine.moveTubeRun(base, _dragSegment!, dx, dy).path;
    }
    callbacks.updateZoneTransient(original.copyWith(manualTubePath: path));
    onStateChanged();
  }

  @override
  void onDragEnd(Point2D worldPoint) {
    final original = _dragOriginal;
    if (original == null || !_dragMoved) {
      _clearDrag();
      return;
    }
    final dragged = _zone;
    final path = dragged?.manualTubePath;
    if (dragged == null || path == null) {
      callbacks.updateZoneTransient(original);
      _clearDrag();
      return;
    }
    // A corner dropped onto its neighbour is merged with it.
    _commit(original, PipeLayoutEngine.dedupePolyline(path));
    _clearDrag();
  }

  @override
  void onPointerUp(Point2D worldPoint) => _clearDrag();

  @override
  void onTap(Point2D worldPoint, PointerDeviceKind deviceKind) {
    final now = DateTime.now();
    final isDoubleTap = _lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapWindow &&
        _lastTapPos != null &&
        GeometryEngine.distanceMm(worldPoint, _lastTapPos!) <=
            _doubleTapDistanceMm;
    _lastTapTime = now;
    _lastTapPos = worldPoint;

    final zone = _zone;
    final corners = zone == null ? const <Point2D>[] : _corners(zone);
    if (zone != null && corners.length >= 2) {
      final corner = _cornerAt(corners, worldPoint);
      if (corner != null) {
        _selectedCorner = corner;
        onStateChanged();
        return;
      }
      final segment = _segmentAt(corners, worldPoint);
      if (segment != null) {
        if (isDoubleTap) {
          final path =
              PipeLayoutEngine.insertTubeCorner(corners, segment, worldPoint);
          _commit(zone, path);
          _selectedCorner = segment + 1;
          _lastTapTime = null;
        } else {
          _selectedCorner = null;
        }
        onStateChanged();
        return;
      }
    }

    // Anywhere else: pick the floor zone under the click.
    final hit = _floorZoneAt(worldPoint);
    _selectedCorner = null;
    if (hit == null) {
      if (zone == null) {
        callbacks.showToast(callbacks.l10n.tube_clickFloorZoneToast);
      }
      onStateChanged();
      return;
    }
    if (hit.id != zoneId) {
      zoneId = hit.id;
      callbacks.selectElement('zone', hit.id);
    }
    onStateChanged();
  }

  @override
  void onDelete() {
    final zone = _zone;
    final corner = _selectedCorner;
    if (zone == null || corner == null) return;
    final corners = _corners(zone);
    final path = PipeLayoutEngine.removeTubeCorner(corners, corner);
    if (path.length == corners.length) return;
    _commit(zone, path);
    _selectedCorner = null;
    onStateChanged();
  }

  @override
  void cancel() {
    final original = _dragOriginal;
    if (original != null && _dragMoved) {
      callbacks.updateZoneTransient(original);
    }
    _clearDrag();
    _selectedCorner = null;
    onStateChanged();
  }

  @override
  InteractionData? getInteractionData() {
    final zone = _zone;
    if (zone == null) return null;
    final corners = _corners(zone);
    if (corners.length < 2) return null;
    final handles = corners.sublist(1, corners.length - 1);
    final active = _dragCorner;
    final selected = _selectedCorner;
    return TubePathData(
      corners: corners,
      handles: handles,
      activeHandleIndex: active == null ? null : active - 1,
      selectedHandleIndex: selected == null || selected - 1 >= handles.length
          ? null
          : selected - 1,
    );
  }

  // ----------------------------------------------------------------
  // Private helpers
  // ----------------------------------------------------------------

  /// Stores [path] as the manual tube of [before] — one undo step. A path
  /// equal to what is already drawn is not a change.
  void _commit(HeatingZone before, List<Point2D> path) {
    if (path.length < 2) {
      callbacks.updateZoneTransient(before);
      return;
    }
    final after = before.copyWith(manualTubePath: path);
    final unchanged = before.manualTubePath != null &&
        _samePath(before.manualTubePath!, path);
    if (unchanged) {
      callbacks.updateZoneTransient(before);
      return;
    }
    undoRedo.execute(UpdateTubePathCommand(
      oldZone: before,
      newZone: after,
      update: callbacks.updateZone,
      label: callbacks.l10n.undo_editTubePath,
    ));
  }

  static bool _samePath(List<Point2D> a, List<Point2D> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (GeometryEngine.distanceMm(a[i], b[i]) > 0.5) return false;
    }
    return true;
  }

  HeatingZone? _floorZoneAt(Point2D point) {
    for (final zone in callbacks.currentZones) {
      if (zone.zoneType == ZoneType.floorHeating &&
          zone.polygon.length >= 3 &&
          GeometryEngine.isPointInPolygon(point, zone.polygon)) {
        return zone;
      }
    }
    return null;
  }

  static double _distanceToSegmentMm(Point2D p, Point2D a, Point2D b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return GeometryEngine.distanceMm(p, a);
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
    return GeometryEngine.distanceMm(
      p,
      Point2D(x: a.x + dx * t, y: a.y + dy * t),
    );
  }

  void _clearDrag() {
    _dragOriginal = null;
    _dragBase = null;
    _dragCorner = null;
    _dragSegment = null;
    _dragAnchor = null;
    _dragMoved = false;
  }
}
