import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/door.dart';
import '../../../data/models/point2d.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';
import 'snap_service.dart';
import 'tool_base.dart';
import 'undo_redo_service.dart';

/// Tool for placing [Door] objects on wall segments.
///
/// The user hovers over a wall to see a preview of the
/// door at the cursor position, then clicks to commit it
/// with default dimensions. The properties panel opens
/// automatically to allow editing.
class DoorPlaceTool extends CanvasTool {
  /// Creates a [DoorPlaceTool].
  DoorPlaceTool({
    required super.callbacks,
    required super.onStateChanged,
    required this.undoRedo,
  });

  /// Shared undo/redo service.
  final UndoRedoService undoRedo;

  /// Default door width in mm.
  static const double _defaultWidthMm = 900.0;

  /// Currently hovered wall start (world mm).
  Point2D? _hoveredWallStart;

  /// Currently hovered wall end (world mm).
  Point2D? _hoveredWallEnd;

  /// Hovered wall ID.
  String? _hoveredWallId;

  /// Preview position along the wall (mm from start).
  double? _previewPositionMm;

  @override
  String get name => 'Place Door';

  @override
  void onPointerMove(Point2D worldPoint) {
    final wall = SnapService.nearestWall(
      worldPoint,
      callbacks.currentWalls,
    );

    if (wall == null) {
      _hoveredWallStart = null;
      _hoveredWallEnd = null;
      _hoveredWallId = null;
      _previewPositionMm = null;
      onStateChanged();
      return;
    }

    final wallLengthMm = GeometryEngine.distanceMm(
      wall.startPoint,
      wall.endPoint,
    );
    final rawPos = SnapService.positionOnWallMm(
      worldPoint,
      wall,
    );
    // Centre the preview on the cursor, clamp to wall.
    final leftEdge = (rawPos - _defaultWidthMm / 2).clamp(
      0.0,
      (wallLengthMm - _defaultWidthMm).clamp(0.0, double.infinity),
    );

    _hoveredWallStart = wall.startPoint;
    _hoveredWallEnd = wall.endPoint;
    _hoveredWallId = wall.id;
    _previewPositionMm = leftEdge;
    onStateChanged();
  }

  @override
  void onTap(Point2D worldPoint, PointerDeviceKind deviceKind) {
    if (_hoveredWallId == null || _previewPositionMm == null) {
      return;
    }

    final wall = callbacks.currentWalls
        .where((w) => w.id == _hoveredWallId)
        .firstOrNull;
    if (wall == null) return;

    final wallLengthMm = GeometryEngine.distanceMm(
      wall.startPoint,
      wall.endPoint,
    );

    // Abort if door doesn't fit.
    if (wallLengthMm < _defaultWidthMm) {
      callbacks.showToast(
        'Wall too short for door '
        '(min ${_defaultWidthMm.round()} mm)',
      );
      return;
    }

    final doorId = IdGenerator.newId();
    final door = Door(
      id: doorId,
      wallSegmentId: _hoveredWallId!,
      positionOnWallMm: _previewPositionMm!,
    );

    // commitDoor is called inside the command's execute().
    undoRedo.execute(_PlaceDoorCommand(
      callbacks: callbacks,
      door: door,
    ));

    // Select the new door in the properties panel.
    callbacks.selectElement('door', doorId);
  }

  @override
  void cancel() {
    _hoveredWallStart = null;
    _hoveredWallEnd = null;
    _hoveredWallId = null;
    _previewPositionMm = null;
    onStateChanged();
  }

  @override
  InteractionData? getInteractionData() {
    if (_hoveredWallStart == null || _hoveredWallEnd == null) {
      return null;
    }
    return WallHighlightData(
      wallStart: _hoveredWallStart!,
      wallEnd: _hoveredWallEnd!,
      previewPositionMm: _previewPositionMm,
      previewWidthMm: _defaultWidthMm,
      isWindow: false,
    );
  }
}

// ================================================================
// Command
// ================================================================

/// Command: place a new door on a wall.
class _PlaceDoorCommand extends Command {
  _PlaceDoorCommand({
    required this.callbacks,
    required this.door,
  });

  final EditorCallbacks callbacks;
  final Door door;

  @override
  String get label => 'Place door';

  @override
  void execute() => callbacks.commitDoor(door);

  @override
  void undo() => callbacks.removeDoor(door.id);
}
