import 'dart:math' show pi, sqrt, atan2;

import '../../data/models/point2d.dart';

/// Geometry calculation engine.
///
/// All functions are pure static. Returns [double.nan] for invalid inputs;
/// never throws.
///
/// Angle convention: 0° = east, 90° = north (mathematical / y-up).
class GeometryEngine {
  GeometryEngine._(); // coverage:ignore-line

  /// Polygon area using the Shoelace formula (m²).
  ///
  /// Vertices are in mm; the result is converted to m².
  static double polygonAreaM2(List<Point2D> vertices) {
    final n = vertices.length;
    if (n < 3) return double.nan;
    var area = 0.0;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += vertices[i].x * vertices[j].y;
      area -= vertices[j].x * vertices[i].y;
    }
    return area.abs() / 2.0 / 1e6; // mm² → m²
  }

  /// Polygon perimeter (m).
  ///
  /// Vertices are in mm; the result is converted to m.
  static double polygonPerimeterM(List<Point2D> vertices) {
    final n = vertices.length;
    if (n < 2) return double.nan;
    var perimeter = 0.0;
    for (var i = 0; i < n; i++) {
      perimeter += distanceMm(vertices[i], vertices[(i + 1) % n]);
    }
    return perimeter / 1000.0; // mm → m
  }

  /// Check if a point is inside a polygon (ray-casting algorithm).
  ///
  /// Points on the boundary are treated as inside.
  static bool isPointInPolygon(Point2D point, List<Point2D> polygon) {
    final n = polygon.length;
    if (n < 3) return false;

    // Boundary check: return true if point lies on any edge.
    for (var i = 0; i < n; i++) {
      if (_isPointOnSegment(point, polygon[i], polygon[(i + 1) % n])) {
        return true;
      }
    }

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

  /// Whether [p] lies on segment [a]→[b] (within floating-point tolerance).
  static bool _isPointOnSegment(Point2D p, Point2D a, Point2D b) {
    final cross = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
    if (cross.abs() > 1e-6) return false;
    final minX = a.x < b.x ? a.x : b.x;
    final maxX = a.x > b.x ? a.x : b.x;
    final minY = a.y < b.y ? a.y : b.y;
    final maxY = a.y > b.y ? a.y : b.y;
    return p.x >= minX - 1e-6 &&
        p.x <= maxX + 1e-6 &&
        p.y >= minY - 1e-6 &&
        p.y <= maxY + 1e-6;
  }

  /// Check if polygon [inner] is entirely contained within polygon [outer].
  ///
  /// Requires all inner vertices to be inside outer AND no inner edge to
  /// cross any outer edge (handles concave cases).
  static bool isPolygonContained(List<Point2D> inner, List<Point2D> outer) {
    for (final v in inner) {
      if (!isPointInPolygon(v, outer)) return false;
    }
    for (var i = 0; i < inner.length; i++) {
      final a1 = inner[i];
      final a2 = inner[(i + 1) % inner.length];
      for (var j = 0; j < outer.length; j++) {
        final b1 = outer[j];
        final b2 = outer[(j + 1) % outer.length];
        if (segmentsIntersect(a1, a2, b1, b2)) return false;
      }
    }
    return true;
  }

  /// Check if a polygon is simple (non-self-intersecting).
  ///
  /// Tests every pair of non-adjacent edges for intersection.
  static bool isSimplePolygon(List<Point2D> vertices) {
    final n = vertices.length;
    if (n < 3) return false;
    for (var i = 0; i < n; i++) {
      for (var j = i + 2; j < n; j++) {
        // Skip the wrap-around pair (first and last edge share vertex 0)
        if (i == 0 && j == n - 1) { continue; }
        if (segmentsIntersect(
          vertices[i],
          vertices[(i + 1) % n],
          vertices[j],
          vertices[(j + 1) % n],
        )) {
          return false;
        }
      }
    }
    return true;
  }

  /// Euclidean distance between two points (mm).
  static double distanceMm(Point2D a, Point2D b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Wall segment length (mm).
  static double segmentLengthMm(Point2D start, Point2D end) =>
      distanceMm(start, end);

  /// Angle of a wall segment in degrees.
  ///
  /// 0° = east, 90° = north — matches [CardinalDirection.fromAngleDegrees].
  /// Uses mathematical y-up convention; negate dy for screen (y-down) coords.
  static double segmentAngleDegrees(Point2D start, Point2D end) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    return atan2(dy, dx) * 180.0 / pi;
  }

  /// Polyline total length (mm).
  static double polylineLengthMm(List<Point2D> points) {
    if (points.length < 2) return double.nan;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += distanceMm(points[i], points[i + 1]);
    }
    return total;
  }

  /// Check if two line segments intersect (strict — shared endpoints excluded).
  ///
  /// Uses the parametric cross-product test. Returns false for parallel or
  /// collinear segments.
  static bool segmentsIntersect(
    Point2D a1,
    Point2D a2,
    Point2D b1,
    Point2D b2,
  ) {
    final d1x = a2.x - a1.x;
    final d1y = a2.y - a1.y;
    final d2x = b2.x - b1.x;
    final d2y = b2.y - b1.y;
    final cross = d1x * d2y - d1y * d2x;
    if (cross.abs() < 1e-10) return false; // parallel / collinear
    final diffX = b1.x - a1.x;
    final diffY = b1.y - a1.y;
    final t = (diffX * d2y - diffY * d2x) / cross;
    final u = (diffX * d1y - diffY * d1x) / cross;
    return t > 0 && t < 1 && u > 0 && u < 1;
  }

  /// Snap a point to the nearest grid intersection.
  static Point2D snapToGrid(Point2D point, double gridSpacingMm) {
    if (gridSpacingMm <= 0) return point;
    final x = (point.x / gridSpacingMm).roundToDouble() * gridSpacingMm;
    final y = (point.y / gridSpacingMm).roundToDouble() * gridSpacingMm;
    return Point2D(x: x, y: y);
  }

  /// Snap a point to the nearest endpoint within [thresholdMm].
  ///
  /// Returns [null] if no endpoint is within the threshold.
  static Point2D? snapToEndpoint(
    Point2D point,
    List<Point2D> endpoints,
    double thresholdMm,
  ) {
    Point2D? nearest;
    var minDist = double.infinity;
    for (final ep in endpoints) {
      final d = distanceMm(point, ep);
      if (d < minDist) {
        minDist = d;
        nearest = ep;
      }
    }
    if (nearest != null && minDist <= thresholdMm) return nearest;
    return null;
  }

  /// Whether point [p] lies on segment [a]→[b] within [toleranceMm] mm.
  ///
  /// Uses a squared perpendicular-distance test (avoids sqrt) to check
  /// collinearity, then confirms the projection parameter t ∈ [0, 1].
  static bool isPointOnSegment(
    Point2D p,
    Point2D a,
    Point2D b, {
    double toleranceMm = 1.0,
  }) {
    final abx = b.x - a.x;
    final aby = b.y - a.y;
    final abLen2 = abx * abx + aby * aby;
    if (abLen2 < 1e-9) return false; // degenerate segment
    // Perpendicular distance² = cross² / abLen2.
    // Compare as cross² ≤ tol² × abLen2 to avoid sqrt.
    final cross = abx * (p.y - a.y) - aby * (p.x - a.x);
    if (cross * cross > toleranceMm * toleranceMm * abLen2) return false;
    // t = dot(AP, AB) / |AB|²; t ∈ [0, 1] means P is between A and B.
    final t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / abLen2;
    const eps = 1e-6;
    return t >= -eps && t <= 1.0 + eps;
  }

  /// Parametric position of [p] projected along segment [a]→[b].
  ///
  /// Returns 0.0 at [a], 1.0 at [b]. Values outside [0, 1] indicate
  /// that [p]'s projection falls beyond the segment endpoints.
  static double parameterAlongSegment(Point2D p, Point2D a, Point2D b) {
    final abx = b.x - a.x;
    final aby = b.y - a.y;
    final len2 = abx * abx + aby * aby;
    if (len2 < 1e-9) return 0.0;
    return ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2;
  }
}
