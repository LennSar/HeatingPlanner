import 'dart:math' show sqrt;

import 'package:flutter/material.dart';

import '../../../data/models/door.dart';
import '../../../data/models/wall_segment.dart';
import '../../../data/models/window_element.dart';

/// Draws window and door elements on the canvas.
///
/// Each opening is rendered as a coloured rectangle
/// overlaid on its parent wall, in world coordinates
/// (1 unit = 1 mm). The parent [Transform] widget
/// converts to screen pixels.
class OpeningPainter extends CustomPainter {
  /// Creates an [OpeningPainter].
  const OpeningPainter({
    required this.windowFill,
    required this.doorFill,
    required this.walls,
    required this.windows,
    required this.doors,
    this.wallThicknessMm = 200.0,
  });

  /// Fill colour for window elements.
  final Color windowFill;

  /// Fill colour for door elements.
  final Color doorFill;

  /// All wall segments (used to look up geometry).
  final List<WallSegment> walls;

  /// All window elements to draw.
  final List<WindowElement> windows;

  /// All door elements to draw.
  final List<Door> doors;

  /// Visual wall thickness in mm (matches [WallPainter]).
  final double wallThicknessMm;

  @override
  void paint(Canvas canvas, Size size) {
    final wallMap = {for (final w in walls) w.id: w};

    final windowPaint = Paint()
      ..color = windowFill
      ..style = PaintingStyle.fill;

    final doorPaint = Paint()
      ..color = doorFill
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (final window in windows) {
      final wall = wallMap[window.wallSegmentId];
      if (wall == null) continue;
      final path = _openingPath(
        wall,
        window.positionOnWallMm,
        window.widthMm.toDouble(),
      );
      canvas.drawPath(path, windowPaint);
      canvas.drawPath(path, outlinePaint);
    }

    for (final door in doors) {
      final wall = wallMap[door.wallSegmentId];
      if (wall == null) continue;
      final path = _openingPath(
        wall,
        door.positionOnWallMm,
        door.widthMm.toDouble(),
      );
      canvas.drawPath(path, doorPaint);
      canvas.drawPath(path, outlinePaint);
    }
  }

  /// Build a rectangle path for an opening on [wall].
  ///
  /// [positionMm] is the distance from the wall's start
  /// to the opening's near edge. [widthMm] is the opening
  /// width along the wall. The rectangle spans the full
  /// wall thickness perpendicularly.
  Path _openingPath(
    WallSegment wall,
    double positionMm,
    double widthMm,
  ) {
    final sx = wall.startPoint.x;
    final sy = wall.startPoint.y;
    final ex = wall.endPoint.x;
    final ey = wall.endPoint.y;

    final dx = ex - sx;
    final dy = ey - sy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return Path();

    // Along-wall unit vector.
    final ux = dx / len;
    final uy = dy / len;

    // Perpendicular half-thickness offsets.
    final px = -uy * wallThicknessMm / 2;
    final py = ux * wallThicknessMm / 2;

    // Corners of the opening rectangle.
    final x0 = sx + ux * positionMm;
    final y0 = sy + uy * positionMm;
    final x1 = sx + ux * (positionMm + widthMm);
    final y1 = sy + uy * (positionMm + widthMm);

    return Path()
      ..moveTo(x0 + px, y0 + py)
      ..lineTo(x1 + px, y1 + py)
      ..lineTo(x1 - px, y1 - py)
      ..lineTo(x0 - px, y0 - py)
      ..close();
  }

  @override
  bool shouldRepaint(OpeningPainter oldDelegate) {
    return oldDelegate.windows != windows ||
        oldDelegate.doors != doors ||
        oldDelegate.walls != walls ||
        oldDelegate.windowFill != windowFill ||
        oldDelegate.doorFill != doorFill;
  }
}
