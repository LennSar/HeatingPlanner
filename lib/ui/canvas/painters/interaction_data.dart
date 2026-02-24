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
