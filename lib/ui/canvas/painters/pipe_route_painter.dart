import 'dart:math' show sqrt;

import 'package:flutter/material.dart';

import '../../../calculation/engines/pipe_layout_engine.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/heating_circuit.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';

/// Draws committed supply and return pipe routing lines.
///
/// Renders each [HeatingCircuit] as two polylines:
///  - [supplyPipe] colour for the supply path
///  - [returnPipe] colour for the return path
///
/// Small directional arrows are drawn every 500 mm along
/// each path to indicate flow direction.
///
/// A route is drawn only up to the boundary of the floor zone it
/// serves; inside the zone the zone's own tube layout continues from
/// that entry point (ADR-038 Rule 1).
class PipeRoutePainter extends CustomPainter {
  /// Creates a [PipeRoutePainter].
  const PipeRoutePainter({
    required this.supplyPipe,
    required this.returnPipe,
    this.circuits = const [],
    this.zones = const [],
    this.bendRadiiMm = const {},
    this.defaultBendRadiusMm = 80.0,
  });

  /// Supply pipe line colour.
  final Color supplyPipe;

  /// Return pipe line colour.
  final Color returnPipe;

  /// Committed heating circuits to draw.
  final List<HeatingCircuit> circuits;

  /// Heating zones, used to stop each route at its own zone's boundary.
  final List<HeatingZone> zones;

  /// Tube bend radius in mm keyed by zone id (ADR-039 Rule 3). A
  /// circuit's corners are rounded with the radius of the zone it serves.
  final Map<String, double> bendRadiiMm;

  /// Bend radius in mm for a circuit whose zone has no entry in
  /// [bendRadiiMm].
  final double defaultBendRadiusMm;

  /// Stroke width of pipe lines in world-space mm.
  static const double _strokeMm = 3.0;

  /// Spacing between directional arrows in mm.
  static const double _arrowSpacingMm = 500.0;

  /// Half-length of each arrowhead in mm.
  static const double _arrowHalfLenMm = 50.0;

  /// Half-width of each arrowhead in mm.
  static const double _arrowHalfWidthMm = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final zoneById = {for (final z in zones) z.id: z};
    for (final circuit in circuits) {
      final zone = zoneById[circuit.heatingZoneId];
      final trim = zone != null &&
          zone.zoneType == ZoneType.floorHeating &&
          zone.polygon.length >= 3;
      // ADR-039 Rule 3: round the corners first, then cut at the zone
      // boundary so the bend next to the zone keeps its full radius.
      final radius =
          bendRadiiMm[circuit.heatingZoneId] ?? defaultBendRadiusMm;
      final supply =
          PipeLayoutEngine.filletPolyline(circuit.supplyRoutePath, radius);
      final back =
          PipeLayoutEngine.filletPolyline(circuit.returnRoutePath, radius);
      _drawPath(
        canvas,
        trim
            ? PipeLayoutEngine.supplyRouteOutsideZone(supply, zone.polygon)
            : supply,
        supplyPipe,
      );
      _drawPath(
        canvas,
        trim
            ? PipeLayoutEngine.returnRouteOutsideZone(back, zone.polygon)
            : back,
        returnPipe,
      );
    }
  }

  /// Draws [path] as a solid polyline in [color] with
  /// directional arrows every [_arrowSpacingMm].
  void _drawPath(
    Canvas canvas,
    List<Point2D> path,
    Color color,
  ) {
    if (path.length < 2) return;

    // Draw polyline.
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = _strokeMm
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()
      ..moveTo(path.first.x, path.first.y);
    for (var i = 1; i < path.length; i++) {
      linePath.lineTo(path[i].x, path[i].y);
    }
    canvas.drawPath(linePath, linePaint);

    // Draw directional arrows.
    _drawArrows(canvas, path, color);
  }

  /// Places a filled arrowhead triangle every [_arrowSpacingMm]
  /// along [path], oriented in the direction of travel.
  void _drawArrows(
    Canvas canvas,
    List<Point2D> path,
    Color color,
  ) {
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // First arrow starts at half the spacing so it appears
    // near the beginning of longer segments.
    var distToNextArrow = _arrowSpacingMm * 0.5;

    for (var i = 0; i < path.length - 1; i++) {
      final ax = path[i].x;
      final ay = path[i].y;
      final bx = path[i + 1].x;
      final by = path[i + 1].y;

      final dx = bx - ax;
      final dy = by - ay;
      final segLen = sqrt(dx * dx + dy * dy);
      if (segLen < 1) continue;

      final ux = dx / segLen; // unit vector along segment
      final uy = dy / segLen;

      var walked = 0.0;
      while (walked + distToNextArrow <= segLen) {
        walked += distToNextArrow;
        distToNextArrow = _arrowSpacingMm;

        final cx = ax + ux * walked;
        final cy = ay + uy * walked;

        // Arrowhead: triangle pointing in flow direction.
        final tipX = cx + ux * _arrowHalfLenMm;
        final tipY = cy + uy * _arrowHalfLenMm;
        final baseX = cx - ux * _arrowHalfLenMm;
        final baseY = cy - uy * _arrowHalfLenMm;
        // Perpendicular offset for the two base corners.
        final px = -uy * _arrowHalfWidthMm;
        final py = ux * _arrowHalfWidthMm;

        final arrowPath = Path()
          ..moveTo(tipX, tipY)
          ..lineTo(baseX + px, baseY + py)
          ..lineTo(baseX - px, baseY - py)
          ..close();

        canvas.drawPath(arrowPath, arrowPaint);
      }

      distToNextArrow -= segLen - walked;
    }
  }

  @override
  bool shouldRepaint(PipeRoutePainter oldDelegate) {
    return oldDelegate.supplyPipe != supplyPipe ||
        oldDelegate.returnPipe != returnPipe ||
        oldDelegate.circuits != circuits ||
        oldDelegate.zones != zones ||
        oldDelegate.bendRadiiMm != bendRadiiMm ||
        oldDelegate.defaultBendRadiusMm != defaultBendRadiusMm;
  }
}

