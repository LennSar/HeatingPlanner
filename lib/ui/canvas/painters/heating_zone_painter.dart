import 'dart:math' show sqrt;

import 'package:flutter/material.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/heating_zone.dart';

/// Draws committed heating zone polygons on the canvas.
///
/// Each zone is coloured according to ADR-004's priority-ordered
/// state machine. For now every zone is in state 1 (unconnected —
/// no distributor/circuit assigned) and is painted with the
/// **red hatched** style: a semi-transparent red fill overlaid
/// with 45° diagonal hatch lines.
///
/// Inside every unconnected zone a simplified tube-routing
/// preview is drawn for the [LayoutPattern.meander] pattern,
/// based on [HeatingZone.tubeSpacingMm] and
/// [HeatingZone.borderDistanceMm].
class HeatingZonePainter extends CustomPainter {
  /// Creates a [HeatingZonePainter].
  const HeatingZonePainter({
    required this.zoneGreen,
    required this.zoneYellow,
    required this.zoneRed,
    required this.supplyPipe,
    this.zones = const [],
  });

  /// Sufficient-output zone colour.
  final Color zoneGreen;

  /// Marginal-output zone colour.
  final Color zoneYellow;

  /// Insufficient-output / unconnected zone colour.
  final Color zoneRed;

  /// Supply-pipe colour used for the meander routing preview.
  final Color supplyPipe;

  /// All heating zones to render on this floor.
  final List<HeatingZone> zones;

  @override
  void paint(Canvas canvas, Size size) {
    for (final zone in zones) {
      if (zone.polygon.length < 3) continue;

      final path = Path()
        ..moveTo(zone.polygon.first.x, zone.polygon.first.y);
      for (var i = 1; i < zone.polygon.length; i++) {
        path.lineTo(zone.polygon[i].x, zone.polygon[i].y);
      }
      path.close();

      // ADR-004 priority chain:
      // State 1 — unconnected (circuitId == null) → red hatched.
      // States 2-5 not yet reachable (no distributor wiring).
      if (zone.zoneType == ZoneType.wallHeating) {
        _paintWallZoneUnconnected(canvas, path, zone);
      } else {
        _paintUnconnected(canvas, path, zone);
      }
    }
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
        ..color = zoneRed.withValues(alpha: 0.15)
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
    if (zone.layoutPattern == LayoutPattern.meander) {
      _drawMeanderPreview(canvas, path, zone);
    }
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

  /// Draws a simplified meander tube-routing preview inside [path].
  ///
  /// Generates horizontal parallel lines spaced
  /// [HeatingZone.tubeSpacingMm] apart, starting
  /// [HeatingZone.borderDistanceMm] inset from the bounding-box
  /// edges, connected by vertical segments on alternating sides to
  /// form a snake/meander pattern.
  ///
  /// The canvas must already be clipped to [path].
  void _drawMeanderPreview(
    Canvas canvas,
    Path path,
    HeatingZone zone,
  ) {
    final bounds = path.getBounds();
    final border = zone.borderDistanceMm.toDouble();
    final spacing = zone.tubeSpacingMm.toDouble();

    final left = bounds.left + border;
    final right = bounds.right - border;
    final top = bounds.top + border;
    final bottom = bounds.bottom - border;

    if (right <= left || bottom <= top || spacing <= 0) return;

    final tubePaint = Paint()
      ..color = supplyPipe.withValues(alpha: 0.45)
      ..strokeWidth = 8.0 // ~8 mm tube diameter in world-space
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final meander = Path();
    var y = top;
    var lineIndex = 0;
    var started = false;

    while (y <= bottom + 0.5) {
      final isEven = lineIndex.isEven;
      final xStart = isEven ? left : right;
      final xEnd = isEven ? right : left;

      if (!started) {
        meander.moveTo(xStart, y);
        started = true;
      } else {
        // Vertical connector from previous line-end to this
        // line-start (same x side, next y level).
        meander.lineTo(xStart, y);
      }
      meander.lineTo(xEnd, y);

      y += spacing;
      lineIndex++;
    }

    canvas.drawPath(meander, tubePaint);
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
        ..color = zoneRed.withValues(alpha: 0.15)
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
      ..color = supplyPipe.withValues(alpha: 0.45)
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
        oldDelegate.zoneRed != zoneRed ||
        oldDelegate.zoneGreen != zoneGreen ||
        oldDelegate.zoneYellow != zoneYellow ||
        oldDelegate.supplyPipe != supplyPipe;
  }
}
