import 'dart:math' show sqrt;

import 'package:flutter/material.dart';

import '../../../calculation/engines/pipe_layout_engine.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';

/// ADR-004 display state for a heating zone.
enum ZoneColorState {
  /// No circuit assigned — red hatched (ADR-004 state 1).
  unconnected,

  /// Room has no heat demand — grey fill (ADR-004 state 2).
  noDemand,

  /// Output < 90 % of demand — red fill (ADR-004 state 3).
  insufficient,

  /// Output 90–99 % of demand — yellow fill (ADR-004 state 4).
  marginal,

  /// Output ≥ 100 % of demand — green fill (ADR-004 state 5).
  sufficient,
}

/// Draws committed heating zone polygons on the canvas.
///
/// Each zone is coloured according to ADR-004's priority-ordered
/// state machine. The display state per zone is supplied via
/// [zoneStates]; zones not present in the map default to
/// [ZoneColorState.unconnected] (red hatched).
///
/// Inside every floor zone the tube layout from [layouts] is drawn in the
/// zone's [LayoutPattern]: one continuous tube that starts where the
/// zone's supply line enters it (ADR-038, ADR-042). The outline shows
/// the ADR-004 state; fill and tube use the zone's identity colour from
/// [palette] so neighbouring zones can be told apart (ADR-042 Rule 3). Transit corridors of
/// other circuits are cut out of the zone's fill, hatch and tube layout.
class HeatingZonePainter extends CustomPainter {
  /// Creates a [HeatingZonePainter].
  const HeatingZonePainter({
    required this.zoneGreen,
    required this.zoneYellow,
    required this.zoneRed,
    required this.zoneGrey,
    required this.supplyPipe,
    this.zones = const [],
    this.zoneStates = const {},
    this.layouts = const {},
    this.palette = const [],
    this.colorIndices = const {},
  });

  /// Sufficient-output zone colour.
  final Color zoneGreen;

  /// Marginal-output zone colour.
  final Color zoneYellow;

  /// Insufficient-output / unconnected zone colour.
  final Color zoneRed;

  /// No-demand zone colour.
  final Color zoneGrey;

  /// Supply-pipe colour used for the meander routing preview.
  final Color supplyPipe;

  /// All heating zones to render on this floor.
  final List<HeatingZone> zones;

  /// ADR-004 display state keyed by zone ID.
  final Map<String, ZoneColorState> zoneStates;

  /// ADR-038 tube layout keyed by floor zone ID. A floor zone without
  /// an entry falls back to a layout with no entry point and no transit
  /// corridors.
  final Map<String, ZonePipeLayout> layouts;

  /// Identity colours for telling zones apart (ADR-042 Rule 3). Empty =
  /// zones are filled with their ADR-004 state colour, as before.
  final List<Color> palette;

  /// Index into [palette] per zone id. Neighbouring zones carry
  /// different indices.
  final Map<String, int> colorIndices;

  /// Identity colour of [zone], or null when no palette is in use.
  Color? _identity(HeatingZone zone) {
    if (palette.isEmpty) return null;
    return palette[(colorIndices[zone.id] ?? 0) % palette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final zone in zones) {
      if (zone.polygon.length < 3) continue;

      final outline = Path()
        ..moveTo(zone.polygon.first.x, zone.polygon.first.y);
      for (var i = 1; i < zone.polygon.length; i++) {
        outline.lineTo(zone.polygon[i].x, zone.polygon[i].y);
      }
      outline.close();
      // ADR-038 Rule 3: the heated shape is the polygon minus the
      // transit corridors of other circuits.
      final path = _heatedPath(outline, layouts[zone.id]);

      final state =
          zoneStates[zone.id] ?? ZoneColorState.unconnected;
      switch (state) {
        case ZoneColorState.unconnected:
          if (zone.zoneType == ZoneType.wallHeating) {
            _paintWallZoneUnconnected(canvas, path, zone);
          } else {
            _paintUnconnected(canvas, path, zone);
          }
        case ZoneColorState.noDemand:
          _paintConnected(canvas, path, zone, zoneGrey);
        case ZoneColorState.insufficient:
          _paintConnected(canvas, path, zone, zoneRed);
        case ZoneColorState.marginal:
          _paintConnected(canvas, path, zone, zoneYellow);
        case ZoneColorState.sufficient:
          _paintConnected(canvas, path, zone, zoneGreen);
      }
    }
  }

  /// Paint a connected zone (ADR-004 states 2–5): outline in the state
  /// [color], fill and tube in the zone's identity colour (ADR-042
  /// Rule 3) — or in [color] when no palette is in use.
  void _paintConnected(
    Canvas canvas,
    Path path,
    HeatingZone zone,
    Color color,
  ) {
    canvas.drawPath(
      path,
      Paint()
        ..color = (_identity(zone) ?? color).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
    canvas.save();
    canvas.clipPath(path);
    if (zone.zoneType == ZoneType.wallHeating) {
      _drawWallZoneTubePreview(canvas, zone);
    } else {
      _drawTubeLayout(canvas, zone);
    }
    canvas.restore();
  }

  /// Paint a zone that has no circuit assigned (ADR-004 state 1).
  void _paintUnconnected(
    Canvas canvas,
    Path path,
    HeatingZone zone,
  ) {
    // Semi-transparent red fill.
    canvas.drawPath(
      path,
      Paint()
        ..color = (_identity(zone)?.withValues(alpha: 0.25) ??
            zoneRed.withValues(alpha: 0.15))
        ..style = PaintingStyle.fill,
    );

    // Red zone outline.
    canvas.drawPath(
      path,
      Paint()
        ..color = zoneRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // 45° diagonal hatch lines (clipped to polygon).
    canvas.save();
    canvas.clipPath(path);
    _drawHatch(canvas, path);
    canvas.restore();

    // Tube-routing preview (clipped to polygon).
    canvas.save();
    canvas.clipPath(path);
    _drawTubeLayout(canvas, zone);
    canvas.restore();
  }

  /// Draws 45° diagonal hatch lines across the bounding box of
  /// [path].  The canvas must already be clipped to [path].
  void _drawHatch(Canvas canvas, Path path) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;

    final paint = Paint()
      ..color = zoneRed.withValues(alpha: 0.35)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Spacing between hatch lines in mm (world-space).
    const spacing = 200.0;

    // Draw lines at 45°: start at (left + offset, top),
    // end at (left + offset + height, bottom).
    // Offset runs from -height to +width so lines cover the
    // entire bounding box.
    final h = bounds.height;
    final w = bounds.width;
    var offset = -h;
    while (offset < w) {
      canvas.drawLine(
        Offset(bounds.left + offset, bounds.top),
        Offset(bounds.left + offset + h, bounds.bottom),
        paint,
      );
      offset += spacing;
    }
  }

  /// Returns [outline] with the transit corridors of [layout] removed
  /// (ADR-038 Rule 3), or [outline] itself when there are none.
  Path _heatedPath(Path outline, ZonePipeLayout? layout) {
    if (layout == null || layout.corridors.isEmpty) return outline;
    final cut = Path();
    for (final corridor in layout.corridors) {
      if (corridor.length < 3) continue;
      cut.addPolygon(
        [for (final p in corridor) Offset(p.x, p.y)],
        true,
      );
    }
    return Path.combine(PathOperation.difference, outline, cut);
  }

  /// Draws the tube layout of a floor [zone] in its
  /// [HeatingZone.layoutPattern] (ADR-038 Rule 2, ADR-042 Rule 2).
  ///
  /// Uses the precomputed path from [layouts]; a zone without an entry
  /// there gets a layout with no entry point. The path is one continuous
  /// polyline from the supply to the return pipe.
  ///
  /// The canvas must already be clipped to the zone's heated shape.
  void _drawTubeLayout(Canvas canvas, HeatingZone zone) {
    final List<Point2D> points = layouts[zone.id]?.pipePath ??
        PipeLayoutEngine.tubePath(
          pattern: zone.layoutPattern,
          polygon: zone.polygon,
          tubeSpacingMm: zone.tubeSpacingMm,
          borderDistanceMm: zone.borderDistanceMm,
        );
    if (points.length < 2) return;

    final tubePaint = Paint()
      ..color = _identity(zone)?.withValues(alpha: 0.9) ??
          supplyPipe.withValues(alpha: 0.45)
      ..strokeWidth = 8.0 // ~8 mm tube diameter in world-space
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final tube = Path()..moveTo(points.first.x, points.first.y);
    for (var i = 1; i < points.length; i++) {
      tube.lineTo(points[i].x, points[i].y);
    }
    canvas.drawPath(tube, tubePaint);
  }

  /// Paint an unconnected wall heating zone (ADR-004 state 1).
  ///
  /// Renders the zone band with the same red hatched fill as floor
  /// zones, then draws tube-line preview lines that run across the
  /// short axis of the band (perpendicular to the wall direction)
  /// at [HeatingZone.tubeSpacingMm] intervals along the wall.
  ///
  /// The band polygon is a 4-vertex rectangle with vertices ordered
  /// [outer-start, outer-end, inner-end, inner-start] as produced by
  /// [WallZonePlaceTool._wallBandPolygon].
  void _paintWallZoneUnconnected(
    Canvas canvas,
    Path path,
    HeatingZone zone,
  ) {
    // Semi-transparent red fill.
    canvas.drawPath(
      path,
      Paint()
        ..color = (_identity(zone)?.withValues(alpha: 0.25) ??
            zoneRed.withValues(alpha: 0.15))
        ..style = PaintingStyle.fill,
    );

    // Red zone outline.
    canvas.drawPath(
      path,
      Paint()
        ..color = zoneRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // 45° hatch (clipped to polygon).
    canvas.save();
    canvas.clipPath(path);
    _drawHatch(canvas, path);
    canvas.restore();

    // Transverse tube-line preview (clipped to polygon).
    canvas.save();
    canvas.clipPath(path);
    _drawWallZoneTubePreview(canvas, zone);
    canvas.restore();
  }

  /// Draws tube-line preview for a wall heating zone.
  ///
  /// Lines run across the band's short axis (perpendicular to the
  /// wall direction) at [HeatingZone.tubeSpacingMm] intervals.
  /// Derived from the 4-vertex band polygon.
  ///
  /// The canvas must already be clipped to the zone polygon.
  void _drawWallZoneTubePreview(Canvas canvas, HeatingZone zone) {
    if (zone.polygon.length < 4) return;
    final spacing = zone.tubeSpacingMm.toDouble();
    if (spacing <= 0) return;

    // Polygon vertices: [outerStart, outerEnd, innerEnd, innerStart].
    final p0 = zone.polygon[0]; // outer-start
    final p1 = zone.polygon[1]; // outer-end
    final p3 = zone.polygon[3]; // inner-start

    // Wall direction vector and its length.
    final wallDx = p1.x - p0.x;
    final wallDy = p1.y - p0.y;
    final wallLen = sqrt(wallDx * wallDx + wallDy * wallDy);
    if (wallLen < 1) return;

    // Perpendicular vector (short-axis of the band).
    final perpDx = p3.x - p0.x;
    final perpDy = p3.y - p0.y;

    final tubePaint = Paint()
      ..color = _identity(zone)?.withValues(alpha: 0.9) ??
          supplyPipe.withValues(alpha: 0.45)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw lines across the band at [spacing] intervals.
    var offset = spacing / 2;
    while (offset < wallLen) {
      final t = offset / wallLen;
      // Interpolate start and end across the band width.
      final fromX = p0.x + wallDx * t;
      final fromY = p0.y + wallDy * t;
      final toX = fromX + perpDx;
      final toY = fromY + perpDy;
      canvas.drawLine(
        Offset(fromX, fromY),
        Offset(toX, toY),
        tubePaint,
      );
      offset += spacing;
    }
  }

  @override
  bool shouldRepaint(HeatingZonePainter oldDelegate) {
    return oldDelegate.zones != zones ||
        oldDelegate.zoneStates != zoneStates ||
        oldDelegate.layouts != layouts ||
        oldDelegate.palette != palette ||
        oldDelegate.colorIndices != colorIndices ||
        oldDelegate.zoneRed != zoneRed ||
        oldDelegate.zoneGreen != zoneGreen ||
        oldDelegate.zoneYellow != zoneYellow ||
        oldDelegate.zoneGrey != zoneGrey ||
        oldDelegate.supplyPipe != supplyPipe;
  }
}
