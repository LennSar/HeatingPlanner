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

/// Ghost polygon data produced while drawing a heating zone.
///
/// Emitted by [ZoneDrawTool] each frame so [InteractionPainter]
/// can render the in-progress polygon, the ghost edge to the
/// cursor, vertex dots, the close-indicator ring, and (when
/// applicable) the red validation-error overlay or the
/// prohibition indicator when the cursor is outside all valid
/// placement areas.
@immutable
class ZoneDrawData extends InteractionData {
  /// Creates [ZoneDrawData].
  const ZoneDrawData({
    required this.vertices,
    this.currentPoint,
    this.hasValidationError = false,
    this.cursorOutsideValidArea = false,
  });

  /// Committed polygon vertices so far (world mm).
  final List<Point2D> vertices;

  /// Current cursor position for the ghost edge (world mm).
  /// Null while the cursor is outside the canvas.
  final Point2D? currentPoint;

  /// True when the most recent close attempt failed because one
  /// or more vertices lay outside the parent room — triggers the
  /// red warning overlay.
  final bool hasValidationError;

  /// True when the cursor is outside all valid placement areas
  /// (no room, or outside primary room and its door-adjacent
  /// neighbours). Triggers the red prohibition indicator.
  final bool cursorOutsideValidArea;
}

/// Highlight data for a selected heating zone.
///
/// Produced by [SelectTool] when a heating zone is selected.
/// Conveys the zone polygon, vertex drag handles, and the
/// currently-active handle index so [InteractionPainter] can
/// draw the selection outline, fill, and editing handles.
@immutable
class ZoneSelectionData extends InteractionData {
  /// Creates [ZoneSelectionData].
  const ZoneSelectionData({
    required this.polygon,
    this.handles = const [],
    this.activeHandleIndex,
  });

  /// Zone polygon vertices (world mm).
  final List<Point2D> polygon;

  /// Handle positions (one per polygon vertex, world mm).
  /// Empty when no editing handles should be shown.
  final List<Point2D> handles;

  /// Index within [handles] of the handle currently being
  /// dragged, or null if no handle is active.
  final int? activeHandleIndex;
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

