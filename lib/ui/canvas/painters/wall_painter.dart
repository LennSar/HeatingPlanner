import 'package:flutter/material.dart';

/// Draws wall segments on the canvas in world coordinates.
///
/// Each wall is rendered as a filled rectangle with
/// [wallFill] colour and [wallStroke] outline.
class WallPainter extends CustomPainter {
  /// Creates a [WallPainter].
  const WallPainter({
    required this.wallFill,
    required this.wallStroke,
  });

  /// Fill colour for wall rectangles.
  final Color wallFill;

  /// Stroke colour for wall outlines.
  final Color wallStroke;

  @override
  void paint(Canvas canvas, Size size) {
    // No-op until wall data is wired through providers.
  }

  @override
  bool shouldRepaint(WallPainter oldDelegate) {
    return oldDelegate.wallFill != wallFill ||
        oldDelegate.wallStroke != wallStroke;
  }
}
