import 'dart:math' show sqrt;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'interaction_data.dart';

/// Draws transient interaction overlays: ghost lines,
/// snap indicators, hover crosshairs, and selection
/// highlights.
///
/// This painter is **not** wrapped in [RepaintBoundary]
/// because it updates every frame during active interaction.
class InteractionPainter extends CustomPainter {
  /// Creates an [InteractionPainter].
  const InteractionPainter({
    this.hoverPoint,
    this.selectionHighlightColor,
    this.interactionData,
  });

  /// Current hover position in world coordinates, if any.
  final Offset? hoverPoint;

  /// Colour for selection/hover highlights.
  final Color? selectionHighlightColor;

  /// Tool-produced interaction data (ghost line or
  /// selection highlight).
  final InteractionData? interactionData;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw crosshair at hover point.
    _drawCrosshair(canvas);

    // Draw tool-specific interaction data.
    if (interactionData != null) {
      switch (interactionData!) {
        case GhostLineData(:final startPoint, :final currentPoint,
              :final snapIndicator, :final snapType):
          _drawGhostLine(
            canvas,
            Offset(startPoint.x, startPoint.y),
            Offset(currentPoint.x, currentPoint.y),
            snapIndicator != null
                ? Offset(snapIndicator.x, snapIndicator.y)
                : null,
            snapType,
          );
        case SelectionHighlightData(:final selectedWalls,
              :final selectedRoom, :final handles,
              :final activeHandleIndex):
          _drawSelectionHighlight(
            canvas,
            selectedWalls,
            selectedRoom,
          );
          _drawWallHandles(canvas, handles, activeHandleIndex);
        case WallHighlightData(
              :final wallStart,
              :final wallEnd,
              :final previewPositionMm,
              :final previewWidthMm,
              :final isWindow,
            ):
          _drawWallHighlight(
            canvas,
            Offset(wallStart.x, wallStart.y),
            Offset(wallEnd.x, wallEnd.y),
            previewPositionMm,
            previewWidthMm,
            isWindow,
          );
        case OpeningSelectionData(
              :final wallStart,
              :final wallEnd,
              :final positionOnWallMm,
              :final widthMm,
              :final isWindow,
              :final handles,
              :final activeHandleIndex,
            ):
          _drawOpeningSelection(
            canvas,
            Offset(wallStart.x, wallStart.y),
            Offset(wallEnd.x, wallEnd.y),
            positionOnWallMm,
            widthMm,
            isWindow,
          );
          _drawWallHandles(canvas, handles, activeHandleIndex);
      }
    }
  }

  void _drawCrosshair(Canvas canvas) {
    if (hoverPoint == null || selectionHighlightColor == null) {
      return;
    }

    final paint = Paint()
      ..color = selectionHighlightColor!.withValues(alpha: 0.3)
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

  void _drawGhostLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Offset? snapIndicator,
    String? snapType,
  ) {
    // Dashed ghost line.
    final ghostPaint = Paint()
      ..color = selectionHighlightColor ?? Colors.blue
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, start, end, ghostPaint, 30.0);

    // Length text at midpoint.
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final lengthMm = sqrt(dx * dx + dy * dy).round();
    final text = '$lengthMm mm';

    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 70,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: selectionHighlightColor ?? Colors.blue,
        fontSize: 70,
      ))
      ..addText(text);

    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 500));

    final mid = Offset(
      (start.dx + end.dx) / 2 - paragraph.width / 2,
      (start.dy + end.dy) / 2 - paragraph.height - 20,
    );
    canvas.drawParagraph(paragraph, mid);

    // Snap indicator circle.
    if (snapIndicator != null) {
      final snapPaint = Paint()
        ..color = snapType == 'endpoint'
            ? Colors.orange
            : (selectionHighlightColor ?? Colors.blue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(
        snapIndicator,
        snapType == 'endpoint' ? 30.0 : 15.0,
        snapPaint,
      );
    }

    // Start point indicator.
    final startPaint = Paint()
      ..color = selectionHighlightColor ?? Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(start, 8.0, startPaint);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashLength,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = sqrt(dx * dx + dy * dy);
    if (distance < 1) return;

    final unitDx = dx / distance;
    final unitDy = dy / distance;
    var drawn = 0.0;
    var drawing = true;

    while (drawn < distance) {
      final segLen =
          (drawn + dashLength > distance)
              ? distance - drawn
              : dashLength;
      if (drawing) {
        canvas.drawLine(
          Offset(
            start.dx + unitDx * drawn,
            start.dy + unitDy * drawn,
          ),
          Offset(
            start.dx + unitDx * (drawn + segLen),
            start.dy + unitDy * (drawn + segLen),
          ),
          paint,
        );
      }
      drawn += segLen;
      drawing = !drawing;
    }
  }

  void _drawSelectionHighlight(
    Canvas canvas,
    List<dynamic> selectedWalls,
    dynamic selectedRoom,
  ) {
    final highlightPaint = Paint()
      ..color = selectionHighlightColor ?? Colors.blue
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;

    // Highlight selected walls.
    for (final wall in selectedWalls) {
      canvas.drawLine(
        Offset(wall.startPoint.x as double,
            wall.startPoint.y as double),
        Offset(wall.endPoint.x as double,
            wall.endPoint.y as double),
        highlightPaint,
      );
    }

    // Highlight selected room polygon.
    if (selectedRoom != null &&
        (selectedRoom.polygon as List).length >= 3) {
      final polygon = selectedRoom.polygon as List;
      final fillPaint = Paint()
        ..color = (selectionHighlightColor ?? Colors.blue)
            .withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(
        polygon[0].x as double,
        polygon[0].y as double,
      );
      for (var i = 1; i < polygon.length; i++) {
        path.lineTo(
          polygon[i].x as double,
          polygon[i].y as double,
        );
      }
      path.close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, highlightPaint);
    }
  }

  void _drawWallHandles(
    Canvas canvas,
    List<dynamic> handles,
    int? activeHandleIndex,
  ) {
    if (handles.isEmpty) return;

    final color = selectionHighlightColor ?? Colors.blue;
    const handleRadius = 30.0; // world-space radius (~8px at default zoom)

    for (var i = 0; i < handles.length; i++) {
      final h = handles[i];
      final center = Offset(h.x as double, h.y as double);
      final isActive = i == activeHandleIndex;

      final fillPaint = Paint()
        ..color = isActive
            ? color
            : color.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 4.0 : 2.0;

      canvas.drawCircle(center, handleRadius, fillPaint);
      canvas.drawCircle(center, handleRadius, strokePaint);
    }
  }

  void _drawWallHighlight(
    Canvas canvas,
    Offset wallStart,
    Offset wallEnd,
    double? previewPositionMm,
    double previewWidthMm,
    bool isWindow,
  ) {
    // Highlight the wall.
    final highlightPaint = Paint()
      ..color = (selectionHighlightColor ?? Colors.blue)
          .withValues(alpha: 0.4)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(wallStart, wallEnd, highlightPaint);

    if (previewPositionMm == null) return;

    final dx = wallEnd.dx - wallStart.dx;
    final dy = wallEnd.dy - wallStart.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return;

    final ux = dx / len;
    final uy = dy / len;
    const halfThick = 100.0; // half of 200 mm wall thickness
    final px = -uy * halfThick;
    final py = ux * halfThick;

    final x0 = wallStart.dx + ux * previewPositionMm;
    final y0 = wallStart.dy + uy * previewPositionMm;
    final x1 = x0 + ux * previewWidthMm;
    final y1 = y0 + uy * previewWidthMm;

    final previewColor = isWindow
        ? const Color(0xFF93C5FD)
        : const Color(0xFFFCD34D);

    final fillPaint = Paint()
      ..color = previewColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final strokePaint2 = Paint()
      ..color = previewColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path()
      ..moveTo(x0 + px, y0 + py)
      ..lineTo(x1 + px, y1 + py)
      ..lineTo(x1 - px, y1 - py)
      ..lineTo(x0 - px, y0 - py)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint2);
  }

  void _drawOpeningSelection(
    Canvas canvas,
    Offset wallStart,
    Offset wallEnd,
    double positionOnWallMm,
    double widthMm,
    bool isWindow,
  ) {
    final dx = wallEnd.dx - wallStart.dx;
    final dy = wallEnd.dy - wallStart.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return;

    final ux = dx / len;
    final uy = dy / len;
    const halfThick = 100.0; // half of 200 mm wall thickness

    final px = -uy * halfThick;
    final py = ux * halfThick;

    final x0 = wallStart.dx + ux * positionOnWallMm;
    final y0 = wallStart.dy + uy * positionOnWallMm;
    final x1 = wallStart.dx + ux * (positionOnWallMm + widthMm);
    final y1 = wallStart.dy + uy * (positionOnWallMm + widthMm);

    final path = Path()
      ..moveTo(x0 + px, y0 + py)
      ..lineTo(x1 + px, y1 + py)
      ..lineTo(x1 - px, y1 - py)
      ..lineTo(x0 - px, y0 - py)
      ..close();

    final fillPaint = Paint()
      ..color = (selectionHighlightColor ?? Colors.blue)
          .withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = selectionHighlightColor ?? Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(InteractionPainter oldDelegate) {
    return oldDelegate.hoverPoint != hoverPoint ||
        oldDelegate.interactionData != interactionData;
  }
}
