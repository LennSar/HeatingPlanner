import 'dart:math' show sqrt;

import '../../data/models/point2d.dart';

/// Extension methods on [List<Point2D>] for polygon utilities.
extension PolygonExt on List<Point2D> {
  /// Computes the signed area of the polygon using the shoelace formula.
  ///
  /// Returns a positive value for counter-clockwise winding.
  double signedArea() {
    final n = length;
    if (n < 3) return 0.0;
    var area = 0.0;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += this[i].x * this[j].y;
      area -= this[j].x * this[i].y;
    }
    return area / 2;
  }

  /// Absolute area of the polygon in mm².
  double area() => signedArea().abs();

  /// Returns true if the polygon vertices are in counter-clockwise order.
  bool isCounterClockwise() => signedArea() > 0;

  /// Perimeter length of the polygon in mm.
  double perimeter() {
    final n = length;
    if (n < 2) return 0.0;
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final dx = this[j].x - this[i].x;
      final dy = this[j].y - this[i].y;
      total += sqrt(dx * dx + dy * dy);
    }
    return total;
  }
}
