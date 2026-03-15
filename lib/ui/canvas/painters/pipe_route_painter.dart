import 'dart:math' show sqrt;

import 'package:flutter/material.dart';

import '../../../data/models/heating_circuit.dart';
import '../../../data/models/point2d.dart';

/// Draws committed supply and return pipe routing lines.
///
/// Renders each [HeatingCircuit] as two polylines:
///  - [supplyPipe] colour for the supply path
///  - [returnPipe] colour for the return path
///
/// Small directional arrows are drawn every 500 mm along
/// each path to indicate flow direction.
class PipeRoutePainter extends CustomPainter {
  /// Creates a [PipeRoutePainter].
  const PipeRoutePainter({
    required this.supplyPipe,
    required this.returnPipe,
    this.circuits = const [],
  });

  /// Supply pipe line colour.
  final Color supplyPipe;

  /// Return pipe line colour.
  final Color returnPipe;

  /// Committed heating circuits to draw.
  final List<HeatingCircuit> circuits;

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
    for (final circuit in circuits) {
      _drawPath(canvas, circuit.supplyRoutePath, supplyPipe);
      _drawPath(canvas, circuit.returnRoutePath, returnPipe);
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
        oldDelegate.circuits != circuits;
  }
}

