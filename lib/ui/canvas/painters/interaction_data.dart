import 'package:flutter/foundation.dart';

import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';

/// Data produced by tools for the interaction painter.
sealed class InteractionData {
  const InteractionData();
}

/// Ghost shown while placing a distributor on the floor plan.
@immutable
class DistributorGhostData extends InteractionData {
  /// Creates [DistributorGhostData] at [position] (world mm).
  const DistributorGhostData({
    required this.position,
    required this.widthMm,
    this.rotationDeg = 0,
  });

  /// Grid-snapped cursor position in world coordinates (mm).
  final Point2D position;

  /// Body width in world-space mm.
  final double widthMm;

  /// Current wall-snapped rotation in degrees (0, 90, 180, or 270).
  final int rotationDeg;
}

/// Selection highlight for a distributor element.
///
/// Produced by [SelectTool] when a distributor is selected.
/// Tells [InteractionPainter] to draw a selection rect and
/// three resize handles (left edge, centre, right edge).
@immutable
class DistributorSelectionData extends InteractionData {
  /// Creates [DistributorSelectionData].
  const DistributorSelectionData({
    required this.position,
    required this.widthMm,
    required this.handles,
    this.activeHandleIndex,
    this.rotationDeg = 0,
  });

  /// Centre of the distributor in world coordinates (mm).
  final Point2D position;

  /// Body width in world-space mm.
  final double widthMm;

  /// Three handle positions: [0] left edge, [1] centre, [2] right edge.
  final List<Point2D> handles;

  /// Index of the currently dragged handle, or null.
  final int? activeHandleIndex;

  /// Current rotation in degrees (0, 90, 180, or 270).
  final int rotationDeg;
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

/// Selection data for a selected wall heating zone.
///
/// Produced by [SelectTool] when a [ZoneType.wallHeating] zone is
/// selected. Conveys the parent wall geometry, zone position/width,
/// and three drag handle positions (left edge, centre, right edge)
/// so [InteractionPainter] can draw the selection band and handles.
@immutable
class WallZoneSelectionData extends InteractionData {
  /// Creates [WallZoneSelectionData].
  const WallZoneSelectionData({
    required this.wallStart,
    required this.wallEnd,
    required this.positionOnWallMm,
    required this.widthMm,
    required this.handles,
    this.activeHandleIndex,
  });

  /// Start endpoint of the parent wall (world mm).
  final Point2D wallStart;

  /// End endpoint of the parent wall (world mm).
  final Point2D wallEnd;

  /// Distance from wall start to the zone's left edge (mm).
  final double positionOnWallMm;

  /// Width of the zone along the wall (mm).
  final double widthMm;

  /// Handle positions: [0] = left edge, [1] = centre, [2] = right edge.
  final List<Point2D> handles;

  /// Index of the handle currently being dragged (0–2), or null.
  final int? activeHandleIndex;
}

/// Cursor data for the wall zone placement tool when not over a valid wall.
///
/// Produced by [WallZonePlaceTool] when the cursor is not within
/// hit-distance of any room-assigned wall segment. The
/// [InteractionPainter] draws the red prohibition indicator near
/// the cursor to signal that clicking has no effect.
@immutable
class WallZoneNoHoverData extends InteractionData {
  /// Creates [WallZoneNoHoverData].
  const WallZoneNoHoverData({required this.cursorPosition});

  /// Current cursor position (world mm).
  final Point2D cursorPosition;
}

/// Hover highlight for the wall zone placement tool.
///
/// Produced by [WallZonePlaceTool] when the cursor is within
/// hit-distance of a room-assigned wall segment. The
/// [InteractionPainter] draws a warm amber overlay on the wall
/// to signal that clicking will place a wall heating zone.
@immutable
class WallZoneHoverData extends InteractionData {
  /// Creates [WallZoneHoverData].
  const WallZoneHoverData({
    required this.wallStart,
    required this.wallEnd,
  });

  /// Start endpoint of the highlighted wall (world mm).
  final Point2D wallStart;

  /// End endpoint of the highlighted wall (world mm).
  final Point2D wallEnd;
}

/// Phase of a pipe circuit routing operation.
///
/// Used by [RouteDrawData] to indicate which segment of
/// the circuit is currently being drawn.
enum RoutePhase {
  /// Drawing the supply line from the distributor to the zone.
  supply,

  /// Drawing the return line from the zone back to the distributor.
  returnLine,
}

/// Data produced by [RouteDrawTool] during circuit routing.
///
/// Emitted each frame so [InteractionPainter] can render:
///  - committed supply and return waypoints as solid polylines
///  - a dashed ghost edge from the last waypoint to the cursor
///  - directional arrows every 500 mm along each committed path
///  - a warning indicator when hovering over an already-connected zone
@immutable
class RouteDrawData extends InteractionData {
  /// Creates [RouteDrawData].
  const RouteDrawData({
    required this.phase,
    required this.supplyPoints,
    this.returnPoints = const [],
    this.currentPoint,
    this.hoveredZoneAlreadyConnected = false,
    this.cumulativeLengthMm = 0.0,
  });

  /// Current routing phase.
  final RoutePhase phase;

  /// Supply route waypoints committed so far (world mm).
  final List<Point2D> supplyPoints;

  /// Return route waypoints committed so far (world mm).
  final List<Point2D> returnPoints;

  /// Current cursor position (world mm), null when off-canvas.
  final Point2D? currentPoint;

  /// True when the cursor hovers over a zone that already has
  /// an assigned circuit — triggers the warning indicator.
  final bool hoveredZoneAlreadyConnected;

  /// Cumulative pipe length in mm (supply + return + ghost edge).
  ///
  /// Shown in the status bar as the user draws the route.
  final double cumulativeLengthMm;
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

