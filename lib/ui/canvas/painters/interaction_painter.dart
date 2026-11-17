import 'dart:math' show pi, sqrt;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../calculation/engines/pipe_layout_engine.dart';
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
    this.supplyPipeColor = const Color(0xFFEF4444),
    this.returnPipeColor = const Color(0xFF3B82F6),
    this.routeBendRadiusMm = 80.0,
  });

  /// Current hover position in world coordinates, if any.
  final Offset? hoverPoint;

  /// Colour for selection/hover highlights.
  final Color? selectionHighlightColor;

  /// Tool-produced interaction data (ghost line or
  /// selection highlight).
  final InteractionData? interactionData;

  /// Supply pipe colour used when drawing a route ghost.
  final Color supplyPipeColor;

  /// Return pipe colour used when drawing a route ghost.
  final Color returnPipeColor;

  /// Bend radius in mm applied to the corners of a connection pipe
  /// while it is being drawn (ADR-039 Rule 3).
  final double routeBendRadiusMm;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw crosshair at hover point.
    _drawCrosshair(canvas);

    // Draw tool-specific interaction data.
    if (interactionData != null) {
      switch (interactionData!) {
        case GhostLineData(:final startPoint, :final currentPoint,
              :final snapIndicator, :final snapType,
              :final orthoGuidelineStart, :final orthoGuidelineEnd,
              :final alignXAnchor, :final alignYAnchor):
          _drawGhostLine(
            canvas,
            Offset(startPoint.x, startPoint.y),
            Offset(currentPoint.x, currentPoint.y),
            snapIndicator != null
                ? Offset(snapIndicator.x, snapIndicator.y)
                : null,
            snapType,
            orthoGuidelineStart != null
                ? Offset(orthoGuidelineStart.x, orthoGuidelineStart.y)
                : null,
            orthoGuidelineEnd != null
                ? Offset(orthoGuidelineEnd.x, orthoGuidelineEnd.y)
                : null,
            alignXAnchor != null
                ? Offset(alignXAnchor.x, alignXAnchor.y)
                : null,
            alignYAnchor != null
                ? Offset(alignYAnchor.x, alignYAnchor.y)
                : null,
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
        case CircuitSelectionData(
              :final supplyPoints,
              :final returnPoints,
              :final handles,
              :final activeHandleIndex,
            ):
          _drawCircuitSelection(canvas, supplyPoints, returnPoints);
          if (handles.isNotEmpty) {
            _drawWallHandles(canvas, handles, activeHandleIndex);
          }
        case ZoneSplitPreviewData(:final start, :final end):
          _drawZoneSplitPreview(
            canvas,
            Offset(start.x, start.y),
            Offset(end.x, end.y),
          );
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
        case DistributorGhostData(
              :final position,
              :final widthMm,
              :final rotationDeg,
            ):
          _drawDistributorGhost(
            canvas,
            Offset(position.x, position.y),
            widthMm,
            rotationDeg,
          );
        case DistributorSelectionData(
              :final position,
              :final widthMm,
              :final handles,
              :final activeHandleIndex,
              :final rotationDeg,
            ):
          _drawDistributorSelection(
            canvas,
            Offset(position.x, position.y),
            widthMm,
            rotationDeg,
          );
          _drawWallHandles(canvas, handles, activeHandleIndex);
        case RectDrawData(:final corner1, :final corner2):
          _drawRectGhost(
            canvas,
            Offset(corner1.x, corner1.y),
            Offset(corner2.x, corner2.y),
          );
        case RoomMoveGhostData(:final wallLines, :final zonePolygons):
          _drawRoomMoveGhost(canvas, wallLines, zonePolygons);
        case RouteDrawData(
              :final supplyPoints,
              :final returnPoints,
              :final waypoints,
              :final currentPoint,
              :final hoveredZoneAlreadyConnected,
            ):
          _drawRouteGhost(
            canvas,
            supplyPoints,
            returnPoints,
            waypoints,
            currentPoint,
            hoveredZoneAlreadyConnected,
          );
        case TubePathData(
              :final corners,
              :final handles,
              :final activeHandleIndex,
              :final selectedHandleIndex,
              :final drawing,
              :final bendRadiusMm,
            ):
          _drawTubePath(canvas, corners, drawing, bendRadiusMm);
          if (handles.isNotEmpty) {
            _drawWallHandles(canvas, handles, activeHandleIndex);
            if (selectedHandleIndex != null &&
                selectedHandleIndex < handles.length) {
              final h = handles[selectedHandleIndex];
              canvas.drawCircle(
                Offset(h.x, h.y),
                48.0,
                Paint()
                  ..color = selectionHighlightColor ?? Colors.blue
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 6.0,
              );
            }
          }
        case MeasureData(
              :final start,
              :final end,
              :final finalized,
              :final snapIndicator,
            ):
          _drawMeasure(
            canvas,
            Offset(start.x, start.y),
            Offset(end.x, end.y),
            finalized,
            snapIndicator != null
                ? Offset(snapIndicator.x, snapIndicator.y)
                : null,
          );
      }
    }
  }

  /// Draws a measure-tool dimension line (ADR-030): a solid line with a
  /// perpendicular end cap at each endpoint and a length label centred
  /// above the midpoint. While [finalized] is false an endpoint dot and
  /// (when snapped) a snap ring track the cursor.
  void _drawMeasure(
    Canvas canvas,
    Offset start,
    Offset end,
    bool finalized,
    Offset? snapIndicator,
  ) {
    final color = selectionHighlightColor ?? Colors.blue;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 20.0 // world-space; ~2 px at default zoom
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, linePaint);

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = sqrt(dx * dx + dy * dy);
    if (length >= 1) {
      // Perpendicular end caps so the dimension reads like a ruler.
      final px = -dy / length * 90.0;
      final py = dx / length * 90.0;
      final capPaint = Paint()
        ..color = color
        ..strokeWidth = 20.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(start.dx + px, start.dy + py),
        Offset(start.dx - px, start.dy - py),
        capPaint,
      );
      canvas.drawLine(
        Offset(end.dx + px, end.dy + py),
        Offset(end.dx - px, end.dy - py),
        capPaint,
      );
    }

    // Length label centred above the midpoint.
    final lengthMm = length.round();
    final text = lengthMm >= 1000
        ? '${(lengthMm / 1000).toStringAsFixed(3)} m'
        : '$lengthMm mm';
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 80),
    )
      ..pushStyle(ui.TextStyle(color: color, fontSize: 80))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 600));
    canvas.drawParagraph(
      paragraph,
      Offset(
        (start.dx + end.dx) / 2 - paragraph.width / 2,
        (start.dy + end.dy) / 2 - paragraph.height - 30,
      ),
    );

    // Endpoint dots.
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(start, 12.0, dotPaint);
    canvas.drawCircle(end, 12.0, dotPaint);

    // Snap ring on the live endpoint.
    if (!finalized && snapIndicator != null) {
      canvas.drawCircle(
        snapIndicator,
        30.0,
        Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0,
      );
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

  /// Draws the ADR-018 Rule 8 hover preview: a dashed bisector line
  /// in the `selectionHighlight` colour at 50 % opacity, showing where
  /// a Zone tool double-click would split the underlying rectangular
  /// zone. The stroke width and dash pattern are world-space — the
  /// parent transform scales them along with the rest of the canvas.
  void _drawZoneSplitPreview(Canvas canvas, Offset start, Offset end) {
    final color = (selectionHighlightColor ?? Colors.blue)
        .withValues(alpha: 0.5);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 20.0 // ~2 px at the default 0.1×–1× zoom range
      ..style = PaintingStyle.stroke;
    // Dash pattern: short on / off, world-space (Rule 8: dash 6 / gap 4
    // scaled for screen — we use 60 / 40 world mm which reads as
    // comparable at typical zoom levels).
    _drawDashedLine(canvas, start, end, paint, 60.0);
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

  void _drawRectGhost(Canvas canvas, Offset corner1, Offset corner2) {
    final paint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromPoints(corner1, corner2);
    canvas.drawRect(rect, paint);

    // Width annotation above the top edge.
    final widthMm = rect.width.round();
    final heightMm = rect.height.round();
    _drawRectAnnotation(
      canvas,
      '$widthMm mm',
      Offset(rect.center.dx, rect.top - 80),
    );
    // Height annotation to the right of the right edge.
    _drawRectAnnotation(
      canvas,
      '$heightMm mm',
      Offset(rect.right + 30, rect.center.dy),
    );
  }

  /// Draws the moving-room ghost (ADR-016): a dashed outline for each
  /// translated wall plus a translucent fill for each translated zone.
  ///
  /// Matches the existing ghost-line styling so the user perceives the
  /// whole room as "in flight" without committing to anything.
  void _drawRoomMoveGhost(
    Canvas canvas,
    List<(Point2D, Point2D)> wallLines,
    List<List<Point2D>> zonePolygons,
  ) {
    final highlight = selectionHighlightColor ?? Colors.blue;

    // Zone fills, drawn first so wall outlines sit on top.
    if (zonePolygons.isNotEmpty) {
      final zoneFill = Paint()
        ..color = highlight.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      final zoneStroke = Paint()
        ..color = highlight.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      for (final poly in zonePolygons) {
        if (poly.length < 3) continue;
        final path = Path()..moveTo(poly.first.x, poly.first.y);
        for (var i = 1; i < poly.length; i++) {
          path.lineTo(poly[i].x, poly[i].y);
        }
        path.close();
        canvas.drawPath(path, zoneFill);
        canvas.drawPath(path, zoneStroke);
      }
    }

    // Walls: dashed lines so the ghost is distinct from committed walls.
    final ghostPaint = Paint()
      ..color = highlight
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;
    for (final line in wallLines) {
      final (a, b) = line;
      _drawDashedLine(
        canvas,
        Offset(a.x, a.y),
        Offset(b.x, b.y),
        ghostPaint,
        30.0,
      );
    }
  }

  void _drawRectAnnotation(Canvas canvas, String text, Offset position) {
    final color = selectionHighlightColor ?? Colors.blue;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.start, fontSize: 70),
    )
      ..pushStyle(ui.TextStyle(color: color, fontSize: 70))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 500));
    canvas.drawParagraph(paragraph, position);
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
    String? snapType, [
    Offset? orthoGuidelineStart,
    Offset? orthoGuidelineEnd,
    Offset? alignXAnchor,
    Offset? alignYAnchor,
  ]) {
    // Dashed ortho-constraint guideline (§6.3 — drawn behind ghost line).
    if (orthoGuidelineStart != null && orthoGuidelineEnd != null) {
      _drawDashedLine(
        canvas,
        orthoGuidelineStart,
        orthoGuidelineEnd,
        Paint()
          ..color = (selectionHighlightColor ?? Colors.blue)
              .withValues(alpha: 0.35)
          ..strokeWidth = 10.0
          ..style = PaintingStyle.stroke,
        20.0,
      );
    }

    // Dashed alignment guides to the tracked room corner(s). Drawn in orange
    // (the same colour as the endpoint-snap indicator below) so the guide
    // reads as "tracking a corner" and is distinct from the blue ortho guide.
    if (alignXAnchor != null) _drawAlignmentGuide(canvas, alignXAnchor, end);
    if (alignYAnchor != null) _drawAlignmentGuide(canvas, alignYAnchor, end);

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

  /// Draws a dashed alignment guide from a tracked room corner [anchor] to the
  /// current ghost endpoint [end], with a small ring marking the corner.
  ///
  /// Rendered in orange to match the endpoint-snap indicator, signalling that
  /// the endpoint is axis-aligned with that corner (CAD object-snap tracking).
  void _drawAlignmentGuide(Canvas canvas, Offset anchor, Offset end) {
    final paint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.6)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, anchor, end, paint, 30.0);
    canvas.drawCircle(
      anchor,
      20.0,
      Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
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

  // ── Distributor ghost / selection ─────────────────────────

  static const double _distBodyH = 240.0;

  void _drawDistributorGhost(
    Canvas canvas,
    Offset center,
    double widthMm,
    int rotationDeg,
  ) {
    final rect = Rect.fromCenter(
      center: center,
      width: widthMm,
      height: _distBodyH,
    );
    final color = selectionHighlightColor ?? Colors.blue;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationDeg * pi / 180.0);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    _drawDashedRect(canvas, rect, color.withValues(alpha: 0.7));

    // Outlet stubs on the front side, so it is clear which way the
    // distributor will face (ADR-044). A new distributor has 4.
    const outlets = 4;
    final pitch = widthMm / outlets;
    final stubPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    for (var i = 0; i < outlets; i++) {
      final x = rect.left + (i + 0.5) * pitch;
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.top - PipeLayoutEngine.distributorStubLengthMm),
        stubPaint,
      );
    }

    canvas.restore();
  }

  void _drawDistributorSelection(
    Canvas canvas,
    Offset center,
    double widthMm,
    int rotationDeg,
  ) {
    final rect = Rect.fromCenter(
      center: center,
      width: widthMm,
      height: _distBodyH,
    );
    final color = selectionHighlightColor ?? Colors.blue;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationDeg * pi / 180.0);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0,
    );

    canvas.restore();
  }

  // ── Route drawing ghost ──────────────────────────────────

  /// Draws the live preview of a pair of connection pipes being drawn
  /// (ADR-040 Rule 5):
  ///  - the supply pipe in [supplyPipeColor] and the return pipe in
  ///    [returnPipeColor], both with bend radii and directional arrows,
  ///    exactly as they would be committed at the cursor position
  ///  - a dot at each placed route point
  ///  - an amber warning indicator when [hoveredZoneConnected]
  void _drawRouteGhost(
    Canvas canvas,
    List<Point2D> supplyPoints,
    List<Point2D> returnPoints,
    List<Point2D> waypoints,
    Point2D? currentPoint,
    bool hoveredZoneConnected,
  ) {
    if (supplyPoints.length >= 2) {
      _drawRoutePath(canvas, supplyPoints, supplyPipeColor);
    }
    if (returnPoints.length >= 2) {
      _drawRoutePath(canvas, returnPoints, returnPipeColor);
    }

    _drawWaypointDots(
      canvas,
      waypoints,
      selectionHighlightColor ?? Colors.blue,
    );

    // Warning when zone already has a circuit.
    if (hoveredZoneConnected && currentPoint != null) {
      _drawAlreadyConnectedWarning(canvas, currentPoint);
    }
  }

  /// Draws the corners of a tube being edited or drawn (ADR-046) as a
  /// dashed polyline; while [drawing], also the tube itself, rounded with
  /// [bendRadiusMm].
  void _drawTubePath(
    Canvas canvas,
    List<Point2D> corners,
    bool drawing,
    double bendRadiusMm,
  ) {
    if (corners.length < 2) return;
    final color = selectionHighlightColor ?? Colors.blue;
    if (drawing) {
      final tube = PipeLayoutEngine.filletPolyline(corners, bendRadiusMm);
      final path = Path()..moveTo(tube.first.x, tube.first.y);
      for (final p in tube.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..strokeWidth = 8.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final dash = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    for (var i = 0; i + 1 < corners.length; i++) {
      _drawDashedLine(
        canvas,
        Offset(corners[i].x, corners[i].y),
        Offset(corners[i + 1].x, corners[i + 1].y),
        dash,
        40.0,
      );
    }
  }

  /// Draws the corner polygon of a selected circuit (ADR-039 Rule 1):
  /// a dashed line through the corner points of both connection pipes,
  /// so the editable corners are visible next to the rounded pipe.
  void _drawCircuitSelection(
    Canvas canvas,
    List<Point2D> supplyPoints,
    List<Point2D> returnPoints,
  ) {
    final paint = Paint()
      ..color = (selectionHighlightColor ?? Colors.blue)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    for (final points in [supplyPoints, returnPoints]) {
      for (var i = 0; i + 1 < points.length; i++) {
        _drawDashedLine(
          canvas,
          Offset(points[i].x, points[i].y),
          Offset(points[i + 1].x, points[i + 1].y),
          paint,
          40.0,
        );
      }
    }
  }

  /// Draws [corners] as a solid polyline in [color] with directional
  /// arrows every 500 mm. Corners are rounded with [routeBendRadiusMm]
  /// (ADR-039 Rule 3).
  void _drawRoutePath(
    Canvas canvas,
    List<Point2D> corners,
    Color color,
  ) {
    final points =
        PipeLayoutEngine.filletPolyline(corners, routeBendRadiusMm);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(points.first.x, points.first.y);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }
    canvas.drawPath(path, paint);
    _drawRouteArrows(canvas, points, color);
  }

  /// Places a filled arrowhead every 500 mm along [points].
  void _drawRouteArrows(
    Canvas canvas,
    List<Point2D> points,
    Color color,
  ) {
    const spacingMm = 500.0;
    const halfLen = 50.0;
    const halfWidth = 30.0;
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    var distToNext = spacingMm * 0.5;

    for (var i = 0; i < points.length - 1; i++) {
      final ax = points[i].x;
      final ay = points[i].y;
      final bx = points[i + 1].x;
      final by = points[i + 1].y;
      final dx = bx - ax;
      final dy = by - ay;
      final segLen = sqrt(dx * dx + dy * dy);
      if (segLen < 1) continue;
      final ux = dx / segLen;
      final uy = dy / segLen;

      var walked = 0.0;
      while (walked + distToNext <= segLen) {
        walked += distToNext;
        distToNext = spacingMm;
        final cx = ax + ux * walked;
        final cy = ay + uy * walked;
        final tipX = cx + ux * halfLen;
        final tipY = cy + uy * halfLen;
        final baseX = cx - ux * halfLen;
        final baseY = cy - uy * halfLen;
        final px = -uy * halfWidth;
        final py = ux * halfWidth;
        final arrowPath = Path()
          ..moveTo(tipX, tipY)
          ..lineTo(baseX + px, baseY + py)
          ..lineTo(baseX - px, baseY - py)
          ..close();
        canvas.drawPath(arrowPath, arrowPaint);
      }
      distToNext -= segLen - walked;
    }
  }

  /// Draws a small filled circle at each waypoint in [points].
  void _drawWaypointDots(
    Canvas canvas,
    List<Point2D> points,
    Color color,
  ) {
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(Offset(p.x, p.y), 12.0, dotPaint);
    }
  }

  /// Draws an amber ⚠ indicator near [point] to signal that
  /// the hovered zone is already connected to a circuit.
  void _drawAlreadyConnectedWarning(
    Canvas canvas,
    Point2D point,
  ) {
    const size = 80.0; // world-space mm
    const yOffset = 130.0;
    final cx = point.x;
    final cy = point.y - yOffset;

    // Equilateral triangle.
    final triPath = Path()
      ..moveTo(cx, cy - size * 0.6)
      ..lineTo(cx - size * 0.55, cy + size * 0.4)
      ..lineTo(cx + size * 0.55, cy + size * 0.4)
      ..close();

    const amber = Color(0xFFF59E0B);
    canvas
      ..drawPath(
        triPath,
        Paint()
          ..color = amber.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill,
      )
      ..drawPath(
        triPath,
        Paint()
          ..color = amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0,
      )
      // Exclamation stem.
      ..drawLine(
        Offset(cx, cy - size * 0.25),
        Offset(cx, cy + size * 0.1),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 8.0
          ..strokeCap = StrokeCap.round,
      );
    // Exclamation dot.
    canvas.drawCircle(
      Offset(cx, cy + size * 0.28),
      5.0,
      Paint()..color = Colors.white,
    );
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke;
    const dash = 30.0;
    // top
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint, dash);
    // right
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint, dash);
    // bottom
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint, dash);
    // left
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint, dash);
  }

  @override
  bool shouldRepaint(InteractionPainter oldDelegate) {
    return oldDelegate.hoverPoint != hoverPoint ||
        oldDelegate.interactionData != interactionData ||
        oldDelegate.supplyPipeColor != supplyPipeColor ||
        oldDelegate.returnPipeColor != returnPipeColor;
  }
}
