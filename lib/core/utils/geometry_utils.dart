import 'dart:math' show sqrt;

import '../../data/models/point2d.dart';

/// Utility functions for 2-D polygon geometry (all coordinates in mm).
abstract final class GeometryUtils {
  /// Signed area of [polygon] via the shoelace formula.
  ///
  /// Positive = counter-clockwise winding.
  static double signedArea(List<Point2D> polygon) {
    final n = polygon.length;
    if (n < 3) return 0.0;
    var area = 0.0;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += polygon[i].x * polygon[j].y;
      area -= polygon[j].x * polygon[i].y;
    }
    return area / 2;
  }

  /// Absolute area of [polygon] in mm².
  static double area(List<Point2D> polygon) => signedArea(polygon).abs();

  /// Perimeter of [polygon] in mm.
  static double perimeter(List<Point2D> polygon) {
    final n = polygon.length;
    if (n < 2) return 0.0;
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final dx = polygon[j].x - polygon[i].x;
      final dy = polygon[j].y - polygon[i].y;
      total += sqrt(dx * dx + dy * dy);
    }
    return total;
  }

  /// Euclidean distance between two points in mm.
  static double distance(Point2D a, Point2D b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Minimum distance from [point] to line segment [a]→[b].
  ///
  /// Uses perpendicular projection clamped to [0, 1].
  static double distanceToSegment(
    Point2D point,
    Point2D a,
    Point2D b,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSq = dx * dx + dy * dy;

    if (lengthSq == 0) return distance(point, a);

    // Project point onto line, clamped to segment.
    var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) /
        lengthSq;
    t = t.clamp(0.0, 1.0);

    final proj = Point2D(
      x: a.x + t * dx,
      y: a.y + t * dy,
    );
    return distance(point, proj);
  }

  /// Returns true if [point] lies inside [polygon] (ray-casting algorithm).
  static bool containsPoint(List<Point2D> polygon, Point2D point) {
    final n = polygon.length;
    var inside = false;
    var j = n - 1;
    for (var i = 0; i < n; i++) {
      final xi = polygon[i].x;
      final yi = polygon[i].y;
      final xj = polygon[j].x;
      final yj = polygon[j].y;
      if (((yi > point.y) != (yj > point.y)) &&
          (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }
}
