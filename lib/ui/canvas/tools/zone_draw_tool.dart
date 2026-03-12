import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';
import 'snap_service.dart';
import 'tool_base.dart';

/// Tool for drawing heating zone polygons by successive clicks.
///
/// Interaction flow (UI/UX §5.3):
///  1. First click starts the polygon.
///  2. Each subsequent click adds a vertex (snapped to grid).
///  3. Clicking within 15 screen-px of the first vertex, or
///     double-clicking, closes and commits the polygon.
///  4. Escape cancels and resets.
///
/// On close the tool:
///  - finds the parent room via [GeometryEngine.isPointInPolygon]
///  - validates all vertices are inside that room
///  - if invalid, sets [ZoneDrawData.hasValidationError] for a red
///    warning overlay and shows a toast, keeping vertices for review
///  - if valid, calls [EditorCallbacks.commitZone] with a
///    [HeatingZone] filled with defaults (tubeSpacingMm 150,
///    meander, borderDistanceMm 100, floorHeating)
class ZoneDrawTool extends CanvasTool {
  /// Creates a [ZoneDrawTool].
  ZoneDrawTool({
    required super.callbacks,
    required super.onStateChanged,
  });

  final List<Point2D> _vertices = [];
  Point2D? _current;
  bool _hasValidationError = false;
  DateTime? _lastTapTime;

  /// Minimum number of vertices needed to close a polygon.
  static const int _minVertices = 3;

  @override
  String get name => 'Draw Zone';

  /// Close-to-first-vertex threshold converted to world mm.
  ///
  /// 15 screen-px / zoom (px per mm) = world-space mm threshold.
  double get _closeThresholdMm => 15.0 / callbacks.currentZoom;

  @override
  void onTap(Point2D worldPoint, PointerDeviceKind deviceKind) {
    // Detect double-tap by comparing successive timestamps.
    final now = DateTime.now();
    final isDoubleTap = _lastTapTime != null &&
        now.difference(_lastTapTime!) <
            const Duration(milliseconds: 300);
    _lastTapTime = now;

    // Clear any previous validation error on new user action.
    _hasValidationError = false;

    // Snap vertex to grid.
    final snapped = SnapService.snapToGrid(worldPoint);

    // Double-tap closes when enough committed vertices exist.
    if (isDoubleTap && _vertices.length >= _minVertices) {
      _closeZone();
      return;
    }

    // Single-click near the first vertex also closes.
    if (_vertices.length >= _minVertices) {
      final dist =
          GeometryEngine.distanceMm(snapped, _vertices.first);
      if (dist <= _closeThresholdMm) {
        _closeZone();
        return;
      }
    }

    _vertices.add(snapped);
    onStateChanged();
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    _current = worldPoint;
    onStateChanged();
  }

  @override
  void cancel() {
    _vertices.clear();
    _current = null;
    _hasValidationError = false;
    _lastTapTime = null;
    onStateChanged();
  }

  @override
  InteractionData? getInteractionData() {
    if (_vertices.isEmpty) return null;
    return ZoneDrawData(
      vertices: List.unmodifiable(_vertices),
      currentPoint: _current,
      hasValidationError: _hasValidationError,
    );
  }

  // ----------------------------------------------------------------
  // Private helpers
  // ----------------------------------------------------------------

  void _closeZone() {
    if (_vertices.length < _minVertices) return;

    // Find the room whose polygon contains the first vertex.
    Room? parentRoom;
    for (final room in callbacks.currentRooms) {
      if (room.polygon.length >= 3 &&
          GeometryEngine.isPointInPolygon(
              _vertices.first, room.polygon)) {
        parentRoom = room;
        break;
      }
    }

    if (parentRoom == null) {
      _hasValidationError = true;
      onStateChanged();
      callbacks.showToast('Draw the zone inside a room.');
      return;
    }

    // Validate every vertex lies inside the parent room.
    for (final vertex in _vertices) {
      if (!GeometryEngine.isPointInPolygon(
          vertex, parentRoom.polygon)) {
        _hasValidationError = true;
        onStateChanged();
        callbacks.showToast(
          'All vertices must be inside the room.',
        );
        return;
      }
    }

    // Build the zone with spec-required defaults.
    final zone = HeatingZone(
      id: IdGenerator.newId(),
      roomId: parentRoom.id,
      polygon: List<Point2D>.from(_vertices),
      tubeSpacingMm: 150,
      tubeTypeId: callbacks.defaultTubeTypeId,
      flooringMaterialId: callbacks.defaultFlooringMaterialId,
      borderDistanceMm: 100,
      layoutPattern: LayoutPattern.meander,
      zoneType: ZoneType.floorHeating,
    );

    callbacks.commitZone(zone);
    _reset();
  }

  void _reset() {
    _vertices.clear();
    _current = null;
    _hasValidationError = false;
    _lastTapTime = null;
    onStateChanged();
  }
}
