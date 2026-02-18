import 'dart:math' show atan2, sqrt;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../data/models/wall_segment.dart';

/// Draws wall segments on the canvas in world coordinates.
///
/// Each wall is rendered as a filled rectangle (offset from
/// the centreline by half thickness) with dimension text.
class WallPainter extends CustomPainter {
  /// Creates a [WallPainter].
  const WallPainter({
    required this.wallFill,
    required this.wallStroke,
    required this.walls,
    this.wallThicknessMm = 200.0,
  });

  /// Fill colour for wall rectangles.
  final Color wallFill;

  /// Stroke colour for wall outlines.
  final Color wallStroke;

  /// All wall segments to draw.
  final List<WallSegment> walls;

  /// Wall thickness in mm (perpendicular to centreline).
  final double wallThicknessMm;

  @override
  void paint(Canvas canvas, Size size) {
    if (walls.isEmpty) return;

    final fillPaint = Paint()
      ..color = wallFill
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = wallStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final halfThick = wallThicknessMm / 2;

    for (final wall in walls) {
      final sx = wall.startPoint.x;
      final sy = wall.startPoint.y;
      final ex = wall.endPoint.x;
      final ey = wall.endPoint.y;

      // Direction along the wall.
      final dx = ex - sx;
      final dy = ey - sy;
      final length = sqrt(dx * dx + dy * dy);
      if (length < 1) continue;

      // Perpendicular unit vector.
      final px = -dy / length * halfThick;
      final py = dx / length * halfThick;

      // Four corners of the wall rectangle.
      final path = Path()
        ..moveTo(sx + px, sy + py)
        ..lineTo(ex + px, ey + py)
        ..lineTo(ex - px, ey - py)
        ..lineTo(sx - px, sy - py)
        ..close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);

      // Dimension text along the wall.
      _drawDimensionText(
        canvas,
        length,
        sx,
        sy,
        dx,
        dy,
        px,
        py,
      );
    }
  }

  void _drawDimensionText(
    Canvas canvas,
    double length,
    double sx,
    double sy,
    double dx,
    double dy,
    double px,
    double py,
  ) {
    final lengthMm = length.round();
    final text = '$lengthMm';

    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 80,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: wallStroke,
        fontSize: 80,
      ))
      ..addText(text);

    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 600));

    // Position text at the midpoint, offset perpendicular.
    final midX = sx + dx / 2;
    final midY = sy + dy / 2;
    final angle = atan2(dy, dx);

    canvas.save();
    canvas.translate(midX + px * 1.5, midY + py * 1.5);
    canvas.rotate(angle);
    canvas.translate(-paragraph.width / 2, -paragraph.height);
    canvas.drawParagraph(paragraph, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(WallPainter oldDelegate) {
    return oldDelegate.walls != walls ||
        oldDelegate.wallFill != wallFill ||
        oldDelegate.wallStroke != wallStroke;
  }
}
