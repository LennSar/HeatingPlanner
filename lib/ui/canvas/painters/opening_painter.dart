import 'package:flutter/material.dart';

/// Draws window and door elements on the canvas.
class OpeningPainter extends CustomPainter {
  /// Creates an [OpeningPainter].
  const OpeningPainter({
    required this.windowFill,
    required this.doorFill,
  });

  /// Fill colour for window elements.
  final Color windowFill;

  /// Fill colour for door elements.
  final Color doorFill;

  @override
  void paint(Canvas canvas, Size size) {
    // No-op until opening data is wired through providers.
  }

  @override
  bool shouldRepaint(OpeningPainter oldDelegate) {
    return oldDelegate.windowFill != windowFill ||
        oldDelegate.doorFill != doorFill;
  }
}
