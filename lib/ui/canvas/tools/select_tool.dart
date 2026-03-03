import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/geometry_utils.dart';
import '../../../data/models/door.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';
import '../../../data/models/window_element.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';
import 'snap_service.dart';
import 'tool_base.dart';
import 'undo_redo_service.dart';

/// Tool for selecting walls, rooms, windows, and doors by
/// clicking, and editing them via drag handles.
///
/// When a wall is selected, three drag handles appear
/// (start, mid, end). Dragging these handles moves or
/// resizes the wall. Connected walls in a room adjust
/// automatically.
///
/// When a window or door is selected, three handles appear
/// on its left edge, centre, and right edge. The centre
/// handle moves the element along the wall; the edge
/// handles resize its width.
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

  /// Minimum opening width (mm).
  static const double _minOpeningWidthMm = 300.0;

  // -- Wall selection state --

  /// Currently selected wall, if any.
  WallSegment? _selectedWall;

  /// Currently selected room, if any.
  Room? _selectedRoom;

  // -- Wall drag state --

  DragHandleType? _dragHandle;
  WallSegment? _dragStartWall;
  List<WallSegment> _dragStartConnected = const [];
  Room? _dragStartRoom;

  // -- Opening selection state --

  /// Currently selected window, if any.
  WindowElement? _selectedWindow;

  /// Currently selected door, if any.
  Door? _selectedDoor;

  // -- Opening drag state --

  DragHandleType? _openingDragHandle;

  /// positionOnWallMm at the start of an opening drag.
  double _openingDragStartPos = 0.0;

  /// widthMm at the start of an opening drag.
  int _openingDragStartWidth = 0;

  /// Snapshot of the parent wall when opening drag begins.
  WallSegment? _openingDragWall;

  /// Snapshot of the selected window at opening drag start.
  WindowElement? _dragStartWindow;

  /// Snapshot of the selected door at opening drag start.
  Door? _dragStartDoor;

  @override
  String get name => 'Select';

  // ================================================================
  // onTap
  // ================================================================

  @override
  void onTap(
    Point2D worldPoint,
    PointerDeviceKind deviceKind,
  ) {
    // Ignore taps during any drag.
    if (_dragHandle != null || _openingDragHandle != null) {
      return;
    }

    // 1. Hit-test windows (rendered on top of walls).
    final window = _hitTestWindow(worldPoint);
    if (window != null) {
      _clearAllSelections();
      _selectedWindow = window;
      callbacks.selectElement('window', window.id);
      onStateChanged();
      return;
    }

    // 2. Hit-test doors.
    final door = _hitTestDoor(worldPoint);
    if (door != null) {
      _clearAllSelections();
      _selectedDoor = door;
      callbacks.selectElement('door', door.id);
      onStateChanged();
      return;
    }

    // 3. Hit-test walls.
    final wall = _hitTestWall(worldPoint);
    if (wall != null) {
      _clearAllSelections();
      _selectedWall = wall;
      callbacks.selectElement('wall', wall.id);
      onStateChanged();
      return;
    }

    // 4. Hit-test rooms.
    final room = _hitTestRoom(worldPoint);
    if (room != null) {
      _clearAllSelections();
      _selectedRoom = room;
      callbacks.selectElement('room', room.id);
      onStateChanged();
      return;
    }

    // Nothing hit — deselect all.
    _clearAllSelections();
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  // ================================================================
  // onPointerDown
  // ================================================================

  @override
  void onPointerDown(Point2D worldPoint, int buttons) {
    // Right-click / Ctrl+click: only for wall disconnect.
    if (buttons & kSecondaryButton != 0) {
      if (_selectedWall != null) {
        _handleSecondaryClick(worldPoint);
      }
      return;
    }

    // Opening handle hit-test (takes priority over wall handles).
    if (_selectedWindow != null || _selectedDoor != null) {
      final wall = _openingParentWall;
      if (wall != null) {
        final pos = _currentOpeningPosition();
        final width = _currentOpeningWidthMm();
        final handles = _openingHandles(wall, pos, width);

        final zoom = callbacks.currentZoom;
        final thresholdMm = zoom > 0
            ? _handleHitRadiusPx / zoom
            : _handleRadiusMm;

        for (var i = 0; i < handles.length; i++) {
          if (GeometryEngine.distanceMm(
                worldPoint,
                handles[i],
              ) <=
              thresholdMm) {
            _openingDragHandle = DragHandleType.values[i];
            _openingDragStartPos = pos;
            _openingDragStartWidth = width.round();
            _openingDragWall = wall;
            _dragStartWindow = _selectedWindow;
            _dragStartDoor = _selectedDoor;
            onStateChanged();
            return;
          }
        }
      }
      // Clicked outside handles while opening selected — don't
      // start a wall drag.
      return;
    }

    // Wall handle hit-test.
    if (_selectedWall == null) return;
    final handleType = _hitTestHandle(worldPoint);
    if (handleType == null) return;

    _dragHandle = handleType;
    _dragStartWall = _selectedWall;
    _dragStartConnected = _findConnectedWalls(_selectedWall!);
    if (_selectedWall!.roomId.isNotEmpty) {
      _dragStartRoom = callbacks.currentRooms
          .where((r) => r.id == _selectedWall!.roomId)
          .firstOrNull;
    } else {
      _dragStartRoom = null;
    }
    onStateChanged();
  }

  // ================================================================
  // onDragUpdate
  // ================================================================

  @override
  void onDragUpdate(Point2D worldPoint) {
    // Opening drag.
    if (_openingDragHandle != null) {
      _applyOpeningDrag(worldPoint);
      onStateChanged();
      return;
    }

    // Wall drag.
    if (_dragHandle == null || _dragStartWall == null) return;

    final excludedIds = {
      _dragStartWall!.id,
      ..._dragStartConnected.map((w) => w.id),
    };
    final snapWalls = callbacks.currentWalls
        .where((w) => !excludedIds.contains(w.id))
        .toList();
    final snap = SnapService.snap(worldPoint, snapWalls);

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

  // ================================================================
  // onDragEnd
  // ================================================================

  @override
  void onDragEnd(Point2D worldPoint) {
    // Opening drag end.
    if (_openingDragHandle != null) {
      _commitOpeningDrag();
      _clearOpeningDragState();
      onStateChanged();
      return;
    }

    // Wall drag end.
    if (_dragHandle == null || _dragStartWall == null) {
      _clearDragState();
      return;
    }

    final currentWall = callbacks.currentWalls
        .where((w) => w.id == _dragStartWall!.id)
        .firstOrNull;

    if (currentWall == null) {
      _clearDragState();
      return;
    }

    final length = GeometryEngine.distanceMm(
      currentWall.startPoint,
      currentWall.endPoint,
    );
    if (length < _minLengthMm) {
      _revertDrag();
      callbacks.showToast(
        'Wall too short (min ${_minLengthMm.round()} mm)',
      );
      _clearDragState();
      return;
    }

    final oldWall = _dragStartWall!;
    final oldConnected = List<WallSegment>.from(_dragStartConnected);
    final oldRoom = _dragStartRoom;
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

    _selectedWall = newWall;
    _clearDragState();
  }

  // ================================================================
  // onSecondaryTap / onDelete / onPointerMove / cancel
  // ================================================================

  @override
  void onSecondaryTap(Point2D worldPoint) {
    _handleSecondaryClick(worldPoint);
  }

  @override
  void onDelete() {
    if (_selectedWindow != null) {
      _deleteSelectedWindow();
    } else if (_selectedDoor != null) {
      _deleteSelectedDoor();
    } else if (_selectedWall != null) {
      _deleteSelectedWall();
    } else if (_selectedRoom != null) {
      _deleteSelectedRoom();
    }
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    // No hover behaviour for select tool currently.
  }

  @override
  void cancel() {
    // Revert opening drag.
    if (_openingDragHandle != null) {
      if (_dragStartWindow != null) {
        callbacks.updateWindow(_dragStartWindow!);
      }
      if (_dragStartDoor != null) {
        callbacks.updateDoor(_dragStartDoor!);
      }
      _clearOpeningDragState();
      onStateChanged();
      return;
    }

    // Revert wall drag.
    if (_dragHandle != null) {
      _revertDrag();
      _clearDragState();
      onStateChanged();
      return;
    }

    // Deselect all.
    _clearAllSelections();
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  // ================================================================
  // getInteractionData
  // ================================================================

  @override
  InteractionData? getInteractionData() {
    // Opening selection takes priority over wall selection.
    if (_selectedWindow != null || _selectedDoor != null) {
      return _buildOpeningSelectionData();
    }

    if (_selectedWall == null && _selectedRoom == null) {
      return null;
    }

    final handles = <Point2D>[];
    int? activeIdx;
    if (_selectedWall != null) {
      final w = _selectedWall!;
      final currentWall = callbacks.currentWalls
              .where((wall) => wall.id == w.id)
              .firstOrNull ??
          w;
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

  // ================================================================
  // Opening helper methods
  // ================================================================

  /// Parent wall of the currently selected window or door.
  WallSegment? get _openingParentWall {
    final wallId = _selectedWindow?.wallSegmentId ??
        _selectedDoor?.wallSegmentId;
    if (wallId == null) return null;
    return callbacks.currentWalls
        .where((w) => w.id == wallId)
        .firstOrNull;
  }

  /// positionOnWallMm of the currently selected opening,
  /// refreshed from current provider state.
  double _currentOpeningPosition() {
    if (_selectedWindow != null) {
      return callbacks.currentWindows
              .where((w) => w.id == _selectedWindow!.id)
              .firstOrNull
              ?.positionOnWallMm ??
          _selectedWindow!.positionOnWallMm;
    }
    return callbacks.currentDoors
            .where((d) => d.id == _selectedDoor!.id)
            .firstOrNull
            ?.positionOnWallMm ??
        _selectedDoor!.positionOnWallMm;
  }

  /// widthMm (as double) of the currently selected opening.
  double _currentOpeningWidthMm() {
    if (_selectedWindow != null) {
      return (callbacks.currentWindows
                  .where((w) => w.id == _selectedWindow!.id)
                  .firstOrNull
                  ?.widthMm ??
              _selectedWindow!.widthMm)
          .toDouble();
    }
    return (callbacks.currentDoors
                .where((d) => d.id == _selectedDoor!.id)
                .firstOrNull
                ?.widthMm ??
            _selectedDoor!.widthMm)
        .toDouble();
  }

  /// Compute world-space handle positions for an opening.
  ///
  /// Returns three [Point2D] values on the wall centre-line:
  /// [0] = left edge, [1] = centre, [2] = right edge.
  List<Point2D> _openingHandles(
    WallSegment wall,
    double posOnWall,
    double widthMm,
  ) {
    final dx = wall.endPoint.x - wall.startPoint.x;
    final dy = wall.endPoint.y - wall.startPoint.y;
    final len =
        GeometryEngine.distanceMm(wall.startPoint, wall.endPoint);
    if (len < 1) return const [];

    final ux = dx / len;
    final uy = dy / len;
    final sx = wall.startPoint.x;
    final sy = wall.startPoint.y;

    return [
      Point2D(
        x: sx + ux * posOnWall,
        y: sy + uy * posOnWall,
      ),
      Point2D(
        x: sx + ux * (posOnWall + widthMm / 2),
        y: sy + uy * (posOnWall + widthMm / 2),
      ),
      Point2D(
        x: sx + ux * (posOnWall + widthMm),
        y: sy + uy * (posOnWall + widthMm),
      ),
    ];
  }

  /// Test whether [point] falls within the bounding rectangle
  /// of an opening on [wall] (along-wall in [posOnWall,
  /// posOnWall+widthMm]; perpendicular within half wall thickness).
  bool _isPointOnOpening(
    Point2D point,
    WallSegment wall,
    double posOnWall,
    double widthMm,
  ) {
    final dx = wall.endPoint.x - wall.startPoint.x;
    final dy = wall.endPoint.y - wall.startPoint.y;
    final len =
        GeometryEngine.distanceMm(wall.startPoint, wall.endPoint);
    if (len < 1) return false;

    final relX = point.x - wall.startPoint.x;
    final relY = point.y - wall.startPoint.y;

    // Along-wall projection (mm from wall start).
    final along = (relX * dx + relY * dy) / len;
    if (along < posOnWall || along > posOnWall + widthMm) {
      return false;
    }

    // Perpendicular distance (within half wall thickness).
    final nx = -dy / len;
    final ny = dx / len;
    final perp = (relX * nx + relY * ny).abs();
    return perp <= _wallHitThresholdMm;
  }

  /// Build [OpeningSelectionData] for the currently selected
  /// window or door.
  OpeningSelectionData? _buildOpeningSelectionData() {
    final isWindow = _selectedWindow != null;
    final id =
        isWindow ? _selectedWindow!.id : _selectedDoor!.id;
    final wallId = isWindow
        ? _selectedWindow!.wallSegmentId
        : _selectedDoor!.wallSegmentId;

    final wall = callbacks.currentWalls
        .where((w) => w.id == wallId)
        .firstOrNull;
    if (wall == null) return null;

    double posOnWall;
    double width;

    if (isWindow) {
      final current = callbacks.currentWindows
          .where((w) => w.id == id)
          .firstOrNull;
      if (current == null) return null;
      posOnWall = current.positionOnWallMm;
      width = current.widthMm.toDouble();
    } else {
      final current = callbacks.currentDoors
          .where((d) => d.id == id)
          .firstOrNull;
      if (current == null) return null;
      posOnWall = current.positionOnWallMm;
      width = current.widthMm.toDouble();
    }

    return OpeningSelectionData(
      wallStart: wall.startPoint,
      wallEnd: wall.endPoint,
      positionOnWallMm: posOnWall,
      widthMm: width,
      isWindow: isWindow,
      handles: _openingHandles(wall, posOnWall, width),
      activeHandleIndex: _openingDragHandle?.index,
    );
  }

  // ================================================================
  // Opening drag helpers
  // ================================================================

  /// Apply a live opening drag update without creating an
  /// undo command (committed on [onDragEnd]).
  void _applyOpeningDrag(Point2D worldPoint) {
    final wall = _openingDragWall;
    if (wall == null) return;

    final projMm =
        SnapService.positionOnWallMm(worldPoint, wall);
    final wallLenMm = GeometryEngine.distanceMm(
      wall.startPoint,
      wall.endPoint,
    );
    final startWidth = _openingDragStartWidth.toDouble();

    switch (_openingDragHandle!) {
      case DragHandleType.mid:
        // Move: snap the left edge to the 100 mm grid.
        final rawPos = projMm - startWidth / 2;
        final snappedPos = _snapAlongWall(rawPos);
        final newPos =
            snappedPos.clamp(0.0, wallLenMm - startWidth);
        _applyOpeningUpdate(newPos, _openingDragStartWidth);

      case DragHandleType.start:
        // Resize: fix right edge, move left edge.
        final rightEdge =
            _openingDragStartPos + startWidth;
        final maxLeft = rightEdge - _minOpeningWidthMm;
        final newLeft =
            _snapAlongWall(projMm).clamp(0.0, maxLeft);
        final newWidth = (rightEdge - newLeft).round();
        _applyOpeningUpdate(newLeft, newWidth);

      case DragHandleType.end:
        // Resize: fix left edge, move right edge.
        final leftEdge = _openingDragStartPos;
        final minRight = leftEdge + _minOpeningWidthMm;
        final newRight =
            _snapAlongWall(projMm).clamp(minRight, wallLenMm);
        final newWidth = (newRight - leftEdge).round();
        _applyOpeningUpdate(leftEdge, newWidth);
    }
  }

  /// Update provider state for the selected opening.
  void _applyOpeningUpdate(double posOnWall, int widthMm) {
    if (_dragStartWindow != null) {
      callbacks.updateWindow(
        _dragStartWindow!.copyWith(
          positionOnWallMm: posOnWall,
          widthMm: widthMm,
        ),
      );
    } else if (_dragStartDoor != null) {
      callbacks.updateDoor(
        _dragStartDoor!.copyWith(
          positionOnWallMm: posOnWall,
          widthMm: widthMm,
        ),
      );
    }
  }

  /// Push an undo command after an opening drag finishes.
  void _commitOpeningDrag() {
    if (_dragStartWindow != null) {
      final current = callbacks.currentWindows
          .where((w) => w.id == _dragStartWindow!.id)
          .firstOrNull;
      if (current != null &&
          (current.positionOnWallMm !=
                  _dragStartWindow!.positionOnWallMm ||
              current.widthMm != _dragStartWindow!.widthMm)) {
        undoRedo.execute(_UpdateWindowCommand(
          oldWindow: _dragStartWindow!,
          newWindow: current,
          update: callbacks.updateWindow,
          label: _openingDragHandle == DragHandleType.mid
              ? 'Move window'
              : 'Resize window',
        ));
      }
    } else if (_dragStartDoor != null) {
      final current = callbacks.currentDoors
          .where((d) => d.id == _dragStartDoor!.id)
          .firstOrNull;
      if (current != null &&
          (current.positionOnWallMm !=
                  _dragStartDoor!.positionOnWallMm ||
              current.widthMm != _dragStartDoor!.widthMm)) {
        undoRedo.execute(_UpdateDoorCommand(
          oldDoor: _dragStartDoor!,
          newDoor: current,
          update: callbacks.updateDoor,
          label: _openingDragHandle == DragHandleType.mid
              ? 'Move door'
              : 'Resize door',
        ));
      }
    }
  }

  void _clearOpeningDragState() {
    _openingDragHandle = null;
    _openingDragWall = null;
    _dragStartWindow = null;
    _dragStartDoor = null;
  }

  /// Snap a distance along the wall axis to the 100 mm grid.
  static double _snapAlongWall(double distanceMm) {
    return (distanceMm / SnapService.gridSpacingMm).round() *
        SnapService.gridSpacingMm;
  }

  // ================================================================
  // Opening hit-testing
  // ================================================================

  /// Find the first window under [point], or null.
  WindowElement? _hitTestWindow(Point2D point) {
    for (final window in callbacks.currentWindows) {
      final wall = callbacks.currentWalls
          .where((w) => w.id == window.wallSegmentId)
          .firstOrNull;
      if (wall == null) continue;
      if (_isPointOnOpening(
        point,
        wall,
        window.positionOnWallMm,
        window.widthMm.toDouble(),
      )) {
        return window;
      }
    }
    return null;
  }

  /// Find the first door under [point], or null.
  Door? _hitTestDoor(Point2D point) {
    for (final door in callbacks.currentDoors) {
      final wall = callbacks.currentWalls
          .where((w) => w.id == door.wallSegmentId)
          .firstOrNull;
      if (wall == null) continue;
      if (_isPointOnOpening(
        point,
        wall,
        door.positionOnWallMm,
        door.widthMm.toDouble(),
      )) {
        return door;
      }
    }
    return null;
  }

  // ================================================================
  // Opening deletion
  // ================================================================

  void _deleteSelectedWindow() {
    final window = _selectedWindow!;
    undoRedo.execute(_DeleteWindowCommand(
      window: window,
      remove: callbacks.removeWindow,
      add: callbacks.commitWindow,
    ));
    _selectedWindow = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  void _deleteSelectedDoor() {
    final door = _selectedDoor!;
    undoRedo.execute(_DeleteDoorCommand(
      door: door,
      remove: callbacks.removeDoor,
      add: callbacks.commitDoor,
    ));
    _selectedDoor = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  // ================================================================
  // Selection clear helper
  // ================================================================

  void _clearAllSelections() {
    _selectedWall = null;
    _selectedRoom = null;
    _selectedWindow = null;
    _selectedDoor = null;
  }

  // ================================================================
  // Wall handle hit-testing
  // ================================================================

  DragHandleType? _hitTestHandle(Point2D worldPoint) {
    if (_selectedWall == null) return null;
    final wall = _currentWallState(_selectedWall!);
    final start = wall.startPoint;
    final end = wall.endPoint;
    final mid = Point2D(
      x: (start.x + end.x) / 2,
      y: (start.y + end.y) / 2,
    );

    final zoom = callbacks.currentZoom;
    final thresholdMm = zoom > 0
        ? _handleHitRadiusPx / zoom
        : _handleRadiusMm;

    if (GeometryEngine.distanceMm(worldPoint, start) <=
        thresholdMm) {
      return DragHandleType.start;
    }
    if (GeometryEngine.distanceMm(worldPoint, end) <=
        thresholdMm) {
      return DragHandleType.end;
    }
    if (GeometryEngine.distanceMm(worldPoint, mid) <=
        thresholdMm) {
      return DragHandleType.mid;
    }
    return null;
  }

  // ================================================================
  // Mid-handle drag (translate wall)
  // ================================================================

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
    _adjustConnectedWalls(orig, newStart: newStart, newEnd: newEnd);
    _updateRoomPolygon();
  }

  // ================================================================
  // Endpoint handle drag (resize/pivot)
  // ================================================================

  void _applyEndpointDrag(
    Point2D snappedPoint, {
    required bool isStart,
  }) {
    final orig = _dragStartWall!;
    final updated = isStart
        ? orig.copyWith(startPoint: snappedPoint)
        : orig.copyWith(endPoint: snappedPoint);
    callbacks.updateWall(updated);
    _adjustConnectedWallAtEndpoint(
      orig,
      movedEndpoint:
          isStart ? orig.startPoint : orig.endPoint,
      newPosition: snappedPoint,
    );
    _updateRoomPolygon();
  }

  // ================================================================
  // Connected wall adjustment
  // ================================================================

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
    return (a.x - b.x).abs() < 0.01 &&
        (a.y - b.y).abs() < 0.01;
  }

  void _adjustConnectedWalls(
    WallSegment origWall, {
    required Point2D newStart,
    required Point2D newEnd,
  }) {
    for (final conn in _dragStartConnected) {
      WallSegment? updated;
      if (_pointsEqual(conn.startPoint, origWall.startPoint)) {
        updated = conn.copyWith(startPoint: newStart);
      } else if (_pointsEqual(
          conn.endPoint, origWall.startPoint)) {
        updated = conn.copyWith(endPoint: newStart);
      } else if (_pointsEqual(
          conn.startPoint, origWall.endPoint)) {
        updated = conn.copyWith(startPoint: newEnd);
      } else if (_pointsEqual(
          conn.endPoint, origWall.endPoint)) {
        updated = conn.copyWith(endPoint: newEnd);
      }
      if (updated != null) callbacks.updateWall(updated);
    }
  }

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
      if (updated != null) callbacks.updateWall(updated);
    }
  }

  // ================================================================
  // Room polygon update
  // ================================================================

  void _updateRoomPolygon() {
    if (_dragStartRoom == null) return;
    final roomId = _dragStartRoom!.id;
    final roomWalls = callbacks.currentWalls
        .where((w) => w.roomId == roomId)
        .toList();
    if (roomWalls.length < 3) return;
    final polygon = _buildPolygonFromWalls(roomWalls);
    if (polygon.isNotEmpty) {
      callbacks.updateRoom(
        _dragStartRoom!.copyWith(polygon: polygon),
      );
    }
  }

  List<Point2D> _buildPolygonFromWalls(
    List<WallSegment> walls,
  ) {
    if (walls.isEmpty) return const [];
    final points = <Point2D>[];
    var current = walls.first.startPoint;
    final visited = <String>{};

    for (var i = 0; i < walls.length; i++) {
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

  // ================================================================
  // Right-click disconnect
  // ================================================================

  void _handleSecondaryClick(Point2D worldPoint) {
    if (_selectedWall == null) return;
    final handleType = _hitTestHandle(worldPoint);
    if (handleType == null) return;
    if (handleType == DragHandleType.mid) return;

    final wall = _currentWallState(_selectedWall!);
    final endpoint = handleType == DragHandleType.start
        ? wall.startPoint
        : wall.endPoint;

    WallSegment? connected;
    for (final other in callbacks.currentWalls) {
      if (other.id == wall.id) continue;
      if (_pointsEqual(other.startPoint, endpoint) ||
          _pointsEqual(other.endPoint, endpoint)) {
        connected = other;
        break;
      }
    }
    if (connected == null) return;

    final nudged = Point2D(x: endpoint.x + 1, y: endpoint.y + 1);
    final updatedWall = handleType == DragHandleType.start
        ? wall.copyWith(startPoint: nudged)
        : wall.copyWith(endPoint: nudged);

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
    _selectedWall = updatedWall;
    onStateChanged();
  }

  // ================================================================
  // Wall deletion
  // ================================================================

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
    undoRedo.execute(_DeleteRoomCommand(
      callbacks: callbacks,
      room: room,
      wallIds: wallIds,
    ));
    _selectedRoom = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  // ================================================================
  // Drag revert helpers
  // ================================================================

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

  // ================================================================
  // Misc helpers
  // ================================================================

  WallSegment _currentWallState(WallSegment wall) {
    return callbacks.currentWalls
            .where((w) => w.id == wall.id)
            .firstOrNull ??
        wall;
  }

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
// Command classes
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
    if (newRoom != null) callbacks.updateRoom(newRoom!);
  }

  @override
  void undo() {
    callbacks.updateWall(oldWall);
    for (final w in oldConnected) {
      callbacks.updateWall(w);
    }
    if (oldRoom != null) callbacks.updateRoom(oldRoom!);
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
  void execute() => callbacks.destroyRoom(room.id);

  @override
  void undo() => callbacks.restoreRoom(room, wallIds);
}

/// Command: move or resize a window element.
class _UpdateWindowCommand extends Command {
  _UpdateWindowCommand({
    required this.oldWindow,
    required this.newWindow,
    required this.update,
    required this.label,
  });

  final WindowElement oldWindow;
  final WindowElement newWindow;
  final void Function(WindowElement) update;

  @override
  final String label;

  @override
  void execute() => update(newWindow);

  @override
  void undo() => update(oldWindow);
}

/// Command: move or resize a door element.
class _UpdateDoorCommand extends Command {
  _UpdateDoorCommand({
    required this.oldDoor,
    required this.newDoor,
    required this.update,
    required this.label,
  });

  final Door oldDoor;
  final Door newDoor;
  final void Function(Door) update;

  @override
  final String label;

  @override
  void execute() => update(newDoor);

  @override
  void undo() => update(oldDoor);
}

/// Command: delete a window element.
class _DeleteWindowCommand extends Command {
  _DeleteWindowCommand({
    required this.window,
    required this.remove,
    required this.add,
  });

  final WindowElement window;
  final void Function(String) remove;
  final void Function(WindowElement) add;

  @override
  String get label => 'Delete window';

  @override
  void execute() => remove(window.id);

  @override
  void undo() => add(window);
}

/// Command: delete a door element.
class _DeleteDoorCommand extends Command {
  _DeleteDoorCommand({
    required this.door,
    required this.remove,
    required this.add,
  });

  final Door door;
  final void Function(String) remove;
  final void Function(Door) add;

  @override
  String get label => 'Delete door';

  @override
  void execute() => remove(door.id);

  @override
  void undo() => add(door);
}
