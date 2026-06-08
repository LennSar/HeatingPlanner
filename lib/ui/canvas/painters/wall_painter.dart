import 'dart:math' show sqrt;

import 'package:flutter/material.dart';

import '../../../calculation/engines/geometry_engine.dart';
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
class WallPainter extends CustomPainter {
  /// Creates a [WallPainter].
  const WallPainter({
    required this.wallFill,
    required this.wallStroke,
    required this.walls,
    required this.rooms,
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

    for (final wall in walls) {
      if (!drawIds.contains(wall.id)) continue;

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

  @override
  bool shouldRepaint(WallPainter oldDelegate) {
    if (oldDelegate.wallFill != wallFill) return true;
    if (oldDelegate.wallStroke != wallStroke) return true;
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
