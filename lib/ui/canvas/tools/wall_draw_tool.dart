import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/wall_segment.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';
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
/// Modifier key behaviour:
/// - **Shift** (`_orthoSnap`): constrain endpoint to H or V axis
///   from the anchor, whichever is closer to the cursor.
/// - **Ctrl** (`_rectMode`): drag from corner A to corner B and
///   commit four wall segments forming a closed rectangle.
/// - **Alt** (`_freePlacement`): skip grid snap for the current
///   point; the raw world coordinate is used instead.
class WallDrawTool extends CanvasTool {
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

  // ---- Modifier flags ----

  /// Shift key: constrain ghost-line endpoint to 0° or 90°.
  bool _orthoSnap = false;

  /// Ctrl key: rectangle mode (drag four walls at once).
  bool _rectMode = false;

  /// Alt key: disable grid snap; use raw world coordinate.
  bool _freePlacement = false;

  // ---- Rect-mode drag state ----
  Point2D? _dragStart;

  /// Minimum wall length in mm (prevents zero-length walls).
  static const double _minLengthMm = 100.0;

  @override
  String get name => 'Draw Wall';

  // ---- Modifier key tracking ----

  /// Update modifier flags from a keyboard event.
  ///
  /// Call on both key-down and key-up so flags stay in sync.
  void updateModifiers({
    required bool shift,
    required bool ctrl,
    required bool alt,
  }) {
    _orthoSnap = shift;
    _rectMode = ctrl;
    _freePlacement = alt;
    onStateChanged();
  }

  // ---- Snap helper ----

  /// Snap [worldPoint] according to active modifier flags.
  ///
  /// - Alt → raw point (no grid snap, no endpoint snap).
  /// - Otherwise → normal [SnapService.snap].
  Point2D _snap(Point2D worldPoint) {
    if (_freePlacement) return worldPoint;
    final result = SnapService.snap(worldPoint, callbacks.currentWalls);
    _currentSnapType = result.type;
    return result.point;
  }

  /// Apply ortho constraint to [endpoint] relative to [anchor].
  ///
  /// If Δx ≥ Δy the endpoint is constrained to the same Y as
  /// the anchor (horizontal). Otherwise the same X (vertical).
  Point2D _ortho(Point2D anchor, Point2D endpoint) {
    if (!_orthoSnap) return endpoint;
    final dx = (endpoint.x - anchor.x).abs();
    final dy = (endpoint.y - anchor.y).abs();
    if (dx >= dy) {
      // Horizontal: lock Y.
      return Point2D(x: endpoint.x, y: anchor.y);
    } else {
      // Vertical: lock X.
      return Point2D(x: anchor.x, y: endpoint.y);
    }
  }

  // ---- CanvasTool overrides ----

  @override
  void onPointerDown(Point2D worldPoint, int buttons) {
    if (!_rectMode) return;
    _dragStart = _snap(worldPoint);
    _currentSnapped = _dragStart;
    onStateChanged();
  }

  @override
  void onDragUpdate(Point2D worldPoint) {
    if (!_rectMode || _dragStart == null) return;
    _currentSnapped = _ortho(_dragStart!, _snap(worldPoint));
    onStateChanged();
  }

  @override
  void onDragEnd(Point2D worldPoint) {
    if (!_rectMode) return;
    final start = _dragStart;
    _dragStart = null;
    if (start == null) return;

    final end = _ortho(start, _snap(worldPoint));

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

    final walls = [
      WallSegment(id: IdGenerator.newId(), roomId: '', startPoint: tl, endPoint: tr),
      WallSegment(id: IdGenerator.newId(), roomId: '', startPoint: tr, endPoint: br),
      WallSegment(id: IdGenerator.newId(), roomId: '', startPoint: br, endPoint: bl),
      WallSegment(id: IdGenerator.newId(), roomId: '', startPoint: bl, endPoint: tl),
    ];

    final oldWalls = callbacks.currentWalls.toList();
    for (final wall in walls) {
      callbacks.commitWall(wall);
    }
    final newWalls = callbacks.currentWalls.toList();

    undoRedo.execute(_CreateWallCommand(
      callbacks: callbacks,
      oldWalls: oldWalls,
      newWalls: newWalls,
    ));

    // Trigger room detection for the last wall.
    final lastWall = walls.last;
    final allWalls = callbacks.currentWalls;
    final detected = RoomDetection.detectClosedRoom(allWalls, lastWall);
    if (detected != null) {
      callbacks.requestRoomDialog(detected.polygon, detected.wallIds);
    }

    _currentSnapped = null;
    onStateChanged();
  }

  @override
  void onTap(
    Point2D worldPoint,
    PointerDeviceKind deviceKind,
  ) {
    if (_rectMode) return; // rect mode uses drag, not tap

    final snapped = _ortho(
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
    if (_rectMode) {
      if (_dragStart != null) {
        _currentSnapped = _ortho(_dragStart!, _snap(worldPoint));
      }
    } else {
      final snap = SnapService.snap(worldPoint, callbacks.currentWalls);
      _currentSnapped = _startPoint != null
          ? _ortho(_startPoint!, snap.point)
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
    if (_rectMode && _dragStart != null && _currentSnapped != null) {
      return RectDrawData(corner1: _dragStart!, corner2: _currentSnapped!);
    }
    if (_startPoint == null || _currentSnapped == null) {
      return null;
    }

    return GhostLineData(
      startPoint: _startPoint!,
      currentPoint: _currentSnapped!,
      snapIndicator:
          (_currentSnapType == SnapType.endpoint ||
                  _currentSnapType == SnapType.wallPoint)
              ? _currentSnapped
              : null,
      snapType: _currentSnapType?.name,
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
