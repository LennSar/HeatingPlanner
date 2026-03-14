import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/geometry_utils.dart';
import '../../../data/models/distributor.dart';
import '../../../data/models/door.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';
import '../../../data/models/window_element.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';
import 'snap_service.dart';
import 'tool_base.dart';
import 'undo_redo_service.dart';

/// A hit-test result item: the element type and its ID.
typedef _HitItem = ({String type, String id});

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

  /// Cycle-click threshold in screen pixels (ADR-005).
  static const double _cycleThresholdPx = 5.0;

  /// Handle hit radius in screen pixels.
  static const double _handleHitRadiusPx = 10.0;

  /// Handle radius in world coordinates (visual size).
  static const double _handleRadiusMm = 30.0;

  /// Minimum wall length (mm).
  static const double _minLengthMm = 100.0;

  /// Minimum opening width (mm).
  static const double _minOpeningWidthMm = 300.0;

  /// Zone drag threshold in screen pixels.
  ///
  /// Movement below this threshold is treated as a click (cycles
  /// selection per ADR-005) rather than initiating a drag.
  static const double _zoneDragThresholdPx = 5.0;

  // -- Click-cycling state (ADR-005) --

  /// World position of the most recent tap.
  Point2D? _lastClickPosition;

  /// Hit stack built on the most recent fresh click.
  List<_HitItem> _lastHitStack = const [];

  /// Current index within [_lastHitStack].
  int _cycleIndex = 0;

  // -- Wall selection state --

  /// Currently selected wall, if any.
  WallSegment? _selectedWall;

  /// Currently selected room, if any.
  Room? _selectedRoom;

  /// Currently selected heating zone, if any.
  HeatingZone? _selectedZone;

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

  // -- Wall zone drag state (opening-style, for ZoneType.wallHeating) --

  /// Which of the three wall-zone handles is being dragged.
  DragHandleType? _wallZoneDragHandle;

  /// positionOnWallMm at the start of a wall-zone drag.
  double _wallZoneDragStartPos = 0.0;

  /// widthMm at the start of a wall-zone drag.
  int _wallZoneDragStartWidth = 0;

  /// The wall the zone is currently attached to during drag.
  /// May change when the zone jumps to a neighbour wall.
  WallSegment? _wallZoneDragWall;

  // -- Zone drag state --

  /// Index of the zone polygon vertex being dragged.
  /// Null while the zone body (all vertices together) is being dragged.
  int? _zoneHandleDragIndex;

  /// True once the pointer has moved beyond [_zoneDragThresholdPx],
  /// activating the actual zone drag.
  bool _zoneDragActive = false;

  /// World point where the pointer went down on the zone
  /// (anchor for threshold check and body-drag delta).
  Point2D? _zoneDragAnchorPoint;

  /// Zone snapshot captured at the start of a zone drag (for revert/undo).
  HeatingZone? _zoneAtDragStart;

  // -- Deferred-tap state (zone pointer-down suppresses onTap) --

  /// Arguments of the tap that was suppressed because the pointer went
  /// down on a selected zone.  Executed on [onPointerUp] if no drag
  /// occurred, discarded if a drag exceeded the threshold.
  ({Point2D point, PointerDeviceKind kind})? _deferredTap;

  /// Set in [onPointerDown] when the pointer lands on a selected zone.
  /// Cleared in the immediately-following [onTap] call.
  bool _zonePointerOnZone = false;

  // -- Distributor selection/drag state --

  /// True when the distributor is the selected element.
  bool _selectedDistributor = false;

  /// True when pointer went down on the selected distributor body.
  bool _distributorPointerOnBody = false;

  /// World anchor point at distributor drag start (for threshold check).
  Point2D? _distributorDragAnchor;

  /// Distributor snapshot at drag start (for revert/undo).
  Distributor? _distributorAtDragStart;

  /// True once the pointer moved past the drag threshold.
  bool _distributorDragActive = false;

  /// Which handle (start=left, mid=center, end=right) is being dragged,
  /// or null if the drag is a plain body drag.
  DragHandleType? _distributorDragHandle;

  /// Deferred tap suppressed by distributor pointer-down.
  ({Point2D point, PointerDeviceKind kind})? _distributorDeferredTap;

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
    // Ignore taps during active wall / opening drags.
    if (_dragHandle != null || _openingDragHandle != null) {
      return;
    }

    // Pointer went down on a selected distributor — defer the tap.
    if (_distributorPointerOnBody) {
      _distributorDeferredTap = (point: worldPoint, kind: deviceKind);
      _distributorPointerOnBody = false;
      return;
    }

    // Pointer went down on a selected zone — defer the tap until
    // onPointerUp so the 5 px drag threshold can be evaluated.
    // (onPointerDown fires before onTap due to Listener vs
    //  GestureDetector ordering, so the flag is already set here.)
    if (_zonePointerOnZone) {
      _deferredTap = (point: worldPoint, kind: deviceKind);
      _zonePointerOnZone = false;
      return;
    }

    _doTap(worldPoint, deviceKind);
    onStateChanged();
  }

  /// Core tap/cycling logic, extracted so it can be called both
  /// from [onTap] and from deferred-tap execution paths.
  void _doTap(Point2D worldPoint, PointerDeviceKind deviceKind) {
    final cycleMm =
        _cycleThresholdPx / callbacks.currentZoom;
    final isSamePos = _lastClickPosition != null &&
        GeometryEngine.distanceMm(
              worldPoint,
              _lastClickPosition!,
            ) <=
            cycleMm;

    if (isSamePos && _lastHitStack.isNotEmpty) {
      // Cycle to the next element in the hit stack.
      _cycleIndex =
          (_cycleIndex + 1) % _lastHitStack.length;
      final item = _lastHitStack[_cycleIndex];
      if (_itemStillExists(item)) {
        _clearAllSelections();
        _selectByHitItem(item);
      }
    } else {
      // Fresh click — build new hit stack.
      final stack = _buildHitStack(worldPoint);
      _lastClickPosition = worldPoint;
      _lastHitStack = stack;
      _cycleIndex = 0;
      _clearAllSelections();
      if (stack.isEmpty) {
        callbacks.selectElement(null, null);
      } else {
        _selectByHitItem(stack.first);
      }
    }
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

    // Zone handle / fill hit-test (when a zone is selected).
    if (_selectedZone != null) {
      final zone = callbacks.currentZones
              .where((z) => z.id == _selectedZone!.id)
              .firstOrNull ??
          _selectedZone!;

      if (zone.zoneType == ZoneType.wallHeating &&
          zone.wallSegmentId != null) {
        // ── Wall zone: opening-style handles ────────────────
        final wall = callbacks.currentWalls
            .where((w) => w.id == zone.wallSegmentId)
            .firstOrNull;
        if (wall != null) {
          final wallLen = GeometryEngine.distanceMm(
            wall.startPoint,
            wall.endPoint,
          );
          final pos = zone.positionOnWallMm ?? 0.0;
          final width =
              zone.widthMm?.toDouble() ?? wallLen;
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
              _wallZoneDragHandle = DragHandleType.values[i];
              _wallZoneDragStartPos = pos;
              _wallZoneDragStartWidth = width.round();
              _wallZoneDragWall = wall;
              _zoneAtDragStart = zone;
              onStateChanged();
              return;
            }
          }
        }
        // Click on zone body — defer tap, no body drag for wall zones.
        if (zone.polygon.length >= 3 &&
            GeometryUtils.containsPoint(zone.polygon, worldPoint)) {
          _zonePointerOnZone = true;
          onStateChanged();
          return;
        }
      } else {
        // ── Floor zone: polygon vertex / body drag ───────────
        final handleIdx = _hitTestZoneHandle(worldPoint);
        if (handleIdx != null) {
          _zoneHandleDragIndex = handleIdx;
          _zoneDragAnchorPoint = worldPoint;
          _zoneAtDragStart = zone;
          _zonePointerOnZone = true;
          onStateChanged();
          return;
        }
        if (zone.polygon.length >= 3 &&
            GeometryUtils.containsPoint(zone.polygon, worldPoint)) {
          _zoneHandleDragIndex = null;
          _zoneDragAnchorPoint = worldPoint;
          _zoneAtDragStart = zone;
          _zonePointerOnZone = true;
          onStateChanged();
          return;
        }
      }
      // Click outside selected zone — fall through to allow
      // wall-handle hit-test or tap-based cycling.
    }

    // Distributor handle / body drag initiation.
    if (_selectedDistributor) {
      final d = callbacks.currentDistributor;
      if (d != null) {
        // Check handles first.
        final zoom = callbacks.currentZoom;
        final thresholdMm =
            zoom > 0 ? _handleHitRadiusPx / zoom : _handleRadiusMm;
        final handles = _distributorHandles(d);
        DragHandleType? hitHandle;
        for (var i = 0; i < handles.length; i++) {
          if (GeometryEngine.distanceMm(worldPoint, handles[i]) <=
              thresholdMm) {
            hitHandle = DragHandleType.values[i];
            break;
          }
        }
        // Fall back to body hit.
        if (hitHandle != null ||
            _isPointOnDistributor(worldPoint, d)) {
          _distributorDragHandle = hitHandle;
          _distributorDragAnchor = worldPoint;
          _distributorAtDragStart = d;
          _distributorDragActive = false;
          _distributorPointerOnBody = true;
          onStateChanged();
          return;
        }
      }
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
    // Distributor body drag.
    if (_distributorDragAnchor != null) {
      if (!_distributorDragActive) {
        final thresholdMm =
            _zoneDragThresholdPx / callbacks.currentZoom;
        if (GeometryEngine.distanceMm(
              worldPoint,
              _distributorDragAnchor!,
            ) >=
            thresholdMm) {
          _distributorDragActive = true;
          _distributorDeferredTap = null;
        }
      }
      if (_distributorDragActive) {
        _applyDistributorDrag(worldPoint);
        onStateChanged();
      }
      return;
    }

    // Wall zone handle drag.
    if (_wallZoneDragHandle != null) {
      _applyWallZoneDrag(worldPoint);
      onStateChanged();
      return;
    }

    // Zone drag (vertex or body).
    if (_zoneDragAnchorPoint != null) {
      if (!_zoneDragActive) {
        final thresholdMm =
            _zoneDragThresholdPx / callbacks.currentZoom;
        if (GeometryEngine.distanceMm(
              worldPoint,
              _zoneDragAnchorPoint!,
            ) >=
            thresholdMm) {
          _zoneDragActive = true;
          _deferredTap = null; // discard — this is definitely a drag
        }
      }
      if (_zoneDragActive) {
        _applyZoneDrag(worldPoint);
        onStateChanged();
      }
      return;
    }

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
    // Distributor drag end.
    if (_distributorDragAnchor != null) {
      if (_distributorDragActive) {
        _commitDistributorDrag();
      } else if (_distributorDeferredTap != null) {
        final tap = _distributorDeferredTap!;
        _distributorDeferredTap = null;
        _clearDistributorDragState();
        _doTap(tap.point, tap.kind);
        onStateChanged();
        return;
      }
      _clearDistributorDragState();
      onStateChanged();
      return;
    }

    // Wall zone handle drag end.
    if (_wallZoneDragHandle != null) {
      _commitWallZoneDrag();
      _clearWallZoneDragState();
      onStateChanged();
      return;
    }

    // Zone drag end.
    if (_zoneDragAnchorPoint != null) {
      if (_zoneDragActive) {
        _commitZoneDrag();
      } else if (_deferredTap != null) {
        // Pointer moved but stayed under the 5 px threshold —
        // treat as a click and execute the deferred tap.
        final tap = _deferredTap!;
        _deferredTap = null;
        _clearZoneDragState();
        _doTap(tap.point, tap.kind);
        onStateChanged();
        return;
      }
      _clearZoneDragState();
      onStateChanged();
      return;
    }

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
    } else if (_selectedDistributor) {
      _deleteSelectedDistributor();
    } else if (_selectedZone != null) {
      _deleteSelectedZone();
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
  void onPointerUp(Point2D worldPoint) {
    // Execute deferred distributor tap.
    if (_distributorDeferredTap != null) {
      final tap = _distributorDeferredTap!;
      _distributorDeferredTap = null;
      _clearDistributorDragState();
      _doTap(tap.point, tap.kind);
      onStateChanged();
      return;
    }

    // Execute the deferred zone tap (pure click, no movement).
    if (_deferredTap != null) {
      final tap = _deferredTap!;
      _deferredTap = null;
      _clearZoneDragState();
      _doTap(tap.point, tap.kind);
      onStateChanged();
    } else {
      _clearZoneDragState();
    }
  }

  @override
  void cancel() {
    // Revert distributor drag.
    if (_distributorDragAnchor != null) {
      if (_distributorAtDragStart != null) {
        callbacks.updateDistributor(_distributorAtDragStart!);
      }
      _clearDistributorDragState();
      onStateChanged();
      return;
    }

    // Revert wall zone drag.
    if (_wallZoneDragHandle != null) {
      if (_zoneAtDragStart != null) {
        callbacks.updateZone(_zoneAtDragStart!);
        _selectedZone = _zoneAtDragStart;
      }
      _clearWallZoneDragState();
      onStateChanged();
      return;
    }

    // Revert zone drag.
    if (_zoneDragAnchorPoint != null) {
      if (_zoneAtDragStart != null) {
        callbacks.updateZone(_zoneAtDragStart!);
        _selectedZone = _zoneAtDragStart;
      }
      _clearZoneDragState();
      onStateChanged();
      return;
    }

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
    // Opening selection takes priority over everything.
    if (_selectedWindow != null || _selectedDoor != null) {
      return _buildOpeningSelectionData();
    }

    // Distributor selection.
    if (_selectedDistributor) {
      final d = callbacks.currentDistributor;
      if (d != null) {
        return DistributorSelectionData(
          position: d.position,
          widthMm: d.widthMm.toDouble(),
          handles: _distributorHandles(d),
          activeHandleIndex: _distributorDragHandle?.index,
        );
      }
    }

    // Zone selection.
    if (_selectedZone != null) {
      final zone = callbacks.currentZones
              .where((z) => z.id == _selectedZone!.id)
              .firstOrNull ??
          _selectedZone!;

      // Wall zones get opening-style selection handles.
      if (zone.zoneType == ZoneType.wallHeating &&
          zone.wallSegmentId != null) {
        return _buildWallZoneSelectionData(zone);
      }

      // Floor zones get polygon vertex handles.
      return ZoneSelectionData(
        polygon: zone.polygon,
        handles: zone.polygon,
        activeHandleIndex:
            _zoneDragActive ? _zoneHandleDragIndex : null,
      );
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
  // Zone editing helpers
  // ================================================================

  /// Returns the polygon vertex index under [worldPoint], or null.
  int? _hitTestZoneHandle(Point2D worldPoint) {
    if (_selectedZone == null) return null;
    final zone = callbacks.currentZones
            .where((z) => z.id == _selectedZone!.id)
            .firstOrNull ??
        _selectedZone!;
    final zoom = callbacks.currentZoom;
    final thresholdMm =
        zoom > 0 ? _handleHitRadiusPx / zoom : _handleRadiusMm;
    for (var i = 0; i < zone.polygon.length; i++) {
      if (GeometryEngine.distanceMm(worldPoint, zone.polygon[i]) <=
          thresholdMm) {
        return i;
      }
    }
    return null;
  }

  /// Apply the in-progress zone drag without committing an undo entry.
  void _applyZoneDrag(Point2D worldPoint) {
    final zone = _zoneAtDragStart!;
    if (_zoneHandleDragIndex != null) {
      // Vertex drag: snap vertex to grid and move it.
      final snapped = SnapService.snapToGrid(worldPoint);
      final newPolygon = List<Point2D>.from(zone.polygon);
      newPolygon[_zoneHandleDragIndex!] = snapped;
      final newZone = zone.copyWith(polygon: newPolygon);
      callbacks.updateZone(newZone);
      _selectedZone = newZone;
    } else {
      // Body drag: translate all vertices by the delta from the anchor.
      final anchor = _zoneDragAnchorPoint!;
      final dx = worldPoint.x - anchor.x;
      final dy = worldPoint.y - anchor.y;
      final newPolygon = zone.polygon
          .map((v) => Point2D(x: v.x + dx, y: v.y + dy))
          .toList();
      final newZone = zone.copyWith(polygon: newPolygon);
      callbacks.updateZone(newZone);
      _selectedZone = newZone;
    }
  }

  /// Validate the final drag position and commit an undo entry if valid;
  /// revert to [_zoneAtDragStart] and show a toast if invalid.
  void _commitZoneDrag() {
    if (_zoneAtDragStart == null) return;
    final zone = callbacks.currentZones
        .where((z) => z.id == _zoneAtDragStart!.id)
        .firstOrNull;
    if (zone == null) return;

    // Validate all vertices remain within valid rooms (ADR-006).
    final allValid =
        zone.polygon.every((v) => _isZonePointValid(v, zone));
    if (!allValid) {
      callbacks.updateZone(_zoneAtDragStart!);
      _selectedZone = _zoneAtDragStart;
      callbacks.showToast('Zone must stay within valid rooms');
      return;
    }

    final oldZone = _zoneAtDragStart!;
    if (oldZone != zone) {
      undoRedo.execute(_MoveZoneCommand(
        oldZone: oldZone,
        newZone: zone,
        update: callbacks.updateZone,
        label: _zoneHandleDragIndex != null
            ? 'Move zone vertex'
            : 'Move zone',
      ));
    }
    _selectedZone = zone;
  }

  void _clearZoneDragState() {
    _zoneHandleDragIndex = null;
    _zoneDragActive = false;
    _zoneDragAnchorPoint = null;
    _zoneAtDragStart = null;
    _deferredTap = null;
    _zonePointerOnZone = false;
  }

  /// Valid rooms for a zone drag: primary room + door-adjacent rooms (ADR-006).
  List<Room> _validRoomsForZone(HeatingZone zone) {
    final primaryRoom = callbacks.currentRooms
        .where((r) => r.id == zone.roomId)
        .firstOrNull;
    if (primaryRoom == null) return [];

    final result = <Room>[primaryRoom];

    final primaryWallIds = callbacks.currentWalls
        .where((w) => w.roomId == zone.roomId)
        .map((w) => w.id)
        .toSet();

    final doorWallIds = callbacks.currentDoors
        .where((d) => primaryWallIds.contains(d.wallSegmentId))
        .map((d) => d.wallSegmentId)
        .toSet();

    final adjacentRoomIds = callbacks.currentWalls
        .where(
          (w) => doorWallIds.contains(w.id) && w.adjacentRoomId != null,
        )
        .map((w) => w.adjacentRoomId!)
        .toSet();

    result.addAll(
      callbacks.currentRooms.where((r) => adjacentRoomIds.contains(r.id)),
    );
    return result;
  }

  bool _isZonePointValid(Point2D point, HeatingZone zone) {
    return _validRoomsForZone(zone).any(
      (r) =>
          r.polygon.length >= 3 &&
          GeometryEngine.isPointInPolygon(point, r.polygon),
    );
  }

  // ================================================================
  // Wall zone helper methods
  // ================================================================

  /// Builds [WallZoneSelectionData] for the currently selected wall zone.
  WallZoneSelectionData? _buildWallZoneSelectionData(
    HeatingZone zone,
  ) {
    // During drag the current wall may differ from zone.wallSegmentId.
    final wall = (_wallZoneDragHandle != null ? _wallZoneDragWall : null) ??
        callbacks.currentWalls
            .where((w) => w.id == zone.wallSegmentId)
            .firstOrNull;
    if (wall == null) return null;

    final wallLen =
        GeometryEngine.distanceMm(wall.startPoint, wall.endPoint);
    final pos = zone.positionOnWallMm ?? 0.0;
    final width = zone.widthMm?.toDouble() ?? wallLen;

    return WallZoneSelectionData(
      wallStart: wall.startPoint,
      wallEnd: wall.endPoint,
      positionOnWallMm: pos,
      widthMm: width,
      handles: _openingHandles(wall, pos, width),
      activeHandleIndex: _wallZoneDragHandle?.index,
    );
  }

  /// Apply a live wall-zone drag update without creating an undo command.
  ///
  /// For the centre handle, if the cursor projects outside the current
  /// wall's extent the zone jumps to the nearest in-room wall.
  void _applyWallZoneDrag(Point2D worldPoint) {
    var wall = _wallZoneDragWall;
    if (wall == null || _zoneAtDragStart == null) return;

    final startWidth = _wallZoneDragStartWidth.toDouble();
    var wallLen =
        GeometryEngine.distanceMm(wall.startPoint, wall.endPoint);

    switch (_wallZoneDragHandle!) {
      case DragHandleType.mid:
        final proj = SnapService.positionOnWallMm(worldPoint, wall);
        // Jump to nearest room wall when cursor leaves current wall.
        if (proj < 0 || proj > wallLen) {
          final nearest = _nearestRoomWall(
            worldPoint,
            excludeId: wall.id,
            roomId: _zoneAtDragStart!.roomId,
          );
          if (nearest != null) {
            wall = nearest;
            _wallZoneDragWall = wall;
            wallLen = GeometryEngine.distanceMm(
              wall.startPoint,
              wall.endPoint,
            );
          }
        }
        final rawPos =
            SnapService.positionOnWallMm(worldPoint, wall) -
                startWidth / 2;
        final snappedPos = _snapAlongWall(rawPos);
        final newPos = snappedPos.clamp(
          0.0,
          (wallLen - startWidth).clamp(0.0, double.infinity),
        );
        _applyWallZoneUpdate(wall, newPos, _wallZoneDragStartWidth);

      case DragHandleType.start:
        final rightEdge = _wallZoneDragStartPos + startWidth;
        final proj = SnapService.positionOnWallMm(worldPoint, wall);
        final maxLeft = rightEdge - _minOpeningWidthMm;
        final newLeft =
            _snapAlongWall(proj).clamp(0.0, maxLeft);
        final newWidth = (rightEdge - newLeft).round();
        _applyWallZoneUpdate(wall, newLeft, newWidth);

      case DragHandleType.end:
        final leftEdge = _wallZoneDragStartPos;
        final proj = SnapService.positionOnWallMm(worldPoint, wall);
        final minRight = leftEdge + _minOpeningWidthMm;
        final newRight =
            _snapAlongWall(proj).clamp(minRight, wallLen);
        final newWidth = (newRight - leftEdge).round();
        _applyWallZoneUpdate(wall, leftEdge, newWidth);
    }
  }

  /// Update provider state for the selected wall zone.
  void _applyWallZoneUpdate(
    WallSegment wall,
    double posOnWall,
    int widthMm,
  ) {
    if (_zoneAtDragStart == null) return;
    final polygon = _deriveWallZonePolygon(wall, posOnWall, widthMm.toDouble());
    final updated = _zoneAtDragStart!.copyWith(
      wallSegmentId: wall.id,
      positionOnWallMm: posOnWall,
      widthMm: widthMm,
      polygon: polygon,
    );
    callbacks.updateZone(updated);
    _selectedZone = updated;
  }

  /// Push an undo command after a wall-zone drag finishes.
  void _commitWallZoneDrag() {
    if (_zoneAtDragStart == null) return;
    final current = callbacks.currentZones
        .where((z) => z.id == _zoneAtDragStart!.id)
        .firstOrNull;
    if (current != null && current != _zoneAtDragStart) {
      undoRedo.execute(_UpdateWallZoneCommand(
        oldZone: _zoneAtDragStart!,
        newZone: current,
        update: callbacks.updateZone,
        label: _wallZoneDragHandle == DragHandleType.mid
            ? 'Move wall zone'
            : 'Resize wall zone',
      ));
    }
    _selectedZone = current ?? _zoneAtDragStart;
  }

  void _clearWallZoneDragState() {
    _wallZoneDragHandle = null;
    _wallZoneDragWall = null;
    _zoneAtDragStart = null;
  }

  /// Derive a 4-vertex band polygon for [wall] between [positionMm]
  /// and [positionMm] + [widthMm], matching the 200 mm visual thickness.
  static List<Point2D> _deriveWallZonePolygon(
    WallSegment wall,
    double positionMm,
    double widthMm,
  ) {
    const halfThickness = 100.0;
    final dx = wall.endPoint.x - wall.startPoint.x;
    final dy = wall.endPoint.y - wall.startPoint.y;
    final len =
        GeometryEngine.distanceMm(wall.startPoint, wall.endPoint);
    if (len < 1) {
      return [
        wall.startPoint,
        wall.endPoint,
        wall.endPoint,
        wall.startPoint,
      ];
    }

    final ux = dx / len;
    final uy = dy / len;
    final px = -uy * halfThickness;
    final py = ux * halfThickness;

    final sx = wall.startPoint.x + ux * positionMm;
    final sy = wall.startPoint.y + uy * positionMm;
    final ex = wall.startPoint.x + ux * (positionMm + widthMm);
    final ey = wall.startPoint.y + uy * (positionMm + widthMm);

    return [
      Point2D(x: sx - px, y: sy - py),
      Point2D(x: ex - px, y: ey - py),
      Point2D(x: ex + px, y: ey + py),
      Point2D(x: sx + px, y: sy + py),
    ];
  }

  /// Nearest wall in [roomId] to [point], excluding [excludeId].
  WallSegment? _nearestRoomWall(
    Point2D point, {
    required String excludeId,
    required String roomId,
  }) {
    WallSegment? nearest;
    var minDist = double.infinity;
    for (final wall in callbacks.currentWalls) {
      if (wall.id == excludeId) continue;
      if (wall.roomId != roomId) continue;
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
    return nearest;
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

  void _deleteSelectedZone() {
    final zone = _selectedZone!;
    undoRedo.execute(_DeleteZoneCommand(
      zone: zone,
      remove: callbacks.removeZone,
      add: callbacks.commitZone,
    ));
    _selectedZone = null;
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
    _selectedZone = null;
    _selectedDistributor = false;
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

  // ================================================================
  // Click-cycling helpers (ADR-005)
  // ================================================================

  /// Builds an ordered hit stack for [point] (ADR-005).
  ///
  /// Priority: openings → zones (smallest-area-first) →
  /// walls (nearest-first) → rooms (smallest-area-first).
  List<_HitItem> _buildHitStack(Point2D point) {
    final items = <_HitItem>[];

    // 1. Windows.
    final window = _hitTestWindow(point);
    if (window != null) {
      items.add((type: 'window', id: window.id));
    }

    // 2. Doors.
    final door = _hitTestDoor(point);
    if (door != null) {
      items.add((type: 'door', id: door.id));
    }

    // 3. Distributor (ADR-005: after openings, before zones).
    final dist = callbacks.currentDistributor;
    if (dist != null && _isPointOnDistributor(point, dist)) {
      items.add((type: 'distributor', id: dist.id));
    }

    // 4. Heating zones (smallest area first).
    final zones = callbacks.currentZones
        .where(
          (z) =>
              z.polygon.length >= 3 &&
              GeometryUtils.containsPoint(z.polygon, point),
        )
        .toList()
      ..sort(
        (a, b) => GeometryUtils.area(a.polygon)
            .compareTo(GeometryUtils.area(b.polygon)),
      );
    for (final z in zones) {
      items.add((type: 'zone', id: z.id));
    }

    // 4. Walls (nearest first).
    final wall = _hitTestWall(point);
    if (wall != null) {
      items.add((type: 'wall', id: wall.id));
    }

    // 5. Rooms (smallest area first).
    final rooms = callbacks.currentRooms
        .where(
          (r) =>
              r.polygon.length >= 3 &&
              GeometryUtils.containsPoint(r.polygon, point),
        )
        .toList()
      ..sort(
        (a, b) => GeometryUtils.area(a.polygon)
            .compareTo(GeometryUtils.area(b.polygon)),
      );
    for (final r in rooms) {
      items.add((type: 'room', id: r.id));
    }

    return items;
  }

  /// Select the element described by [item] and notify the
  /// properties panel.
  void _selectByHitItem(_HitItem item) {
    switch (item.type) {
      case 'window':
        final w = callbacks.currentWindows
            .where((x) => x.id == item.id)
            .firstOrNull;
        if (w != null) {
          _selectedWindow = w;
          callbacks.selectElement('window', w.id);
        }
      case 'door':
        final d = callbacks.currentDoors
            .where((x) => x.id == item.id)
            .firstOrNull;
        if (d != null) {
          _selectedDoor = d;
          callbacks.selectElement('door', d.id);
        }
      case 'distributor':
        final d = callbacks.currentDistributor;
        if (d != null && d.id == item.id) {
          _selectedDistributor = true;
          callbacks.selectElement('distributor', d.id);
        }
      case 'zone':
        final z = callbacks.currentZones
            .where((x) => x.id == item.id)
            .firstOrNull;
        if (z != null) {
          _selectedZone = z;
          callbacks.selectElement('zone', z.id);
        }
      case 'wall':
        final w = callbacks.currentWalls
            .where((x) => x.id == item.id)
            .firstOrNull;
        if (w != null) {
          _selectedWall = w;
          callbacks.selectElement('wall', w.id);
        }
      case 'room':
        final r = callbacks.currentRooms
            .where((x) => x.id == item.id)
            .firstOrNull;
        if (r != null) {
          _selectedRoom = r;
          callbacks.selectElement('room', r.id);
        }
    }
  }

  /// Returns true if the element described by [item] still
  /// exists in the current editor state.
  bool _itemStillExists(_HitItem item) {
    return switch (item.type) {
      'window' =>
        callbacks.currentWindows.any((x) => x.id == item.id),
      'door' =>
        callbacks.currentDoors.any((x) => x.id == item.id),
      'distributor' =>
        callbacks.currentDistributor?.id == item.id,
      'zone' =>
        callbacks.currentZones.any((x) => x.id == item.id),
      'wall' =>
        callbacks.currentWalls.any((x) => x.id == item.id),
      'room' =>
        callbacks.currentRooms.any((x) => x.id == item.id),
      _ => false,
    };
  }

  // ================================================================
  // Distributor helpers
  // ================================================================

  static const double _distHalfH = 240.0 / 2;
  static const double _distMinWidthMm = 100.0;

  bool _isPointOnDistributor(Point2D point, Distributor d) {
    final halfW = d.widthMm.toDouble() / 2;
    return (point.x - d.position.x).abs() <= halfW &&
        (point.y - d.position.y).abs() <= _distHalfH;
  }

  /// Three handles: [0] left edge (start), [1] centre (mid), [2] right edge (end).
  List<Point2D> _distributorHandles(Distributor d) {
    final halfW = d.widthMm.toDouble() / 2;
    return [
      Point2D(x: d.position.x - halfW, y: d.position.y),
      Point2D(x: d.position.x, y: d.position.y),
      Point2D(x: d.position.x + halfW, y: d.position.y),
    ];
  }

  void _applyDistributorDrag(Point2D worldPoint) {
    final orig = _distributorAtDragStart!;
    final halfW = orig.widthMm.toDouble() / 2;
    final snappedX =
        (worldPoint.x / SnapService.gridSpacingMm).round() *
            SnapService.gridSpacingMm;

    switch (_distributorDragHandle) {
      case DragHandleType.start: // left handle → resize from left
        final rightEdge = orig.position.x + halfW;
        final newLeft =
            snappedX.clamp(double.negativeInfinity, rightEdge - _distMinWidthMm);
        final newWidth = (rightEdge - newLeft).round();
        final newCenterX = rightEdge - newWidth / 2;
        callbacks.updateDistributor(orig.copyWith(
          position: Point2D(x: newCenterX, y: orig.position.y),
          widthMm: newWidth,
        ));
      case DragHandleType.end: // right handle → resize from right
        final leftEdge = orig.position.x - halfW;
        final newRight =
            snappedX.clamp(leftEdge + _distMinWidthMm, double.infinity);
        final newWidth = (newRight - leftEdge).round();
        final newCenterX = leftEdge + newWidth / 2;
        callbacks.updateDistributor(orig.copyWith(
          position: Point2D(x: newCenterX, y: orig.position.y),
          widthMm: newWidth,
        ));
      case DragHandleType.mid || null: // centre handle or body → move
        final snapped = SnapService.snapToGrid(worldPoint);
        callbacks.updateDistributor(orig.copyWith(position: snapped));
    }
  }

  void _commitDistributorDrag() {
    if (_distributorAtDragStart == null) return;
    final current = callbacks.currentDistributor;
    if (current != null && current != _distributorAtDragStart) {
      undoRedo.execute(_MoveDistributorCommand(
        oldDistributor: _distributorAtDragStart!,
        newDistributor: current,
        update: callbacks.updateDistributor,
      ));
    }
    _selectedDistributor = true;
  }

  void _clearDistributorDragState() {
    _distributorDragAnchor = null;
    _distributorAtDragStart = null;
    _distributorDragActive = false;
    _distributorDragHandle = null;
    _distributorDeferredTap = null;
    _distributorPointerOnBody = false;
  }

  void _deleteSelectedDistributor() {
    final d = callbacks.currentDistributor;
    if (d == null) return;
    callbacks.requestDistributorDeleteDialog(
      onConfirmed: () {
        undoRedo.execute(_DeleteDistributorCommand(
          distributor: d,
          add: callbacks.commitDistributor,
          remove: callbacks.removeDistributor,
        ));
        _selectedDistributor = false;
        callbacks.selectElement(null, null);
        onStateChanged();
      },
    );
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

/// Command: delete a heating zone.
class _DeleteZoneCommand extends Command {
  _DeleteZoneCommand({
    required this.zone,
    required this.remove,
    required this.add,
  });

  final HeatingZone zone;
  final void Function(String) remove;
  final void Function(HeatingZone) add;

  @override
  String get label => 'Delete zone';

  @override
  void execute() => remove(zone.id);

  @override
  void undo() => add(zone);
}

/// Command: move or resize a wall heating zone.
class _UpdateWallZoneCommand extends Command {
  _UpdateWallZoneCommand({
    required this.oldZone,
    required this.newZone,
    required this.update,
    required this.label,
  });

  final HeatingZone oldZone;
  final HeatingZone newZone;
  final void Function(HeatingZone) update;

  @override
  final String label;

  @override
  void execute() => update(newZone);

  @override
  void undo() => update(oldZone);
}

/// Command: move the distributor to a new position.
class _MoveDistributorCommand extends Command {
  _MoveDistributorCommand({
    required this.oldDistributor,
    required this.newDistributor,
    required this.update,
  });

  final Distributor oldDistributor;
  final Distributor newDistributor;
  final void Function(Distributor) update;

  @override
  String get label => 'Move distributor';

  @override
  void execute() => update(newDistributor);

  @override
  void undo() => update(oldDistributor);
}

/// Command: delete the distributor from the floor.
class _DeleteDistributorCommand extends Command {
  _DeleteDistributorCommand({
    required this.distributor,
    required this.add,
    required this.remove,
  });

  final Distributor distributor;
  final void Function(Distributor) add;
  final void Function() remove;

  @override
  String get label => 'Delete distributor';

  @override
  void execute() => remove();

  @override
  void undo() => add(distributor);
}

/// Command: move a zone polygon (vertex drag or body drag).
class _MoveZoneCommand extends Command {
  _MoveZoneCommand({
    required this.oldZone,
    required this.newZone,
    required this.update,
    required this.label,
  });

  final HeatingZone oldZone;
  final HeatingZone newZone;
  final void Function(HeatingZone) update;

  @override
  final String label;

  @override
  void execute() => update(newZone);

  @override
  void undo() => update(oldZone);
}
