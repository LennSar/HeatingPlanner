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

  /// Minimum wall length in mm (prevents zero-length walls).
  static const double _minLengthMm = 100.0;

  @override
  String get name => 'Draw Wall';

  @override
  void onTap(
    Point2D worldPoint,
    PointerDeviceKind deviceKind,
  ) {
    final snap = SnapService.snap(
      worldPoint,
      callbacks.currentWalls,
    );
    final snapped = snap.point;

    if (_startPoint == null) {
      // First click: set start point.
      _startPoint = snapped;
      onStateChanged();
      return;
    }

    // Second click: validate and commit wall.
    final lengthMm = GeometryEngine.distanceMm(
      _startPoint!,
      snapped,
    );
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
    final detected = RoomDetection.detectClosedRoom(
      allWalls,
      wall,
    );
    if (detected != null) {
      callbacks.requestRoomDialog(
        detected.polygon,
        detected.wallIds,
      );
    }
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    final snap = SnapService.snap(
      worldPoint,
      callbacks.currentWalls,
    );
    _currentSnapped = snap.point;
    _currentSnapType = snap.type;
    onStateChanged();
  }

  @override
  void cancel() {
    _startPoint = null;
    _currentSnapped = null;
    _currentSnapType = null;
    onStateChanged();
  }

  @override
  InteractionData? getInteractionData() {
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
