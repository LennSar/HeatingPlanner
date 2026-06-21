import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';
import 'modifier_draw_tool.dart';
import 'room_detection.dart';
import 'snap_service.dart';
import 'tool_base.dart';
import 'undo_redo_service.dart';

/// Tool for drawing wall segments by click-click.
///
/// First click sets the start point, second click commits
/// the wall. The endpoint becomes the next start (chaining).
/// Alternatively, press and hold, drag to the endpoint, and
/// release: a wall held a typical duration commits on release
/// (no chaining). Escape cancels the current segment.
///
/// Modifier key behaviour (shared [ModifierDrawTool] flags):
/// - **Shift** ([orthoSnap]): constrain endpoint to H or V axis
///   from the anchor, whichever is closer to the cursor.
/// - **Ctrl** ([rectMode]): drag from corner A to corner B and
///   commit four wall segments forming a closed rectangle.
/// - **Alt** ([freePlacement]): skip grid snap for the current
///   point; the raw world coordinate is used instead.
class WallDrawTool extends CanvasTool with ModifierDrawTool {
  /// Creates a [WallDrawTool].
  WallDrawTool({
    required super.callbacks,
    required super.onStateChanged,
    required this.undoRedo,
  });

  /// Shared undo/redo service.
  final UndoRedoService undoRedo;

  /// Fixed start point of the current wall being drawn.
  Point2D? _startPoint;

  /// Current snapped cursor position.
  Point2D? _currentSnapped;

  /// Snap type for the current cursor position.
  SnapType? _currentSnapType;

  /// Existing room corner the current endpoint is X-aligned to (vertical
  /// alignment guide), or null when no corner shares the endpoint's X.
  Point2D? _alignXAnchor;

  /// Existing room corner the current endpoint is Y-aligned to (horizontal
  /// alignment guide), or null when no corner shares the endpoint's Y.
  Point2D? _alignYAnchor;

  // ---- Rect-mode drag state ----
  Point2D? _dragStart;

  // ---- Non-rect press-hold-drag state ----

  /// Snapped world point captured on pointer-down (the anchor for a
  /// press-hold-drag when no [_startPoint] has been set yet).
  Point2D? _pressSnapped;

  /// Timestamp of the last pointer-down, used to tell a deliberate
  /// press-hold-drag from an accidental micro-jitter during a click.
  DateTime? _pressTime;

  /// Minimum wall length in mm (prevents zero-length walls).
  static const double _minLengthMm = 100.0;

  /// A press held at least this long before release is treated as a
  /// deliberate hold-drag (commits the wall) even if the cursor barely
  /// moved. Shorter presses fall back to click-click semantics.
  static const int _holdThresholdMs = 200;

  @override
  String get name => 'Draw Wall';

  // ---- Snap helper ----

  /// Snap [worldPoint] according to active modifier flags.
  ///
  /// - Alt ([freePlacement]) → raw point (no grid snap, no
  ///   endpoint snap).
  /// - Otherwise → normal [SnapService.snap] (endpoint / wall /
  ///   grid snap).
  Point2D _snap(Point2D worldPoint) {
    if (freePlacement) return worldPoint;
    final result = SnapService.snap(
      worldPoint,
      callbacks.currentWalls,
      callbacks.currentGridSpacingMm,
    );
    _currentSnapType = result.type;
    return result.point;
  }

  /// Resolve the prospective wall endpoint for [worldPoint]: grid/endpoint/wall
  /// snap → ortho constraint (from [anchor]) → corner alignment.
  ///
  /// [anchor] is the effective start of the segment being drawn (the click-
  /// chain [_startPoint], or the press point for a fresh press-hold-drag); when
  /// null the raw snapped point is returned (placing the start point itself).
  ///
  /// Captures any aligned corner(s) in [_alignXAnchor] / [_alignYAnchor] so
  /// [getInteractionData] can draw the dashed alignment guides. Alignment is
  /// always active while an [anchor] exists; under ortho ([orthoSnap]) only the
  /// free axis is re-aligned so the constrained axis stays locked. When the
  /// point already endpoint-snaps onto a corner, no extra alignment is applied.
  Point2D _resolveEndpoint(Point2D worldPoint, Point2D? anchor) {
    final snapped = _snap(worldPoint);
    if (anchor == null) {
      _alignXAnchor = null;
      _alignYAnchor = null;
      return snapped;
    }

    final ortho = applyOrtho(anchor, snapped);

    // Alt bypasses snapping entirely (raw placement); skip alignment too.
    // Already exactly on a corner — nothing to align further.
    if (freePlacement || _currentSnapType == SnapType.endpoint) {
      _alignXAnchor = null;
      _alignYAnchor = null;
      return ortho;
    }

    // Under ortho the constrained axis is fixed; only re-align the free axis.
    var alignX = true;
    var alignY = true;
    if (orthoSnap) {
      final horizontal =
          (snapped.x - anchor.x).abs() >= (snapped.y - anchor.y).abs();
      alignX = horizontal; // horizontal run → Y locked → X is free
      alignY = !horizontal;
    }

    final result = SnapService.alignToCorners(
      ortho,
      callbacks.currentWalls,
      alignX: alignX,
      alignY: alignY,
    );
    _alignXAnchor = result.xAnchor;
    _alignYAnchor = result.yAnchor;
    return result.point;
  }

  // ---- CanvasTool overrides ----

  @override
  void onPointerDown(Point2D worldPoint, int buttons) {
    syncModifiersFromHardware();
    if (!rectMode) {
      // Non-rect: record the press so a press-hold-drag can commit a
      // wall on release (handled in onDragEnd). A pure click without a
      // drag is still handled by onTap (click-click), unchanged.
      _pressTime = DateTime.now();
      _pressSnapped = _resolveEndpoint(worldPoint, _startPoint);
      _currentSnapped = _pressSnapped;
      onStateChanged();
      return;
    }
    // Grid snap then corner snap (ADR-009 §Rule 1).
    _dragStart = SnapService.snapRectCorner(
      _snap(worldPoint),
      callbacks.currentWalls,
      callbacks.currentGridSpacingMm,
    );
    _currentSnapped = _dragStart;
    onStateChanged();
  }

  @override
  void onDragUpdate(Point2D worldPoint) {
    if (!rectMode) {
      // Non-rect press-hold-drag: live ghost line from the anchor
      // (existing start point, or the press point for a fresh wall).
      final anchor = _startPoint ?? _pressSnapped;
      if (anchor == null) return;
      _currentSnapped = _resolveEndpoint(worldPoint, anchor);
      onStateChanged();
      return;
    }
    if (_dragStart == null) return;
    // Grid snap → ortho → corner snap.
    final orthoSnapped = applyOrtho(_dragStart!, _snap(worldPoint));
    _currentSnapped = SnapService.snapRectCorner(
      orthoSnapped,
      callbacks.currentWalls,
      callbacks.currentGridSpacingMm,
    );
    onStateChanged();
  }

  @override
  void onDragEnd(Point2D worldPoint) {
    if (!rectMode) {
      // Non-rect press-hold-drag: commit a single wall on release.
      // The anchor is the existing start point (mid-chain) or the
      // press point captured on pointer-down for a fresh wall. onTap
      // may already have set _startPoint to the press point (it fires
      // ~100 ms into a slow press); either way the anchor is the same.
      final anchor = _startPoint ?? _pressSnapped;
      final pressTime = _pressTime;
      _pressSnapped = null;
      _pressTime = null;
      if (anchor == null) return;

      final end = _resolveEndpoint(worldPoint, anchor);
      final lengthMm = GeometryEngine.distanceMm(anchor, end);
      final heldLongEnough = pressTime != null &&
          DateTime.now().difference(pressTime).inMilliseconds >=
              _holdThresholdMs;

      // Only a deliberate hold-drag (held a typical duration and long
      // enough to be intentional) commits. Otherwise the gesture was a
      // click with a stray micro-jitter — leave click-click state, which
      // onTap has already established, untouched.
      if (!heldLongEnough || lengthMm < _minLengthMm) {
        _currentSnapped = _startPoint;
        onStateChanged();
        return;
      }

      _commitWall(anchor, end);
      // A hold-drag finishes the wall on release (no chaining).
      _startPoint = null;
      _currentSnapped = null;
      _currentSnapType = null;
      onStateChanged();
      return;
    }
    final start = _dragStart;
    _dragStart = null;
    if (start == null) return;

    // Grid snap (a) → ortho (b) → corner snap (c) → dimension snap (d).
    // Order matches ADR-010 §Rule 3.
    final end = SnapService.snapRectDimension(
      start,
      SnapService.snapRectCorner(
        applyOrtho(start, _snap(worldPoint)),
        callbacks.currentWalls,
        callbacks.currentGridSpacingMm,
      ),
      callbacks.currentWalls,
    );

    final w = (end.x - start.x).abs();
    final h = (end.y - start.y).abs();

    if (w < _minLengthMm || h < _minLengthMm) {
      callbacks.showToast('Rectangle too small — both sides must be ≥ 100 mm');
      _currentSnapped = null;
      onStateChanged();
      return;
    }

    // Build four corner points.
    final tl = Point2D(
      x: start.x < end.x ? start.x : end.x,
      y: start.y < end.y ? start.y : end.y,
    );
    final tr = Point2D(x: tl.x + w, y: tl.y);
    final br = Point2D(x: tl.x + w, y: tl.y + h);
    final bl = Point2D(x: tl.x, y: tl.y + h);

    // Snapshot walls and rooms before any mutations (for undo).
    final oldWalls = callbacks.currentWalls.toList();
    final oldRooms = callbacks.currentRooms.toList();

    // Commit each edge, reusing any room-assigned wall that already
    // matches the edge within 50 mm (ADR-009 §Rules 2–3). Unmatched
    // edges go through commitWallWithSplit so ADR-003 corner-split
    // logic applies at intersections.
    //
    // firstNewWall tracks the first wall that was actually committed
    // this drag. It is used (instead of lastEffectiveWall) as the
    // anchor for room detection so that BFS starts on a freshly-added
    // wall. When the last processed edge happens to be a matched
    // existing wall (e.g. edge 4 = the shared edge), BFS from that
    // wall's endpoint traverses the matched room's own existing cycle
    // (same hop-count as Room 2's path) and returns the wrong wallIds.
    // Starting BFS from a new wall avoids this ambiguity entirely.
    WallSegment? firstNewWall;
    WallSegment? lastEffectiveWall;
    for (final (a, b) in [(tl, tr), (tr, br), (br, bl), (bl, tl)]) {
      final match = SnapService.matchExistingWall(a, b, oldWalls);
      if (match != null) {
        // Reuse the existing wall; addRoomFromDetection will promote it
        // to WallType.interior and insert the ADR-001 mirror copy.
        lastEffectiveWall = match;
      } else {
        final wall = WallSegment(
          id: IdGenerator.newId(),
          roomId: '',
          startPoint: a,
          endPoint: b,
        );
        callbacks.commitWallWithSplit(wall);
        lastEffectiveWall = wall;
        firstNewWall ??= wall;
      }
    }

    if (lastEffectiveWall == null) {
      // All four edges matched — degenerate rect on top of existing room.
      _currentSnapped = null;
      onStateChanged();
      return;
    }

    final newWalls = callbacks.currentWalls.toList();

    // Register one undo command covering walls + room (ADR-009 §Rule 5).
    // newRooms starts as oldRooms (safe default when dialog is cancelled).
    // The onCreated callback updates it when the room is confirmed.
    final cmd = _RectDrawCommand(
      callbacks: callbacks,
      oldWalls: oldWalls,
      oldRooms: oldRooms,
      newWalls: newWalls,
      newRooms: oldRooms,
    );
    undoRedo.execute(cmd);

    // Use a newly committed wall as the BFS anchor for room detection.
    // Falling back to lastEffectiveWall (an existing matched wall) can
    // cause BFS to return the neighbouring room's own cycle when both
    // paths have the same hop-count (see comment above).
    final detectionWall = firstNewWall ?? lastEffectiveWall;
    final allWalls = callbacks.currentWalls;
    final result = RoomDetection.detectRoom(
      allWalls,
      detectionWall,
      existingRooms: callbacks.currentRooms,
    );
    switch (result.outcome) {
      case RoomDetectionOutcome.detected:
        callbacks.requestRoomDialog(
          result.room!.polygon,
          result.room!.wallIds,
          onCreated: (walls, rooms) {
            // Update the undo command so a single Ctrl+Z reverts both
            // the rect walls and the newly created room.
            cmd.newWalls = walls;
            cmd.newRooms = rooms;
          },
        );
      case RoomDetectionOutcome.overlapsExistingRoom:
        callbacks.showToast(_overlapErrorMessage);
      case RoomDetectionOutcome.none:
        break;
    }

    _currentSnapped = null;
    onStateChanged();
  }

  @override
  void onTap(
    Point2D worldPoint,
    PointerDeviceKind deviceKind,
  ) {
    syncModifiersFromHardware();
    if (rectMode) return; // rect mode uses drag, not tap

    final snapped = _resolveEndpoint(worldPoint, _startPoint);

    if (_startPoint == null) {
      // First click: set start point.
      _startPoint = snapped;
      onStateChanged();
      return;
    }

    // Second click: validate and commit wall.
    final lengthMm = GeometryEngine.distanceMm(_startPoint!, snapped);
    if (lengthMm < _minLengthMm) return;

    _commitWall(_startPoint!, snapped);

    // Chain: use endpoint as next start.
    _startPoint = snapped;
    onStateChanged();
  }

  /// Build, commit (with host-wall split), register undo for, and run
  /// room detection on a single wall from [start] to [end].
  void _commitWall(Point2D start, Point2D end) {
    final wall = WallSegment(
      id: IdGenerator.newId(),
      roomId: '',
      startPoint: start,
      endPoint: end,
    );

    // Snapshot walls before commit for undo.
    final oldWalls = callbacks.currentWalls.toList();
    callbacks.commitWallWithSplit(wall);
    // Snapshot walls after commit for redo.
    final newWalls = callbacks.currentWalls.toList();

    // Register as undoable command. execute() is a no-op on
    // first call because state is already at newWalls.
    undoRedo.execute(_CreateWallCommand(
      callbacks: callbacks,
      oldWalls: oldWalls,
      newWalls: newWalls,
    ));

    // Check for room detection.
    final result = RoomDetection.detectRoom(
      callbacks.currentWalls,
      wall,
      existingRooms: callbacks.currentRooms,
    );
    switch (result.outcome) {
      case RoomDetectionOutcome.detected:
        callbacks.requestRoomDialog(
          result.room!.polygon,
          result.room!.wallIds,
        );
      case RoomDetectionOutcome.overlapsExistingRoom:
        callbacks.showToast(_overlapErrorMessage);
      case RoomDetectionOutcome.none:
        break;
    }
  }

  /// Toast shown when a drawn wall loop cannot form a unique room
  /// because every candidate constellation overlaps an existing room.
  static const String _overlapErrorMessage =
      'Cannot create room — these walls overlap an existing room. '
      'Adjust the walls so the new room does not enclose another.';

  @override
  void onPointerMove(Point2D worldPoint) {
    if (rectMode) {
      if (_dragStart != null) {
        // Mirror onDragUpdate: grid snap → ortho → corner snap so the
        // ghost rectangle preview matches what will be committed.
        final orthoSnapped = applyOrtho(_dragStart!, _snap(worldPoint));
        _currentSnapped = SnapService.snapRectCorner(
          orthoSnapped,
          callbacks.currentWalls,
          callbacks.currentGridSpacingMm,
        );
      }
    } else {
      // _resolveEndpoint applies snap (sets _currentSnapType), ortho, and
      // corner alignment, capturing any alignment anchors for the guides.
      _currentSnapped = _resolveEndpoint(worldPoint, _startPoint);
    }
    onStateChanged();
  }

  @override
  void cancel() {
    _startPoint = null;
    _dragStart = null;
    _pressSnapped = null;
    _pressTime = null;
    _currentSnapped = null;
    _currentSnapType = null;
    _alignXAnchor = null;
    _alignYAnchor = null;
    onStateChanged();
  }

  @override
  InteractionData? getInteractionData() {
    if (rectMode && _dragStart != null && _currentSnapped != null) {
      return RectDrawData(corner1: _dragStart!, corner2: _currentSnapped!);
    }
    if (_startPoint == null || _currentSnapped == null) {
      return null;
    }

    // Build ortho guideline when Shift is held (shared helper —
    // extends 20 m each way along the constrained axis so it spans
    // the visible canvas at any zoom level).
    final (orthoStart, orthoEnd) =
        orthoGuideline(_startPoint!, _currentSnapped!);

    return GhostLineData(
      startPoint: _startPoint!,
      currentPoint: _currentSnapped!,
      snapIndicator:
          (_currentSnapType == SnapType.endpoint ||
                  _currentSnapType == SnapType.wallPoint)
              ? _currentSnapped
              : null,
      snapType: _currentSnapType?.name,
      orthoGuidelineStart: orthoStart,
      orthoGuidelineEnd: orthoEnd,
      alignXAnchor: _alignXAnchor,
      alignYAnchor: _alignYAnchor,
    );
  }
}

// ================================================================
// Command classes
// ================================================================

/// Command: draw a new wall segment (with optional host-wall split).
///
/// Stores the full wall list before and after [commitWallWithSplit]
/// so the entire operation — new wall plus any split fragments —
/// can be reversed as one atomic undo step.
class _CreateWallCommand extends Command {
  _CreateWallCommand({
    required this.callbacks,
    required this.oldWalls,
    required this.newWalls,
  });

  final EditorCallbacks callbacks;
  final List<WallSegment> oldWalls;
  final List<WallSegment> newWalls;

  @override
  String get label => 'Draw wall';

  @override
  void execute() => callbacks.replaceAllWalls(newWalls);

  @override
  void undo() => callbacks.replaceAllWalls(oldWalls);
}

/// Command: draw a rectangle (four walls + optional room detection).
///
/// Created in [WallDrawTool.onDragEnd] when rect mode is active.
/// [newWalls] and [newRooms] are initialised to the post-wall-commit
/// state (before the room dialog). If the dialog is confirmed, the
/// [onCreated] callback updates them to the full post-room state so
/// that a single Ctrl+Z reverts both the rect walls and the room
/// entity (ADR-009 §Rule 5). If the dialog is cancelled, undo still
/// correctly reverts only the walls.
class _RectDrawCommand extends Command {
  _RectDrawCommand({
    required this.callbacks,
    required this.oldWalls,
    required this.oldRooms,
    required List<WallSegment> newWalls,
    required List<Room> newRooms,
  })  : newWalls = List.of(newWalls),
        newRooms = List.of(newRooms);

  final EditorCallbacks callbacks;
  final List<WallSegment> oldWalls;
  final List<Room> oldRooms;

  /// Mutable: updated by the room-dialog [onCreated] callback.
  List<WallSegment> newWalls;

  /// Mutable: updated by the room-dialog [onCreated] callback.
  List<Room> newRooms;

  @override
  String get label => 'Draw rectangle';

  @override
  void execute() =>
      callbacks.replaceAllWallsAndRooms(newWalls, newRooms);

  @override
  void undo() =>
      callbacks.replaceAllWallsAndRooms(oldWalls, oldRooms);
}
