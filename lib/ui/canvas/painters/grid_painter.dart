import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Draws a dot grid on the canvas in world coordinates.
///
/// Dots are placed at regular intervals defined by
/// [gridSpacingMm]. Only the visible portion of the grid
/// is drawn, based on [visibleRect] in world coordinates.
class GridPainter extends CustomPainter {
  /// Creates a [GridPainter].
  const GridPainter({
    required this.gridSpacingMm,
    required this.visibleRect,
    required this.dotColor,
  });

  /// Grid spacing in mm (world units).
  final double gridSpacingMm;

  /// Visible area in world coordinates.
  final Rect visibleRect;

  /// Colour for grid dots.
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (gridSpacingMm <= 0) return;

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Snap the visible rect to grid boundaries.
    final startX =
        (visibleRect.left / gridSpacingMm).floor() *
            gridSpacingMm;
    final startY =
        (visibleRect.top / gridSpacingMm).floor() *
            gridSpacingMm;
    final endX = visibleRect.right;
    final endY = visibleRect.bottom;

    // Collect dots for efficient rendering.
    final points = <ui.Offset>[];
    for (var x = startX; x <= endX; x += gridSpacingMm) {
      for (var y = startY; y <= endY; y += gridSpacingMm) {
        points.add(Offset(x, y));
      }
    }

    canvas.drawPoints(ui.PointMode.points, points, dotPaint);
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.gridSpacingMm != gridSpacingMm ||
        oldDelegate.visibleRect != visibleRect ||
        oldDelegate.dotColor != dotColor;
  }
}
