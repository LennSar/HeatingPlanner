import 'package:flutter/material.dart';

/// Draws heating zone polygons with semi-transparent fill.
class HeatingZonePainter extends CustomPainter {
  /// Creates a [HeatingZonePainter].
  const HeatingZonePainter({
    required this.zoneGreen,
    required this.zoneYellow,
    required this.zoneRed,
  });

  /// Sufficient output zone colour.
  final Color zoneGreen;

  /// Marginal output zone colour.
  final Color zoneYellow;

  /// Insufficient output zone colour.
  final Color zoneRed;

  @override
  void paint(Canvas canvas, Size size) {
    // No-op until zone data is wired through providers.
  }

  @override
  bool shouldRepaint(HeatingZonePainter oldDelegate) {
    return oldDelegate.zoneGreen != zoneGreen ||
        oldDelegate.zoneYellow != zoneYellow ||
        oldDelegate.zoneRed != zoneRed;
  }
}
