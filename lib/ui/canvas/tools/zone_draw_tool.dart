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
/// Interaction flow (UI/UX §5.3 + ADR-006):
///  1. First click is only accepted inside a room polygon. That
///     room becomes the primary room for the zone.
///  2. Each subsequent click adds a vertex (snapped to grid) if
///     the point is inside the primary room OR inside an adjacent
///     room sharing a door-connected wall with it (ADR-006).
///     Clicks outside all valid rooms are silently rejected.
///  3. Clicking within 15 screen-px of the first vertex, or
///     double-clicking, closes and commits the polygon.
///  4. Escape cancels and resets.
///  5. While the cursor is outside all valid placement areas, a
///     red prohibition indicator is painted near the cursor.
///
/// On close the tool calls [EditorCallbacks.commitZone] with a
/// [HeatingZone] filled with defaults (tubeSpacingMm 150,
/// meander, borderDistanceMm 100, floorHeating).
class ZoneDrawTool extends CanvasTool {
  /// Creates a [ZoneDrawTool].
  ZoneDrawTool({
    required super.callbacks,
    required super.onStateChanged,
  });

  final List<Point2D> _vertices = [];
  Point2D? _current;
  bool _hasValidationError = false;

  /// True when the cursor is outside all valid placement areas.
  bool _cursorOutsideValidArea = false;

  DateTime? _lastTapTime;

  /// The room where the first vertex was placed (ADR-006).
  Room? _primaryRoom;

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
    final snapped = SnapService.snapToGrid(
      worldPoint,
      callbacks.currentGridSpacingMm,
    );

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

    // First vertex: find and lock the primary room.
    if (_vertices.isEmpty) {
      final room = _findRoomAt(snapped);
      if (room == null) return; // silently reject outside any room
      _primaryRoom = room;
      _vertices.add(snapped);
      onStateChanged();
      return;
    }

    // Subsequent vertices: validate against primary + door-adjacent.
    if (!_isValidPosition(snapped)) return; // silently reject

    _vertices.add(snapped);
    onStateChanged();
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    _current = worldPoint;
    _cursorOutsideValidArea = !_isValidPosition(worldPoint);
    onStateChanged();
  }

  @override
  void cancel() {
    _reset();
  }

  @override
  InteractionData? getInteractionData() {
    // Show the prohibition indicator even before any vertex is placed,
    // but don't return data when the cursor is inside a valid area and
    // no polygon has started yet (nothing useful to draw).
    if (_vertices.isEmpty) {
      if (!_cursorOutsideValidArea || _current == null) return null;
    }
    return ZoneDrawData(
      vertices: List.unmodifiable(_vertices),
      currentPoint: _current,
      hasValidationError: _hasValidationError,
      cursorOutsideValidArea: _cursorOutsideValidArea,
    );
  }

  // ----------------------------------------------------------------
  // Private helpers
  // ----------------------------------------------------------------

  /// Returns the first room whose polygon contains [point], or null.
  Room? _findRoomAt(Point2D point) {
    for (final room in callbacks.currentRooms) {
      if (room.polygon.length >= 3 &&
          GeometryEngine.isPointInPolygon(point, room.polygon)) {
        return room;
      }
    }
    return null;
  }

  /// True if [point] lies inside a valid placement area.
  ///
  /// Before the primary room is established (no vertices yet), any
  /// room is valid. After the first vertex, only the primary room
  /// and its door-adjacent neighbours (ADR-006) are valid.
  bool _isValidPosition(Point2D point) {
    final rooms = _primaryRoom != null
        ? _validRooms()
        : callbacks.currentRooms;
    return rooms.any(
      (r) =>
          r.polygon.length >= 3 &&
          GeometryEngine.isPointInPolygon(point, r.polygon),
    );
  }

  /// Returns the primary room plus any rooms that share a
  /// door-connected wall with it (ADR-006).
  List<Room> _validRooms() {
    if (_primaryRoom == null) return [];
    final result = <Room>[_primaryRoom!];

    // Wall IDs belonging to the primary room.
    final primaryWallIds = callbacks.currentWalls
        .where((w) => w.roomId == _primaryRoom!.id)
        .map((w) => w.id)
        .toSet();

    // Which of those walls carry at least one door?
    final doorWallIds = callbacks.currentDoors
        .where((d) => primaryWallIds.contains(d.wallSegmentId))
        .map((d) => d.wallSegmentId)
        .toSet();

    // Collect adjacent room IDs from those door-bearing walls.
    final adjacentRoomIds = callbacks.currentWalls
        .where(
          (w) =>
              doorWallIds.contains(w.id) && w.adjacentRoomId != null,
        )
        .map((w) => w.adjacentRoomId!)
        .toSet();

    // Add the matching room objects.
    result.addAll(
      callbacks.currentRooms
          .where((r) => adjacentRoomIds.contains(r.id)),
    );

    return result;
  }

  void _closeZone() {
    if (_vertices.length < _minVertices) return;

    // Use the locked primary room (established at first vertex).
    final parentRoom = _primaryRoom;
    if (parentRoom == null) {
      _hasValidationError = true;
      onStateChanged();
      callbacks.showToast('Draw the zone inside a room.');
      return;
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
    _cursorOutsideValidArea = false;
    _primaryRoom = null;
    _lastTapTime = null;
    onStateChanged();
  }
}
