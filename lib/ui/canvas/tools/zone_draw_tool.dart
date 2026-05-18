import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';
import 'modifier_draw_tool.dart';
import 'snap_service.dart';
import 'tool_base.dart';

/// Tool for drawing heating zone polygons by successive clicks,
/// or — with Ctrl held — by dragging a rectangle corner to corner.
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
/// Desktop modifier vocabulary (shared [ModifierDrawTool] flags,
/// mirroring [WallDrawTool] — see `DECISIONS.md` ADR-013):
/// - **Shift** ([orthoSnap]): constrain the ghost edge from the
///   previous vertex (polygon mode) or the rect drag endpoint to
///   0° or 90°.
/// - **Ctrl** ([rectMode]): drag from corner A to corner B to
///   commit a four-vertex rectangular zone in one gesture.
/// - **Alt** ([freePlacement]): skip grid snap for the current
///   vertex / corner; the raw world coordinate is used instead.
///
/// Per ADR-013 the rectangle corners are **not** passed through
/// [SnapService.snapRectCorner] / [SnapService.snapRectDimension]
/// (those are wall/room-graph features). The §5.3 / ADR-006
/// vertex-in-room validation applies to every rectangle corner,
/// and both polygon and rectangle closes commit through the same
/// [_commitZone] path.
///
/// On close the tool calls [EditorCallbacks.commitZone] with a
/// [HeatingZone] filled with defaults (tubeSpacingMm 150,
/// meander, borderDistanceMm 100, floorHeating).
class ZoneDrawTool extends CanvasTool with ModifierDrawTool {
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

  // ---- Rect-mode drag state (Ctrl, ADR-013) ----

  /// Snapped drag-start corner of the current rectangle, or null.
  Point2D? _rectDragStart;

  /// Snapped (and ortho-constrained) opposite corner during the
  /// current rectangle drag, or null.
  Point2D? _rectDragCurrent;

  /// Minimum number of vertices needed to close a polygon.
  static const int _minVertices = 3;

  /// Minimum rectangle side length in mm (ADR-013, mirrors
  /// [WallDrawTool]'s wall-length minimum).
  static const double _minRectSideMm = 100.0;

  @override
  String get name => 'Draw Zone';

  /// Close-to-first-vertex threshold converted to world mm.
  ///
  /// 15 screen-px / zoom (px per mm) = world-space mm threshold.
  double get _closeThresholdMm => 15.0 / callbacks.currentZoom;

  /// Grid-snap [raw] unless Alt ([freePlacement]) is held, in which
  /// case the raw world coordinate is used.
  ///
  /// Zones never snap to wall endpoints/interiors (unlike
  /// [WallDrawTool]'s `_snap`), so this uses pure grid snap.
  Point2D _snapZone(Point2D raw) => freePlacement
      ? raw
      : SnapService.snapToGrid(raw, callbacks.currentGridSpacingMm);

  @override
  void onTap(Point2D worldPoint, PointerDeviceKind deviceKind) {
    if (rectMode) return; // rect mode uses drag, not tap

    // Detect double-tap by comparing successive timestamps.
    final now = DateTime.now();
    final isDoubleTap = _lastTapTime != null &&
        now.difference(_lastTapTime!) <
            const Duration(milliseconds: 300);
    _lastTapTime = now;

    // Clear any previous validation error on new user action.
    _hasValidationError = false;

    // Grid snap (Alt-aware), then ortho-constrain from the previous
    // vertex when Shift is held.
    var snapped = _snapZone(worldPoint);
    if (_vertices.isNotEmpty) {
      snapped = applyOrtho(_vertices.last, snapped);
    }

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

  // ---- Rect-mode drag (Ctrl, ADR-013) ----

  @override
  void onPointerDown(Point2D worldPoint, int buttons) {
    if (!rectMode) return;
    // Grid snap only — ADR-013 does NOT apply snapRectCorner.
    _rectDragStart = _snapZone(worldPoint);
    _rectDragCurrent = _rectDragStart;
    onStateChanged();
  }

  @override
  void onDragUpdate(Point2D worldPoint) {
    if (!rectMode || _rectDragStart == null) return;
    // Grid snap → ortho. No snapRectCorner / snapRectDimension.
    _rectDragCurrent =
        applyOrtho(_rectDragStart!, _snapZone(worldPoint));
    onStateChanged();
  }

  @override
  void onDragEnd(Point2D worldPoint) {
    if (!rectMode) return;
    final start = _rectDragStart;
    if (start == null) return;

    // Grid snap → ortho (ADR-013: no snapRectCorner/Dimension).
    final end = applyOrtho(start, _snapZone(worldPoint));

    final w = (end.x - start.x).abs();
    final h = (end.y - start.y).abs();
    if (w < _minRectSideMm || h < _minRectSideMm) {
      callbacks.showToast(
        'Zone rectangle too small — both sides must be ≥ 100 mm',
      );
      _reset();
      return;
    }

    // Primary room = the room containing the drag-start corner
    // (§5.3: "the room where the first vertex was placed").
    final primaryRoom = _findRoomAt(start);
    if (primaryRoom == null) {
      callbacks.showToast('Draw the zone inside a room.');
      _reset();
      return;
    }
    _primaryRoom = primaryRoom;

    final minX = start.x < end.x ? start.x : end.x;
    final minY = start.y < end.y ? start.y : end.y;
    final maxX = start.x > end.x ? start.x : end.x;
    final maxY = start.y > end.y ? start.y : end.y;
    final corners = <Point2D>[
      Point2D(x: minX, y: minY),
      Point2D(x: maxX, y: minY),
      Point2D(x: maxX, y: maxY),
      Point2D(x: minX, y: maxY),
    ];

    // §5.3 / ADR-006: every corner must lie inside the primary
    // room or a door-connected adjacent room.
    if (!corners.every(_isValidPosition)) {
      callbacks.showToast(
        'Zone rectangle must stay inside the room '
        '(or a door-connected room).',
      );
      _reset();
      return;
    }

    _commitZone(corners, primaryRoom);
    _reset();
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    if (rectMode) {
      // Keep the rect ghost fresh; the active drag is driven by
      // onDragUpdate (defensive parity with WallDrawTool).
      if (_rectDragStart != null) {
        _rectDragCurrent =
            applyOrtho(_rectDragStart!, _snapZone(worldPoint));
      }
      _cursorOutsideValidArea = !_isValidPosition(worldPoint);
      onStateChanged();
      return;
    }
    // Polygon mode: preview the snapped (and ortho-constrained)
    // vertex so the ghost edge matches where the click will land.
    _current = _vertices.isEmpty
        ? worldPoint
        : applyOrtho(_vertices.last, _snapZone(worldPoint));
    _cursorOutsideValidArea = !_isValidPosition(worldPoint);
    onStateChanged();
  }

  @override
  void cancel() {
    _reset();
  }

  @override
  InteractionData? getInteractionData() {
    // Rect-mode ghost reuses the WallDrawTool rectangle painter.
    if (rectMode &&
        _rectDragStart != null &&
        _rectDragCurrent != null) {
      return RectDrawData(
        corner1: _rectDragStart!,
        corner2: _rectDragCurrent!,
      );
    }
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

    _commitZone(List<Point2D>.from(_vertices), parentRoom);
    _reset();
  }

  /// Commits a zone [polygon] for [parentRoom] with the spec-required
  /// defaults. Shared by the polygon-close and rectangle-commit paths
  /// (ADR-013: "both commit through the existing zone-commit path").
  void _commitZone(List<Point2D> polygon, Room parentRoom) {
    final zone = HeatingZone(
      id: IdGenerator.newId(),
      roomId: parentRoom.id,
      polygon: polygon,
      tubeSpacingMm: 150,
      tubeTypeId: callbacks.defaultTubeTypeId,
      flooringMaterialId: callbacks.defaultFlooringMaterialId,
      borderDistanceMm: 100,
      layoutPattern: LayoutPattern.meander,
      zoneType: ZoneType.floorHeating,
    );

    callbacks.commitZone(zone);
  }

  void _reset() {
    _vertices.clear();
    _current = null;
    _hasValidationError = false;
    _cursorOutsideValidArea = false;
    _primaryRoom = null;
    _lastTapTime = null;
    _rectDragStart = null;
    _rectDragCurrent = null;
    onStateChanged();
  }
}
