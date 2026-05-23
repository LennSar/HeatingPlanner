import 'dart:math' show sqrt;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../../calculation/engines/geometry_engine.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';

/// Draws wall segments on the canvas as filled mitered rectangles whose
/// thickness comes from [WallSegment.thicknessMm] (ADR-017).
///
/// Per-wall thickness gives every wall its own width, and corner mitering
/// from [GeometryEngine.roomFaceEdges] produces clean junctions where two
/// walls meet at any angle. ADR-001 shared mirror pairs are drawn once —
/// the copy with the alphabetically-greater `id` is skipped so the result
/// is deterministic.
///
/// When [selectedWallId] is non-null and that wall's [anchorMode] is not
/// [WallAnchorMode.centerline], a pin/lock glyph is rendered at the
/// midpoint of the anchored face. The glyph is drawn in **screen space**
/// (constant 14 px diameter regardless of zoom) per ADR-017 Rule 10 and
/// `agent-ui-ux.md §7.3`.
class WallPainter extends CustomPainter {
  /// Creates a [WallPainter].
  const WallPainter({
    required this.wallFill,
    required this.wallStroke,
    required this.walls,
    required this.rooms,
    required this.worldToScreen,
    this.selectedWallId,
    this.pinFill,
    this.pinStroke,
  });

  /// Fill colour for wall rectangles.
  final Color wallFill;

  /// Stroke colour for wall outlines.
  final Color wallStroke;

  /// All wall segments to draw.
  final List<WallSegment> walls;

  /// All rooms — needed to derive per-wall mitered faces via
  /// [GeometryEngine.roomFaceEdges].
  final List<Room> rooms;

  /// Active world-to-screen transform used to project the pinned-face
  /// glyph anchor point into screen pixels.
  final Matrix4 worldToScreen;

  /// Id of the currently selected wall (or `null`). Drives the pin
  /// glyph rendering — only the selected wall ever shows a glyph.
  final String? selectedWallId;

  /// Pin-glyph fill colour. Defaults to [wallStroke] when null.
  final Color? pinFill;

  /// Pin-glyph stroke colour. Defaults to [wallFill] when null.
  final Color? pinStroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (walls.isEmpty) return;

    final fillPaint = Paint()
      ..color = wallFill
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = wallStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // ADR-001: skip mirror duplicates with the larger id so each shared
    // wall is drawn exactly once.
    final drawIds = <String>{};
    for (final w in walls) {
      final mirror = w.mirrorId;
      if (mirror != null && w.id.compareTo(mirror) > 0) continue;
      drawIds.add(w.id);
    }

    // Pre-compute inner / outer mitered edges per room (ADR-017 Rule 4).
    final innerEdges = <String, ({Point2D start, Point2D end})>{};
    final outerEdges = <String, ({Point2D start, Point2D end})>{};
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
      outerEdges.addAll(
        GeometryEngine.roomFaceEdges(
          walls: roomWalls,
          roomPolygon: room.polygon,
          side: RoomFaceSide.outer,
        ),
      );
    }

    WallSegment? selectedWall;

    for (final wall in walls) {
      if (!drawIds.contains(wall.id)) continue;
      if (wall.id == selectedWallId) selectedWall = wall;

      final inner = innerEdges[wall.id];
      final outer = outerEdges[wall.id];

      final Path body;
      if (inner != null && outer != null) {
        // Mitered rectangle from the four offset-face corners.
        body = Path()
          ..moveTo(inner.start.x, inner.start.y)
          ..lineTo(outer.start.x, outer.start.y)
          ..lineTo(outer.end.x, outer.end.y)
          ..lineTo(inner.end.x, inner.end.y)
          ..close();
      } else {
        // Orphan / unassigned wall — no room to derive miter from. Fall
        // back to a plain ±½t perpendicular rectangle.
        final body0 = _perpendicularRect(wall);
        if (body0 == null) continue;
        body = body0;
      }
      canvas.drawPath(body, fillPaint);
      canvas.drawPath(body, strokePaint);
    }

    if (selectedWall != null &&
        selectedWall.anchorMode != WallAnchorMode.centerline) {
      _drawPinGlyph(
        canvas,
        wall: selectedWall,
        innerEdge: innerEdges[selectedWall.id],
        outerEdge: outerEdges[selectedWall.id],
      );
    }
  }

  /// Fallback ±½t rectangle for walls that have no room context.
  Path? _perpendicularRect(WallSegment wall) {
    final dx = wall.endPoint.x - wall.startPoint.x;
    final dy = wall.endPoint.y - wall.startPoint.y;
    final length = sqrt(dx * dx + dy * dy);
    if (length < 1) return null;
    final half = wall.thicknessMm / 2.0;
    final px = -dy / length * half;
    final py = dx / length * half;
    return Path()
      ..moveTo(wall.startPoint.x + px, wall.startPoint.y + py)
      ..lineTo(wall.endPoint.x + px, wall.endPoint.y + py)
      ..lineTo(wall.endPoint.x - px, wall.endPoint.y - py)
      ..lineTo(wall.startPoint.x - px, wall.startPoint.y - py)
      ..close();
  }

  /// Renders the ADR-017 Rule 10 pinned-face glyph at a fixed 14 px
  /// diameter in screen space. The anchor is the midpoint of the
  /// inner or outer face depending on [WallSegment.anchorMode].
  ///
  /// At call time the [canvas] already carries [worldToScreen] in its
  /// current transform (applied by [_StaticWorldPainter]). To draw in
  /// pure screen space we temporarily invert that transform, draw the
  /// circle at the projected pixel coordinate, then restore — so the
  /// glyph stays a constant 14 px diameter regardless of zoom.
  void _drawPinGlyph(
    Canvas canvas, {
    required WallSegment wall,
    required ({Point2D start, Point2D end})? innerEdge,
    required ({Point2D start, Point2D end})? outerEdge,
  }) {
    final edge = wall.anchorMode == WallAnchorMode.innerFace
        ? innerEdge
        : outerEdge;
    if (edge == null) return;
    final v = worldToScreen.transform3(
      Vector3(
        (edge.start.x + edge.end.x) / 2.0,
        (edge.start.y + edge.end.y) / 2.0,
        0,
      ),
    );
    final inverse = Matrix4.inverted(worldToScreen);
    canvas.save();
    canvas.transform(inverse.storage);
    final fill = Paint()
      ..color = pinFill ?? wallStroke
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = pinStroke ?? wallFill
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final centre = Offset(v.x, v.y);
    canvas.drawCircle(centre, 7.0, fill);
    canvas.drawCircle(centre, 7.0, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(WallPainter oldDelegate) {
    if (oldDelegate.wallFill != wallFill) return true;
    if (oldDelegate.wallStroke != wallStroke) return true;
    if (oldDelegate.selectedWallId != selectedWallId) return true;
    if (oldDelegate.worldToScreen != worldToScreen) return true;
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
