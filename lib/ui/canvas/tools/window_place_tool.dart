import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/window_element.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';
import 'snap_service.dart';
import 'tool_base.dart';
import 'undo_redo_service.dart';

/// Tool for placing [WindowElement] objects on wall
/// segments by clicking.
///
/// The user hovers over a wall to see a preview of the
/// window at the cursor position, then clicks to commit
/// it with default dimensions. The properties panel
/// opens automatically to allow editing.
class WindowPlaceTool extends CanvasTool {
  /// Creates a [WindowPlaceTool].
  WindowPlaceTool({
    required super.callbacks,
    required super.onStateChanged,
    required this.undoRedo,
  });

  /// Shared undo/redo service.
  final UndoRedoService undoRedo;

  /// Default window width in mm.
  static const double _defaultWidthMm = 1200.0;

  /// Currently hovered wall start (world mm).
  Point2D? _hoveredWallStart;

  /// Currently hovered wall end (world mm).
  Point2D? _hoveredWallEnd;

  /// Hovered wall ID.
  String? _hoveredWallId;

  /// Preview position along the wall (mm from start).
  double? _previewPositionMm;

  @override
  String get name => 'Place Window';

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

    // Abort if window doesn't fit.
    if (wallLengthMm < _defaultWidthMm) {
      callbacks.showToast(
        'Wall too short for window '
        '(min ${_defaultWidthMm.round()} mm)',
      );
      return;
    }

    final windowId = IdGenerator.newId();
    final window = WindowElement(
      id: windowId,
      wallSegmentId: _hoveredWallId!,
      positionOnWallMm: _previewPositionMm!,
    );

    // Note: commitWindow is called inside the command's execute().
    // We use execute() so the command is on the undo stack and
    // execute() runs the action.
    undoRedo.execute(_PlaceWindowCommand(
      callbacks: callbacks,
      window: window,
    ));

    // Select the new window in the properties panel.
    callbacks.selectElement('window', windowId);
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
      isWindow: true,
    );
  }
}

// ================================================================
// Command
// ================================================================

/// Command: place a new window on a wall.
class _PlaceWindowCommand extends Command {
  _PlaceWindowCommand({
    required this.callbacks,
    required this.window,
  });

  final EditorCallbacks callbacks;
  final WindowElement window;

  @override
  String get label => 'Place window';

  @override
  void execute() => callbacks.commitWindow(window);

  @override
  void undo() => callbacks.removeWindow(window.id);
}
