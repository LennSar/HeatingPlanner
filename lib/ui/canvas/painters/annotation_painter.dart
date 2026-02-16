import 'package:flutter/material.dart';

/// Draws dimension labels and annotation text on the canvas.
class AnnotationPainter extends CustomPainter {
  /// Creates an [AnnotationPainter].
  const AnnotationPainter({required this.textColor});

  /// Colour for annotation text.
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    // No-op until annotation data is available.
  }

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) {
    return oldDelegate.textColor != textColor;
  }
}
