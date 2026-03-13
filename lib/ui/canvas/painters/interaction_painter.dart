import 'dart:math' show sqrt;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../data/models/point2d.dart';
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
        case ZoneDrawData(
              :final vertices,
              :final currentPoint,
              :final hasValidationError,
              :final cursorOutsideValidArea,
            ):
          _drawZoneGhost(
            canvas,
            vertices,
            currentPoint,
            hasValidationError,
            cursorOutsideValidArea,
          );
        case ZoneSelectionData(
              :final polygon,
              :final handles,
              :final activeHandleIndex,
            ):
          _drawZoneSelectionHighlight(canvas, polygon);
          if (handles.isNotEmpty) {
            _drawWallHandles(canvas, handles, activeHandleIndex);
          }
        case WallZoneSelectionData(
              :final wallStart,
              :final wallEnd,
              :final positionOnWallMm,
              :final widthMm,
              :final handles,
              :final activeHandleIndex,
            ):
          _drawWallZoneSelection(
            canvas,
            Offset(wallStart.x, wallStart.y),
            Offset(wallEnd.x, wallEnd.y),
            positionOnWallMm,
            widthMm,
          );
          _drawWallHandles(canvas, handles, activeHandleIndex);
        case WallZoneNoHoverData(:final cursorPosition):
          _drawProhibitionIndicator(canvas, cursorPosition);
        case WallZoneHoverData(:final wallStart, :final wallEnd):
          _drawWallZoneHover(
            canvas,
            Offset(wallStart.x, wallStart.y),
            Offset(wallEnd.x, wallEnd.y),
          );
      }
    }
  }

  /// Draws the selection band and outline for a selected wall heating zone.
  ///
  /// Renders the zone as an amber rectangle of 200 mm thickness along
  /// the wall between [positionOnWallMm] and [positionOnWallMm] + [widthMm].
  void _drawWallZoneSelection(
    Canvas canvas,
    Offset wallStart,
    Offset wallEnd,
    double positionOnWallMm,
    double widthMm,
  ) {
    final dx = wallEnd.dx - wallStart.dx;
    final dy = wallEnd.dy - wallStart.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return;

    final ux = dx / len;
    final uy = dy / len;
    const halfThick = 100.0;
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

    const amber = Color(0xFFFFA726);
    canvas.drawPath(
      path,
      Paint()
        ..color = amber.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0,
    );
  }

  /// Highlights a wall segment in amber to indicate it can receive
  /// a wall heating zone on click.
  void _drawWallZoneHover(
    Canvas canvas,
    Offset wallStart,
    Offset wallEnd,
  ) {
    canvas.drawLine(
      wallStart,
      wallEnd,
      Paint()
        ..color = Colors.orange.withValues(alpha: 0.7)
        ..strokeWidth = 10.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Draws a selection highlight for a committed heating zone.
  void _drawZoneSelectionHighlight(
    Canvas canvas,
    List<Point2D> polygon,
  ) {
    if (polygon.length < 3) return;

    final path = Path()
      ..moveTo(polygon.first.x, polygon.first.y);
    for (var i = 1; i < polygon.length; i++) {
      path.lineTo(polygon[i].x, polygon[i].y);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = (selectionHighlightColor ?? Colors.blue)
            .withValues(alpha: 0.20)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = selectionHighlightColor ?? Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0,
    );
  }

  /// Draws a red prohibition circle (⊘) at [point] to signal that
  /// the cursor is outside all valid zone placement areas.
  void _drawProhibitionIndicator(Canvas canvas, Point2D point) {
    // Radius doubled to 80 mm; centre floated above the cursor
    // so the indicator is not obscured by the pointer glyph.
    const double radius = 80.0; // world-space mm
    const double gap = 20.0; // gap between cursor and circle bottom
    final cx = point.x;
    // Subtract so the bottom edge of the circle sits `gap` mm
    // above the cursor tip (y increases downward in canvas space).
    final cy = point.y - radius - gap;

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(cx, cy), radius, paint);

    // Diagonal bar at 45° (top-left → bottom-right).
    const double d = radius * 0.707; // radius / sqrt(2)
    canvas.drawLine(
      Offset(cx - d, cy - d),
      Offset(cx + d, cy + d),
      paint,
    );
  }

  /// Draws the in-progress zone polygon ghost.
  ///
  /// Renders:
  ///  - prohibition indicator when [cursorOutsideValidArea] is true
  ///  - semi-transparent filled polygon (committed vertices +
  ///    cursor position to preview the next edge)
  ///  - solid edges between committed vertices
  ///  - dashed ghost edge from the last vertex to the cursor
  ///  - vertex dots (world-space radius 12 mm)
  ///  - close-indicator ring around the first vertex when ≥3
  ///    vertices are committed (signals where to click to close)
  ///  - red error overlay when [hasValidationError] is true
  void _drawZoneGhost(
    Canvas canvas,
    List<Point2D> vertices,
    Point2D? currentPoint,
    bool hasValidationError,
    bool cursorOutsideValidArea,
  ) {
    // Prohibition indicator when cursor is outside valid area.
    if (cursorOutsideValidArea && currentPoint != null) {
      _drawProhibitionIndicator(canvas, currentPoint);
    }

    if (vertices.isEmpty) return;

    final pts =
        vertices.map((v) => Offset(v.x, v.y)).toList();
    final color = hasValidationError
        ? Colors.red
        : (selectionHighlightColor ?? Colors.blue);

    // ── Ghost polygon fill ──────────────────────────────────
    if (pts.length >= 2) {
      final ghostPath = Path()
        ..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        ghostPath.lineTo(pts[i].dx, pts[i].dy);
      }
      if (currentPoint != null) {
        ghostPath.lineTo(currentPoint.x, currentPoint.y);
      }
      ghostPath.close();

      canvas.drawPath(
        ghostPath,
        Paint()
          ..color = color.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        ghostPath,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Dashed ghost edge: last vertex → cursor ─────────────
    if (currentPoint != null) {
      _drawDashedLine(
        canvas,
        pts.last,
        Offset(currentPoint.x, currentPoint.y),
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke,
        30.0,
      );
    }

    // ── Vertex dots ─────────────────────────────────────────
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final pt in pts) {
      canvas.drawCircle(pt, 12.0, dotPaint);
    }

    // ── Close-indicator ring around the first vertex ─────────
    if (pts.length >= 3) {
      canvas.drawCircle(
        pts.first,
        40.0,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }

    // ── Red error overlay ────────────────────────────────────
    if (hasValidationError && pts.length >= 3) {
      final errPath = Path()
        ..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        errPath.lineTo(pts[i].dx, pts[i].dy);
      }
      errPath.close();

      canvas.drawPath(
        errPath,
        Paint()
          ..color = Colors.red.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        errPath,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0,
      );
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
