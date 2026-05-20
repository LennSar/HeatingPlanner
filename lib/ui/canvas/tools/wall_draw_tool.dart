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
/// Escape cancels the current segment.
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

  // ---- Rect-mode drag state ----
  Point2D? _dragStart;

  /// Minimum wall length in mm (prevents zero-length walls).
  static const double _minLengthMm = 100.0;

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

  // ---- CanvasTool overrides ----

  @override
  void onPointerDown(Point2D worldPoint, int buttons) {
    if (!rectMode) return;
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
    if (!rectMode || _dragStart == null) return;
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
    if (!rectMode) return;
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
    final detected = RoomDetection.detectClosedRoom(allWalls, detectionWall);
    if (detected != null) {
      callbacks.requestRoomDialog(
        detected.polygon,
        detected.wallIds,
        onCreated: (walls, rooms) {
          // Update the undo command so a single Ctrl+Z reverts both
          // the rect walls and the newly created room.
          cmd.newWalls = walls;
          cmd.newRooms = rooms;
        },
      );
    }

    _currentSnapped = null;
    onStateChanged();
  }

  @override
  void onTap(
    Point2D worldPoint,
    PointerDeviceKind deviceKind,
  ) {
    if (rectMode) return; // rect mode uses drag, not tap

    final snapped = applyOrtho(
      _startPoint ?? worldPoint,
      _snap(worldPoint),
    );

    if (_startPoint == null) {
      // First click: set start point.
      _startPoint = snapped;
      onStateChanged();
      return;
    }

    // Second click: validate and commit wall.
    final lengthMm = GeometryEngine.distanceMm(_startPoint!, snapped);
    if (lengthMm < _minLengthMm) return;

    final wall = WallSegment(
      id: IdGenerator.newId(),
      roomId: '',
      startPoint: _startPoint!,
      endPoint: snapped,
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

    // Chain: use endpoint as next start.
    _startPoint = snapped;
    onStateChanged();

    // Check for room detection.
    final allWalls = callbacks.currentWalls;
    final detected = RoomDetection.detectClosedRoom(allWalls, wall);
    if (detected != null) {
      callbacks.requestRoomDialog(detected.polygon, detected.wallIds);
    }
  }

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
      final snap = SnapService.snap(
        worldPoint,
        callbacks.currentWalls,
        callbacks.currentGridSpacingMm,
      );
      _currentSnapped = _startPoint != null
          ? applyOrtho(_startPoint!, snap.point)
          : snap.point;
      _currentSnapType = snap.type;
    }
    onStateChanged();
  }

  @override
  void cancel() {
    _startPoint = null;
    _dragStart = null;
    _currentSnapped = null;
    _currentSnapType = null;
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
