import 'package:flutter/material.dart';

/// Draws transient interaction overlays: snap indicators,
/// hover highlights, and in-progress drawing previews.
///
/// This painter is **not** wrapped in [RepaintBoundary]
/// because it updates every frame during active interaction.
class InteractionPainter extends CustomPainter {
  /// Creates an [InteractionPainter].
  const InteractionPainter({
    this.hoverPoint,
    this.selectionHighlightColor,
  });

  /// Current hover position in world coordinates, if any.
  final Offset? hoverPoint;

  /// Colour for selection/hover highlights.
  final Color? selectionHighlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (hoverPoint == null || selectionHighlightColor == null) {
      return;
    }

    final paint = Paint()
      ..color = selectionHighlightColor!.withValues(
        alpha: 0.3,
      )
      ..strokeWidth = 1.0;

    const len = 20.0;
    canvas.drawLine(
      hoverPoint! + const Offset(-len, 0),
      hoverPoint! + const Offset(len, 0),
      paint,
    );
    canvas.drawLine(
      hoverPoint! + const Offset(0, -len),
      hoverPoint! + const Offset(0, len),
      paint,
    );
  }

  @override
  bool shouldRepaint(InteractionPainter oldDelegate) {
    return oldDelegate.hoverPoint != hoverPoint;
  }
}
