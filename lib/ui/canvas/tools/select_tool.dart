import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../calculation/providers/pipe_layout_providers.dart';
import '../../../core/utils/geometry_utils.dart';
import '../../../core/utils/id_generator.dart';
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
import 'circuit_commands.dart';
import 'editor_callbacks.dart';
import 'snap_service.dart';
import 'split_zone_command.dart';
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

  /// Walls in the multi-selection (Ctrl/Cmd-click).
  ///
  /// Length >= 2 means "group mode" — a body drag on any member translates
  /// every member rigidly (see [_applyGroupDrag]). Length <= 1 means normal
  /// single-wall behaviour. The last element is the primary and mirrors
  /// [_selectedWall]. Reset by [_clearAllSelections].
  List<WallSegment> _multiWalls = const [];

  /// Currently selected room, if any.
  Room? _selectedRoom;

  /// Currently selected heating zone, if any.
  HeatingZone? _selectedZone;

  // -- Wall drag state --

  DragHandleType? _dragHandle;
  WallSegment? _dragStartWall;
  List<WallSegment> _dragStartConnected = const [];

  /// ADR-035: square-snap guides for a dragged room corner. Each incident
  /// wall pivots about its fixed far end (`_squareAnchorA` / `_squareAnchorB`)
  /// and snaps to run along the unit direction (`_squareDirA` / `_squareDirB`)
  /// that is perpendicular to its adjacent wall. Set at drag-start for a plain
  /// corner (endpoint) drag whose room neighbours are known; null otherwise
  /// (so the snap stays off for free walls and rect-reshape).
  Point2D? _squareAnchorA;
  Point2D? _squareDirA;
  Point2D? _squareAnchorB;
  Point2D? _squareDirB;
  // World point where a wall-body (translate) drag was grabbed, so the
  // wall follows the pointer by that offset instead of snapping its
  // midpoint to the cursor (no jump when grabbed away from the middle).
  Point2D? _wallDragAnchor;
  Room? _dragStartRoom;
  // ADR-011: snapshot of the mirror wall's room at drag start.
  Room? _dragStartMirrorRoom;

  // -- Multi-wall group drag state (>= 2 walls selected) --

  /// The selected walls, frozen at group-drag start (translated each frame
  /// from these snapshots so motion is never accumulated).
  List<WallSegment> _groupWallsAtStart = const [];

  /// Non-group walls that shared an endpoint with a group wall at drag
  /// start (their shared corner follows the translation). Includes ADR-011
  /// mirror partners, which share both endpoints and so translate wholly.
  List<WallSegment> _groupConnectedAtStart = const [];

  /// Rooms whose polygon is rebuilt from its (now-moved) walls each frame.
  Set<String> _groupRoomIds = const {};

  /// World point where the group drag was grabbed.
  Point2D? _groupDragAnchor;

  /// True once the pointer crossed the drag threshold — the gesture is a
  /// confirmed group move (below the threshold it stays a click).
  bool _groupDragActive = false;

  /// Full pre-drag snapshots (all walls / rooms) so the move commits and
  /// reverts atomically via [_GroupMoveWallsCommand].
  List<WallSegment> _groupOldWalls = const [];
  List<Room> _groupOldRooms = const [];

  /// True when the group drag keeps every wall's orientation (ADR-027): the
  /// selection slides perpendicular to itself and connected walls only
  /// change length, never angle. Sampled (Ctrl/Shift held) at drag start
  /// and held for the whole drag, mirroring [_keepWallOrientation].
  bool _groupKeepOrientation = false;

  /// The selected wall under the grab point — its direction defines the
  /// slide normal for [_applyGroupDragKeepOrientation].
  WallSegment? _groupGrabWall;

  // -- ADR-012: Ctrl-endpoint rectangle-reshape state --

  /// Ctrl modifier held (sampled by [updateModifiers]).
  bool _ctrlHeld = false;

  /// Shift modifier held (sampled by [updateModifiers]).
  ///
  /// Used together with Ctrl to gate the keep-orientation wall-body
  /// translate (ADR-027): while either is held, dragging a wall's mid
  /// handle slides the wall parallel to itself and the connected walls
  /// only change length, never orientation.
  bool _shiftHeld = false;

  /// True when the current mid-handle (wall-body) drag is in
  /// keep-orientation mode (ADR-027).
  ///
  /// Sampled at drag-start (Shift or Ctrl held) and held for the whole
  /// drag — toggling the modifier mid-drag does not switch modes,
  /// mirroring the ADR-012 Rule 7 convention.
  bool _keepWallOrientation = false;

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

  // -- Connection pipe edit state (ADR-039 Rule 1) --

  /// Circuit as it was before the drag — restored on cancel and kept
  /// as the undo snapshot. Null when no pipe drag is armed.
  HeatingCircuit? _circuitDragOriginal;

  /// Circuit the drag offsets are applied to: [_circuitDragOriginal],
  /// plus the corner inserted when a section next to the distributor
  /// is grabbed.
  HeatingCircuit? _circuitDragBase;

  /// Route points that follow the pointer during the drag.
  List<_RoutePointRef> _circuitDragTargets = const [];

  /// World point where the pointer went down on the pipe.
  Point2D? _circuitDragAnchor;

  /// True once the pointer has moved past the drag threshold.
  bool _circuitDragActive = false;

  /// True when a single corner is dragged (snaps to the grid itself);
  /// false when a section is translated (its offset snaps).
  bool _circuitDragIsCorner = false;

  // -- Zone edge drag state (linked boundary, ADR-037 Rule 5) --

  /// Zones taking part in the active edge drag, captured at pointer-down
  /// together with the polygon vertex indices that lie on the dragged
  /// boundary line. Empty when no edge drag is armed.
  List<({HeatingZone zone, List<int> indices})> _zoneEdgeDragParts =
      const [];

  /// Unit normal of the dragged boundary line (the only direction the
  /// boundary moves in).
  Point2D? _zoneEdgeDragNormal;

  /// Unit normal of the zone boundary under the hovering pointer, or
  /// null. Drives the resize cursor.
  Point2D? _hoverZoneEdgeNormal;

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

  // -- ADR-016: Room-interior drag (move entire room) --

  /// True when [onPointerDown] landed inside a room interior (not on a
  /// wall hit-band or wall handle) and the press has yet to resolve into
  /// either a "move" (drag past threshold) or a plain "select" (release
  /// within threshold). Mirrors the [_zonePointerOnZone] / deferred-tap
  /// flow used for zones.
  bool _roomPointerInside = false;

  /// World-space anchor recorded when [_roomPointerInside] is armed.
  ///
  /// Used to: (1) gate the drag-threshold check in [onDragUpdate],
  /// (2) compute the grid-snapped translation delta as
  /// `snappedCursor − dragStart` (ADR-016 Rule 2).
  Point2D? _roomMoveAnchor;

  /// The room that will translate during a confirmed room-move drag.
  ///
  /// Captured at pointer-down so the drag uses the room snapshot from
  /// that moment even if other providers refresh mid-gesture.
  Room? _roomMoveRoom;

  /// Snapshot of the moved room's walls at pointer-down (the pre-move
  /// geometry that the commit translates from and that undo restores).
  List<WallSegment> _roomMoveWallsAtStart = const [];

  /// Snapshot of the moved room's zones at pointer-down (their polygons
  /// translate with the room, per ADR-016 Rule 2).
  List<HeatingZone> _roomMoveZonesAtStart = const [];

  /// Full pre-move snapshot (all walls / rooms / zones) — used so the
  /// "Move room" command can revert detaches, splits, promotions, and
  /// mirror-copy insertions in a single atomic `replaceAll...` (Rule 5).
  List<WallSegment> _roomMoveOldWalls = const [];
  List<Room> _roomMoveOldRooms = const [];
  List<HeatingZone> _roomMoveOldZones = const [];

  /// True once the pointer has crossed [_zoneDragThresholdPx] of the
  /// anchor — the gesture is now a confirmed room move and the ghost
  /// preview becomes visible.
  bool _roomMoveDragActive = false;

  /// Current snapped translation in world-mm. Updated every frame
  /// during the drag and used to render the ghost (ADR-016 Rule 2).
  Point2D _roomMoveDelta = const Point2D(x: 0, y: 0);

  /// Alt-held flag forwarded by the canvas keyboard handler.
  ///
  /// When true, [onDragUpdate] uses the raw cursor (no grid snap) for
  /// the translation, mirroring the Alt = free-placement convention
  /// the other tools follow.
  bool _altHeld = false;

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

  /// Update the modifier-key flags from the canvas keyboard handler.
  ///
  /// Cmd on macOS maps to the same Ctrl flag via the keyboard shortcut
  /// layer. Call on both key-down and key-up so the flags stay in sync
  /// (mirrors [WallDrawTool.updateModifiers]). [alt] is read by the
  /// ADR-016 room-move drag to disable grid snap (free placement).
  void updateModifiers({
    required bool ctrl,
    bool shift = false,
    bool alt = false,
  }) {
    if (_ctrlHeld == ctrl && _shiftHeld == shift && _altHeld == alt) return;
    _ctrlHeld = ctrl;
    _shiftHeld = shift;
    _altHeld = alt;
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

  /// Set of logical keys that count as "Shift" for the keep-orientation
  /// wall-drag gate (ADR-027).
  static final Set<LogicalKeyboardKey> _shiftLogicalKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.shift,
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
    } else {
      final pressed = HardwareKeyboard.instance.logicalKeysPressed;
      _ctrlHeld = pressed.any(_ctrlLogicalKeys.contains);
    }
    if (debugShiftHeldOverride != null) {
      _shiftHeld = debugShiftHeldOverride!;
    } else {
      final pressed = HardwareKeyboard.instance.logicalKeysPressed;
      _shiftHeld = pressed.any(_shiftLogicalKeys.contains);
    }
  }

  /// Test-only override for the live-hardware sync in
  /// [_syncCtrlHeldFromHardware]. When non-null, the rect-reshape gate
  /// uses this value instead of polling [HardwareKeyboard].
  @visibleForTesting
  bool? debugCtrlHeldOverride;

  /// Test-only override for the Shift state read by
  /// [_syncCtrlHeldFromHardware] (ADR-027 keep-orientation gate).
  @visibleForTesting
  bool? debugShiftHeldOverride;

  /// True when the canvas should swap the cursor to the rect-crosshair
  /// for the rect-reshape affordance (ADR-012 Rule 8).
  ///
  /// True iff Ctrl is held and the pointer is currently hovering an
  /// endpoint handle of a wall whose room is rectangle-eligible, or a
  /// corner of a rectangle-eligible selected zone (ADR-013).
  bool get shouldUseRectCrosshair =>
      _ctrlHeld && _hoverEndpointOnRectRoom;

  /// True when the canvas should show the grab (or grabbing) hand
  /// cursor for the room-interior move affordance (ADR-016, UI/UX
  /// §6.2). `grab` while hovering an unhandled room interior; flips to
  /// `grabbing` once the pointer is actively dragging the room.
  bool _hoverOnRoomInterior = false;

  /// Unit normal of the draggable zone boundary under the pointer (or
  /// of the boundary being dragged), or null when there is none
  /// (ADR-037 Rule 5). The canvas shows a resize cursor along it.
  Point2D? get zoneEdgeResizeNormal => _zoneEdgeDragParts.isNotEmpty
      ? _zoneEdgeDragNormal
      : _hoverZoneEdgeNormal;

  /// True when the room-move drag is active (past threshold). The
  /// canvas reads this to switch from "grab" to "grabbing".
  bool get isMovingRoom => _roomMoveDragActive;

  /// True when the cursor is hovering a room interior with no
  /// handle / opening / zone competing for it.
  bool get shouldUseGrabCursor => _hoverOnRoomInterior;

  // ================================================================
  // ADR-012 rectangle helpers
  // ================================================================

  /// Axis-aligned tolerance (mm) for rectangle-eligibility and
  /// corner-identity checks (ADR-012 Rule 1).
  static const double _rectTolMm = 1.0;

  /// Returns the 4 corners of a rectangular room when [walls] satisfies
  /// the eligibility rules (ADR-012 Rule 1); otherwise returns null.
  ///
  /// Rules: at least 4 walls, all axis-aligned within 1 mm, whose **true
  /// corners** (endpoints where a horizontal and a vertical wall meet) are
  /// exactly 4 distinct points using exactly 2 distinct x-values and 2
  /// distinct y-values (→ 90° interior angles).
  ///
  /// A shared wall is often split into two collinear fragments when an
  /// adjacent room is attached (ADR-003), so a geometrically rectangular room
  /// can carry 5+ walls with a 180° "straight" vertex mid-edge. Those
  /// collinear mid-edge points are not real corners and are ignored, so the
  /// room stays rectangle-eligible (its Width/Height dimensions keep showing).
  ///
  /// Public API: also consumed by the room properties panel as the
  /// single source of rectangle-eligibility / corner extraction for the
  /// ADR-015 Width/Height resize (the panel must not reimplement this).
  static List<Point2D>? rectangleCorners(List<WallSegment> walls) {
    if (walls.length < 4) return null;
    const tol = _rectTolMm;

    // Every wall must be axis-aligned: either Δx < tol or Δy < tol.
    for (final w in walls) {
      final dx = (w.startPoint.x - w.endPoint.x).abs();
      final dy = (w.startPoint.y - w.endPoint.y).abs();
      if (dx >= tol && dy >= tol) return null;
      if (dx < tol && dy < tol) return null; // degenerate (zero-length)
    }

    bool isHorizontal(WallSegment w) =>
        (w.startPoint.y - w.endPoint.y).abs() < tol;

    // Collect distinct endpoints and, per point, whether a horizontal and/or
    // a vertical wall is incident. A true corner has both; a collinear
    // mid-edge point (from an ADR-003 split) has only one orientation.
    final pts = <Point2D>[];
    final hasH = <bool>[];
    final hasV = <bool>[];
    void mark(Point2D p, bool horizontal) {
      for (var i = 0; i < pts.length; i++) {
        if ((pts[i].x - p.x).abs() < tol && (pts[i].y - p.y).abs() < tol) {
          if (horizontal) {
            hasH[i] = true;
          } else {
            hasV[i] = true;
          }
          return;
        }
      }
      pts.add(p);
      hasH.add(horizontal);
      hasV.add(!horizontal);
    }

    for (final w in walls) {
      final h = isHorizontal(w);
      mark(w.startPoint, h);
      mark(w.endPoint, h);
    }

    final corners = <Point2D>[
      for (var i = 0; i < pts.length; i++)
        if (hasH[i] && hasV[i]) pts[i],
    ];
    if (corners.length != 4) return null;

    // Exactly 2 distinct x and 2 distinct y → axis-aligned rectangle.
    final xs = <double>[];
    final ys = <double>[];
    for (final c in corners) {
      if (!xs.any((v) => (v - c.x).abs() < tol)) xs.add(c.x);
      if (!ys.any((v) => (v - c.y).abs() < tol)) ys.add(c.y);
    }
    if (xs.length != 2 || ys.length != 2) return null;

    // Every wall must lie on the rectangle's boundary — a horizontal wall on
    // one of the two y-lines, a vertical wall on one of the two x-lines. This
    // rejects a rectangle carrying a stray interior wall (whose endpoints were
    // filtered out above as non-corners) while still accepting collinear edge
    // splits (which sit on a boundary line).
    for (final w in walls) {
      if (isHorizontal(w)) {
        if ((w.startPoint.y - ys[0]).abs() >= tol &&
            (w.startPoint.y - ys[1]).abs() >= tol) {
          return null;
        }
      } else {
        if ((w.startPoint.x - xs[0]).abs() >= tol &&
            (w.startPoint.x - xs[1]).abs() >= tol) {
          return null;
        }
      }
    }

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

    // Pointer went down inside a room interior — defer the tap so
    // drag past threshold becomes a "Move room" and release within
    // threshold still only selects (ADR-016 Rule 1).
    if (_roomPointerInside) {
      _deferredTap = (point: worldPoint, kind: deviceKind);
      _roomPointerInside = false;
      return;
    }

    _doTap(worldPoint, deviceKind);
    onStateChanged();
  }

  /// Core tap/cycling logic, extracted so it can be called both
  /// from [onTap] and from deferred-tap execution paths.
  void _doTap(Point2D worldPoint, PointerDeviceKind deviceKind) {
    // Ctrl/Cmd-click toggles a wall in the multi-selection (additive),
    // bypassing the ADR-005 single-element cycle. Re-sync the live key
    // state first so a missed key-up cannot strand the gate. On macOS the
    // gesture is Cmd-click (literal Ctrl-click is a system right-click).
    _syncCtrlHeldFromHardware();
    if (_ctrlHeld) {
      final hit = _hitTestWall(worldPoint);
      if (hit != null) {
        _toggleWallInMultiSelect(hit);
        return;
      }
    }

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

    // ADR-039 Rule 1: a press on a corner or a section of the selected
    // circuit's connection pipes drags it.
    if (_tryBeginCircuitDrag(worldPoint)) {
      onStateChanged();
      return;
    }

    // ADR-037 Rule 5: a press on a zone boundary drags that boundary;
    // every zone sharing it follows.
    if (_tryBeginZoneEdgeDrag(worldPoint)) {
      onStateChanged();
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

    // Multi-wall group drag: a body press on any selected wall translates
    // every selected wall together (ADR-034). Takes priority over the
    // single-wall handle path below.
    if (_multiWalls.length >= 2 && _isPointOnAnyGroupWall(worldPoint)) {
      _beginGroupDrag(worldPoint);
      return;
    }

    // Wall handle hit-test.
    if (_selectedWall == null) {
      _armRoomMoveIfApplicable(worldPoint);
      return;
    }
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
    if (handleType == null) {
      // Not on a wall handle — drop any wall-drag state still armed from a
      // prior press so it can't drive a stale-anchor translate on the next
      // drag-update, then fall back to the room-move arming.
      _clearDragState();
      _armRoomMoveIfApplicable(worldPoint);
      return;
    }

    _dragHandle = handleType;
    _wallDragAnchor =
        handleType == DragHandleType.mid ? worldPoint : null;
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

    // ADR-027: keep-orientation wall-body translate. When the mid handle
    // is grabbed with Shift or Ctrl held, the wall slides parallel to
    // itself and connected walls only change length, never orientation
    // (a square room stays square). Sampled once and held for the whole
    // drag, mirroring the ADR-012 Rule 7 convention.
    _keepWallOrientation = handleType == DragHandleType.mid &&
        (_ctrlHeld || _shiftHeld);

    _rectReshapeMode = false;
    if (_ctrlHeld &&
        _multiWalls.length < 2 &&
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

    // ADR-035: capture the dragged corner's square-snap guides so a plain
    // (non-rect-reshape) corner drag can lock to 90°. Skipped for the mid
    // handle and whenever rect-reshape (ADR-012) owns the drag.
    _squareAnchorA = null;
    _squareDirA = null;
    _squareAnchorB = null;
    _squareDirB = null;
    if (!_rectReshapeMode &&
        (handleType == DragHandleType.start ||
            handleType == DragHandleType.end)) {
      final corner = handleType == DragHandleType.start
          ? _selectedWall!.startPoint
          : _selectedWall!.endPoint;
      _captureCornerSquareGuides(corner);
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

    // Connection pipe corner / section drag (ADR-039 Rule 1).
    if (_circuitDragAnchor != null) {
      if (!_circuitDragActive) {
        final thresholdMm =
            _zoneDragThresholdPx / callbacks.currentZoom;
        if (GeometryEngine.distanceMm(worldPoint, _circuitDragAnchor!) >=
            thresholdMm) {
          _circuitDragActive = true;
          _deferredTap = null; // definitely a drag
        }
      }
      if (_circuitDragActive) {
        _applyCircuitDrag(worldPoint);
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
        if (_zoneEdgeDragParts.isNotEmpty) {
          _applyZoneEdgeDrag(worldPoint);
        } else if (_zoneRectReshapeMode) {
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

    // ADR-016: room-interior drag.
    if (_roomMoveAnchor != null) {
      if (!_roomMoveDragActive) {
        final thresholdMm =
            _zoneDragThresholdPx / callbacks.currentZoom;
        if (GeometryEngine.distanceMm(
              worldPoint,
              _roomMoveAnchor!,
            ) >=
            thresholdMm) {
          _roomMoveDragActive = true;
          _deferredTap = null; // discard — this is definitely a drag
        }
      }
      if (_roomMoveDragActive) {
        _roomMoveDelta = _computeRoomMoveDelta(worldPoint);
        onStateChanged();
      }
      return;
    }

    // ADR-034: multi-wall group drag.
    if (_groupDragAnchor != null) {
      if (!_groupDragActive) {
        final thresholdMm =
            _zoneDragThresholdPx / callbacks.currentZoom;
        if (GeometryEngine.distanceMm(
              worldPoint,
              _groupDragAnchor!,
            ) >=
            thresholdMm) {
          _groupDragActive = true;
        }
      }
      if (_groupDragActive) {
        if (_groupKeepOrientation) {
          _applyGroupDragKeepOrientation(worldPoint);
        } else {
          _applyGroupDrag(_computeGroupDelta(worldPoint));
        }
        onStateChanged();
      }
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
        // Wall-body translate: snapping is handled inside the apply
        // helpers relative to the grab anchor, so pass the raw cursor.
        if (_keepWallOrientation) {
          _applyMidDragKeepOrientation(worldPoint);
        } else {
          _applyMidDrag(worldPoint);
        }
      case DragHandleType.start:
        _applyEndpointDrag(_cornerSnap(worldPoint, snap), isStart: true);
      case DragHandleType.end:
        _applyEndpointDrag(_cornerSnap(worldPoint, snap), isStart: false);
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

    // Connection pipe drag end (ADR-039 Rule 1).
    if (_circuitDragAnchor != null) {
      if (_circuitDragActive) {
        _commitCircuitDrag();
      } else if (_deferredTap != null) {
        // Stayed under the drag threshold — treat as a click.
        final tap = _deferredTap!;
        _clearCircuitDragState();
        _deferredTap = null;
        _zonePointerOnZone = false;
        _doTap(tap.point, tap.kind);
        onStateChanged();
        return;
      }
      _clearCircuitDragState();
      _deferredTap = null;
      _zonePointerOnZone = false;
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
        if (_zoneEdgeDragParts.isNotEmpty) {
          _commitZoneEdgeDrag();
        } else if (_zoneRectReshapeMode) {
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

    // ADR-016: room-interior drag end.
    if (_roomMoveAnchor != null) {
      if (_roomMoveDragActive) {
        _commitRoomMove(worldPoint);
      } else if (_deferredTap != null) {
        // Pointer moved but stayed under the threshold — treat as a
        // click and let the normal cycling logic select.
        final tap = _deferredTap!;
        _deferredTap = null;
        _clearRoomMoveState();
        _doTap(tap.point, tap.kind);
        onStateChanged();
        return;
      }
      _clearRoomMoveState();
      onStateChanged();
      return;
    }

    // ADR-034: multi-wall group drag end.
    if (_groupDragAnchor != null) {
      if (_groupDragActive) {
        _commitGroupDrag();
      }
      // A non-drag release (below threshold) keeps the multi-selection;
      // the GestureDetector still delivers onTap for a pure click.
      _clearGroupDragState();
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

    // ADR-016 / UI/UX §6.2: hover over a room interior with no wall /
    // handle / opening competing → grab-hand cursor. Skip during any
    // active drag so the grabbing-hand stays put.
    final wasOnRoom = _hoverOnRoomInterior;
    final onRoom = _isRoomInteriorHit(worldPoint);
    _hoverOnRoomInterior = onRoom;

    // ADR-037 Rule 5: resize cursor over a draggable zone boundary.
    final wasEdge = _hoverZoneEdgeNormal;
    _hoverZoneEdgeNormal = _zoneDragAnchorPoint == null
        ? _zoneEdgeDragCandidate(worldPoint)?.normal
        : null;

    if (wasHover != hovering ||
        wasOnRoom != onRoom ||
        wasEdge != _hoverZoneEdgeNormal) {
      onStateChanged();
    }
  }

  @override
  void onPointerUp(Point2D worldPoint) {
    // A pure click (no drag) that armed a wall / opening / wall-zone drag
    // in onPointerDown lands here — a real drag routes through onDragEnd
    // instead. Drop that armed-but-unused state so a stale handle + grab
    // anchor cannot leak into the next gesture and teleport the element to
    // the cursor on a later, separate click.
    if (_dragHandle != null) _clearDragState();
    if (_openingDragHandle != null) _clearOpeningDragState();
    if (_wallZoneDragHandle != null) _clearWallZoneDragState();
    // ADR-039: same for an armed-but-undragged pipe grab.
    if (_circuitDragAnchor != null) _clearCircuitDragState();
    // ADR-034: drop an armed-but-undragged group grab so it can't leak.
    if (_groupDragAnchor != null && !_groupDragActive) {
      _clearGroupDragState();
    }

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
      _clearRoomMoveState();
      _doTap(tap.point, tap.kind);
      onStateChanged();
    } else {
      _clearZoneDragState();
      _clearRoomMoveState();
    }
  }

  @override
  void cancel() {
    // Revert distributor drag. The drag was transient (no DB write), so
    // an in-memory restore returns to the persisted pre-drag value.
    if (_distributorDragAnchor != null) {
      if (_distributorAtDragStart != null) {
        callbacks.updateDistributorTransient(_distributorAtDragStart!);
      }
      _clearDistributorDragState();
      onStateChanged();
      return;
    }

    // Revert connection pipe drag (transient only — nothing persisted).
    if (_circuitDragAnchor != null) {
      final original = _circuitDragOriginal;
      if (original != null) {
        callbacks.updateCircuitTransient(original);
        _selectedCircuit = original;
      }
      _clearCircuitDragState();
      _deferredTap = null;
      _zonePointerOnZone = false;
      onStateChanged();
      return;
    }

    // Revert wall zone drag.
    if (_wallZoneDragHandle != null) {
      if (_zoneAtDragStart != null) {
        callbacks.updateZoneTransient(_zoneAtDragStart!);
        _selectedZone = _zoneAtDragStart;
      }
      _clearWallZoneDragState();
      onStateChanged();
      return;
    }

    // Revert zone drag.
    if (_zoneDragAnchorPoint != null) {
      if (_zoneEdgeDragParts.isNotEmpty) _revertZoneEdgeDrag();
      if (_zoneAtDragStart != null) {
        callbacks.updateZoneTransient(_zoneAtDragStart!);
        _selectedZone = _zoneAtDragStart;
      }
      _clearZoneDragState();
      onStateChanged();
      return;
    }

    // Revert opening drag.
    if (_openingDragHandle != null) {
      if (_dragStartWindow != null) {
        callbacks.updateWindowTransient(_dragStartWindow!);
      }
      if (_dragStartDoor != null) {
        callbacks.updateDoorTransient(_dragStartDoor!);
      }
      _clearOpeningDragState();
      onStateChanged();
      return;
    }

    // ADR-016: room-interior drag mutates no state during onDragUpdate
    // (the ghost is preview-only), so cancelling just drops the ghost.
    if (_roomMoveAnchor != null) {
      _clearRoomMoveState();
      onStateChanged();
      return;
    }

    // ADR-034: revert an in-flight group drag. The drag only ever wrote
    // transient state, so restoring the pre-drag snapshot in memory is
    // enough (the database still holds the pre-drag values).
    if (_groupDragAnchor != null) {
      _revertGroupDrag();
      _clearGroupDragState();
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
    // ADR-016: room-move ghost takes priority while a room is in flight.
    if (_roomMoveDragActive && _roomMoveRoom != null) {
      final dx = _roomMoveDelta.x;
      final dy = _roomMoveDelta.y;
      final wallLines = <(Point2D, Point2D)>[
        for (final w in _roomMoveWallsAtStart)
          (
            Point2D(x: w.startPoint.x + dx, y: w.startPoint.y + dy),
            Point2D(x: w.endPoint.x + dx, y: w.endPoint.y + dy),
          ),
      ];
      final zonePolys = <List<Point2D>>[
        for (final z in _roomMoveZonesAtStart)
          [
            for (final p in z.polygon)
              Point2D(x: p.x + dx, y: p.y + dy),
          ],
      ];
      return RoomMoveGhostData(
        wallLines: wallLines,
        zonePolygons: zonePolys,
      );
    }

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

    // Circuit selection: corner polygon + corner handles (ADR-039).
    if (_selectedCircuit != null) {
      final circuit = _currentSelectedCircuit();
      if (circuit == null) return null;
      final handles = _circuitHandles(circuit);
      int? active;
      if (_circuitDragActive && _circuitDragIsCorner) {
        final target = _circuitDragTargets.first;
        final idx = handles.indexWhere(
          (h) => h.supply == target.supply && h.index == target.index,
        );
        if (idx >= 0) active = idx;
      }
      return CircuitSelectionData(
        supplyPoints: _leadPath(circuit),
        returnPoints:
            _hasRoute(circuit) ? const [] : circuit.returnRoutePath,
        handles: [
          for (final h in handles) _routePoint(circuit, h),
        ],
        activeHandleIndex: active,
      );
    }

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

    // ADR-034: multi-wall selection highlights every member with no
    // endpoint handles (the group only supports a rigid body translate).
    if (_multiWalls.length >= 2) {
      return SelectionHighlightData(
        selectedWalls: [
          for (final w in _multiWalls) _currentWallState(w),
        ],
        handles: const [],
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
      // Only the two endpoint handles are drawn. The wall body itself is
      // grabbable to translate the wall, so no midpoint dot is shown.
      handles.addAll([start, end]);
      if (_dragHandle == DragHandleType.start) {
        activeIdx = 0;
      } else if (_dragHandle == DragHandleType.end) {
        activeIdx = 1;
      }
    }

    return SelectionHighlightData(
      selectedWalls: _selectedWall != null
          ? [_currentWallState(_selectedWall!)]
          : const [],
      selectedRoom: _selectedRoom != null
          ? _currentRoomState(_selectedRoom!)
          : null,
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
      callbacks.updateZoneTransient(newZone);
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
      callbacks.updateZoneTransient(newZone);
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
      // Transient revert: the drag never persisted, so restoring the
      // pre-drag zone in memory is enough — no DB write needed.
      callbacks.updateZoneTransient(_zoneAtDragStart!);
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
    _zoneEdgeDragParts = const [];
    _zoneEdgeDragNormal = null;
  }

  // ================================================================
  // Connection pipe editing (ADR-039 Rule 1)
  // ================================================================

  /// The selected circuit as it currently is in editor state, or null
  /// when it no longer exists.
  HeatingCircuit? _currentSelectedCircuit() {
    final id = _selectedCircuit?.id;
    if (id == null) return null;
    return callbacks.currentCircuits.where((c) => c.id == id).firstOrNull;
  }

  /// True when [c] was drawn as one route with a derived pipe pair
  /// (ADR-040). Its route — not the two pipes — is what gets edited; a
  /// [_RoutePointRef] with `supply: true` then addresses the route.
  static bool _hasRoute(HeatingCircuit c) => c.centerlinePath.length >= 2;

  /// The polyline a `supply: true` reference addresses on [c].
  static List<Point2D> _leadPath(HeatingCircuit c) =>
      _hasRoute(c) ? c.centerlinePath : c.supplyRoutePath;

  static Point2D _routePoint(HeatingCircuit c, _RoutePointRef ref) =>
      ref.supply ? _leadPath(c)[ref.index] : c.returnRoutePath[ref.index];

  /// True when the supply pipe ends where the return pipe starts — the
  /// turning point inside the zone, which both pipes share.
  static bool _sharesZoneEnd(HeatingCircuit c) =>
      !_hasRoute(c) &&
      c.supplyRoutePath.isNotEmpty &&
      c.returnRoutePath.isNotEmpty &&
      GeometryEngine.distanceMm(
            c.supplyRoutePath.last,
            c.returnRoutePath.first,
          ) <=
          1.0;

  /// Draggable corners of [c]. The supply start and the return end sit
  /// on the distributor and are fixed. The shared zone end appears once
  /// (as the last supply point).
  static List<_RoutePointRef> _circuitHandles(HeatingCircuit c) {
    if (_hasRoute(c)) {
      return [
        for (var i = 1; i < c.centerlinePath.length; i++)
          (supply: true, index: i),
      ];
    }
    final shared = _sharesZoneEnd(c);
    return [
      for (var i = 1; i < c.supplyRoutePath.length; i++)
        (supply: true, index: i),
      for (var i = shared ? 1 : 0; i < c.returnRoutePath.length - 1; i++)
        (supply: false, index: i),
    ];
  }

  /// Arms a corner or section drag on the selected circuit when
  /// [worldPoint] is on one of its handles or pipes.
  bool _tryBeginCircuitDrag(Point2D worldPoint) {
    final circuit = _currentSelectedCircuit();
    if (circuit == null) return false;
    _selectedCircuit = circuit;
    final shared = _sharesZoneEnd(circuit);
    final zoom = callbacks.currentZoom;
    final handleMm =
        zoom > 0 ? _handleHitRadiusPx / zoom : _handleRadiusMm;

    // 1. Corner handle.
    for (final h in _circuitHandles(circuit)) {
      if (GeometryEngine.distanceMm(worldPoint, _routePoint(circuit, h)) >
          handleMm) {
        continue;
      }
      final isZoneEnd = shared &&
          h.supply &&
          h.index == _leadPath(circuit).length - 1;
      _circuitDragOriginal = circuit;
      _circuitDragBase = circuit;
      _circuitDragTargets = [
        h,
        if (isZoneEnd) (supply: false, index: 0),
      ];
      _circuitDragIsCorner = true;
      _circuitDragAnchor = worldPoint;
      _circuitDragActive = false;
      _zonePointerOnZone = true; // defer the tap
      return true;
    }

    // 2. Section (the nearest segment within the pipe hit band).
    ({bool supply, int index})? segment;
    var best = _circuitHitThresholdMm;
    void scan(List<Point2D> path, {required bool supply}) {
      for (var i = 0; i + 1 < path.length; i++) {
        final d = _distanceToSegmentMm(worldPoint, path[i], path[i + 1]);
        if (d <= best) {
          best = d;
          segment = (supply: supply, index: i);
        }
      }
    }

    final hasRoute = _hasRoute(circuit);
    scan(_leadPath(circuit), supply: true);
    if (hasRoute) {
      // The two pipes run either side of the route; a press on either
      // of them grabs the route section it belongs to.
      final onPipe = _polylineHit(circuit.supplyRoutePath, worldPoint) ||
          _polylineHit(circuit.returnRoutePath, worldPoint);
      if (!onPipe) segment = null;
    } else {
      scan(circuit.returnRoutePath, supply: false);
    }
    final seg = segment;
    if (seg == null) return false;

    var supply = List<Point2D>.from(_leadPath(circuit));
    var back = List<Point2D>.from(circuit.returnRoutePath);
    var first = seg.index;
    // An end on the distributor stays put: grabbing the section next to
    // it inserts a corner there, so the section can still be moved.
    if (seg.supply && first == 0) {
      supply = [supply.first, ...supply];
      first = 1;
    } else if (!seg.supply && first == back.length - 2) {
      back = [...back, back.last];
    }
    final targets = <_RoutePointRef>[
      (supply: seg.supply, index: first),
      (supply: seg.supply, index: first + 1),
    ];
    // The shared zone end moves on both pipes.
    if (shared) {
      if (seg.supply && first + 1 == supply.length - 1) {
        targets.add((supply: false, index: 0));
      } else if (!seg.supply && first == 0) {
        targets.add((supply: true, index: supply.length - 1));
      }
    }

    _circuitDragOriginal = circuit;
    _circuitDragBase = hasRoute
        ? circuit.copyWith(centerlinePath: supply)
        : circuit.copyWith(
            supplyRoutePath: supply,
            returnRoutePath: back,
          );
    _circuitDragTargets = targets;
    _circuitDragIsCorner = false;
    _circuitDragAnchor = worldPoint;
    _circuitDragActive = false;
    _zonePointerOnZone = true; // defer the tap
    return true;
  }

  /// Moves the dragged corner or section to follow [worldPoint].
  ///
  /// A corner snaps to the grid; a section keeps its shape and its
  /// offset is chosen so its first point lands on the grid.
  void _applyCircuitDrag(Point2D worldPoint) {
    final base = _circuitDragBase;
    final anchor = _circuitDragAnchor;
    if (base == null || anchor == null || _circuitDragTargets.isEmpty) {
      return;
    }
    final grid = callbacks.currentGridSpacingMm;
    final lead = _routePoint(base, _circuitDragTargets.first);
    final Point2D snapped;
    if (_circuitDragIsCorner) {
      snapped = SnapService.snapToGrid(worldPoint, grid);
    } else {
      snapped = SnapService.snapToGrid(
        Point2D(
          x: lead.x + worldPoint.x - anchor.x,
          y: lead.y + worldPoint.y - anchor.y,
        ),
        grid,
      );
    }
    final dx = snapped.x - lead.x;
    final dy = snapped.y - lead.y;

    final supply = List<Point2D>.from(_leadPath(base));
    final back = List<Point2D>.from(base.returnRoutePath);
    for (final t in _circuitDragTargets) {
      final list = t.supply ? supply : back;
      list[t.index] =
          Point2D(x: list[t.index].x + dx, y: list[t.index].y + dy);
    }
    // ADR-040: a route is laid out again on every move — both pipes
    // follow, parallel and at the set distance from walls.
    final updated = _hasRoute(base)
        ? relaidConnectionPipes(
            base,
            callbacks.currentWalls,
            centerline: supply,
          )
        : base.copyWith(
            supplyRoutePath: supply,
            returnRoutePath: back,
          );
    callbacks.updateCircuitTransient(updated);
    _selectedCircuit = updated;
  }

  /// Validates and commits the pipe drag as one undo entry.
  ///
  /// Points that ended up on top of their neighbour are merged — that
  /// is also how a corner is removed. The pipe must still end inside
  /// the zone it serves; otherwise the drag is reverted with a toast.
  void _commitCircuitDrag() {
    final original = _circuitDragOriginal;
    final dragged = _currentSelectedCircuit();
    if (original == null || dragged == null) return;

    List<Point2D> dedupe(List<Point2D> path) {
      final out = <Point2D>[];
      for (final p in path) {
        if (out.isEmpty || GeometryEngine.distanceMm(out.last, p) > 1.0) {
          out.add(p);
        }
      }
      return out.length >= 2 ? out : path;
    }

    // A route was already laid out (and de-duplicated) during the drag.
    final result = _hasRoute(dragged)
        ? dragged
        : dragged.copyWith(
            supplyRoutePath: dedupe(dragged.supplyRoutePath),
            returnRoutePath: dedupe(dragged.returnRoutePath),
          );
    final zoneEnd = _leadPath(result);

    final zone = callbacks.currentZones
        .where((z) => z.id == result.heatingZoneId)
        .firstOrNull;
    final endsInZone = zone == null ||
        zone.polygon.length < 3 ||
        zoneEnd.isEmpty ||
        GeometryEngine.isPointInPolygon(zoneEnd.last, zone.polygon);
    if (!endsInZone) {
      callbacks.updateCircuitTransient(original);
      _selectedCircuit = original;
      callbacks.showToast(callbacks.l10n.circuit_routeMustEndInZoneToast);
      return;
    }

    if (result == original) {
      callbacks.updateCircuitTransient(original);
      _selectedCircuit = original;
      return;
    }
    undoRedo.execute(UpdateCircuitCommand(
      oldCircuit: original,
      newCircuit: result,
      update: callbacks.updateCircuit,
      label: callbacks.l10n.undo_editConnectionPipe,
    ));
    _selectedCircuit = result;
  }

  void _clearCircuitDragState() {
    _circuitDragOriginal = null;
    _circuitDragBase = null;
    _circuitDragTargets = const [];
    _circuitDragAnchor = null;
    _circuitDragActive = false;
    _circuitDragIsCorner = false;
  }

  // ================================================================
  // Zone edge drag — linked boundaries (ADR-037 Rule 5)
  // ================================================================

  /// Finds the zone boundary a press at [worldPoint] would drag.
  ///
  /// A boundary is the maximal straight line made of overlapping,
  /// collinear floor-zone edges — so the divider between a full-height
  /// zone and two stacked neighbours is one boundary. It is draggable
  /// when it is shared by two or more zones (no selection needed), or
  /// when it is an edge of the currently selected zone.
  ///
  /// Returns the unit [normal] of the boundary and, per affected zone,
  /// the vertex indices that lie on it; null when nothing qualifies or
  /// another handle has priority at this point.
  ({
    Point2D normal,
    List<({HeatingZone zone, List<int> indices})> parts,
  })? _zoneEdgeDragCandidate(Point2D worldPoint) {
    final zoom = callbacks.currentZoom;
    final thresholdMm =
        zoom > 0 ? _handleHitRadiusPx / zoom : _handleRadiusMm;

    // Priority: vertex handles of the selected zone, handles of the
    // selected wall, the selected distributor and a multi-wall group
    // all win over a boundary drag.
    if (_selectedWindow != null || _selectedDoor != null) return null;
    if (_selectedZone != null && _hitTestZoneHandle(worldPoint) != null) {
      return null;
    }
    if (_selectedWall != null && _hitTestHandle(worldPoint) != null) {
      return null;
    }
    if (_selectedDistributor) {
      final d = callbacks.currentDistributor;
      if (d != null && _isPointOnDistributor(worldPoint, d)) return null;
    }
    if (_multiWalls.length >= 2 && _isPointOnAnyGroupWall(worldPoint)) {
      return null;
    }

    final zones = callbacks.currentZones
        .where(
          (z) =>
              z.zoneType == ZoneType.floorHeating && z.polygon.length >= 3,
        )
        .toList();

    // Nearest zone edge under the pointer.
    Point2D? a;
    Point2D? b;
    var bestDist = thresholdMm;
    for (final z in zones) {
      final n = z.polygon.length;
      for (var i = 0; i < n; i++) {
        final p = z.polygon[i];
        final q = z.polygon[(i + 1) % n];
        final d = _distanceToSegmentMm(worldPoint, p, q);
        if (d <= bestDist) {
          bestDist = d;
          a = p;
          b = q;
        }
      }
    }
    if (a == null || b == null) return null;

    final len = GeometryEngine.distanceMm(a, b);
    if (len < 1.0) return null;
    final ux = (b.x - a.x) / len;
    final uy = (b.y - a.y) / len;
    const tol = 1.0;
    double along(Point2D p) => (p.x - a!.x) * ux + (p.y - a.y) * uy;
    double across(Point2D p) => (p.x - a!.x) * -uy + (p.y - a.y) * ux;

    // Grow the boundary over every collinear zone edge that overlaps it.
    var lo = 0.0;
    var hi = len;
    var grew = true;
    while (grew) {
      grew = false;
      for (final z in zones) {
        final n = z.polygon.length;
        for (var i = 0; i < n; i++) {
          final p = z.polygon[i];
          final q = z.polygon[(i + 1) % n];
          if (across(p).abs() > tol || across(q).abs() > tol) continue;
          final e0 = math.min(along(p), along(q));
          final e1 = math.max(along(p), along(q));
          if (math.min(e1, hi) - math.max(e0, lo) <= tol) continue;
          if (e0 < lo - tol) {
            lo = e0;
            grew = true;
          }
          if (e1 > hi + tol) {
            hi = e1;
            grew = true;
          }
        }
      }
    }

    // Vertices on the boundary, per zone. A zone that only touches the
    // boundary with a single corner is not part of it.
    final parts = <({HeatingZone zone, List<int> indices})>[];
    for (final z in zones) {
      final indices = <int>[
        for (var i = 0; i < z.polygon.length; i++)
          if (across(z.polygon[i]).abs() <= tol &&
              along(z.polygon[i]) >= lo - tol &&
              along(z.polygon[i]) <= hi + tol)
            i,
      ];
      if (indices.length >= 2) parts.add((zone: z, indices: indices));
    }
    if (parts.isEmpty) return null;
    final involvesSelected = _selectedZone != null &&
        parts.any((p) => p.zone.id == _selectedZone!.id);
    if (parts.length < 2 && !involvesSelected) return null;

    return (normal: Point2D(x: -uy, y: ux), parts: parts);
  }

  /// Arms a boundary drag when [worldPoint] is on a draggable zone
  /// boundary. The tap is deferred exactly like a zone-body press, so a
  /// press without movement still selects.
  bool _tryBeginZoneEdgeDrag(Point2D worldPoint) {
    final hit = _zoneEdgeDragCandidate(worldPoint);
    if (hit == null) return false;
    _zoneEdgeDragParts = hit.parts;
    _zoneEdgeDragNormal = hit.normal;
    _zoneHandleDragIndex = null;
    _zoneDragAnchorPoint = worldPoint;
    _zoneAtDragStart = null;
    _zoneRectReshapeMode = false;
    _zonePointerOnZone = true;
    return true;
  }

  /// Moves the dragged boundary to follow [worldPoint] along its normal.
  ///
  /// An axis-aligned boundary snaps to the grid. Every zone on the
  /// boundary is reshaped together, so growing one zone shrinks its
  /// neighbour by the same amount. A position that would invert a zone,
  /// leave an edge shorter than 100 mm or push a vertex out of its valid
  /// rooms (ADR-006) is ignored — the boundary stays at its last valid
  /// position.
  void _applyZoneEdgeDrag(Point2D worldPoint) {
    final normal = _zoneEdgeDragNormal;
    final anchor = _zoneDragAnchorPoint;
    if (normal == null || anchor == null || _zoneEdgeDragParts.isEmpty) {
      return;
    }
    var shift = (worldPoint.x - anchor.x) * normal.x +
        (worldPoint.y - anchor.y) * normal.y;

    final first = _zoneEdgeDragParts.first;
    final onLine = first.zone.polygon[first.indices.first];
    final axisAligned = normal.x.abs() < 1e-6 || normal.y.abs() < 1e-6;
    if (axisAligned) {
      final moved = Point2D(
        x: onLine.x + normal.x * shift,
        y: onLine.y + normal.y * shift,
      );
      final snapped = SnapService.snapToGrid(
        moved,
        callbacks.currentGridSpacingMm,
      );
      shift = (snapped.x - onLine.x) * normal.x +
          (snapped.y - onLine.y) * normal.y;
    }

    final updated = <HeatingZone>[];
    for (final part in _zoneEdgeDragParts) {
      final polygon = List<Point2D>.from(part.zone.polygon);
      for (final i in part.indices) {
        polygon[i] = Point2D(
          x: polygon[i].x + normal.x * shift,
          y: polygon[i].y + normal.y * shift,
        );
      }
      if (!_isZoneEdgeDragResultValid(part.zone, polygon)) return;
      updated.add(part.zone.copyWith(polygon: polygon));
    }
    for (final zone in updated) {
      callbacks.updateZoneTransient(zone);
      if (_selectedZone?.id == zone.id) _selectedZone = zone;
    }
  }

  /// Whether [polygon] is an acceptable new shape for [original] during
  /// a boundary drag.
  bool _isZoneEdgeDragResultValid(
    HeatingZone original,
    List<Point2D> polygon,
  ) {
    double signedArea(List<Point2D> pts) {
      var sum = 0.0;
      for (var i = 0; i < pts.length; i++) {
        final p = pts[i];
        final q = pts[(i + 1) % pts.length];
        sum += p.x * q.y - q.x * p.y;
      }
      return sum;
    }

    final before = signedArea(original.polygon);
    final after = signedArea(polygon);
    if (before * after <= 0) return false;
    for (var i = 0; i < polygon.length; i++) {
      final len = GeometryEngine.distanceMm(
        polygon[i],
        polygon[(i + 1) % polygon.length],
      );
      if (len < _minLengthMm) return false;
    }
    if (!GeometryEngine.isSimplePolygon(polygon)) return false;
    return polygon.every((v) => _isZonePointValid(v, original));
  }

  /// Commits the boundary drag as one undo entry covering every zone
  /// that changed.
  void _commitZoneEdgeDrag() {
    final oldZones = <HeatingZone>[];
    final newZones = <HeatingZone>[];
    for (final part in _zoneEdgeDragParts) {
      final current = callbacks.currentZones
          .where((z) => z.id == part.zone.id)
          .firstOrNull;
      if (current == null || current == part.zone) continue;
      oldZones.add(part.zone);
      newZones.add(current);
    }
    if (newZones.isEmpty) return;
    undoRedo.execute(_MoveZonesCommand(
      oldZones: oldZones,
      newZones: newZones,
      update: callbacks.updateZone,
      label: callbacks.l10n.undo_moveZoneBoundary,
    ));
    for (final zone in newZones) {
      if (_selectedZone?.id == zone.id) _selectedZone = zone;
    }
  }

  /// Restores every zone of the boundary drag to its pre-drag shape.
  /// The drag only wrote transient state, so no persist is needed.
  void _revertZoneEdgeDrag() {
    for (final part in _zoneEdgeDragParts) {
      callbacks.updateZoneTransient(part.zone);
      if (_selectedZone?.id == part.zone.id) _selectedZone = part.zone;
    }
  }

  /// Distance from [p] to segment [a]→[b] in mm.
  static double _distanceToSegmentMm(Point2D p, Point2D a, Point2D b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 < 1e-9) return GeometryEngine.distanceMm(p, a);
    final t =
        (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
    return GeometryEngine.distanceMm(
      p,
      Point2D(x: a.x + dx * t, y: a.y + dy * t),
    );
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
    callbacks.updateZoneTransient(updated);
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
      callbacks.updateWindowTransient(
        _dragStartWindow!.copyWith(
          positionOnWallMm: posOnWall,
          widthMm: widthMm,
        ),
      );
    } else if (_dragStartDoor != null) {
      callbacks.updateDoorTransient(
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
    undoRedo.execute(DeleteCircuitCommand(
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
    _multiWalls = const [];
    _selectedRoom = null;
    _selectedWindow = null;
    _selectedDoor = null;
    _selectedZone = null;
    _selectedDistributor = false;
    _selectedCircuit = null;
  }

  // ================================================================
  // Multi-wall selection (Ctrl/Cmd-click)
  // ================================================================

  /// Add or remove [wall] from the multi-wall selection.
  ///
  /// Seeds the set from the existing single wall selection (if any) so the
  /// first Ctrl-click after a plain click extends rather than replaces.
  /// Re-resolves every member to its live [WallSegment] and keeps the last
  /// one as the primary (mirrored into [_selectedWall] and the global
  /// selection provider so the properties panel still has a target).
  void _toggleWallInMultiSelect(WallSegment wall) {
    // Build the working id list, seeding from the current selection.
    final ids = <String>[
      if (_multiWalls.isNotEmpty)
        for (final w in _multiWalls) w.id
      else if (_selectedWall != null)
        _selectedWall!.id,
    ];

    if (ids.contains(wall.id)) {
      ids.remove(wall.id);
    } else {
      ids.add(wall.id);
    }

    // Re-resolve to live wall instances, preserving order.
    final resolved = <WallSegment>[
      for (final id in ids)
        if (callbacks.currentWalls
                .where((w) => w.id == id)
                .firstOrNull
            case final w?)
          w,
    ];

    // Switching to a wall selection clears any other element type.
    _selectedRoom = null;
    _selectedWindow = null;
    _selectedDoor = null;
    _selectedZone = null;
    _selectedDistributor = false;
    _selectedCircuit = null;

    _multiWalls = resolved.length >= 2 ? resolved : const [];
    _selectedWall = resolved.isEmpty ? null : resolved.last;
    callbacks.selectElement(
      _selectedWall == null ? null : 'wall',
      _selectedWall?.id,
    );

    // Reset the cycle anchor so the next plain click starts fresh.
    _lastClickPosition = null;
    _lastHitStack = const [];
    _cycleIndex = 0;

    onStateChanged();
  }

  // ================================================================
  // Wall handle hit-testing
  // ================================================================

  DragHandleType? _hitTestHandle(Point2D worldPoint) {
    if (_selectedWall == null) return null;
    final wall = _currentWallState(_selectedWall!);
    final start = wall.startPoint;
    final end = wall.endPoint;

    final zoom = callbacks.currentZoom;
    final thresholdMm = zoom > 0
        ? _handleHitRadiusPx / zoom
        : _handleRadiusMm;

    // Endpoint handles (resize) take priority near the ends.
    if (GeometryEngine.distanceMm(worldPoint, start) <=
        thresholdMm) {
      return DragHandleType.start;
    }
    if (GeometryEngine.distanceMm(worldPoint, end) <=
        thresholdMm) {
      return DragHandleType.end;
    }
    // Anywhere else along the wall body translates the whole wall. Uses
    // the same hit band as wall selection so the entire wall is grabbable
    // (no midpoint dot required).
    if (GeometryUtils.distanceToSegment(worldPoint, start, end) <=
        _wallHitThresholdMm) {
      return DragHandleType.mid;
    }
    return null;
  }

  // ================================================================
  // Mid-handle drag (translate wall)
  // ================================================================

  void _applyMidDrag(Point2D worldPoint) {
    final orig = _dragStartWall!;
    // Anchor: the world point where the wall was grabbed. The wall is
    // translated by the pointer delta from that anchor (so grabbing
    // anywhere along the wall — not just its midpoint — feels natural).
    // Falls back to the midpoint if the anchor was somehow not captured.
    final anchor = _wallDragAnchor ??
        Point2D(
          x: (orig.startPoint.x + orig.endPoint.x) / 2,
          y: (orig.startPoint.y + orig.endPoint.y) / 2,
        );

    // Grid-snap the moved start point so the wall stays aligned, then
    // translate both endpoints by that snapped delta.
    final movedStart = Point2D(
      x: orig.startPoint.x + (worldPoint.x - anchor.x),
      y: orig.startPoint.y + (worldPoint.y - anchor.y),
    );
    final snappedStart = SnapService.snapToGrid(
      movedStart,
      callbacks.currentGridSpacingMm,
    );
    final dx = snappedStart.x - orig.startPoint.x;
    final dy = snappedStart.y - orig.startPoint.y;

    final newStart = Point2D(
      x: orig.startPoint.x + dx,
      y: orig.startPoint.y + dy,
    );
    final newEnd = Point2D(
      x: orig.endPoint.x + dx,
      y: orig.endPoint.y + dy,
    );

    callbacks.updateWallTransient(
      orig.copyWith(startPoint: newStart, endPoint: newEnd),
    );
    _adjustConnectedWalls(orig, newStart: newStart, newEnd: newEnd);
    _updateRoomPolygon();
  }

  // ================================================================
  // Mid-handle drag, keep-orientation (ADR-027)
  // ================================================================

  /// Wall-body translate that preserves the orientation of every wall.
  ///
  /// With Shift or Ctrl held, the dragged wall slides **parallel to
  /// itself** (only the perpendicular component of the pointer motion is
  /// applied), and each connected wall's shared corner is recomputed as
  /// the intersection of that connected wall's own (fixed) line with the
  /// dragged wall's new line. Connected walls therefore keep their
  /// direction and only change length — a rectangular room stays
  /// rectangular for the whole drag.
  void _applyMidDragKeepOrientation(Point2D worldPoint) {
    final orig = _dragStartWall!;
    final dirX = orig.endPoint.x - orig.startPoint.x;
    final dirY = orig.endPoint.y - orig.startPoint.y;
    final len = math.sqrt(dirX * dirX + dirY * dirY);
    if (len < 1e-6) {
      // Degenerate wall — fall back to the plain translate.
      _applyMidDrag(worldPoint);
      return;
    }

    // Unit normal (perpendicular) of the dragged wall.
    final nx = -dirY / len;
    final ny = dirX / len;

    final anchor = _wallDragAnchor ??
        Point2D(
          x: (orig.startPoint.x + orig.endPoint.x) / 2,
          y: (orig.startPoint.y + orig.endPoint.y) / 2,
        );

    // Perpendicular component of the raw pointer delta — the parallel
    // component is ignored so the wall never slides along its own axis.
    var perp =
        (worldPoint.x - anchor.x) * nx + (worldPoint.y - anchor.y) * ny;

    // Grid-snap the offset along the normal: snap the perpendicularly
    // translated start point, then keep only its perpendicular component
    // so the wall stays exactly parallel to its original line. Alt
    // (free placement) skips the snap, consistent with the other tools.
    if (!_altHeld) {
      final movedStart = Point2D(
        x: orig.startPoint.x + perp * nx,
        y: orig.startPoint.y + perp * ny,
      );
      final snapped = SnapService.snapToGrid(
        movedStart,
        callbacks.currentGridSpacingMm,
      );
      perp = (snapped.x - orig.startPoint.x) * nx +
          (snapped.y - orig.startPoint.y) * ny;
    }

    // Two points defining the dragged wall's new (infinite) line: the
    // original endpoints translated perpendicularly by `perp`.
    final lineStart = Point2D(
      x: orig.startPoint.x + perp * nx,
      y: orig.startPoint.y + perp * ny,
    );
    final lineEnd = Point2D(
      x: orig.endPoint.x + perp * nx,
      y: orig.endPoint.y + perp * ny,
    );

    // Recompute each corner as the intersection of the connected wall's
    // fixed line with the dragged wall's new line. Falls back to the
    // purely translated endpoint when no non-parallel connected wall is
    // found (free end, or a collinear continuation).
    final newStart =
        _keepOrientationCorner(orig.startPoint, lineStart, lineEnd) ??
            lineStart;
    final newEnd =
        _keepOrientationCorner(orig.endPoint, lineStart, lineEnd) ?? lineEnd;

    callbacks.updateWallTransient(
      orig.copyWith(startPoint: newStart, endPoint: newEnd),
    );
    _adjustConnectedWalls(orig, newStart: newStart, newEnd: newEnd);
    _updateRoomPolygon();
  }

  /// New position of the dragged wall's [origEndpoint] under
  /// keep-orientation: the intersection of a connected wall's fixed line
  /// (through its far endpoint and [origEndpoint]) with the dragged
  /// wall's new line ([lineStart]–[lineEnd]). Returns null when no usable
  /// (non-parallel) connected wall is attached at that endpoint.
  Point2D? _keepOrientationCorner(
    Point2D origEndpoint,
    Point2D lineStart,
    Point2D lineEnd,
  ) {
    for (final conn in _dragStartConnected) {
      // Skip the ADR-011 mirror partner: it is collinear with the dragged
      // wall (parallel line, no useful intersection) and is synced
      // separately by updateWall.
      if (conn.mirrorId == _dragStartWall!.id) continue;
      Point2D? farPoint;
      if (_pointsEqual(conn.startPoint, origEndpoint)) {
        farPoint = conn.endPoint;
      } else if (_pointsEqual(conn.endPoint, origEndpoint)) {
        farPoint = conn.startPoint;
      }
      if (farPoint == null) continue;
      final hit = GeometryEngine.lineIntersection(
        farPoint,
        origEndpoint,
        lineStart,
        lineEnd,
      );
      if (hit != null) return hit;
    }
    return null;
  }

  // ================================================================
  // Endpoint handle drag (resize/pivot)
  // ================================================================

  /// ADR-035: capture the dragged [corner]'s square-snap guides — for each of
  /// the two walls meeting at the corner, the fixed far end it pivots about
  /// and the unit direction perpendicular to that wall's adjacent (also fixed)
  /// neighbour. Each side is set independently; sides without a usable
  /// adjacent wall (or a corner with no room) are left null so the snap stays
  /// off there.
  void _captureCornerSquareGuides(Point2D corner) {
    final room = _dragStartRoom;
    if (room == null) return;
    final dragged = _dragStartWall!;
    final roomWalls = callbacks.currentWalls
        .where((w) => w.roomId == room.id)
        .toList();

    // Edge 1 — the dragged wall, pivoting about its far end A.
    final aFar = _otherEnd(dragged, corner);
    final neighbourA =
        _adjacentRoomWall(roomWalls, exclude: dragged, sharedPoint: aFar);
    if (neighbourA != null) {
      _squareAnchorA = aFar;
      _squareDirA = _perpUnit(aFar, _otherEnd(neighbourA, aFar));
    }

    // Edge 2 — the connected wall (the other room wall meeting at the corner),
    // pivoting about its far end B.
    final connected =
        _adjacentRoomWall(roomWalls, exclude: dragged, sharedPoint: corner);
    if (connected != null) {
      final bFar = _otherEnd(connected, corner);
      final neighbourB =
          _adjacentRoomWall(roomWalls, exclude: connected, sharedPoint: bFar);
      if (neighbourB != null) {
        _squareAnchorB = bFar;
        _squareDirB = _perpUnit(bFar, _otherEnd(neighbourB, bFar));
      }
    }
  }

  /// First room wall (other than [exclude]) that touches [sharedPoint].
  WallSegment? _adjacentRoomWall(
    List<WallSegment> roomWalls, {
    required WallSegment exclude,
    required Point2D sharedPoint,
  }) {
    for (final w in roomWalls) {
      if (w.id == exclude.id) continue;
      if (_pointsEqual(w.startPoint, sharedPoint) ||
          _pointsEqual(w.endPoint, sharedPoint)) {
        return w;
      }
    }
    return null;
  }

  /// The endpoint of [wall] that is not [end].
  Point2D _otherEnd(WallSegment wall, Point2D end) =>
      _pointsEqual(wall.startPoint, end) ? wall.endPoint : wall.startPoint;

  /// Unit vector perpendicular to the direction [a] → [b].
  Point2D _perpUnit(Point2D a, Point2D b) {
    final len = GeometryEngine.distanceMm(a, b);
    if (len < 1e-6) return const Point2D(x: 1, y: 0);
    return Point2D(x: -(b.y - a.y) / len, y: (b.x - a.x) / len);
  }

  /// ADR-035: prefer the square-corner snap over the plain grid fallback
  /// while dragging a room corner. Explicit endpoint / wall-interior joins
  /// still win, and the snap is skipped unless drag-start found a guide.
  Point2D _cornerSnap(Point2D cursor, SnapResult snap) {
    if (snap.type == SnapType.endpoint || snap.type == SnapType.wallPoint) {
      return snap.point;
    }
    return SnapService.snapCornerSquare(
          cursor,
          anchorA: _squareAnchorA,
          dirA: _squareDirA,
          anchorB: _squareAnchorB,
          dirB: _squareDirB,
        ) ??
        snap.point;
  }

  void _applyEndpointDrag(
    Point2D snappedPoint, {
    required bool isStart,
  }) {
    final orig = _dragStartWall!;
    final updated = isStart
        ? orig.copyWith(startPoint: snappedPoint)
        : orig.copyWith(endPoint: snappedPoint);
    callbacks.updateWallTransient(updated);
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
      if (updated != null) callbacks.updateWallTransient(updated);
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
      if (updated != null) callbacks.updateWallTransient(updated);
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
          callbacks.updateRoomTransient(
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
          callbacks.updateRoomTransient(
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
    // ADR-018 Rule 1.2 / Rule 9: zone right-click opens the context
    // menu (delete + split items). Hit-test directly so the menu fires
    // whether or not the zone is currently selected.
    final zone = _zoneAtPoint(worldPoint);
    if (zone != null) {
      _openZoneContextMenu(worldPoint, zone);
      return;
    }

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
  // ADR-018 — zone right-click context menu
  // ================================================================

  /// Returns the smallest-area zone whose polygon contains [point], or
  /// null. Mirrors the zone hit-test in [_buildHitStack] so right-click
  /// targets exactly the zone a left-click would have selected.
  HeatingZone? _zoneAtPoint(Point2D point) {
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
    return zones.isEmpty ? null : zones.first;
  }

  /// Builds a [ZoneContextMenuRequest] for [zone] and hands it to the
  /// canvas widget. Floor zones get split items (disabled with a tooltip
  /// when the shape cannot be cut in two, ADR-037 Rule 1); wall zones
  /// hide split items.
  void _openZoneContextMenu(Point2D worldPoint, HeatingZone zone) {
    final isFloor = zone.zoneType == ZoneType.floorHeating;
    final splitEnabled =
        isFloor && SplitZoneCommand.canSplit(zone.polygon);
    callbacks.requestZoneContextMenu(
      ZoneContextMenuRequest(
        worldPoint: worldPoint,
        showSplitItems: isFloor,
        splitEnabled: splitEnabled,
        onDelete: () => _deleteZoneById(zone.id),
        onSplitVertically: () =>
            _dispatchSplit(zone.id, SplitDirection.vertical),
        onSplitHorizontally: () =>
            _dispatchSplit(zone.id, SplitDirection.horizontal),
      ),
    );
  }

  /// Deletes the zone with [zoneId] via the existing [_DeleteZoneCommand],
  /// reading the latest state so the captured snapshot is fresh.
  void _deleteZoneById(String zoneId) {
    final zone =
        callbacks.currentZones.where((z) => z.id == zoneId).firstOrNull;
    if (zone == null) return;
    undoRedo.execute(_DeleteZoneCommand(
      zone: zone,
      remove: callbacks.removeZone,
      add: callbacks.commitZone,
      label: callbacks.l10n.undo_deleteZone,
    ));
    if (_selectedZone?.id == zoneId) {
      _selectedZone = null;
      callbacks.selectElement(null, null);
    }
    onStateChanged();
  }

  /// Dispatches a [SplitZoneCommand] for the zone with [zoneId] along
  /// [direction], emitting the appropriate toast on rejection
  /// (ADR-018 Rule 4 / Rule 9).
  void _dispatchSplit(String zoneId, SplitDirection direction) {
    final zone =
        callbacks.currentZones.where((z) => z.id == zoneId).firstOrNull;
    if (zone == null) return;
    final result = SplitZoneCommand.tryBuild(
      parent: zone,
      direction: direction,
      circuits: callbacks.currentCircuits,
      label: callbacks.l10n.undo_splitZone,
      add: callbacks.commitZone,
      remove: callbacks.removeZone,
      updateCircuit: callbacks.updateCircuit,
    );
    switch (result) {
      case SplitBuildOk(:final command):
        undoRedo.execute(command);
        if (_selectedZone?.id == zoneId) {
          _selectedZone = null;
          callbacks.selectElement(null, null);
        }
        onStateChanged();
      case SplitBuildRejectedTooSmall():
        callbacks.showToast(callbacks.l10n.zone_splitTooSmallToast);
      case SplitBuildRejectedShape():
        callbacks.showToast(
          callbacks.l10n.zone_splitNonRectangularToast,
        );
    }
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

    // ADR-019: snapshot pre-delete tuple (walls + rooms + zones +
    // windows + doors) so one Ctrl+Z restores the whole cascade,
    // including any reverted mirror partners.
    final oldWalls = List<WallSegment>.unmodifiable(callbacks.currentWalls);
    final oldRooms = List<Room>.unmodifiable(callbacks.currentRooms);
    final oldZones = List<HeatingZone>.unmodifiable(callbacks.currentZones);
    final oldWindows =
        List<WindowElement>.unmodifiable(callbacks.currentWindows);
    final oldDoors = List<Door>.unmodifiable(callbacks.currentDoors);

    callbacks.destroyRoomCascade(room.id);

    final newWalls = List<WallSegment>.unmodifiable(callbacks.currentWalls);
    final newRooms = List<Room>.unmodifiable(callbacks.currentRooms);
    final newZones = List<HeatingZone>.unmodifiable(callbacks.currentZones);
    final newWindows =
        List<WindowElement>.unmodifiable(callbacks.currentWindows);
    final newDoors = List<Door>.unmodifiable(callbacks.currentDoors);

    undoRedo.execute(_DeleteRoomCommand(
      callbacks: callbacks,
      oldWalls: oldWalls,
      oldRooms: oldRooms,
      oldZones: oldZones,
      oldWindows: oldWindows,
      oldDoors: oldDoors,
      newWalls: newWalls,
      newRooms: newRooms,
      newZones: newZones,
      newWindows: newWindows,
      newDoors: newDoors,
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
    // Transient: the drag never persisted (every frame went through the
    // `*Transient` mutators), so the database still holds the pre-drag
    // values — restoring in-memory state is enough and avoids a
    // redundant write.
    if (_dragStartWall != null) {
      callbacks.updateWallTransient(_dragStartWall!);
    }
    for (final conn in _dragStartConnected) {
      callbacks.updateWallTransient(conn);
    }
    if (_dragStartRoom != null) {
      callbacks.updateRoomTransient(_dragStartRoom!);
    }
    // ADR-011: also restore the mirror room polygon.
    if (_dragStartMirrorRoom != null) {
      callbacks.updateRoomTransient(_dragStartMirrorRoom!);
    }
  }

  void _clearDragState() {
    _dragHandle = null;
    _wallDragAnchor = null;
    _dragStartWall = null;
    _dragStartConnected = const [];
    _squareAnchorA = null;
    _squareDirA = null;
    _squareAnchorB = null;
    _squareDirB = null;
    _dragStartRoom = null;
    _dragStartMirrorRoom = null;
    _keepWallOrientation = false;
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
  // ADR-034: multi-wall group drag (rigid translate)
  // ================================================================

  /// True when [worldPoint] lies within the hit-band of any wall in the
  /// multi-selection — the grab test that starts a group translate.
  bool _isPointOnAnyGroupWall(Point2D worldPoint) {
    for (final w in _multiWalls) {
      if (GeometryUtils.distanceToSegment(
            worldPoint,
            w.startPoint,
            w.endPoint,
          ) <=
          _wallHitThresholdMm) {
        return true;
      }
    }
    return false;
  }

  /// Freeze the snapshots a group drag translates from each frame.
  void _beginGroupDrag(Point2D worldPoint) {
    final groupIds = _multiWalls.map((w) => w.id).toSet();

    // ADR-027 / ADR-034: Ctrl or Shift held at drag start keeps every
    // wall's orientation for the whole drag (re-sync from the live key
    // state first so a missed key-up cannot strand the gate).
    _syncCtrlHeldFromHardware();
    _groupKeepOrientation = _ctrlHeld || _shiftHeld;

    // Grab wall: the selected wall nearest the press — its direction sets
    // the slide normal for the keep-orientation path.
    _groupGrabWall = null;
    var nearestDist = double.infinity;
    for (final w in _multiWalls) {
      final d = GeometryUtils.distanceToSegment(
        worldPoint,
        w.startPoint,
        w.endPoint,
      );
      if (d < nearestDist) {
        nearestDist = d;
        _groupGrabWall = w;
      }
    }

    // Live state of the selected walls, preserving order.
    _groupWallsAtStart = [
      for (final w in _multiWalls)
        if (callbacks.currentWalls
                .where((c) => c.id == w.id)
                .firstOrNull
            case final live?)
          live,
    ];

    // Non-group walls that share an endpoint with any group wall — their
    // shared corner follows the translation. ADR-011 mirror partners share
    // both endpoints and so translate wholly.
    _groupConnectedAtStart = [
      for (final c in callbacks.currentWalls)
        if (!groupIds.contains(c.id) &&
            _groupWallsAtStart.any((g) => _sharesEndpoint(g, c)))
          c,
    ];

    // Rooms whose polygon must be rebuilt from their (moved) walls.
    _groupRoomIds = {
      for (final w in _groupWallsAtStart)
        if (w.roomId.isNotEmpty) w.roomId,
      for (final c in _groupConnectedAtStart)
        if (c.roomId.isNotEmpty) c.roomId,
    };

    _groupDragAnchor = worldPoint;
    _groupDragActive = false;
    _groupOldWalls = List<WallSegment>.unmodifiable(callbacks.currentWalls);
    _groupOldRooms = List<Room>.unmodifiable(callbacks.currentRooms);
    onStateChanged();
  }

  /// Grid-snapped translation `cursor − anchor` (Alt = raw, free
  /// placement). Mirrors [_computeRoomMoveDelta].
  Point2D _computeGroupDelta(Point2D cursor) {
    final anchor = _groupDragAnchor!;
    if (_altHeld) {
      return Point2D(x: cursor.x - anchor.x, y: cursor.y - anchor.y);
    }
    final spacing = callbacks.currentGridSpacingMm;
    final dx = ((cursor.x - anchor.x) / spacing).roundToDouble() * spacing;
    final dy = ((cursor.y - anchor.y) / spacing).roundToDouble() * spacing;
    return Point2D(x: dx, y: dy);
  }

  /// True when [p] coincides with an original endpoint of a group wall.
  bool _endpointInGroup(Point2D p) {
    for (final g in _groupWallsAtStart) {
      if (_pointsEqual(g.startPoint, p) || _pointsEqual(g.endPoint, p)) {
        return true;
      }
    }
    return false;
  }

  /// Apply a live group translation (transient only — committed on
  /// [onDragEnd]). Translates from the frozen snapshots each frame so the
  /// motion is never accumulated.
  void _applyGroupDrag(Point2D delta) {
    // 1. Translate every selected wall rigidly.
    for (final w in _groupWallsAtStart) {
      callbacks.updateWallTransient(
        w.copyWith(
          startPoint:
              Point2D(x: w.startPoint.x + delta.x, y: w.startPoint.y + delta.y),
          endPoint:
              Point2D(x: w.endPoint.x + delta.x, y: w.endPoint.y + delta.y),
        ),
      );
    }

    // 2. Move the shared corners of connected (non-group) walls. An
    //    endpoint that coincided with an original group endpoint follows
    //    by `delta`; the rest of the wall stays put (so a perpendicular
    //    divider just lengthens and stays axis-aligned).
    for (final c in _groupConnectedAtStart) {
      var updated = c;
      var changed = false;
      if (_endpointInGroup(c.startPoint)) {
        updated = updated.copyWith(
          startPoint:
              Point2D(x: c.startPoint.x + delta.x, y: c.startPoint.y + delta.y),
        );
        changed = true;
      }
      if (_endpointInGroup(c.endPoint)) {
        updated = updated.copyWith(
          endPoint:
              Point2D(x: c.endPoint.x + delta.x, y: c.endPoint.y + delta.y),
        );
        changed = true;
      }
      if (changed) callbacks.updateWallTransient(updated);
    }

    // 3. Rebuild affected room polygons from their now-moved walls.
    _rebuildGroupRoomPolygons();
  }

  /// Keep-orientation group translate (ADR-027 generalised to a set).
  ///
  /// The whole selection slides by the perpendicular component of the
  /// pointer motion (relative to the grab wall's normal) — the parallel
  /// component is dropped, so the walls never slide along their own axis.
  /// Each connected (non-group) wall's shared corner is recomputed as the
  /// intersection of that wall's fixed line with the moved group wall's new
  /// line, so connected walls keep their direction and only change length
  /// (angles to the rest of the plan are preserved).
  void _applyGroupDragKeepOrientation(Point2D worldPoint) {
    final ref = _groupGrabWall ??
        (_groupWallsAtStart.isNotEmpty ? _groupWallsAtStart.first : null);
    if (ref == null) return;

    final dirX = ref.endPoint.x - ref.startPoint.x;
    final dirY = ref.endPoint.y - ref.startPoint.y;
    final len = math.sqrt(dirX * dirX + dirY * dirY);
    if (len < 1e-6) {
      // Degenerate grab wall — fall back to the plain translate.
      _applyGroupDrag(_computeGroupDelta(worldPoint));
      return;
    }

    // Unit normal of the grab wall.
    final nx = -dirY / len;
    final ny = dirX / len;
    final anchor = _groupDragAnchor!;

    // Perpendicular component of the raw pointer delta. Grid-snap the
    // offset along the normal (Alt = free placement) exactly as the
    // single-wall path does.
    var perp =
        (worldPoint.x - anchor.x) * nx + (worldPoint.y - anchor.y) * ny;
    if (!_altHeld) {
      final movedRef = Point2D(
        x: ref.startPoint.x + perp * nx,
        y: ref.startPoint.y + perp * ny,
      );
      final snapped = SnapService.snapToGrid(
        movedRef,
        callbacks.currentGridSpacingMm,
      );
      perp = (snapped.x - ref.startPoint.x) * nx +
          (snapped.y - ref.startPoint.y) * ny;
    }
    final ox = perp * nx;
    final oy = perp * ny;

    // Translate every group wall by the same perpendicular offset, then
    // pin each endpoint shared with a non-group wall to the recomputed
    // corner. Record orig→new so the connected walls follow to the exact
    // same corners.
    final remap = <(Point2D, Point2D)>[];
    for (final w in _groupWallsAtStart) {
      final lineStart =
          Point2D(x: w.startPoint.x + ox, y: w.startPoint.y + oy);
      final lineEnd = Point2D(x: w.endPoint.x + ox, y: w.endPoint.y + oy);
      final newStart =
          _groupCornerFor(w.startPoint, w.id, lineStart, lineEnd) ?? lineStart;
      final newEnd =
          _groupCornerFor(w.endPoint, w.id, lineStart, lineEnd) ?? lineEnd;
      callbacks.updateWallTransient(
        w.copyWith(startPoint: newStart, endPoint: newEnd),
      );
      remap.add((w.startPoint, newStart));
      remap.add((w.endPoint, newEnd));
    }

    // Connected (non-group) walls follow their shared corner only —
    // length changes, orientation preserved.
    for (final c in _groupConnectedAtStart) {
      var updated = c;
      var changed = false;
      final ns = _remapLookup(remap, c.startPoint);
      if (ns != null) {
        updated = updated.copyWith(startPoint: ns);
        changed = true;
      }
      final ne = _remapLookup(remap, c.endPoint);
      if (ne != null) {
        updated = updated.copyWith(endPoint: ne);
        changed = true;
      }
      if (changed) callbacks.updateWallTransient(updated);
    }

    _rebuildGroupRoomPolygons();
  }

  /// New position of a group wall's [origEndpoint] under keep-orientation:
  /// the intersection of a connected non-group wall's fixed line (through
  /// its far endpoint and [origEndpoint]) with the moved group wall's new
  /// line ([lineStart]–[lineEnd]). Returns null when no usable
  /// (non-parallel, non-mirror) connected wall is attached there.
  Point2D? _groupCornerFor(
    Point2D origEndpoint,
    String wallId,
    Point2D lineStart,
    Point2D lineEnd,
  ) {
    for (final conn in _groupConnectedAtStart) {
      // Skip the ADR-011 mirror partner: collinear with the group wall, so
      // no useful intersection. It is synced via updateWallTransient.
      if (conn.mirrorId == wallId) continue;
      Point2D? farPoint;
      if (_pointsEqual(conn.startPoint, origEndpoint)) {
        farPoint = conn.endPoint;
      } else if (_pointsEqual(conn.endPoint, origEndpoint)) {
        farPoint = conn.startPoint;
      }
      if (farPoint == null) continue;
      final hit = GeometryEngine.lineIntersection(
        farPoint,
        origEndpoint,
        lineStart,
        lineEnd,
      );
      if (hit != null) return hit;
    }
    return null;
  }

  /// Look up the new position of [p] in an orig→new corner [remap].
  Point2D? _remapLookup(List<(Point2D, Point2D)> remap, Point2D p) {
    for (final pair in remap) {
      if (_pointsEqual(pair.$1, p)) return pair.$2;
    }
    return null;
  }

  /// Rebuild the polygon of every room touched by the group drag from its
  /// (now-moved) walls.
  void _rebuildGroupRoomPolygons() {
    for (final roomId in _groupRoomIds) {
      final room = callbacks.currentRooms
          .where((r) => r.id == roomId)
          .firstOrNull;
      if (room == null) continue;
      final roomWalls = callbacks.currentWalls
          .where((w) => w.roomId == roomId)
          .toList();
      if (roomWalls.length < 3) continue;
      final polygon = _buildPolygonFromWalls(roomWalls);
      if (polygon.isNotEmpty) {
        callbacks.updateRoomTransient(room.copyWith(polygon: polygon));
      }
    }
  }

  /// Persist the settled group geometry and push one atomic undo command.
  ///
  /// The drag wrote transient (in-memory) state only, so the final values
  /// are routed through the persisting [EditorCallbacks.updateWall] /
  /// [EditorCallbacks.updateRoom] before snapshotting — the same pattern
  /// as [_commitRectReshape] / [_commitRoomMove].
  void _commitGroupDrag() {
    final movedIds = <String>{
      for (final w in _groupWallsAtStart) w.id,
      for (final c in _groupConnectedAtStart) c.id,
    };

    var anyChange = false;
    for (final id in movedIds) {
      final cur =
          callbacks.currentWalls.where((w) => w.id == id).firstOrNull;
      final old = _groupOldWalls.where((w) => w.id == id).firstOrNull;
      if (cur == null || old == null) continue;
      if (cur.startPoint != old.startPoint || cur.endPoint != old.endPoint) {
        callbacks.updateWall(cur);
        anyChange = true;
      }
    }
    if (!anyChange) return;

    for (final roomId in _groupRoomIds) {
      final cur =
          callbacks.currentRooms.where((r) => r.id == roomId).firstOrNull;
      if (cur != null) callbacks.updateRoom(cur);
    }

    final newWalls = List<WallSegment>.unmodifiable(callbacks.currentWalls);
    final newRooms = List<Room>.unmodifiable(callbacks.currentRooms);
    undoRedo.execute(_GroupMoveWallsCommand(
      callbacks: callbacks,
      oldWalls: _groupOldWalls,
      oldRooms: _groupOldRooms,
      newWalls: newWalls,
      newRooms: newRooms,
    ));

    // Refresh the selection to the live (post-move) wall instances.
    _multiWalls = [
      for (final w in _multiWalls)
        if (callbacks.currentWalls
                .where((x) => x.id == w.id)
                .firstOrNull
            case final live?)
          live,
    ];
    _selectedWall = _multiWalls.isEmpty ? null : _multiWalls.last;
  }

  /// Transient-restore the pre-drag geometry (cancel / Escape).
  void _revertGroupDrag() {
    for (final w in [..._groupWallsAtStart, ..._groupConnectedAtStart]) {
      final old = _groupOldWalls.where((o) => o.id == w.id).firstOrNull;
      if (old != null) callbacks.updateWallTransient(old);
    }
    for (final roomId in _groupRoomIds) {
      final old = _groupOldRooms.where((o) => o.id == roomId).firstOrNull;
      if (old != null) callbacks.updateRoomTransient(old);
    }
  }

  void _clearGroupDragState() {
    _groupWallsAtStart = const [];
    _groupConnectedAtStart = const [];
    _groupRoomIds = const {};
    _groupDragAnchor = null;
    _groupDragActive = false;
    _groupOldWalls = const [];
    _groupOldRooms = const [];
    _groupKeepOrientation = false;
    _groupGrabWall = null;
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
  // ADR-016: move entire room by interior drag
  // ================================================================

  /// Returns true when [worldPoint] lies inside some room polygon and
  /// is NOT within a wall hit-band (ADR-016 Rule 1).
  ///
  /// "Inside a room interior" is the trigger condition for a room-move
  /// drag; it is also what gates the grab/grabbing cursor. The wall
  /// hit-band exclusion delegates to [_hitTestWall], which uses the
  /// same 100 mm half-thickness already used for wall selection — so
  /// "near a wall" never arms a room move.
  bool _isRoomInteriorHit(Point2D worldPoint) {
    // Disqualify: pointer over any opening / circuit / distributor.
    if (_hitTestWindow(worldPoint) != null) return false;
    if (_hitTestDoor(worldPoint) != null) return false;
    if (_hitTestCircuit(worldPoint) != null) return false;
    final dist = callbacks.currentDistributor;
    if (dist != null && _isPointOnDistributor(worldPoint, dist)) {
      return false;
    }
    // Disqualify: pointer inside a wall hit-band.
    if (_hitTestWall(worldPoint) != null) return false;
    // Qualify only if some room polygon contains the point.
    for (final r in callbacks.currentRooms) {
      if (r.polygon.length >= 3 &&
          GeometryUtils.containsPoint(r.polygon, worldPoint)) {
        return true;
      }
    }
    return false;
  }

  /// Smallest-area room containing [worldPoint], matching the
  /// hit-stack room ordering used elsewhere in this tool.
  Room? _roomContaining(Point2D worldPoint) {
    final rooms = callbacks.currentRooms
        .where(
          (r) =>
              r.polygon.length >= 3 &&
              GeometryUtils.containsPoint(r.polygon, worldPoint),
        )
        .toList()
      ..sort(
        (a, b) => GeometryUtils.area(a.polygon)
            .compareTo(GeometryUtils.area(b.polygon)),
      );
    return rooms.isEmpty ? null : rooms.first;
  }

  /// Arm the room-move gesture when [worldPoint] qualifies as a room
  /// interior with no competing element (ADR-016 Rule 1).
  ///
  /// The arming snapshots the room, its walls, its zones, and the full
  /// pre-move state so:
  ///   - the drag's ghost can translate the snapshot every frame
  ///     without touching live state,
  ///   - the commit uses the original geometry as the source of truth,
  ///   - the "Move room" undo command can revert detaches, splits, and
  ///     mirror-copy insertions atomically (Rule 5).
  void _armRoomMoveIfApplicable(Point2D worldPoint) {
    if (!_isRoomInteriorHit(worldPoint)) return;
    final room = _roomContaining(worldPoint);
    if (room == null) return;

    _roomPointerInside = true;
    _roomMoveAnchor = worldPoint;
    _roomMoveRoom = room;
    _roomMoveDragActive = false;
    _roomMoveDelta = const Point2D(x: 0, y: 0);
    _roomMoveWallsAtStart = callbacks.currentWalls
        .where((w) => w.roomId == room.id)
        .toList(growable: false);
    _roomMoveZonesAtStart = callbacks.currentZones
        .where((z) => z.roomId == room.id)
        .toList(growable: false);
    _roomMoveOldWalls =
        List<WallSegment>.unmodifiable(callbacks.currentWalls);
    _roomMoveOldRooms =
        List<Room>.unmodifiable(callbacks.currentRooms);
    _roomMoveOldZones =
        List<HeatingZone>.unmodifiable(callbacks.currentZones);
    onStateChanged();
  }

  /// Compute the translation delta for the current cursor (ADR-016 R2).
  ///
  /// Default = grid-snapped vector `cursor − anchor`. With Alt held the
  /// raw cursor wins (free placement, matching other tools' convention).
  Point2D _computeRoomMoveDelta(Point2D cursor) {
    final anchor = _roomMoveAnchor!;
    if (_altHeld) {
      return Point2D(x: cursor.x - anchor.x, y: cursor.y - anchor.y);
    }
    // Snap the *delta* to the grid so the rigid translation lands on
    // grid-aligned positions regardless of where the press started.
    final spacing = callbacks.currentGridSpacingMm;
    final dx = ((cursor.x - anchor.x) / spacing).roundToDouble() * spacing;
    final dy = ((cursor.y - anchor.y) / spacing).roundToDouble() * spacing;
    return Point2D(x: dx, y: dy);
  }

  void _clearRoomMoveState() {
    _roomPointerInside = false;
    _roomMoveAnchor = null;
    _roomMoveRoom = null;
    _roomMoveWallsAtStart = const [];
    _roomMoveZonesAtStart = const [];
    _roomMoveOldWalls = const [];
    _roomMoveOldRooms = const [];
    _roomMoveOldZones = const [];
    _roomMoveDragActive = false;
    _roomMoveDelta = const Point2D(x: 0, y: 0);
  }

  /// Reconcile the moved room against existing rooms on drop (ADR-016
  /// Rules 3–6).
  ///
  /// Pipeline (faithful reuse of the room-draw path; no shared-wall
  /// logic is re-implemented here):
  ///
  ///   1. Snapshot the post-detach delta corner so any nearby existing
  ///      corner can fold into the translation (ADR-009 Rule 1
  ///      `snapRectCorner`). The whole-room translation stays rigid:
  ///      one corner's snap delta is applied uniformly to every wall.
  ///   2. Detach any shared-wall partner of the moved room. The partner
  ///      reverts to `exterior` with `mirrorId` / `adjacentRoomId`
  ///      cleared on both sides (Rule 3); the moved room's own copy is
  ///      removed in step 3 anyway.
  ///   3. Remove the moved room's walls and its Room entity so the
  ///      room-draw pipeline (`commitWallWithSplit` +
  ///      `addRoomFromDetection`) can re-create them at the destination.
  ///   4. For each translated edge, either reuse a matching existing
  ///      room wall (`SnapService.matchExistingWall`, 50 mm both
  ///      endpoints — same matcher as `WallDrawTool` rect mode) or
  ///      create a fresh unassigned wall and route it through
  ///      `commitWallWithSplit` (ADR-003 host-wall split).
  ///   5. `addRoomFromDetection` re-adds the room with its original id
  ///      / name / temperature and the new wall ids; promote +
  ///      ADR-001 mirror copy + ADR-011 `mirrorId` linkage happen
  ///      inside that one call.
  ///   6. Translate each zone polygon by the same delta.
  ///   7. Push one "Move room" command that snapshots the full final
  ///      state so a single Ctrl+Z reverts the move including
  ///      regenerated / severed shared walls (Rule 5).
  void _commitRoomMove(Point2D rawCursor) {
    final room = _roomMoveRoom;
    if (room == null) return;
    var delta = _computeRoomMoveDelta(rawCursor);

    // (1) ADR-009 Rule 1 corner snap on the translated corners; pick the
    // nearest snap and fold its offset back into the whole-room delta so
    // the translation stays rigid (no shearing).
    if (!_altHeld) {
      final otherWalls = callbacks.currentWalls
          .where((w) => w.roomId != room.id)
          .toList(growable: false);
      double bestAdjX = 0;
      double bestAdjY = 0;
      double bestDist = double.infinity;
      for (final w in _roomMoveWallsAtStart) {
        for (final ep in [w.startPoint, w.endPoint]) {
          final translated = Point2D(x: ep.x + delta.x, y: ep.y + delta.y);
          final snapped = SnapService.snapRectCorner(
            translated,
            otherWalls,
            callbacks.currentGridSpacingMm,
          );
          if (snapped == translated) continue;
          final adjX = snapped.x - translated.x;
          final adjY = snapped.y - translated.y;
          final d = adjX * adjX + adjY * adjY;
          if (d < bestDist) {
            bestDist = d;
            bestAdjX = adjX;
            bestAdjY = adjY;
          }
        }
      }
      if (bestDist != double.infinity) {
        delta = Point2D(x: delta.x + bestAdjX, y: delta.y + bestAdjY);
      }
    }

    // Pure-rotation-no-translation: a click without drag past threshold
    // never reaches _commitRoomMove (the deferred-tap branch handles
    // that), but a drag that snapped back to zero is still a no-op.
    if (delta.x == 0 && delta.y == 0) return;

    // (2) Detach shared partners before we delete the moved room's walls.
    // Each partner's mirrorId is nulled out *before* updateWall runs so
    // ADR-011 mirror sync cannot pull the moved wall along with it.
    final partnersToDetach = <WallSegment>[];
    for (final w in _roomMoveWallsAtStart) {
      final partnerId = w.mirrorId;
      if (partnerId == null) continue;
      final partner = callbacks.currentWalls
          .where((p) => p.id == partnerId)
          .firstOrNull;
      if (partner == null) continue;
      partnersToDetach.add(
        partner.copyWith(
          wallType: WallType.exterior,
          adjacentRoomId: null,
          mirrorId: null,
        ),
      );
    }
    for (final detached in partnersToDetach) {
      callbacks.updateWall(detached);
    }

    // (3) Remove the moved room's walls and the Room entity, so the
    // reconciliation can recreate them via the room-draw pipeline. The
    // Room object itself is re-added in step (5) with the same id /
    // name / temp / etc. — only `polygon` is translated.
    for (final w in _roomMoveWallsAtStart) {
      callbacks.removeWall(w.id);
    }
    callbacks.destroyRoom(room.id);

    // (4) Recreate edges. For each pre-move wall translate its endpoints
    // by `delta`, then either match an existing room-assigned wall
    // (50 mm both endpoints, ADR-009 Rule 2) or insert a fresh wall via
    // `commitWallWithSplit` (ADR-003 host split when an endpoint lands
    // mid-wall). The collected `roomWallIds` are passed to
    // `addRoomFromDetection` in step (5).
    //
    // ADR-017: when the fresh path is taken, the original wall's
    // [wallType], [thicknessMm], [anchorMode], and [constructionId] are
    // carried over so the recreated wall is the same physical wall the
    // user configured pre-move. Previously-shared walls (`mirrorId !=
    // null`) revert to [WallType.exterior] per ADR-016 Rule 3; the
    // forced-centerline anchor of the shared pair is reset so
    // `commitWallWithSplit`'s Rule 2 default upgrade kicks in.
    //
    // For matched edges (shared-wall promotion), the moved-side wall's
    // pre-move properties are threaded through to `addRoomFromDetection`
    // via `movedSideProperties` so its Rule 8 resolver can see both
    // sides of the merge (ADR-017 Rule 8 cases a–d).
    final wallIdsForRoom = <String>[];
    final movedSideProps = <String, WallSegment>{};
    for (final w in _roomMoveWallsAtStart) {
      final a = Point2D(x: w.startPoint.x + delta.x, y: w.startPoint.y + delta.y);
      final b = Point2D(x: w.endPoint.x + delta.x, y: w.endPoint.y + delta.y);
      final match = SnapService.matchExistingWall(
        a,
        b,
        callbacks.currentWalls,
      );
      if (match != null) {
        wallIdsForRoom.add(match.id);
        movedSideProps[match.id] = w;
        continue;
      }
      final wasShared = w.mirrorId != null;
      final fresh = WallSegment(
        id: IdGenerator.newId(),
        roomId: '',
        startPoint: a,
        endPoint: b,
        wallType: wasShared ? WallType.exterior : w.wallType,
        thicknessMm: w.thicknessMm,
        anchorMode: wasShared ? WallAnchorMode.centerline : w.anchorMode,
        constructionId: w.constructionId,
      );
      // This path builds the room boundary itself from `fresh.id`, so the
      // new wall must stay intact — opt out of reverse new-wall splitting
      // (host splits still apply). Partial-overlap reconciliation here is
      // handled by `matchExistingWall` above.
      callbacks.commitWallWithSplit(fresh, splitNewWall: false);
      wallIdsForRoom.add(fresh.id);
    }

    // (5) Re-add the moved room with translated polygon via the same
    // promote-+-mirror pipeline used by room drawing. Room identity
    // (id, name, target temp, …) is preserved.
    final translatedPolygon = [
      for (final p in room.polygon)
        Point2D(x: p.x + delta.x, y: p.y + delta.y),
    ];
    callbacks.addRoomFromDetection(
      room: room.copyWith(polygon: translatedPolygon),
      wallIds: wallIdsForRoom,
      movedSideProperties: movedSideProps,
    );

    // (6) Translate the room's zones by the same delta. roomId stays
    // unchanged so zone-to-room linkage survives the move.
    for (final z in _roomMoveZonesAtStart) {
      final newPoly = [
        for (final v in z.polygon)
          Point2D(x: v.x + delta.x, y: v.y + delta.y),
      ];
      callbacks.updateZone(z.copyWith(polygon: newPoly));
    }

    // (7) Snapshot the post-state and push a single undo command that
    // atomically reverts every change in one Ctrl+Z (Rule 5).
    final newWalls = List<WallSegment>.unmodifiable(callbacks.currentWalls);
    final newRooms = List<Room>.unmodifiable(callbacks.currentRooms);
    final newZones = List<HeatingZone>.unmodifiable(callbacks.currentZones);

    undoRedo.execute(_MoveRoomCommand(
      callbacks: callbacks,
      oldWalls: _roomMoveOldWalls,
      oldRooms: _roomMoveOldRooms,
      oldZones: _roomMoveOldZones,
      newWalls: newWalls,
      newRooms: newRooms,
      newZones: newZones,
    ));

    // Keep the moved room selected so the properties panel updates.
    _selectedRoom = callbacks.currentRooms
        .where((r) => r.id == room.id)
        .firstOrNull;
    if (_selectedRoom != null) {
      callbacks.selectElement('room', _selectedRoom!.id);
    }
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

  /// Returns the live state of [room] from [EditorCallbacks.currentRooms],
  /// falling back to the cached snapshot when the room is gone. Mirrors
  /// [_currentWallState] so the selection highlight (the blue room fill)
  /// tracks polygon edits made outside this tool — e.g. a Width/Height
  /// change committed from the room properties panel (ADR-015).
  Room _currentRoomState(Room room) {
    return callbacks.currentRooms
            .where((r) => r.id == room.id)
            .firstOrNull ??
        room;
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
  /// the nearest wall within [SnapService.wallHoverThresholdMm], outlet
  /// stubs facing away from the wall (ADR-044).
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
    return SnapService.distributorRotationAlongWall(position, nearest);
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
        callbacks.updateDistributorTransient(orig.copyWith(
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
        callbacks.updateDistributorTransient(orig.copyWith(
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
        callbacks.updateDistributorTransient(orig.copyWith(
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

/// Command: ADR-019 cascade delete of a room.
///
/// Snapshots the full pre- and post-delete tuples (walls + rooms +
/// zones + windows + doors) so one Ctrl+Z restores the room, every
/// cascaded child, and every reverted mirror partner in a single
/// atomic state update. Mirrors the `_MoveRoomCommand` /
/// `_RectDrawCommand` snapshot pattern — DAO writes are issued during
/// the initial `destroyRoomCascade` call and are not re-applied on
/// undo (the in-memory state is authoritative).
class _DeleteRoomCommand extends Command {
  _DeleteRoomCommand({
    required this.callbacks,
    required this.oldWalls,
    required this.oldRooms,
    required this.oldZones,
    required this.oldWindows,
    required this.oldDoors,
    required this.newWalls,
    required this.newRooms,
    required this.newZones,
    required this.newWindows,
    required this.newDoors,
    required this.label,
  });

  final EditorCallbacks callbacks;
  final List<WallSegment> oldWalls;
  final List<Room> oldRooms;
  final List<HeatingZone> oldZones;
  final List<WindowElement> oldWindows;
  final List<Door> oldDoors;
  final List<WallSegment> newWalls;
  final List<Room> newRooms;
  final List<HeatingZone> newZones;
  final List<WindowElement> newWindows;
  final List<Door> newDoors;

  @override
  final String label;

  @override
  void execute() => callbacks.replaceAllForRoomCascade(
        newWalls,
        newRooms,
        newZones,
        newWindows,
        newDoors,
      );

  @override
  void undo() => callbacks.replaceAllForRoomCascade(
        oldWalls,
        oldRooms,
        oldZones,
        oldWindows,
        oldDoors,
      );
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

/// Command: ADR-034 multi-wall group translate — all selected walls plus
/// their connected boundary walls and rebuilt room polygons replaced
/// atomically, so one Ctrl+Z reverts the whole move (including any ADR-011
/// mirror-partner updates the translation triggered).
///
/// Mirrors [_RectReshapeCommand]: DAO writes are issued during the
/// `_commitGroupDrag` `updateWall`/`updateRoom` calls; the initial
/// `execute()` reconcile is therefore a no-op (state already equals the new
/// tuple) and only matters for redo.
class _GroupMoveWallsCommand extends Command {
  _GroupMoveWallsCommand({
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
  String get label => 'Move walls';

  @override
  void execute() =>
      callbacks.replaceAllWallsAndRooms(newWalls, newRooms);

  @override
  void undo() =>
      callbacks.replaceAllWallsAndRooms(oldWalls, oldRooms);
}

/// Command: ADR-016 move entire room — walls + rooms + zones replaced
/// atomically so a single Ctrl+Z reverts the whole move including
/// regenerated / severed shared walls and translated zones.
///
/// Mirrors [_RectReshapeCommand] / [_RectDrawCommand] (the existing
/// before/after snapshot pattern in this codebase); the only difference
/// is that this command also captures zones because the moved room's
/// `HeatingZone` polygons translated with the room.
class _MoveRoomCommand extends Command {
  _MoveRoomCommand({
    required this.callbacks,
    required this.oldWalls,
    required this.oldRooms,
    required this.oldZones,
    required this.newWalls,
    required this.newRooms,
    required this.newZones,
  });

  final EditorCallbacks callbacks;
  final List<WallSegment> oldWalls;
  final List<Room> oldRooms;
  final List<HeatingZone> oldZones;
  final List<WallSegment> newWalls;
  final List<Room> newRooms;
  final List<HeatingZone> newZones;

  @override
  String get label => 'Move room';

  @override
  void execute() =>
      callbacks.replaceAllWallsRoomsZones(newWalls, newRooms, newZones);

  @override
  void undo() =>
      callbacks.replaceAllWallsRoomsZones(oldWalls, oldRooms, oldZones);
}

/// Command: move a zone polygon (vertex drag or body drag).
/// One corner point of a circuit's supply or return route.
typedef _RoutePointRef = ({bool supply, int index});

/// Command: reshape several zones at once — one boundary drag
/// (ADR-037 Rule 5). [oldZones] and [newZones] are index-aligned.
class _MoveZonesCommand extends Command {
  _MoveZonesCommand({
    required this.oldZones,
    required this.newZones,
    required this.update,
    required this.label,
  });

  final List<HeatingZone> oldZones;
  final List<HeatingZone> newZones;
  final void Function(HeatingZone) update;

  @override
  final String label;

  @override
  void execute() => newZones.forEach(update);

  @override
  void undo() => oldZones.forEach(update);
}

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
