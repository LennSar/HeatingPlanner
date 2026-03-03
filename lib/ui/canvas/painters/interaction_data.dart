import 'package:flutter/foundation.dart';

import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';

/// Data produced by tools for the interaction painter.
sealed class InteractionData {
  const InteractionData();
}

/// Ghost line shown while drawing a wall.
@immutable
class GhostLineData extends InteractionData {
  /// Creates [GhostLineData].
  const GhostLineData({
    required this.startPoint,
    required this.currentPoint,
    this.snapIndicator,
    this.snapType,
  });

  /// Fixed start of the ghost line (world mm).
  final Point2D startPoint;

  /// Current snapped cursor position (world mm).
  final Point2D currentPoint;

  /// Position of the snap indicator, if snapping.
  final Point2D? snapIndicator;

  /// Type of snap ('endpoint', 'wallPoint', or 'grid').
  final String? snapType;
}

/// Highlight data for selected elements.
@immutable
class SelectionHighlightData extends InteractionData {
  /// Creates [SelectionHighlightData].
  const SelectionHighlightData({
    this.selectedWalls = const [],
    this.selectedRoom,
    this.handles = const [],
    this.activeHandleIndex,
  });

  /// Walls currently selected / highlighted.
  final List<WallSegment> selectedWalls;

  /// Room currently selected / highlighted.
  final Room? selectedRoom;

  /// Drag handles on the selected wall (start, mid, end).
  final List<Point2D> handles;

  /// Index of the handle currently being dragged (0–2),
  /// or null if not dragging.
  final int? activeHandleIndex;
}

/// Which kind of handle is being dragged.
enum DragHandleType {
  /// Start endpoint handle.
  start,

  /// Midpoint handle (translates entire wall).
  mid,

  /// End endpoint handle.
  end,
}

/// Highlight data for window/door placement hover state.
///
/// Shown while the user hovers the window or door tool
/// over a wall segment to indicate where the opening
/// will be placed.
@immutable
class WallHighlightData extends InteractionData {
  /// Creates [WallHighlightData].
  const WallHighlightData({
    required this.wallStart,
    required this.wallEnd,
    this.previewPositionMm,
    this.previewWidthMm = 1200.0,
    this.isWindow = true,
  });

  /// Start of the highlighted wall (world mm).
  final Point2D wallStart;

  /// End of the highlighted wall (world mm).
  final Point2D wallEnd;

  /// Position of the preview opening along the wall
  /// (mm from wall start). Null = no specific preview.
  final double? previewPositionMm;

  /// Width of the preview opening in mm.
  final double previewWidthMm;

  /// True for window preview; false for door preview.
  final bool isWindow;
}

/// Highlight data for a selected window or door element.
///
/// Produced by [SelectTool] when a window or door is
/// selected. Conveys the opening's rectangle geometry and
/// drag handle positions (left edge, move, right edge).
@immutable
class OpeningSelectionData extends InteractionData {
  /// Creates [OpeningSelectionData].
  const OpeningSelectionData({
    required this.wallStart,
    required this.wallEnd,
    required this.positionOnWallMm,
    required this.widthMm,
    required this.isWindow,
    required this.handles,
    this.activeHandleIndex,
  });

  /// Start of the parent wall (world mm).
  final Point2D wallStart;

  /// End of the parent wall (world mm).
  final Point2D wallEnd;

  /// Distance from wall start to the opening's left edge (mm).
  final double positionOnWallMm;

  /// Width of the opening (mm).
  final double widthMm;

  /// True for window; false for door.
  final bool isWindow;

  /// Handle positions: [0] = left edge, [1] = mid/move,
  /// [2] = right edge. All on the wall centre-line (world mm).
  final List<Point2D> handles;

  /// Index of the handle currently being dragged (0–2),
  /// or null if not dragging.
  final int? activeHandleIndex;
}

