import 'dart:math' show atan2, max, min, pi, sqrt;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';

/// Draws dimension labels on the canvas:
///
/// - Wall length labels at each wall's inner-edge midpoint, showing
///   the EN 12831 *Lichtmaß* length (ADR-017 Rule 5). When a wall is
///   the current selection a small secondary centerline-length
///   sub-label is drawn just outside the primary label per
///   `agent-ui-ux.md §7.3`.
/// - Room width / height labels for rectangle-eligible rooms
///   (ADR-015), derived from the inner clear polygon.
class AnnotationPainter extends CustomPainter {
  /// Creates an [AnnotationPainter].
  const AnnotationPainter({
    required this.textColor,
    required this.walls,
    required this.rooms,
    this.selectedWallId,
    this.fontSizeWorldMm = 80.0,
    this.secondaryFontSizeWorldMm = 56.0,
  });

  /// Colour for annotation text.
  final Color textColor;

  /// All wall segments on the floor.
  final List<WallSegment> walls;

  /// All rooms on the floor.
  final List<Room> rooms;

  /// Id of the currently selected wall, or `null`. When set, that
  /// wall's centerline-length sub-label is also drawn.
  final String? selectedWallId;

  /// Primary label font size in world-mm units.
  final double fontSizeWorldMm;

  /// Secondary (centerline) sub-label font size in world-mm units.
  final double secondaryFontSizeWorldMm;

  @override
  void paint(Canvas canvas, Size size) {
    if (walls.isEmpty && rooms.isEmpty) return;

    // ADR-001: skip mirror duplicates so each shared wall labels once.
    final drawIds = <String>{};
    for (final w in walls) {
      final mirror = w.mirrorId;
      if (mirror != null && w.id.compareTo(mirror) > 0) continue;
      drawIds.add(w.id);
    }

    final innerEdges = <String, ({Point2D start, Point2D end})>{};
    for (final room in rooms) {
      if (room.polygon.length < 3) continue;
      final roomWalls = walls.where((w) => w.roomId == room.id).toList();
      if (roomWalls.isEmpty) continue;
      innerEdges.addAll(
        GeometryEngine.roomFaceEdges(
          walls: roomWalls,
          roomPolygon: room.polygon,
          side: RoomFaceSide.inner,
        ),
      );
    }

    for (final wall in walls) {
      if (!drawIds.contains(wall.id)) continue;

      final inner = innerEdges[wall.id];
      // Primary label: inner edge length (ADR-017 Rule 5).
      final ({Point2D start, Point2D end}) labelEdge;
      if (inner != null) {
        labelEdge = inner;
      } else {
        // Orphan wall — no room context. Use the centerline.
        labelEdge = (start: wall.startPoint, end: wall.endPoint);
      }
      final innerLen = GeometryEngine.distanceMm(
        labelEdge.start,
        labelEdge.end,
      );
      _drawLengthLabel(
        canvas,
        text: '${innerLen.round()}',
        edge: labelEdge,
        outwardSide: _outwardSide(wall, labelEdge),
        fontSize: fontSizeWorldMm,
        offsetMul: 1.0,
      );

      if (wall.id == selectedWallId) {
        // Secondary sub-label: centerline length, smaller, offset
        // further outward so it never overlaps the primary label.
        final centerLen = GeometryEngine.distanceMm(
          wall.startPoint,
          wall.endPoint,
        );
        _drawLengthLabel(
          canvas,
          text: '${centerLen.round()} (CL)',
          edge: labelEdge,
          outwardSide: _outwardSide(wall, labelEdge),
          fontSize: secondaryFontSizeWorldMm,
          offsetMul: 2.4,
        );
      }
    }

    // Room dimension labels (ADR-015): inner-clear width × height for
    // rectangle-eligible rooms.
    for (final room in rooms) {
      if (room.polygon.length < 3) continue;
      final roomWalls = walls.where((w) => w.roomId == room.id).toList();
      if (roomWalls.length != 4) continue;
      final offsets = <double>[];
      var matched = true;
      for (var i = 0; i < room.polygon.length; i++) {
        final pa = room.polygon[i];
        final pb = room.polygon[(i + 1) % room.polygon.length];
        WallSegment? m;
        for (final w in roomWalls) {
          if ((_pointEq(w.startPoint, pa) && _pointEq(w.endPoint, pb)) ||
              (_pointEq(w.startPoint, pb) && _pointEq(w.endPoint, pa))) {
            m = w;
            break;
          }
        }
        if (m == null) {
          matched = false;
          break;
        }
        offsets.add(-m.thicknessMm / 2.0);
      }
      if (!matched) continue;
      final inner = GeometryEngine.offsetPolygonPerEdge(
        centerline: room.polygon,
        edgeOffsetsMm: offsets,
      );
      if (inner.length != 4) continue;
      if (!_isAxisAlignedRectangle(inner)) continue;
      var minX = inner.first.x;
      var maxX = inner.first.x;
      var minY = inner.first.y;
      var maxY = inner.first.y;
      for (final p in inner) {
        minX = min(minX, p.x);
        maxX = max(maxX, p.x);
        minY = min(minY, p.y);
        maxY = max(maxY, p.y);
      }
      final widthMm = (maxX - minX).round();
      final heightMm = (maxY - minY).round();
      final cx = (minX + maxX) / 2.0;
      final cy = (minY + maxY) / 2.0;
      _drawCenteredLabel(
        canvas,
        text: '$widthMm × $heightMm mm',
        worldX: cx,
        worldY: cy,
        fontSize: fontSizeWorldMm,
      );
    }
  }

  /// Returns the outward-normal direction of the wall relative to its
  /// owning room, expressed as a unit vector. Used to push labels just
  /// outside the inner edge so they don't overlap the wall body.
  ({double x, double y}) _outwardSide(
    WallSegment wall,
    ({Point2D start, Point2D end}) edge,
  ) {
    final dx = edge.end.x - edge.start.x;
    final dy = edge.end.y - edge.start.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1e-6) return (x: 0, y: -1);
    // Compute outward normal using the room polygon winding (same
    // convention as GeometryEngine.offsetPolygonPerEdge). For the
    // inner-edge label we want to draw on the **room-interior side**
    // so the number sits inside the room rather than over the wall.
    final room = rooms.where((r) => r.id == wall.roomId).firstOrNull;
    if (room == null || room.polygon.length < 3) {
      return (x: -dy / len, y: dx / len);
    }
    var signedArea2 = 0.0;
    for (var i = 0; i < room.polygon.length; i++) {
      final a = room.polygon[i];
      final b = room.polygon[(i + 1) % room.polygon.length];
      signedArea2 += a.x * b.y - b.x * a.y;
    }
    final windingSign = signedArea2 > 0 ? 1.0 : -1.0;
    // Inward normal of the wall (room interior side) is `-outward`.
    return (x: -windingSign * dy / len, y: windingSign * dx / len);
  }

  void _drawLengthLabel(
    Canvas canvas, {
    required String text,
    required ({Point2D start, Point2D end}) edge,
    required ({double x, double y}) outwardSide,
    required double fontSize,
    required double offsetMul,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
      ),
    )
      ..pushStyle(ui.TextStyle(color: textColor, fontSize: fontSize))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: fontSize * 8));

    final midX = (edge.start.x + edge.end.x) / 2.0;
    final midY = (edge.start.y + edge.end.y) / 2.0;
    final dx = edge.end.x - edge.start.x;
    final dy = edge.end.y - edge.start.y;
    final angle = atan2(dy, dx);
    // Keep labels right-side up: flip 180° when the wall runs right-to-left.
    final keepUp = angle.abs() > pi / 2 ? angle + pi : angle;

    final off = fontSize * offsetMul;
    canvas.save();
    canvas.translate(
      midX + outwardSide.x * off,
      midY + outwardSide.y * off,
    );
    canvas.rotate(keepUp);
    canvas.translate(-paragraph.width / 2, -paragraph.height / 2);
    canvas.drawParagraph(paragraph, Offset.zero);
    canvas.restore();
  }

  void _drawCenteredLabel(
    Canvas canvas, {
    required String text,
    required double worldX,
    required double worldY,
    required double fontSize,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
      ),
    )
      ..pushStyle(ui.TextStyle(color: textColor, fontSize: fontSize))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: fontSize * 12));
    canvas.save();
    canvas.translate(
      worldX - paragraph.width / 2,
      worldY - paragraph.height / 2,
    );
    canvas.drawParagraph(paragraph, Offset.zero);
    canvas.restore();
  }

  bool _pointEq(Point2D a, Point2D b) =>
      (a.x - b.x).abs() <= 1.0 && (a.y - b.y).abs() <= 1.0;

  /// Whether [vertices] form an axis-aligned 4-vertex rectangle within
  /// 1 mm tolerance.
  bool _isAxisAlignedRectangle(List<Point2D> vertices) {
    if (vertices.length != 4) return false;
    for (var i = 0; i < 4; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % 4];
      final dx = (a.x - b.x).abs();
      final dy = (a.y - b.y).abs();
      if (dx > 1.0 && dy > 1.0) return false;
    }
    return true;
  }

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) {
    if (oldDelegate.textColor != textColor) return true;
    if (oldDelegate.selectedWallId != selectedWallId) return true;
    if (oldDelegate.fontSizeWorldMm != fontSizeWorldMm) return true;
    if (oldDelegate.secondaryFontSizeWorldMm !=
        secondaryFontSizeWorldMm) {
      return true;
    }
    if (!identical(oldDelegate.walls, walls)) {
      if (oldDelegate.walls.length != walls.length) return true;
      for (var i = 0; i < walls.length; i++) {
        final a = walls[i];
        final b = oldDelegate.walls[i];
        if (a.id != b.id ||
            a.startPoint != b.startPoint ||
            a.endPoint != b.endPoint ||
            a.thicknessMm != b.thicknessMm ||
            a.anchorMode != b.anchorMode ||
            a.mirrorId != b.mirrorId) {
          return true;
        }
      }
    }
    if (!identical(oldDelegate.rooms, rooms)) return true;
    return false;
  }
}
