import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../../calculation/engines/pipe_layout_engine.dart';
import '../../../data/models/distributor.dart';

/// Draws the distributor manifold symbol on the canvas.
///
/// The symbol is a filled rectangle (widthMm × 240 mm in world
/// space) representing the header/manifold body, one outlet stub per
/// circuit ([Distributor.outletCount]) on its front side, equally spaced
/// across the width, and a centred label "D" (ADR-044). Supply and return
/// of a circuit share a stub — on site they sit one above the other.
/// Stubs in [occupiedOutlets] are drawn filled, free ones as an outline.
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
    this.occupiedOutlets = const {},
  });

  /// The distributor to draw.
  final Distributor distributor;

  /// Fill colour for the manifold body.
  final Color bodyColor;

  /// Stroke / outline colour.
  final Color strokeColor;

  /// Colour for the "D" label text.
  final Color labelColor;

  /// Outlet indices a circuit is connected to.
  final Set<int> occupiedOutlets;

  // ── Fixed geometry constants (world mm) ──────────────────
  static const double _bodyH = PipeLayoutEngine.distributorBodyDepthMm;
  static const double _stubLen = PipeLayoutEngine.distributorStubLengthMm;
  static const double _stubW = 30.0;
  static const double _strokeW = 10.0;
  static const double _labelSize = 120.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = distributor.position.x;
    final cy = distributor.position.y;
    final bodyW = distributor.widthMm.toDouble();

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

    // Outlet stubs on the front face, one per circuit (ADR-044). Same
    // spacing as PipeLayoutEngine.distributorOutletPoints.
    final count = distributor.outletCount;
    if (count > 0) {
      final pitch = bodyW / count;
      final stubW = math.min(_stubW, pitch * 0.6);
      for (var i = 0; i < count; i++) {
        _drawStub(
          canvas,
          cx - bodyW / 2 + (i + 0.5) * pitch,
          cy - _bodyH / 2,
          stubW,
          occupied: occupiedOutlets.contains(i),
        );
      }
    }

    // "D" label in the centre.
    _drawLabel(canvas, cx, cy, bodyW);

    canvas.restore();
  }

  /// One outlet stub at [x], from the body face [y] outwards (local −y).
  void _drawStub(
    Canvas canvas,
    double x,
    double y,
    double width, {
    required bool occupied,
  }) {
    final rect = Rect.fromLTRB(
      x - width / 2,
      y - _stubLen,
      x + width / 2,
      y,
    );
    if (occupied) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawRect(
        rect.deflate(math.min(_strokeW, width) / 4),
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.min(_strokeW, width) / 2,
      );
    }
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
        oldDelegate.labelColor != labelColor ||
        !setEquals(oldDelegate.occupiedOutlets, occupiedOutlets);
  }
}
