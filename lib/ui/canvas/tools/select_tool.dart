import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/geometry_utils.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';
import 'snap_service.dart';
import 'tool_base.dart';
import 'undo_redo_service.dart';

/// Tool for selecting walls and rooms by clicking, and
/// editing wall positions via drag handles.
///
/// When a wall is selected, three drag handles appear
/// (start, mid, end). Dragging these handles moves or
/// resizes the wall. Connected walls in a room adjust
/// automatically.
class SelectTool extends CanvasTool {
  /// Creates a [SelectTool].
  SelectTool({
    required super.callbacks,
    required super.onStateChanged,
    required this.undoRedo,
  });

  /// Shared undo/redo service.
  final UndoRedoService undoRedo;

  /// Hit-test threshold for walls (half wall thickness).
  static const double _wallHitThresholdMm = 100.0;

  /// Handle hit radius in screen pixels.
  static const double _handleHitRadiusPx = 10.0;

  /// Handle radius in world coordinates (visual size).
  static const double _handleRadiusMm = 30.0;

  /// Minimum wall length (mm).
  static const double _minLengthMm = 100.0;

  /// Currently selected wall, if any.
  WallSegment? _selectedWall;

  /// Currently selected room, if any.
  Room? _selectedRoom;

  // -- Drag state --

  /// Which handle is being dragged (null = no drag).
  DragHandleType? _dragHandle;

  /// Wall state at the start of the drag (for revert).
  WallSegment? _dragStartWall;

  /// Connected wall snapshots at drag start (for revert).
  List<WallSegment> _dragStartConnected = const [];

  /// Room snapshot at drag start (for polygon update).
  Room? _dragStartRoom;

  @override
  String get name => 'Select';

  @override
  void onTap(
    Point2D worldPoint,
    PointerDeviceKind deviceKind,
  ) {
    // If dragging, ignore taps.
    if (_dragHandle != null) return;

    // Try to hit-test walls first.
    final wall = _hitTestWall(worldPoint);
    if (wall != null) {
      _selectedWall = wall;
      _selectedRoom = null;
      callbacks.selectElement('wall', wall.id);
      onStateChanged();
      return;
    }

    // Try to hit-test rooms.
    final room = _hitTestRoom(worldPoint);
    if (room != null) {
      _selectedWall = null;
      _selectedRoom = room;
      callbacks.selectElement('room', room.id);
      onStateChanged();
      return;
    }

    // Nothing hit — deselect.
    _selectedWall = null;
    _selectedRoom = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  @override
  void onPointerDown(Point2D worldPoint, int buttons) {
    if (_selectedWall == null) return;

    // Right-click / Ctrl+click: disconnect handle.
    if (buttons & kSecondaryButton != 0) {
      _handleSecondaryClick(worldPoint);
      return;
    }

    // Left-click on a handle starts a drag.
    final handleType = _hitTestHandle(worldPoint);
    if (handleType == null) return;

    _dragHandle = handleType;
    _dragStartWall = _selectedWall;

    // Snapshot connected walls.
    _dragStartConnected = _findConnectedWalls(_selectedWall!);

    // Snapshot room if the wall belongs to one.
    if (_selectedWall!.roomId.isNotEmpty) {
      _dragStartRoom = callbacks.currentRooms
          .where((r) => r.id == _selectedWall!.roomId)
          .firstOrNull;
    } else {
      _dragStartRoom = null;
    }

    onStateChanged();
  }

  @override
  void onDragUpdate(Point2D worldPoint) {
    if (_dragHandle == null || _dragStartWall == null) return;

    final snap = SnapService.snap(worldPoint, callbacks.currentWalls);

    switch (_dragHandle!) {
      case DragHandleType.mid:
        _applyMidDrag(snap.point);
      case DragHandleType.start:
        _applyEndpointDrag(snap.point, isStart: true);
      case DragHandleType.end:
        _applyEndpointDrag(snap.point, isStart: false);
    }

    onStateChanged();
  }

  @override
  void onDragEnd(Point2D worldPoint) {
    if (_dragHandle == null || _dragStartWall == null) {
      _clearDragState();
      return;
    }

    // Refresh _selectedWall from current state.
    final currentWall = callbacks.currentWalls
        .where((w) => w.id == _dragStartWall!.id)
        .firstOrNull;

    if (currentWall == null) {
      _clearDragState();
      return;
    }

    // Validate minimum length.
    final length = GeometryEngine.distanceMm(
      currentWall.startPoint,
      currentWall.endPoint,
    );
    if (length < _minLengthMm) {
      // Revert to pre-drag state.
      _revertDrag();
      callbacks.showToast(
        'Wall too short (min ${_minLengthMm.round()} mm)',
      );
      _clearDragState();
      return;
    }

    // Commit as an undo command.
    final oldWall = _dragStartWall!;
    final oldConnected = List<WallSegment>.from(_dragStartConnected);
    final oldRoom = _dragStartRoom;

    // Gather current state of moved walls.
    final newWall = currentWall;
    final newConnected = <WallSegment>[];
    for (final oc in oldConnected) {
      final cur = callbacks.currentWalls
          .where((w) => w.id == oc.id)
          .firstOrNull;
      if (cur != null) newConnected.add(cur);
    }
    final newRoom = oldRoom != null
        ? callbacks.currentRooms
              .where((r) => r.id == oldRoom.id)
              .firstOrNull
        : null;

    // Only push command if something actually changed.
    if (oldWall.startPoint != newWall.startPoint ||
        oldWall.endPoint != newWall.endPoint) {
      undoRedo.execute(_MoveWallCommand(
        callbacks: callbacks,
        oldWall: oldWall,
        newWall: newWall,
        oldConnected: oldConnected,
        newConnected: newConnected,
        oldRoom: oldRoom,
        newRoom: newRoom,
      ));
    }

    // Update selected wall reference.
    _selectedWall = newWall;
    _clearDragState();
  }

  @override
  void onSecondaryTap(Point2D worldPoint) {
    _handleSecondaryClick(worldPoint);
  }

  @override
  void onDelete() {
    if (_selectedWall != null) {
      _deleteSelectedWall();
    } else if (_selectedRoom != null) {
      _deleteSelectedRoom();
    }
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    // No hover behavior for select tool currently.
  }

  @override
  void cancel() {
    if (_dragHandle != null) {
      _revertDrag();
      _clearDragState();
      onStateChanged();
      return;
    }
    _selectedWall = null;
    _selectedRoom = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  @override
  InteractionData? getInteractionData() {
    if (_selectedWall == null && _selectedRoom == null) {
      return null;
    }

    // Build handle positions for the selected wall.
    final handles = <Point2D>[];
    int? activeIdx;
    if (_selectedWall != null) {
      final w = _selectedWall!;
      // Refresh wall from current state during drag.
      final currentWall = callbacks.currentWalls
          .where((wall) => wall.id == w.id)
          .firstOrNull ?? w;
      final start = currentWall.startPoint;
      final end = currentWall.endPoint;
      final mid = Point2D(
        x: (start.x + end.x) / 2,
        y: (start.y + end.y) / 2,
      );
      handles.addAll([start, mid, end]);

      if (_dragHandle != null) {
        activeIdx = _dragHandle!.index;
      }
    }

    return SelectionHighlightData(
      selectedWalls: _selectedWall != null
          ? [_currentWallState(_selectedWall!)]
          : const [],
      selectedRoom: _selectedRoom,
      handles: handles,
      activeHandleIndex: activeIdx,
    );
  }

  // ----- Handle hit-testing -----

  /// Returns which handle is under [worldPoint], or null.
  DragHandleType? _hitTestHandle(Point2D worldPoint) {
    if (_selectedWall == null) return null;

    final wall = _currentWallState(_selectedWall!);
    final start = wall.startPoint;
    final end = wall.endPoint;
    final mid = Point2D(
      x: (start.x + end.x) / 2,
      y: (start.y + end.y) / 2,
    );

    // Convert handle hit radius from screen pixels to world mm.
    final zoom = callbacks.currentZoom;
    final thresholdMm = zoom > 0
        ? _handleHitRadiusPx / zoom
        : _handleRadiusMm;

    // Test each handle (start, mid, end). Prioritise
    // start/end over mid when overlapping short walls.
    if (GeometryEngine.distanceMm(worldPoint, start) <= thresholdMm) {
      return DragHandleType.start;
    }
    if (GeometryEngine.distanceMm(worldPoint, end) <= thresholdMm) {
      return DragHandleType.end;
    }
    if (GeometryEngine.distanceMm(worldPoint, mid) <= thresholdMm) {
      return DragHandleType.mid;
    }
    return null;
  }

  // ----- Mid-handle drag (translate wall) -----

  void _applyMidDrag(Point2D snappedPoint) {
    final orig = _dragStartWall!;
    final origMid = Point2D(
      x: (orig.startPoint.x + orig.endPoint.x) / 2,
      y: (orig.startPoint.y + orig.endPoint.y) / 2,
    );
    final dx = snappedPoint.x - origMid.x;
    final dy = snappedPoint.y - origMid.y;

    final newStart = Point2D(
      x: orig.startPoint.x + dx,
      y: orig.startPoint.y + dy,
    );
    final newEnd = Point2D(
      x: orig.endPoint.x + dx,
      y: orig.endPoint.y + dy,
    );

    callbacks.updateWall(
      orig.copyWith(startPoint: newStart, endPoint: newEnd),
    );

    // Adjust connected walls: their near endpoints follow,
    // far endpoints stay fixed.
    _adjustConnectedWalls(
      orig,
      newStart: newStart,
      newEnd: newEnd,
    );

    // Update room polygon if applicable.
    _updateRoomPolygon();
  }

  // ----- Endpoint handle drag (resize/pivot) -----

  void _applyEndpointDrag(Point2D snappedPoint, {required bool isStart}) {
    final orig = _dragStartWall!;

    final updated = isStart
        ? orig.copyWith(startPoint: snappedPoint)
        : orig.copyWith(endPoint: snappedPoint);

    callbacks.updateWall(updated);

    // Adjust the connected wall at the dragged endpoint.
    _adjustConnectedWallAtEndpoint(
      orig,
      movedEndpoint: isStart ? orig.startPoint : orig.endPoint,
      newPosition: snappedPoint,
    );

    // Update room polygon if applicable.
    _updateRoomPolygon();
  }

  // ----- Connected wall adjustment -----

  /// Find walls that share an endpoint with [wall].
  List<WallSegment> _findConnectedWalls(WallSegment wall) {
    final connected = <WallSegment>[];
    for (final other in callbacks.currentWalls) {
      if (other.id == wall.id) continue;
      if (_sharesEndpoint(wall, other)) {
        connected.add(other);
      }
    }
    return connected;
  }

  bool _sharesEndpoint(WallSegment a, WallSegment b) {
    return _pointsEqual(a.startPoint, b.startPoint) ||
        _pointsEqual(a.startPoint, b.endPoint) ||
        _pointsEqual(a.endPoint, b.startPoint) ||
        _pointsEqual(a.endPoint, b.endPoint);
  }

  bool _pointsEqual(Point2D a, Point2D b) {
    return (a.x - b.x).abs() < 0.01 && (a.y - b.y).abs() < 0.01;
  }

  /// During mid-drag, adjust connected walls so their near
  /// endpoints follow and far endpoints stay fixed.
  void _adjustConnectedWalls(
    WallSegment origWall, {
    required Point2D newStart,
    required Point2D newEnd,
  }) {
    for (final conn in _dragStartConnected) {
      WallSegment? updated;

      if (_pointsEqual(conn.startPoint, origWall.startPoint)) {
        updated = conn.copyWith(startPoint: newStart);
      } else if (_pointsEqual(conn.endPoint, origWall.startPoint)) {
        updated = conn.copyWith(endPoint: newStart);
      } else if (_pointsEqual(conn.startPoint, origWall.endPoint)) {
        updated = conn.copyWith(startPoint: newEnd);
      } else if (_pointsEqual(conn.endPoint, origWall.endPoint)) {
        updated = conn.copyWith(endPoint: newEnd);
      }

      if (updated != null) {
        callbacks.updateWall(updated);
      }
    }
  }

  /// During endpoint drag, adjust the single connected wall
  /// at the moved endpoint.
  void _adjustConnectedWallAtEndpoint(
    WallSegment origWall, {
    required Point2D movedEndpoint,
    required Point2D newPosition,
  }) {
    for (final conn in _dragStartConnected) {
      WallSegment? updated;

      if (_pointsEqual(conn.startPoint, movedEndpoint)) {
        updated = conn.copyWith(startPoint: newPosition);
      } else if (_pointsEqual(conn.endPoint, movedEndpoint)) {
        updated = conn.copyWith(endPoint: newPosition);
      }

      if (updated != null) {
        callbacks.updateWall(updated);
      }
    }
  }

  // ----- Room polygon update -----

  void _updateRoomPolygon() {
    if (_dragStartRoom == null) return;

    final roomId = _dragStartRoom!.id;
    final roomWalls = callbacks.currentWalls
        .where((w) => w.roomId == roomId)
        .toList();

    if (roomWalls.length < 3) return;

    // Rebuild polygon from wall endpoints.
    final polygon = _buildPolygonFromWalls(roomWalls);
    if (polygon.isNotEmpty) {
      callbacks.updateRoom(
        _dragStartRoom!.copyWith(polygon: polygon),
      );
    }
  }

  /// Build an ordered polygon from a set of connected walls.
  List<Point2D> _buildPolygonFromWalls(List<WallSegment> walls) {
    if (walls.isEmpty) return const [];

    // Build adjacency: each endpoint maps to its wall(s).
    final points = <Point2D>[];
    var current = walls.first.startPoint;
    final visited = <String>{};

    for (var i = 0; i < walls.length; i++) {
      // Find next unvisited wall that starts or ends at current.
      WallSegment? next;
      for (final w in walls) {
        if (visited.contains(w.id)) continue;
        if (_pointsEqual(w.startPoint, current) ||
            _pointsEqual(w.endPoint, current)) {
          next = w;
          break;
        }
      }
      if (next == null) break;

      visited.add(next.id);
      if (_pointsEqual(next.startPoint, current)) {
        points.add(next.startPoint);
        current = next.endPoint;
      } else {
        points.add(next.endPoint);
        current = next.startPoint;
      }
    }

    return points;
  }

  // ----- Right-click disconnect -----

  void _handleSecondaryClick(Point2D worldPoint) {
    if (_selectedWall == null) return;

    final handleType = _hitTestHandle(worldPoint);
    if (handleType == null) return;
    if (handleType == DragHandleType.mid) return;

    final wall = _currentWallState(_selectedWall!);
    final endpoint = handleType == DragHandleType.start
        ? wall.startPoint
        : wall.endPoint;

    // Find the connected wall at this endpoint.
    WallSegment? connected;
    for (final other in callbacks.currentWalls) {
      if (other.id == wall.id) continue;
      if (_pointsEqual(other.startPoint, endpoint) ||
          _pointsEqual(other.endPoint, endpoint)) {
        connected = other;
        break;
      }
    }

    if (connected == null) return; // Not connected.

    // Disconnect by nudging the endpoint slightly (1mm offset).
    final nudged = Point2D(
      x: endpoint.x + 1,
      y: endpoint.y + 1,
    );
    final updatedWall = handleType == DragHandleType.start
        ? wall.copyWith(startPoint: nudged)
        : wall.copyWith(endPoint: nudged);

    // Check if this wall was part of a room.
    Room? destroyedRoom;
    List<String> roomWallIds = const [];
    if (wall.roomId.isNotEmpty) {
      destroyedRoom = callbacks.currentRooms
          .where((r) => r.id == wall.roomId)
          .firstOrNull;
      if (destroyedRoom != null) {
        roomWallIds = callbacks.currentWalls
            .where((w) => w.roomId == destroyedRoom!.id)
            .map((w) => w.id)
            .toList();
      }
    }

    undoRedo.execute(_DisconnectWallCommand(
      callbacks: callbacks,
      wallId: wall.id,
      oldWall: wall,
      newWall: updatedWall,
      destroyedRoom: destroyedRoom,
      roomWallIds: roomWallIds,
    ));

    // Update selection to reflect changed wall.
    _selectedWall = updatedWall;
    onStateChanged();
  }

  // ----- Deletion -----

  void _deleteSelectedWall() {
    final wall = _currentWallState(_selectedWall!);

    Room? destroyedRoom;
    List<String> roomWallIds = const [];
    if (wall.roomId.isNotEmpty) {
      destroyedRoom = callbacks.currentRooms
          .where((r) => r.id == wall.roomId)
          .firstOrNull;
      if (destroyedRoom != null) {
        roomWallIds = callbacks.currentWalls
            .where((w) => w.roomId == destroyedRoom!.id)
            .map((w) => w.id)
            .toList();
      }
    }

    undoRedo.execute(_DeleteWallCommand(
      callbacks: callbacks,
      wall: wall,
      destroyedRoom: destroyedRoom,
      roomWallIds: roomWallIds,
    ));

    _selectedWall = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  void _deleteSelectedRoom() {
    final room = _selectedRoom!;
    final wallIds = callbacks.currentWalls
        .where((w) => w.roomId == room.id)
        .map((w) => w.id)
        .toList();

    // Room deletion requires confirmation (async), so we
    // execute it immediately through the command system.
    // The caller (FloorPlanCanvas) handles the confirmation
    // dialog before invoking onDelete.
    undoRedo.execute(_DeleteRoomCommand(
      callbacks: callbacks,
      room: room,
      wallIds: wallIds,
    ));

    _selectedRoom = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  // ----- Revert drag -----

  void _revertDrag() {
    if (_dragStartWall != null) {
      callbacks.updateWall(_dragStartWall!);
    }
    for (final conn in _dragStartConnected) {
      callbacks.updateWall(conn);
    }
    if (_dragStartRoom != null) {
      callbacks.updateRoom(_dragStartRoom!);
    }
  }

  void _clearDragState() {
    _dragHandle = null;
    _dragStartWall = null;
    _dragStartConnected = const [];
    _dragStartRoom = null;
  }

  // ----- Helpers -----

  /// Get the latest version of a wall from current state.
  WallSegment _currentWallState(WallSegment wall) {
    return callbacks.currentWalls
            .where((w) => w.id == wall.id)
            .firstOrNull ??
        wall;
  }

  /// Find the nearest wall within the hit threshold.
  WallSegment? _hitTestWall(Point2D point) {
    WallSegment? nearest;
    var minDist = double.infinity;

    for (final wall in callbacks.currentWalls) {
      final dist = GeometryUtils.distanceToSegment(
        point,
        wall.startPoint,
        wall.endPoint,
      );
      if (dist < minDist) {
        minDist = dist;
        nearest = wall;
      }
    }

    if (nearest != null && minDist <= _wallHitThresholdMm) {
      return nearest;
    }
    return null;
  }

  /// Find the room whose polygon contains [point].
  Room? _hitTestRoom(Point2D point) {
    for (final room in callbacks.currentRooms) {
      if (room.polygon.length >= 3 &&
          GeometryUtils.containsPoint(room.polygon, point)) {
        return room;
      }
    }
    return null;
  }
}

// ================================================================
// Command classes for undo/redo
// ================================================================

/// Command: move/resize a wall and its connected walls.
class _MoveWallCommand extends Command {
  _MoveWallCommand({
    required this.callbacks,
    required this.oldWall,
    required this.newWall,
    required this.oldConnected,
    required this.newConnected,
    this.oldRoom,
    this.newRoom,
  });

  final EditorCallbacks callbacks;
  final WallSegment oldWall;
  final WallSegment newWall;
  final List<WallSegment> oldConnected;
  final List<WallSegment> newConnected;
  final Room? oldRoom;
  final Room? newRoom;

  @override
  String get label => 'Move wall';

  @override
  void execute() {
    callbacks.updateWall(newWall);
    for (final w in newConnected) {
      callbacks.updateWall(w);
    }
    if (newRoom != null) {
      callbacks.updateRoom(newRoom!);
    }
  }

  @override
  void undo() {
    callbacks.updateWall(oldWall);
    for (final w in oldConnected) {
      callbacks.updateWall(w);
    }
    if (oldRoom != null) {
      callbacks.updateRoom(oldRoom!);
    }
  }
}

/// Command: disconnect a wall at an endpoint.
class _DisconnectWallCommand extends Command {
  _DisconnectWallCommand({
    required this.callbacks,
    required this.wallId,
    required this.oldWall,
    required this.newWall,
    this.destroyedRoom,
    this.roomWallIds = const [],
  });

  final EditorCallbacks callbacks;
  final String wallId;
  final WallSegment oldWall;
  final WallSegment newWall;
  final Room? destroyedRoom;
  final List<String> roomWallIds;

  @override
  String get label => 'Disconnect wall';

  @override
  void execute() {
    callbacks.updateWall(newWall);
    if (destroyedRoom != null) {
      callbacks.destroyRoom(destroyedRoom!.id);
    }
  }

  @override
  void undo() {
    callbacks.updateWall(oldWall);
    if (destroyedRoom != null) {
      callbacks.restoreRoom(destroyedRoom!, roomWallIds);
    }
  }
}

/// Command: delete a wall (and its room if applicable).
class _DeleteWallCommand extends Command {
  _DeleteWallCommand({
    required this.callbacks,
    required this.wall,
    this.destroyedRoom,
    this.roomWallIds = const [],
  });

  final EditorCallbacks callbacks;
  final WallSegment wall;
  final Room? destroyedRoom;
  final List<String> roomWallIds;

  @override
  String get label => 'Delete wall';

  @override
  void execute() {
    if (destroyedRoom != null) {
      callbacks.destroyRoom(destroyedRoom!.id);
    }
    callbacks.removeWall(wall.id);
  }

  @override
  void undo() {
    callbacks.commitWall(wall);
    if (destroyedRoom != null) {
      callbacks.restoreRoom(destroyedRoom!, roomWallIds);
    }
  }
}

/// Command: delete a room (walls preserved, roomId cleared).
class _DeleteRoomCommand extends Command {
  _DeleteRoomCommand({
    required this.callbacks,
    required this.room,
    required this.wallIds,
  });

  final EditorCallbacks callbacks;
  final Room room;
  final List<String> wallIds;

  @override
  String get label => 'Delete room';

  @override
  void execute() {
    callbacks.destroyRoom(room.id);
  }

  @override
  void undo() {
    callbacks.restoreRoom(room, wallIds);
  }
}
