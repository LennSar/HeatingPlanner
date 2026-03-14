import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../data/models/distributor.dart';

/// Draws the distributor manifold symbol on the canvas.
///
/// The symbol is a filled rectangle (widthMm × 240 mm in world
/// space) representing the header/manifold body, with two
/// short pipe stubs extending upward (supply) and two
/// extending downward (return), and a centred label "D".
///
/// All dimensions are in world-space millimetres so they
/// scale correctly with the canvas transform.
class DistributorPainter extends CustomPainter {
  /// Creates a [DistributorPainter].
  const DistributorPainter({
    required this.distributor,
    required this.bodyColor,
    required this.strokeColor,
    required this.labelColor,
  });

  /// The distributor to draw.
  final Distributor distributor;

  /// Fill colour for the manifold body.
  final Color bodyColor;

  /// Stroke / outline colour.
  final Color strokeColor;

  /// Colour for the "D" label text.
  final Color labelColor;

  // ── Fixed geometry constants (world mm) ──────────────────
  static const double _bodyH = 240.0;
  static const double _stubLen = 120.0;
  static const double _stubW = 20.0;
  static const double _strokeW = 10.0;
  static const double _labelSize = 120.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = distributor.position.x;
    final cy = distributor.position.y;
    final bodyW = distributor.widthMm.toDouble();
    // Stub offset scales with body width (20% from centre).
    final stubOffset = bodyW * 0.2;

    // Apply rotation around the distributor centre.
    final angleRad = distributor.rotationDeg * math.pi / 180.0;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angleRad);
    canvas.translate(-cx, -cy);

    final body = Rect.fromCenter(
      center: Offset(cx, cy),
      width: bodyW,
      height: _bodyH,
    );

    // Body fill.
    canvas.drawRect(
      body,
      Paint()
        ..color = bodyColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );

    // Body outline.
    canvas.drawRect(
      body,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeW,
    );

    // Supply stubs (upward from top edge).
    _drawStub(canvas, cx - stubOffset, cy - _bodyH / 2, up: true);
    _drawStub(canvas, cx + stubOffset, cy - _bodyH / 2, up: true);

    // Return stubs (downward from bottom edge).
    _drawStub(canvas, cx - stubOffset, cy + _bodyH / 2, up: false);
    _drawStub(canvas, cx + stubOffset, cy + _bodyH / 2, up: false);

    // "D" label in the centre.
    _drawLabel(canvas, cx, cy, bodyW);

    canvas.restore();
  }

  void _drawStub(
    Canvas canvas,
    double x,
    double y, {
    required bool up,
  }) {
    final yEnd = up ? y - _stubLen : y + _stubLen;
    canvas.drawRect(
      Rect.fromLTRB(
        x - _stubW / 2,
        up ? yEnd : y,
        x + _stubW / 2,
        up ? y : yEnd,
      ),
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.fill,
    );
  }

  void _drawLabel(Canvas canvas, double cx, double cy, double bodyW) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: _labelSize,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: labelColor,
          fontSize: _labelSize,
          fontWeight: ui.FontWeight.bold,
        ),
      )
      ..addText('D');

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: bodyW));

    canvas.drawParagraph(
      paragraph,
      Offset(
        cx - bodyW / 2,
        cy - paragraph.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(DistributorPainter oldDelegate) {
    return oldDelegate.distributor != distributor ||
        oldDelegate.bodyColor != bodyColor ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.labelColor != labelColor;
  }
}
