import 'package:flutter/material.dart';

/// Draws supply and return pipe routing lines.
class PipeRoutePainter extends CustomPainter {
  /// Creates a [PipeRoutePainter].
  const PipeRoutePainter({
    required this.supplyPipe,
    required this.returnPipe,
  });

  /// Supply pipe line colour.
  final Color supplyPipe;

  /// Return pipe line colour.
  final Color returnPipe;

  @override
  void paint(Canvas canvas, Size size) {
    // No-op until circuit data is wired through providers.
  }

  @override
  bool shouldRepaint(PipeRoutePainter oldDelegate) {
    return oldDelegate.supplyPipe != supplyPipe ||
        oldDelegate.returnPipe != returnPipe;
  }
}
