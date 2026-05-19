import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/geometry_utils.dart';
import '../../../data/models/distributor.dart';
import '../../../data/models/door.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/heating_circuit.dart';
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

  /// Hit-test threshold for circuit polylines (mm).
  static const double _circuitHitThresholdMm = 200.0;

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
  // ADR-011: snapshot of the mirror wall's room at drag start.
  Room? _dragStartMirrorRoom;

  // -- ADR-012: Ctrl-endpoint rectangle-reshape state --

  /// Ctrl modifier held (sampled by [updateModifiers]).
  bool _ctrlHeld = false;

  /// True when the current endpoint drag is in rect-reshape mode.
  ///
  /// Sampled at drag-start and held for the duration of the drag —
  /// releasing Ctrl mid-drag does not switch modes (ADR-012 Rule 7).
  bool _rectReshapeMode = false;

  /// Diagonally opposite (fixed) corner during a rect-reshape drag.
  Point2D? _rectReshapeAnchor;

  /// Original (pre-drag) position of the dragged corner.
  Point2D? _rectReshapeOriginalCorner;

  /// Live raw cursor position used for the ghost preview (no snap).
  Point2D? _rectReshapeCursor;

  /// The 4 walls of the rectangle being reshaped.
  List<WallSegment> _rectReshapeWalls = const [];

  /// All walls snapshot before the drag started (for undo).
  List<WallSegment> _rectReshapeOldWalls = const [];

  /// All rooms snapshot before the drag started (for undo).
  List<Room> _rectReshapeOldRooms = const [];

  /// True when hovering an endpoint handle of a rectangle-eligible
  /// room (ADR-012) or a corner of a rectangle-eligible zone (ADR-013).
  ///
  /// Read by the canvas to swap the cursor to the rect-crosshair when
  /// Ctrl is held (ADR-012 Rule 8; same affordance for zones).
  bool _hoverEndpointOnRectRoom = false;

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

  // -- Zone rect-reshape state (Ctrl + corner drag, ADR-013) --

  /// True when the current zone vertex drag is a rectangle reshape.
  ///
  /// Sampled at drag-start and held for the whole drag — releasing
  /// Ctrl mid-drag does not switch modes (mirrors ADR-012 Rule 7).
  bool _zoneRectReshapeMode = false;

  /// Diagonally-opposite (fixed) zone corner during a rect reshape.
  Point2D? _zoneRectAnchor;

  /// Live raw cursor for the rect-reshape ghost (no commit until end).
  Point2D? _zoneRectCursor;

  // -- Deferred-tap state (zone pointer-down suppresses onTap) --

  /// Arguments of the tap that was suppressed because the pointer went
  /// down on a selected zone.  Executed on [onPointerUp] if no drag
  /// occurred, discarded if a drag exceeded the threshold.
  ({Point2D point, PointerDeviceKind kind})? _deferredTap;

  /// Set in [onPointerDown] when the pointer lands on a selected zone.
  /// Cleared in the immediately-following [onTap] call.
  bool _zonePointerOnZone = false;

  // -- Circuit selection state --

  /// Currently selected circuit, if any.
  HeatingCircuit? _selectedCircuit;

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
  // Modifier-key tracking (ADR-012 Rule 7)
  // ================================================================

  /// Update the Ctrl-held flag from the canvas keyboard handler.
  ///
  /// Cmd on macOS maps to the same flag via the keyboard shortcut
  /// layer. Call on both key-down and key-up so the flag stays in
  /// sync (mirrors [WallDrawTool.updateModifiers]).
  void updateModifiers({required bool ctrl}) {
    if (_ctrlHeld == ctrl) return;
    _ctrlHeld = ctrl;
    onStateChanged();
  }

  /// Set of logical keys that count as "Ctrl" for the rect-reshape
  /// gate (ADR-012). Cmd on macOS maps via the keyboard layer to the
  /// same logical role.
  static final Set<LogicalKeyboardKey> _ctrlLogicalKeys = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.meta,
  };

  /// Re-sync [_ctrlHeld] from the live hardware key state.
  ///
  /// The cached flag tracks key-down/up events forwarded from the
  /// canvas keyboard handler, but those events can be lost when focus
  /// shifts mid-shortcut (e.g., the Cmd-up after Cmd+Z when a dialog
  /// opens during undo) — leaving the cache stranded "on" and
  /// erroneously engaging rect-reshape on subsequent corner drags.
  /// Polling [HardwareKeyboard.instance.logicalKeysPressed] at
  /// drag-start makes the gate reflect the actual key state.
  ///
  /// [debugCtrlHeldOverride] lets stub-based tool tests assert the
  /// gate's logic without simulating real hardware key events.
  void _syncCtrlHeldFromHardware() {
    if (debugCtrlHeldOverride != null) {
      _ctrlHeld = debugCtrlHeldOverride!;
      return;
    }
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    _ctrlHeld = pressed.any(_ctrlLogicalKeys.contains);
  }

  /// Test-only override for the live-hardware sync in
  /// [_syncCtrlHeldFromHardware]. When non-null, the rect-reshape gate
  /// uses this value instead of polling [HardwareKeyboard].
  @visibleForTesting
  bool? debugCtrlHeldOverride;

  /// True when the canvas should swap the cursor to the rect-crosshair
  /// for the rect-reshape affordance (ADR-012 Rule 8).
  ///
  /// True iff Ctrl is held and the pointer is currently hovering an
  /// endpoint handle of a wall whose room is rectangle-eligible, or a
  /// corner of a rectangle-eligible selected zone (ADR-013).
  bool get shouldUseRectCrosshair =>
      _ctrlHeld && _hoverEndpointOnRectRoom;

  // ================================================================
  // ADR-012 rectangle helpers
  // ================================================================

  /// Axis-aligned tolerance (mm) for rectangle-eligibility and
  /// corner-identity checks (ADR-012 Rule 1).
  static const double _rectTolMm = 1.0;

  /// Returns the 4 corners of a rectangular room when [walls] satisfies
  /// the eligibility rules (ADR-012 Rule 1); otherwise returns null.
  ///
  /// Rules: exactly 4 walls, all axis-aligned within 1 mm, with 4
  /// distinct corner points using exactly 2 distinct x-values and 2
  /// distinct y-values (which implies 90° interior angles for any
  /// closed cycle through those 4 corners with axis-aligned segments).
  ///
  /// Public API: also consumed by the room properties panel as the
  /// single source of rectangle-eligibility / corner extraction for the
  /// ADR-015 Width/Height resize (the panel must not reimplement this).
  static List<Point2D>? rectangleCorners(List<WallSegment> walls) {
    if (walls.length != 4) return null;
    const tol = _rectTolMm;

    // Every wall must be axis-aligned: either Δx < tol or Δy < tol.
    for (final w in walls) {
      final dx = (w.startPoint.x - w.endPoint.x).abs();
      final dy = (w.startPoint.y - w.endPoint.y).abs();
      if (dx >= tol && dy >= tol) return null;
    }

    // Collect distinct corner points (within tolerance).
    final corners = <Point2D>[];
    bool addUnique(Point2D p) {
      for (final c in corners) {
        if ((c.x - p.x).abs() < tol && (c.y - p.y).abs() < tol) {
          return false;
        }
      }
      corners.add(p);
      return true;
    }
    for (final w in walls) {
      addUnique(w.startPoint);
      addUnique(w.endPoint);
    }
    if (corners.length != 4) return null;

    // Exactly 2 distinct x and 2 distinct y → axis-aligned rectangle.
    final xs = <double>[];
    final ys = <double>[];
    for (final c in corners) {
      if (!xs.any((v) => (v - c.x).abs() < tol)) xs.add(c.x);
      if (!ys.any((v) => (v - c.y).abs() < tol)) ys.add(c.y);
    }
    if (xs.length != 2 || ys.length != 2) return null;

    return corners;
  }

  /// Identifies the dragged corner, the diagonal anchor, and the two
  /// adjacent corners around [dragCorner] within a rectangle defined by
  /// [corners] (ADR-012 Rule 2).
  ///
  /// Returns null when [dragCorner] does not match any of the 4 corners
  /// within 1 mm tolerance, or when the rectangle is degenerate.
  ///
  /// - `anchor`: the corner whose x and y both differ from [dragCorner].
  /// - `xAdj`:   the corner sharing [dragCorner]'s x-coordinate (same
  ///             vertical edge as dragCorner).
  /// - `yAdj`:   the corner sharing [dragCorner]'s y-coordinate (same
  ///             horizontal edge as dragCorner).
  @visibleForTesting
  static ({
    Point2D dragCorner,
    Point2D anchor,
    Point2D xAdj,
    Point2D yAdj,
  })? identifyRectCornersAroundDrag(
    List<Point2D> corners,
    Point2D dragCorner,
  ) {
    const tol = _rectTolMm;
    Point2D? exact;
    for (final c in corners) {
      if ((c.x - dragCorner.x).abs() < tol &&
          (c.y - dragCorner.y).abs() < tol) {
        exact = c;
        break;
      }
    }
    if (exact == null) return null;

    Point2D? anchor;
    Point2D? xAdj;
    Point2D? yAdj;
    for (final c in corners) {
      if (identical(c, exact)) continue;
      final sameX = (c.x - exact.x).abs() < tol;
      final sameY = (c.y - exact.y).abs() < tol;
      if (sameX && !sameY) {
        xAdj = c;
      } else if (!sameX && sameY) {
        yAdj = c;
      } else if (!sameX && !sameY) {
        anchor = c;
      }
    }
    if (anchor == null || xAdj == null || yAdj == null) return null;
    return (dragCorner: exact, anchor: anchor, xAdj: xAdj, yAdj: yAdj);
  }

  /// Returns the 4 corners of a rectangular zone [polygon] when it is
  /// an axis-aligned rectangle (exactly 4 vertices, 2 distinct x and
  /// 2 distinct y within 1 mm); otherwise null (ADR-013).
  ///
  /// Zone-polygon analogue of [rectangleCorners] (which inspects wall
  /// segments). Used to gate the Ctrl + corner-drag rectangle reshape.
  @visibleForTesting
  static List<Point2D>? rectangleZoneCorners(List<Point2D> polygon) {
    if (polygon.length != 4) return null;
    const tol = _rectTolMm;
    final xs = <double>[];
    final ys = <double>[];
    for (final p in polygon) {
      if (!xs.any((v) => (v - p.x).abs() < tol)) xs.add(p.x);
      if (!ys.any((v) => (v - p.y).abs() < tol)) ys.add(p.y);
    }
    if (xs.length != 2 || ys.length != 2) return null;
    return List<Point2D>.from(polygon);
  }

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

          // ADR-013 / ADR-012-style: Ctrl + corner drag reshapes a
          // rectangular zone (diagonal corner fixed, dragged corner
          // follows). Re-sync the live key state first so a missed
          // key-up cannot strand the gate "on".
          _syncCtrlHeldFromHardware();
          _zoneRectReshapeMode = false;
          if (_ctrlHeld) {
            final corners = rectangleZoneCorners(zone.polygon);
            if (corners != null) {
              final ids = identifyRectCornersAroundDrag(
                corners,
                zone.polygon[handleIdx],
              );
              if (ids != null) {
                _zoneRectReshapeMode = true;
                _zoneRectAnchor = ids.anchor;
                _zoneRectCursor = ids.dragCorner;
              }
            }
          }
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
    // Refresh the cached _selectedWall reference from current state.
    // After an undo (or any mutation routed through
    // replaceAllWallsAndRooms), the cached instance keeps the
    // post-commit geometry while its ID still resolves — letting a
    // stale instance reach _findConnectedWalls or the rect-reshape
    // eligibility check breaks both connected-wall follow and the
    // ADR-012 corner identification.
    final refreshedSelected = callbacks.currentWalls
        .where((w) => w.id == _selectedWall!.id)
        .firstOrNull;
    if (refreshedSelected == null) {
      _selectedWall = null;
      callbacks.selectElement(null, null);
      return;
    }
    _selectedWall = refreshedSelected;

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

    // ADR-012: decide rect-reshape mode at drag-start. The flag is
    // sampled once and held for the entire drag — releasing Ctrl
    // mid-drag does not switch modes. Re-sync from the live hardware
    // state first so a missed key-up (e.g., Cmd-up swallowed when a
    // dialog opens mid-Cmd+Z) cannot strand the gate "on" and force
    // rect-reshape on a plain corner drag.
    _syncCtrlHeldFromHardware();
    _rectReshapeMode = false;
    if (_ctrlHeld &&
        (handleType == DragHandleType.start ||
            handleType == DragHandleType.end) &&
        _selectedWall!.roomId.isNotEmpty) {
      final roomWalls = callbacks.currentWalls
          .where((w) => w.roomId == _selectedWall!.roomId)
          .toList();
      final corners = rectangleCorners(roomWalls);
      if (corners != null) {
        final draggedPoint = handleType == DragHandleType.start
            ? _selectedWall!.startPoint
            : _selectedWall!.endPoint;
        final ids = identifyRectCornersAroundDrag(corners, draggedPoint);
        if (ids != null) {
          _rectReshapeMode = true;
          _rectReshapeAnchor = ids.anchor;
          _rectReshapeOriginalCorner = ids.dragCorner;
          _rectReshapeCursor = ids.dragCorner;
          _rectReshapeWalls = List<WallSegment>.unmodifiable(roomWalls);
          _rectReshapeOldWalls =
              List<WallSegment>.unmodifiable(callbacks.currentWalls);
          _rectReshapeOldRooms =
              List<Room>.unmodifiable(callbacks.currentRooms);
        }
      }
    }
    // ADR-011: snapshot the mirror wall's room so we can keep it in sync.
    final mirrorWallId = _selectedWall!.mirrorId;
    if (mirrorWallId != null) {
      final mirrorWall = callbacks.currentWalls
          .where((w) => w.id == mirrorWallId)
          .firstOrNull;
      final mirrorRoomId =
          (mirrorWall != null && mirrorWall.roomId.isNotEmpty)
              ? mirrorWall.roomId
              : null;
      _dragStartMirrorRoom = mirrorRoomId != null
          ? callbacks.currentRooms
                .where((r) => r.id == mirrorRoomId)
                .firstOrNull
          : null;
    } else {
      _dragStartMirrorRoom = null;
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
        if (_zoneRectReshapeMode) {
          // Ghost only — no state mutation until onDragEnd. Uses the
          // raw cursor for a responsive preview; the grid snap is
          // applied at commit (mirrors ADR-012 rect-reshape).
          _zoneRectCursor = worldPoint;
        } else {
          _applyZoneDrag(worldPoint);
        }
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

    // ADR-012 rect-reshape: ghost preview only, no state mutation.
    // Uses raw cursor (no snap) for a responsive ghost; the snap
    // pipeline applies at onDragEnd (Rule 4).
    if (_rectReshapeMode) {
      _rectReshapeCursor = worldPoint;
      onStateChanged();
      return;
    }

    final excludedIds = {
      _dragStartWall!.id,
      ..._dragStartConnected.map((w) => w.id),
    };
    final snapWalls = callbacks.currentWalls
        .where((w) => !excludedIds.contains(w.id))
        .toList();
    final snap = SnapService.snap(
      worldPoint,
      snapWalls,
      callbacks.currentGridSpacingMm,
    );

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
        if (_zoneRectReshapeMode) {
          _commitZoneRectReshape(worldPoint);
        } else {
          _commitZoneDrag();
        }
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

    // ADR-012 rect-reshape commit.
    if (_rectReshapeMode) {
      _commitRectReshape(worldPoint);
      _clearDragState();
      onStateChanged();
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
    final oldMirrorRoom = _dragStartMirrorRoom;
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
    // ADR-011: capture the mirror room's post-drag state for undo/redo.
    final newMirrorRoom = oldMirrorRoom != null
        ? callbacks.currentRooms
              .where((r) => r.id == oldMirrorRoom.id)
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
        oldMirrorRoom: oldMirrorRoom,
        newMirrorRoom: newMirrorRoom,
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
    } else if (_selectedCircuit != null) {
      _deleteSelectedCircuit();
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
    // Track whether the pointer is hovering an endpoint handle of a
    // rectangle-eligible room (ADR-012 Rule 8) or a corner of a
    // rectangle-eligible zone (ADR-013) so the canvas can swap the
    // cursor when Ctrl is held.
    final wasHover = _hoverEndpointOnRectRoom;
    var hovering = false;
    if (_selectedWall != null && _dragHandle == null) {
      final handle = _hitTestHandle(worldPoint);
      if (handle == DragHandleType.start || handle == DragHandleType.end) {
        final roomId = _selectedWall!.roomId;
        if (roomId.isNotEmpty) {
          final roomWalls = callbacks.currentWalls
              .where((w) => w.roomId == roomId)
              .toList();
          if (rectangleCorners(roomWalls) != null) {
            hovering = true;
          }
        }
      }
    }
    if (!hovering &&
        _selectedZone != null &&
        _zoneDragAnchorPoint == null) {
      final zone = callbacks.currentZones
          .where((z) => z.id == _selectedZone!.id)
          .firstOrNull;
      if (zone != null &&
          zone.zoneType != ZoneType.wallHeating &&
          rectangleZoneCorners(zone.polygon) != null &&
          _hitTestZoneHandle(worldPoint) != null) {
        hovering = true;
      }
    }
    _hoverEndpointOnRectRoom = hovering;
    if (wasHover != hovering) onStateChanged();
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
      // ADR-012 rect-reshape mutates no state during onDragUpdate,
      // so no revert is needed — just drop the ghost.
      if (!_rectReshapeMode) {
        _revertDrag();
      }
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
    // ADR-012 rect-reshape ghost preview takes priority while
    // the drag is in progress. Uses RectDrawData so the painter
    // renders the same four-wall outline + width/height
    // annotations as rect-mode wall drawing.
    if (_rectReshapeMode &&
        _dragHandle != null &&
        _rectReshapeAnchor != null &&
        _rectReshapeCursor != null) {
      return RectDrawData(
        corner1: _rectReshapeAnchor!,
        corner2: _rectReshapeCursor!,
      );
    }

    // Zone rect-reshape ghost (Ctrl + corner drag on a rectangular
    // zone). Shown once the drag passes the threshold; before that the
    // normal vertex handles stay visible. Reuses the rect ghost so the
    // preview matches Ctrl-drawing a new zone (ADR-013).
    if (_zoneRectReshapeMode &&
        _zoneDragActive &&
        _zoneRectAnchor != null &&
        _zoneRectCursor != null) {
      return RectDrawData(
        corner1: _zoneRectAnchor!,
        corner2: _zoneRectCursor!,
      );
    }

    // Circuit selection — no handles needed.
    if (_selectedCircuit != null) return null;

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
          rotationDeg: d.rotationDeg,
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
      final snapped = SnapService.snapToGrid(
        worldPoint,
        callbacks.currentGridSpacingMm,
      );
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

  /// Reshape a rectangular zone from a Ctrl + corner drag (ADR-013).
  ///
  /// The diagonally-opposite corner ([_zoneRectAnchor]) stays fixed;
  /// the dragged corner moves to the snapped cursor; the two adjacent
  /// corners reposition so the zone stays an axis-aligned rectangle —
  /// the same model as drawing a new rectangular zone with Ctrl
  /// (ZoneDrawTool) and as ADR-012's room reshape.
  ///
  /// Per ADR-013 zones use **pure grid snap** (Alt-aware, matching the
  /// existing zone vertex drag) — no `snapRectCorner`,
  /// `snapRectDimension`, or wall-endpoint snap. Rejects (with a toast,
  /// no mutation) when the result is < 100 mm on a side or any corner
  /// leaves a valid room (ADR-006).
  void _commitZoneRectReshape(Point2D rawCursor) {
    final anchor = _zoneRectAnchor;
    final zone0 = _zoneAtDragStart;
    if (anchor == null || zone0 == null) return;

    final zone = callbacks.currentZones
            .where((z) => z.id == zone0.id)
            .firstOrNull ??
        zone0;

    final cNew = SnapService.snapToGrid(
      rawCursor,
      callbacks.currentGridSpacingMm,
    );

    // Minimum-dimension validation (mirror ADR-012 Rule 6).
    final w = (cNew.x - anchor.x).abs();
    final h = (cNew.y - anchor.y).abs();
    if (w < _minLengthMm || h < _minLengthMm) {
      callbacks.showToast('Zone too small (min 100×100 mm)');
      return;
    }

    final tlx = math.min(anchor.x, cNew.x);
    final tly = math.min(anchor.y, cNew.y);
    final brx = math.max(anchor.x, cNew.x);
    final bry = math.max(anchor.y, cNew.y);
    final newPolygon = [
      Point2D(x: tlx, y: tly),
      Point2D(x: brx, y: tly),
      Point2D(x: brx, y: bry),
      Point2D(x: tlx, y: bry),
    ];

    // ADR-006: every corner must remain in a valid room.
    if (!newPolygon.every((p) => _isZonePointValid(p, zone))) {
      callbacks.showToast('Zone must stay within valid rooms');
      return;
    }

    final newZone = zone.copyWith(polygon: newPolygon);
    callbacks.updateZone(newZone);
    if (zone != newZone) {
      undoRedo.execute(_MoveZoneCommand(
        oldZone: zone,
        newZone: newZone,
        update: callbacks.updateZone,
        label: 'Resize zone',
      ));
    }
    _selectedZone = newZone;
  }

  void _clearZoneDragState() {
    _zoneHandleDragIndex = null;
    _zoneDragActive = false;
    _zoneDragAnchorPoint = null;
    _zoneAtDragStart = null;
    _deferredTap = null;
    _zonePointerOnZone = false;
    _zoneRectReshapeMode = false;
    _zoneRectAnchor = null;
    _zoneRectCursor = null;
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

  /// Snap a distance along the wall axis to the active grid.
  double _snapAlongWall(double distanceMm) {
    final spacing = callbacks.currentGridSpacingMm;
    return (distanceMm / spacing).round() * spacing;
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
  // Circuit hit-testing
  // ================================================================

  /// Returns true if [point] is within [_circuitHitThresholdMm] of any
  /// segment in [path].
  bool _polylineHit(List<Point2D> path, Point2D point) {
    for (var i = 0; i < path.length - 1; i++) {
      if (GeometryUtils.distanceToSegment(
            point,
            path[i],
            path[i + 1],
          ) <=
          _circuitHitThresholdMm) {
        return true;
      }
    }
    return false;
  }

  /// Returns the first circuit whose supply or return polyline is hit.
  HeatingCircuit? _hitTestCircuit(Point2D point) {
    for (final circuit in callbacks.currentCircuits) {
      if (_polylineHit(circuit.supplyRoutePath, point) ||
          _polylineHit(circuit.returnRoutePath, point)) {
        return circuit;
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
      label: callbacks.l10n.undo_deleteWindow,
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
      label: callbacks.l10n.undo_deleteDoor,
    ));
    _selectedDoor = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  void _deleteSelectedCircuit() {
    final circuit = _selectedCircuit!;
    // Snapshot the zone that is currently connected so undo can restore it.
    final connectedZone = callbacks.currentZones
        .where((z) => z.circuitId == circuit.id)
        .firstOrNull;
    undoRedo.execute(_DeleteCircuitCommand(
      circuit: circuit,
      connectedZone: connectedZone,
      remove: callbacks.removeCircuit,
      add: callbacks.commitCircuit,
      updateZone: callbacks.updateZone,
      label: callbacks.l10n.undo_deleteCircuit,
    ));
    _selectedCircuit = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  void _deleteSelectedZone() {
    final zone = _selectedZone!;
    undoRedo.execute(_DeleteZoneCommand(
      zone: zone,
      remove: callbacks.removeZone,
      add: callbacks.commitZone,
      label: callbacks.l10n.undo_deleteZone,
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
    _selectedCircuit = null;
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
      // ADR-011: the mirror wall's geometry is already fully and correctly
      // synced by updateWall's mirror path.  A second partial update here
      // would trigger ADR-011 again and corrupt the original wall.
      if (conn.mirrorId == origWall.id) continue;
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
      // ADR-011: skip the mirror wall — already synced by updateWall.
      if (conn.mirrorId == origWall.id) continue;
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
    // Room on the dragged wall's side.
    if (_dragStartRoom != null) {
      final roomId = _dragStartRoom!.id;
      final roomWalls = callbacks.currentWalls
          .where((w) => w.roomId == roomId)
          .toList();
      if (roomWalls.length >= 3) {
        final polygon = _buildPolygonFromWalls(roomWalls);
        if (polygon.isNotEmpty) {
          callbacks.updateRoom(
            _dragStartRoom!.copyWith(polygon: polygon),
          );
        }
      }
    }
    // ADR-011: also rebuild the mirror wall's room polygon.
    if (_dragStartMirrorRoom != null) {
      final mirrorRoomId = _dragStartMirrorRoom!.id;
      final mirrorRoomWalls = callbacks.currentWalls
          .where((w) => w.roomId == mirrorRoomId)
          .toList();
      if (mirrorRoomWalls.length >= 3) {
        final polygon = _buildPolygonFromWalls(mirrorRoomWalls);
        if (polygon.isNotEmpty) {
          callbacks.updateRoom(
            _dragStartMirrorRoom!.copyWith(polygon: polygon),
          );
        }
      }
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
      label: callbacks.l10n.undo_deleteWall,
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
      label: callbacks.l10n.undo_deleteRoom,
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
    // ADR-011: also restore the mirror room polygon.
    if (_dragStartMirrorRoom != null) {
      callbacks.updateRoom(_dragStartMirrorRoom!);
    }
  }

  void _clearDragState() {
    _dragHandle = null;
    _dragStartWall = null;
    _dragStartConnected = const [];
    _dragStartRoom = null;
    _dragStartMirrorRoom = null;
    _clearRectReshapeState();
  }

  void _clearRectReshapeState() {
    _rectReshapeMode = false;
    _rectReshapeAnchor = null;
    _rectReshapeOriginalCorner = null;
    _rectReshapeCursor = null;
    _rectReshapeWalls = const [];
    _rectReshapeOldWalls = const [];
    _rectReshapeOldRooms = const [];
  }

  // ================================================================
  // ADR-012 rectangle reshape commit
  // ================================================================

  /// Apply the snap pipeline, validate, and commit the four wall
  /// updates as a single undo batch (ADR-012 Rules 4–6).
  void _commitRectReshape(Point2D rawCursor) {
    final anchor = _rectReshapeAnchor;
    final original = _rectReshapeOriginalCorner;
    final roomWalls = _rectReshapeWalls;
    if (anchor == null || original == null || roomWalls.isEmpty) return;

    // Exclude the room being reshaped from snap candidates — snapping a
    // corner onto its own diagonal would collapse the room (ADR-012 Rule 4).
    final excluded = roomWalls.map((w) => w.id).toSet();
    final snapCandidates = callbacks.currentWalls
        .where((w) => !excluded.contains(w.id))
        .toList();

    // (a) grid + endpoint snap.
    final snap = SnapService.snap(
      rawCursor,
      snapCandidates,
      callbacks.currentGridSpacingMm,
    );
    // (b) rect-corner snap to other rooms' corners.
    final cornerSnapped = SnapService.snapRectCorner(
      snap.point,
      snapCandidates,
      callbacks.currentGridSpacingMm,
    );
    // (c) rect-dimension snap with the diagonal anchor as the
    // "drag-start" reference.
    final cNew = SnapService.snapRectDimension(
      anchor,
      cornerSnapped,
      snapCandidates,
    );

    // ADR-012 Rule 6: minimum-dimension validation. Both rectangle
    // width and height must be ≥ 100 mm; otherwise reject.
    final w = (cNew.x - anchor.x).abs();
    final h = (cNew.y - anchor.y).abs();
    if (w < _minLengthMm || h < _minLengthMm) {
      callbacks.showToast('Room too small (min 100×100 mm)');
      return;
    }

    // Build the remap table from old corners → new corners (Rule 3).
    final a1Old = Point2D(x: original.x, y: anchor.y);
    final a2Old = Point2D(x: anchor.x, y: original.y);
    final a1New = Point2D(x: cNew.x, y: anchor.y);
    final a2New = Point2D(x: anchor.x, y: cNew.y);

    bool eq(Point2D a, Point2D b) =>
        (a.x - b.x).abs() < _rectTolMm && (a.y - b.y).abs() < _rectTolMm;
    Point2D remap(Point2D p) {
      if (eq(p, original)) return cNew;
      if (eq(p, anchor)) return anchor;
      if (eq(p, a1Old)) return a1New;
      if (eq(p, a2Old)) return a2New;
      return p; // safety fallback — should not occur for a true rectangle
    }

    // Apply remap to each of the 4 walls. Routing through
    // EditorStateNotifier.updateWall lets ADR-011 mirror sync
    // propagate to any shared-wall partner automatically.
    for (final wall in roomWalls) {
      final updated = wall.copyWith(
        startPoint: remap(wall.startPoint),
        endPoint: remap(wall.endPoint),
      );
      callbacks.updateWall(updated);
    }

    // Update the dragged room's polygon to the new rectangle.
    final roomId = _selectedWall?.roomId ?? '';
    if (roomId.isNotEmpty) {
      final room = callbacks.currentRooms
          .where((r) => r.id == roomId)
          .firstOrNull;
      if (room != null) {
        final tlx = math.min(anchor.x, cNew.x);
        final tly = math.min(anchor.y, cNew.y);
        final brx = math.max(anchor.x, cNew.x);
        final bry = math.max(anchor.y, cNew.y);
        final polygon = [
          Point2D(x: tlx, y: tly),
          Point2D(x: brx, y: tly),
          Point2D(x: brx, y: bry),
          Point2D(x: tlx, y: bry),
        ];
        callbacks.updateRoom(room.copyWith(polygon: polygon));
      }
    }

    // Snapshot the post-state so the undo command can replay the
    // entire batch as a single atomic step (ADR-012 Rule 5).
    final newWalls = callbacks.currentWalls.toList();
    final newRooms = callbacks.currentRooms.toList();

    undoRedo.execute(_RectReshapeCommand(
      callbacks: callbacks,
      oldWalls: _rectReshapeOldWalls,
      oldRooms: _rectReshapeOldRooms,
      newWalls: newWalls,
      newRooms: newRooms,
    ));

    // Refresh the selected-wall reference to the post-update state.
    final updatedSelected = callbacks.currentWalls
        .where((wall) => wall.id == _selectedWall?.id)
        .firstOrNull;
    if (updatedSelected != null) _selectedWall = updatedSelected;
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

    // 4. Heating circuits (polyline proximity).
    final circuit = _hitTestCircuit(point);
    if (circuit != null) {
      items.add((type: 'circuit', id: circuit.id));
    }

    // 5. Heating zones (smallest area first).
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
      case 'circuit':
        final c = callbacks.currentCircuits
            .where((x) => x.id == item.id)
            .firstOrNull;
        if (c != null) {
          _selectedCircuit = c;
          callbacks.selectElement('circuit', c.id);
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
      'circuit' =>
        callbacks.currentCircuits.any((x) => x.id == item.id),
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
    final cx = d.position.x;
    final cy = d.position.y;
    final dx = point.x - cx;
    final dy = point.y - cy;
    // Transform point into the distributor's local (unrotated) space.
    final rad = -d.rotationDeg * math.pi / 180.0;
    final lx = dx * math.cos(rad) - dy * math.sin(rad);
    final ly = dx * math.sin(rad) + dy * math.cos(rad);
    final halfW = d.widthMm.toDouble() / 2;
    return lx.abs() <= halfW && ly.abs() <= _distHalfH;
  }

  /// Three handles: [0] left/start, [1] centre/mid, [2] right/end.
  ///
  /// Handle positions are rotated to match the distributor's [rotationDeg].
  List<Point2D> _distributorHandles(Distributor d) {
    final cx = d.position.x;
    final cy = d.position.y;
    final halfW = d.widthMm.toDouble() / 2;
    final rad = d.rotationDeg * math.pi / 180.0;
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);
    return [
      Point2D(x: cx - halfW * cosA, y: cy - halfW * sinA),
      Point2D(x: cx, y: cy),
      Point2D(x: cx + halfW * cosA, y: cy + halfW * sinA),
    ];
  }

  /// Returns the rotation (0–359°) that aligns the distributor parallel to
  /// the nearest wall within [SnapService.wallHoverThresholdMm].
  ///
  /// Uses the exact wall angle so any wall orientation is supported.
  /// Returns [currentRotation] unchanged when no wall is nearby.
  static int _wallSnapRotationAt(
    Point2D position,
    int currentRotation,
    List<WallSegment> walls,
  ) {
    final nearest = SnapService.nearestWall(position, walls);
    if (nearest == null) return currentRotation;
    final dx = nearest.endPoint.x - nearest.startPoint.x;
    final dy = nearest.endPoint.y - nearest.startPoint.y;
    double angleDeg = math.atan2(dy, dx) * 180.0 / math.pi;
    if (angleDeg < 0) angleDeg += 360.0;
    return angleDeg.round() % 360;
  }

  void _applyDistributorDrag(Point2D worldPoint) {
    final orig = _distributorAtDragStart!;
    final halfW = orig.widthMm.toDouble() / 2;

    // Project cursor onto the distributor's rotated axis (local space).
    final rad = orig.rotationDeg * math.pi / 180.0;
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);
    final relX = worldPoint.x - orig.position.x;
    final relY = worldPoint.y - orig.position.y;
    final projAlong = relX * cosA + relY * sinA;
    final snappedProj =
        (projAlong / callbacks.currentGridSpacingMm).round() *
            callbacks.currentGridSpacingMm;

    switch (_distributorDragHandle) {
      case DragHandleType.start: // start/left handle — right edge fixed
        final newLeftProj = snappedProj.clamp(
          double.negativeInfinity,
          halfW - _distMinWidthMm,
        );
        final newWidth = (halfW - newLeftProj).round();
        final newCenterOffset = (halfW + newLeftProj) / 2.0;
        callbacks.updateDistributor(orig.copyWith(
          position: Point2D(
            x: orig.position.x + newCenterOffset * cosA,
            y: orig.position.y + newCenterOffset * sinA,
          ),
          widthMm: newWidth,
        ));
      case DragHandleType.end: // end/right handle — left edge fixed
        final newRightProj = snappedProj.clamp(
          -halfW + _distMinWidthMm,
          double.infinity,
        );
        final newWidth = (newRightProj + halfW).round();
        final newCenterOffset = (-halfW + newRightProj) / 2.0;
        callbacks.updateDistributor(orig.copyWith(
          position: Point2D(
            x: orig.position.x + newCenterOffset * cosA,
            y: orig.position.y + newCenterOffset * sinA,
          ),
          widthMm: newWidth,
        ));
      case DragHandleType.mid || null: // body / centre handle — move + wall snap
        final snapped = SnapService.snapToGrid(
          worldPoint,
          callbacks.currentGridSpacingMm,
        );
        final newRotation = _wallSnapRotationAt(
          snapped,
          orig.rotationDeg,
          callbacks.currentWalls,
        );
        callbacks.updateDistributor(orig.copyWith(
          position: snapped,
          rotationDeg: newRotation,
        ));
    }
  }

  /// Cycle the selected distributor's rotation 90° clockwise.
  void onRotateDistributor() {
    if (!_selectedDistributor) return;
    final d = callbacks.currentDistributor;
    if (d == null) return;
    final newRotation = (d.rotationDeg + 90) % 360;
    final updated = d.copyWith(rotationDeg: newRotation);
    undoRedo.execute(_MoveDistributorCommand(
      oldDistributor: d,
      newDistributor: updated,
      update: callbacks.updateDistributor,
      label: callbacks.l10n.undo_rotateDistributor,
    ));
    onStateChanged();
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
          label: callbacks.l10n.undo_deleteDistributor,
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
    this.oldMirrorRoom,
    this.newMirrorRoom,
  });

  final EditorCallbacks callbacks;
  final WallSegment oldWall;
  final WallSegment newWall;
  final List<WallSegment> oldConnected;
  final List<WallSegment> newConnected;
  final Room? oldRoom;
  final Room? newRoom;
  // ADR-011: mirror room snapshots for undo/redo.
  final Room? oldMirrorRoom;
  final Room? newMirrorRoom;

  @override
  String get label => 'Move wall';

  @override
  void execute() {
    callbacks.updateWall(newWall);
    for (final w in newConnected) {
      callbacks.updateWall(w);
    }
    if (newRoom != null) callbacks.updateRoom(newRoom!);
    if (newMirrorRoom != null) callbacks.updateRoom(newMirrorRoom!);
  }

  @override
  void undo() {
    callbacks.updateWall(oldWall);
    for (final w in oldConnected) {
      callbacks.updateWall(w);
    }
    if (oldRoom != null) callbacks.updateRoom(oldRoom!);
    if (oldMirrorRoom != null) callbacks.updateRoom(oldMirrorRoom!);
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
    required this.label,
    this.destroyedRoom,
    this.roomWallIds = const [],
  });

  final EditorCallbacks callbacks;
  final WallSegment wall;
  final Room? destroyedRoom;
  final List<String> roomWallIds;

  @override
  final String label;

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
    required this.label,
  });

  final EditorCallbacks callbacks;
  final Room room;
  final List<String> wallIds;

  @override
  final String label;

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
    required this.label,
  });

  final WindowElement window;
  final void Function(String) remove;
  final void Function(WindowElement) add;

  @override
  final String label;

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
    required this.label,
  });

  final Door door;
  final void Function(String) remove;
  final void Function(Door) add;

  @override
  final String label;

  @override
  void execute() => remove(door.id);

  @override
  void undo() => add(door);
}

/// Command: delete a heating circuit and disconnect its zone.
class _DeleteCircuitCommand extends Command {
  _DeleteCircuitCommand({
    required this.circuit,
    required this.connectedZone,
    required this.remove,
    required this.add,
    required this.updateZone,
    required this.label,
  });

  final HeatingCircuit circuit;
  final HeatingZone? connectedZone;
  final void Function(String) remove;
  final void Function(HeatingCircuit) add;
  final void Function(HeatingZone) updateZone;

  @override
  final String label;

  @override
  void execute() => remove(circuit.id);

  @override
  void undo() {
    add(circuit);
    if (connectedZone != null) {
      updateZone(connectedZone!);
    }
  }
}

/// Command: delete a heating zone.
class _DeleteZoneCommand extends Command {
  _DeleteZoneCommand({
    required this.zone,
    required this.remove,
    required this.add,
    required this.label,
  });

  final HeatingZone zone;
  final void Function(String) remove;
  final void Function(HeatingZone) add;

  @override
  final String label;

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

/// Command: move or rotate the distributor.
class _MoveDistributorCommand extends Command {
  _MoveDistributorCommand({
    required this.oldDistributor,
    required this.newDistributor,
    required this.update,
    String? label,
  }) : _label = label ?? 'Move distributor';

  final Distributor oldDistributor;
  final Distributor newDistributor;
  final void Function(Distributor) update;
  final String _label;

  @override
  String get label => _label;

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
    required this.label,
  });

  final Distributor distributor;
  final void Function(Distributor) add;
  final void Function() remove;

  @override
  final String label;

  @override
  void execute() => remove();

  @override
  void undo() => add(distributor);
}

/// Command: ADR-012 rectangle-reshape — four wall updates + room polygon
/// update committed as a single atomic snapshot.
///
/// Stores the full walls/rooms lists before and after the reshape so
/// the entire batch (including any ADR-011 mirror-wall partner updates
/// triggered by the four `updateWall` calls) can be reverted as one
/// undo step.
class _RectReshapeCommand extends Command {
  _RectReshapeCommand({
    required this.callbacks,
    required this.oldWalls,
    required this.oldRooms,
    required this.newWalls,
    required this.newRooms,
  });

  final EditorCallbacks callbacks;
  final List<WallSegment> oldWalls;
  final List<Room> oldRooms;
  final List<WallSegment> newWalls;
  final List<Room> newRooms;

  @override
  String get label => 'Reshape rectangle';

  @override
  void execute() =>
      callbacks.replaceAllWallsAndRooms(newWalls, newRooms);

  @override
  void undo() =>
      callbacks.replaceAllWallsAndRooms(oldWalls, oldRooms);
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
