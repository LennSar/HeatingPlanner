import 'package:flutter/material.dart';

import '../../../calculation/engines/pipe_layout_engine.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/distributor.dart';
import '../../../data/models/door.dart';
import '../../../data/models/heating_circuit.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';
import '../../../data/models/window_element.dart';
import 'annotation_painter.dart';
import 'distributor_painter.dart';
import 'grid_painter.dart';
import 'heating_zone_painter.dart';
import 'opening_painter.dart';
import 'pipe_route_painter.dart';
import 'wall_painter.dart';

/// The non-interactive world is split into four stacked [CustomPaint]
/// layers — [GridLayerPainter], [GeometryLayerPainter], [PipeLayerPainter]
/// and [AnnotationLayerPainter] — each sitting behind its own
/// `RepaintBoundary`. The split groups sub-painters by what invalidates
/// them so a geometry edit (which mints fresh `walls`/`rooms` list
/// identities every drag frame) repaints only the layers whose inputs
/// actually changed. In particular the grid depends on none of the
/// geometry and therefore never repaints during a wall or room drag, and the
/// expensive annotation text layout (ADR-026) is isolated on its own layer
/// fed by a drag-throttled geometry snapshot.
///
/// Stacking order, bottom → top: grid, then geometry (zones → walls →
/// openings), then pipes/distributor, then annotations. This reproduces the
/// exact draw order of the former single-pass painter.

/// Bottom layer: the dot grid.
///
/// Depends only on the world [transform], [gridSpacingMm], [visibleRect]
/// and [dotColor]. None of those change while geometry is being dragged,
/// so [shouldRepaint] returns false throughout a wall/room edit and the
/// grid is never rebuilt or redrawn.
class GridLayerPainter extends CustomPainter {
  /// Creates a [GridLayerPainter].
  const GridLayerPainter({
    required this.transform,
    required this.gridSpacingMm,
    required this.visibleRect,
    required this.dotColor,
  });

  /// World → screen transform applied before delegating to [GridPainter].
  final Matrix4 transform;

  /// Grid spacing in mm (world units).
  final double gridSpacingMm;

  /// Visible area in world coordinates.
  final Rect visibleRect;

  /// Colour for grid dots (`HeatingPlannerColors.gridDot`).
  final Color dotColor;

  /// Minimum on-screen spacing (px) between grid dots. Below this the grid
  /// spacing is doubled so a zoomed-out view never tries to draw hundreds of
  /// thousands of sub-pixel dots per frame (the dominant pan/zoom cost).
  static const double _minDotScreenPx = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transform.storage);
    GridPainter(
      gridSpacingMm: _effectiveSpacingMm,
      visibleRect: visibleRect,
      dotColor: dotColor,
    ).paint(canvas, size);
    canvas.restore();
  }

  /// Grid spacing actually drawn: [gridSpacingMm] scaled up by the smallest
  /// power of two that keeps adjacent dots at least [_minDotScreenPx] apart on
  /// screen at the current zoom. This bounds the visible dot count to roughly
  /// (viewport / [_minDotScreenPx])², independent of how far the view is
  /// zoomed out, instead of growing without limit as the zoom shrinks.
  double get _effectiveSpacingMm {
    final scale = transform.storage[0];
    var spacing = gridSpacingMm;
    if (scale > 0 && spacing > 0) {
      while (spacing * scale < _minDotScreenPx) {
        spacing *= 2;
      }
    }
    return spacing;
  }

  @override
  bool shouldRepaint(GridLayerPainter oldDelegate) {
    return transform != oldDelegate.transform ||
        gridSpacingMm != oldDelegate.gridSpacingMm ||
        visibleRect != oldDelegate.visibleRect ||
        dotColor != oldDelegate.dotColor;
  }
}

/// Middle layer: committed geometry — heating zones, walls and openings.
///
/// Repaints when any of the committed geometry collections, the per-zone
/// display states, the [transform], or the theme [colors] change. The
/// list-identity (`identical`) checks mean an in-place geometry edit that
/// mints a fresh list identity triggers a repaint, while an unrelated
/// rebuild that reuses the same lists does not.
class GeometryLayerPainter extends CustomPainter {
  /// Creates a [GeometryLayerPainter].
  const GeometryLayerPainter({
    required this.transform,
    required this.colors,
    required this.walls,
    required this.rooms,
    required this.windows,
    required this.doors,
    required this.zones,
    required this.zoneStates,
    this.zoneLayouts = const {},
    this.zoneColorIndices = const {},
  });

  /// World → screen transform.
  final Matrix4 transform;

  /// Theme colours (identity-stable across rebuilds unless the theme changes).
  final HeatingPlannerColors colors;

  /// All wall segments on the floor.
  final List<WallSegment> walls;

  /// All rooms on the floor.
  final List<Room> rooms;

  /// All windows on the floor.
  final List<WindowElement> windows;

  /// All doors on the floor.
  final List<Door> doors;

  /// All heating zones on the floor.
  final List<HeatingZone> zones;

  /// ADR-004 display state per zone id.
  final Map<String, ZoneColorState> zoneStates;

  /// ADR-038 tube layout per floor zone id.
  final Map<String, ZonePipeLayout> zoneLayouts;

  /// ADR-042 identity colour index per zone id (into
  /// `colors.zonePalette`).
  final Map<String, int> zoneColorIndices;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transform.storage);

    HeatingZonePainter(
      zoneGreen: colors.zoneGreen,
      zoneYellow: colors.zoneYellow,
      zoneRed: colors.zoneRed,
      zoneGrey: colors.zoneGrey,
      supplyPipe: colors.supplyPipe,
      zones: zones,
      zoneStates: zoneStates,
      layouts: zoneLayouts,
      palette: colors.zonePalette,
      colorIndices: zoneColorIndices,
    ).paint(canvas, size);

    WallPainter(
      wallFill: colors.wallFill,
      wallStroke: colors.wallStroke,
      walls: walls,
      rooms: rooms,
    ).paint(canvas, size);

    OpeningPainter(
      windowFill: colors.windowFill,
      doorFill: colors.doorFill,
      walls: walls,
      windows: windows,
      doors: doors,
    ).paint(canvas, size);

    canvas.restore();
  }

  @override
  bool shouldRepaint(GeometryLayerPainter oldDelegate) {
    return transform != oldDelegate.transform ||
        !identical(colors, oldDelegate.colors) ||
        !identical(walls, oldDelegate.walls) ||
        !identical(rooms, oldDelegate.rooms) ||
        !identical(windows, oldDelegate.windows) ||
        !identical(doors, oldDelegate.doors) ||
        !identical(zones, oldDelegate.zones) ||
        !identical(zoneStates, oldDelegate.zoneStates) ||
        !identical(zoneLayouts, oldDelegate.zoneLayouts) ||
        !identical(zoneColorIndices, oldDelegate.zoneColorIndices);
  }
}

/// Third layer: pipe routes and the distributor.
///
/// Cheap vector draws keyed on [circuits] / [distributor]. Split out from the
/// annotation layer (ADR-026) so a distributor or pipe edit never drags the
/// expensive whole-floor text layout along with it, and vice-versa. Does
/// **not** repaint on hover or pointer motion — those flow through the
/// separate interaction layer.
class PipeLayerPainter extends CustomPainter {
  /// Creates a [PipeLayerPainter].
  const PipeLayerPainter({
    required this.transform,
    required this.colors,
    required this.circuits,
    this.zones = const [],
    this.bendRadiiMm = const {},
    this.defaultBendRadiusMm = 80.0,
    this.distributor,
  });

  /// World → screen transform.
  final Matrix4 transform;

  /// Theme colours (identity-stable across rebuilds unless the theme changes).
  final HeatingPlannerColors colors;

  /// All heating circuits — read by the pipe-route painter.
  final List<HeatingCircuit> circuits;

  /// All heating zones — the pipe-route painter stops each route at the
  /// boundary of its own zone, where the zone's tube layout takes over
  /// (ADR-038 Rule 1).
  final List<HeatingZone> zones;

  /// Tube bend radius in mm per zone id (ADR-039 Rule 3).
  final Map<String, double> bendRadiiMm;

  /// Bend radius in mm for a circuit whose zone is unknown.
  final double defaultBendRadiusMm;

  /// The single distributor, or null when none is placed.
  final Distributor? distributor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transform.storage);

    if (distributor != null) {
      DistributorPainter(
        distributor: distributor!,
        bodyColor: colors.wallFill,
        strokeColor: colors.wallStroke,
        labelColor: colors.wallStroke,
      ).paint(canvas, size);
    }

    PipeRoutePainter(
      supplyPipe: colors.supplyPipe,
      returnPipe: colors.returnPipe,
      circuits: circuits,
      zones: zones,
      bendRadiiMm: bendRadiiMm,
      defaultBendRadiusMm: defaultBendRadiusMm,
    ).paint(canvas, size);

    canvas.restore();
  }

  @override
  bool shouldRepaint(PipeLayerPainter oldDelegate) {
    return transform != oldDelegate.transform ||
        !identical(colors, oldDelegate.colors) ||
        !identical(circuits, oldDelegate.circuits) ||
        !identical(zones, oldDelegate.zones) ||
        !identical(bendRadiiMm, oldDelegate.bendRadiiMm) ||
        defaultBendRadiusMm != oldDelegate.defaultBendRadiusMm ||
        distributor != oldDelegate.distributor;
  }
}

/// Top non-interactive layer: dimension annotations (per-wall *Lichtmaß*
/// length labels and per-room width × height labels).
///
/// [AnnotationPainter] lays out a fresh `ui.Paragraph` for every wall and
/// every room on each paint — the most expensive thing the world layers draw.
/// Isolating it behind its own `RepaintBoundary` and keying `shouldRepaint`
/// solely on [walls] / [rooms] means the text layout runs
/// only when that geometry's list identity actually changes. The canvas feeds
/// this layer from [annotationGeometryProvider], which throttles that identity
/// to ~10 fps during a drag (ADR-026): the wall outline moves live every frame,
/// the labels follow at the sampled rate, and a distributor/pipe edit never
/// touches this layer at all.
class AnnotationLayerPainter extends CustomPainter {
  /// Creates an [AnnotationLayerPainter].
  const AnnotationLayerPainter({
    required this.transform,
    required this.onSurface,
    required this.walls,
    required this.rooms,
    this.cache,
  });

  /// World → screen transform.
  final Matrix4 transform;

  /// Colour for annotation text (`ColorScheme.onSurface`).
  final Color onSurface;

  /// All wall segments — read by the annotation painter.
  final List<WallSegment> walls;

  /// All rooms — read by the annotation painter.
  final List<Room> rooms;

  /// Cross-paint cache of laid-out label paragraphs (ADR-026). Owned by the
  /// canvas state so the per-wall/room text layout is reused across pan/zoom
  /// frames, where only [transform] changes.
  final AnnotationLabelCache? cache;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transform.storage);
    AnnotationPainter(
      textColor: onSurface,
      walls: walls,
      rooms: rooms,
      cache: cache,
    ).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AnnotationLayerPainter oldDelegate) {
    return transform != oldDelegate.transform ||
        onSurface != oldDelegate.onSurface ||
        !identical(walls, oldDelegate.walls) ||
        !identical(rooms, oldDelegate.rooms);
  }
}
