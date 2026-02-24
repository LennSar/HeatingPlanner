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

    // Compute integer grid indices that cover the visible rect.
    // Each dot position is n * gridSpacingMm (exact integer multiple),
    // anchored to world origin (0, 0) — identical to SnapService.snapToGrid.
    // Using index-based multiplication avoids floating-point drift that
    // can occur with repeated += addition.
    final nStart =
        (visibleRect.left / gridSpacingMm).floor().toInt();
    final nEnd =
        (visibleRect.right / gridSpacingMm).ceil().toInt();
    final mStart =
        (visibleRect.top / gridSpacingMm).floor().toInt();
    final mEnd =
        (visibleRect.bottom / gridSpacingMm).ceil().toInt();

    // Collect dots for efficient rendering.
    final points = <ui.Offset>[];
    for (var n = nStart; n <= nEnd; n++) {
      for (var m = mStart; m <= mEnd; m++) {
        points.add(Offset(n * gridSpacingMm, m * gridSpacingMm));
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
