import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/geometry_engine.dart';
import 'package:heating_planner/data/models/point2d.dart';

void main() {
  // Standard rectangle used by multiple tests
  const rectangle = [
    Point2D(x: 0, y: 0),
    Point2D(x: 5000, y: 0),
    Point2D(x: 5000, y: 4000),
    Point2D(x: 0, y: 4000),
  ];

  // ── polygonAreaM2 tests ───────────────────────────────────────────────

  group('GeometryEngine.polygonAreaM2', () {
    test('GE-1: rectangle area (shoelace)', () {
      final area = GeometryEngine.polygonAreaM2(rectangle);
      // 5000mm * 4000mm = 20e6 mm^2 = 20 m^2
      expect(area, closeTo(20.0, 0.01));
    });

    test('triangle area', () {
      final area = GeometryEngine.polygonAreaM2(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 6000, y: 0),
        Point2D(x: 3000, y: 4000),
      ]);
      // 0.5 * 6 * 4 = 12 m^2
      expect(area, closeTo(12.0, 0.01));
    });

    test('L-shaped polygon', () {
      final area = GeometryEngine.polygonAreaM2(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 4000, y: 0),
        Point2D(x: 4000, y: 2000),
        Point2D(x: 2000, y: 2000),
        Point2D(x: 2000, y: 4000),
        Point2D(x: 0, y: 4000),
      ]);
      // Full rect = 4*4 = 16, minus cut = 2*2 = 4, net = 12 m^2
      expect(area, closeTo(12.0, 0.01));
    });

    test('fewer than 3 vertices returns NaN', () {
      final area = GeometryEngine.polygonAreaM2(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 1000, y: 0),
      ]);
      expect(area.isNaN, isTrue);
    });

    test('degenerate polygon (collinear) has zero area', () {
      final area = GeometryEngine.polygonAreaM2(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 1000, y: 0),
        Point2D(x: 2000, y: 0),
      ]);
      expect(area, closeTo(0.0, 0.001));
    });
  });

  // ── polygonPerimeterM tests ──────────────────────────────────────────

  group('GeometryEngine.polygonPerimeterM', () {
    test('rectangle perimeter', () {
      final p = GeometryEngine.polygonPerimeterM(rectangle);
      // 2*(5+4) = 18 m
      expect(p, closeTo(18.0, 0.001));
    });

    test('fewer than 2 vertices returns NaN', () {
      final p = GeometryEngine.polygonPerimeterM(const [
        Point2D(x: 0, y: 0),
      ]);
      expect(p.isNaN, isTrue);
    });
  });

  // ── isPointInPolygon tests ───────────────────────────────────────────

  group('GeometryEngine.isPointInPolygon', () {
    test('GE-2: point inside rectangle', () {
      expect(
        GeometryEngine.isPointInPolygon(
          const Point2D(x: 2500, y: 2000),
          rectangle,
        ),
        isTrue,
      );
    });

    test('GE-2: point outside rectangle', () {
      expect(
        GeometryEngine.isPointInPolygon(
          const Point2D(x: 6000, y: 2000),
          rectangle,
        ),
        isFalse,
      );
    });

    test('GE-2: point on edge treated as inside', () {
      // The ray-casting algorithm may or may not include boundary points.
      // Spec says "on edge → treated as inside".
      // This is implementation-dependent; we test the spec expectation.
      final result = GeometryEngine.isPointInPolygon(
        const Point2D(x: 5000, y: 2000),
        rectangle,
      );
      // Note: strict ray-casting may return false for boundary.
      // If this fails, the engine needs a boundary check.
      expect(result, isTrue);
    });

    test('point clearly outside on all sides', () {
      expect(
        GeometryEngine.isPointInPolygon(
          const Point2D(x: -100, y: -100),
          rectangle,
        ),
        isFalse,
      );
    });

    test('fewer than 3 vertices returns false', () {
      expect(
        GeometryEngine.isPointInPolygon(
          const Point2D(x: 0, y: 0),
          const [Point2D(x: 0, y: 0), Point2D(x: 1000, y: 0)],
        ),
        isFalse,
      );
    });
  });

  // ── isPolygonContained tests ─────────────────────────────────────────

  group('GeometryEngine.isPolygonContained', () {
    test('inner polygon fully inside outer', () {
      const inner = [
        Point2D(x: 1000, y: 1000),
        Point2D(x: 4000, y: 1000),
        Point2D(x: 4000, y: 3000),
        Point2D(x: 1000, y: 3000),
      ];
      expect(
        GeometryEngine.isPolygonContained(inner, rectangle),
        isTrue,
      );
    });

    test('inner polygon partially outside', () {
      const inner = [
        Point2D(x: 3000, y: 1000),
        Point2D(x: 7000, y: 1000),
        Point2D(x: 7000, y: 3000),
        Point2D(x: 3000, y: 3000),
      ];
      expect(
        GeometryEngine.isPolygonContained(inner, rectangle),
        isFalse,
      );
    });

    test('inner polygon completely outside', () {
      const inner = [
        Point2D(x: 6000, y: 6000),
        Point2D(x: 8000, y: 6000),
        Point2D(x: 8000, y: 8000),
        Point2D(x: 6000, y: 8000),
      ];
      expect(
        GeometryEngine.isPolygonContained(inner, rectangle),
        isFalse,
      );
    });
  });

  // ── isSimplePolygon tests ────────────────────────────────────────────

  group('GeometryEngine.isSimplePolygon', () {
    test('simple rectangle is simple', () {
      expect(GeometryEngine.isSimplePolygon(rectangle), isTrue);
    });

    test('figure-8 (self-intersecting) is not simple', () {
      const figure8 = [
        Point2D(x: 0, y: 0),
        Point2D(x: 2000, y: 2000),
        Point2D(x: 2000, y: 0),
        Point2D(x: 0, y: 2000),
      ];
      expect(GeometryEngine.isSimplePolygon(figure8), isFalse);
    });

    test('fewer than 3 vertices returns false', () {
      expect(
        GeometryEngine.isSimplePolygon(const [
          Point2D(x: 0, y: 0),
          Point2D(x: 1000, y: 0),
        ]),
        isFalse,
      );
    });

    test('triangle is simple', () {
      expect(
        GeometryEngine.isSimplePolygon(const [
          Point2D(x: 0, y: 0),
          Point2D(x: 3000, y: 0),
          Point2D(x: 1500, y: 2000),
        ]),
        isTrue,
      );
    });
  });

  // ── distanceMm tests ────────────────────────────────────────────────

  group('GeometryEngine.distanceMm', () {
    test('horizontal distance', () {
      final d = GeometryEngine.distanceMm(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 5000, y: 0),
      );
      expect(d, closeTo(5000.0, 1.0));
    });

    test('diagonal distance (3-4-5 triangle)', () {
      final d = GeometryEngine.distanceMm(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 3000, y: 4000),
      );
      expect(d, closeTo(5000.0, 1.0));
    });

    test('same point = zero distance', () {
      final d = GeometryEngine.distanceMm(
        const Point2D(x: 100, y: 200),
        const Point2D(x: 100, y: 200),
      );
      expect(d, equals(0.0));
    });
  });

  // ── segmentLengthMm tests ──────────────────────────────────────────

  group('GeometryEngine.segmentLengthMm', () {
    test('delegates to distanceMm', () {
      final l = GeometryEngine.segmentLengthMm(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 3000, y: 4000),
      );
      expect(l, closeTo(5000.0, 1.0));
    });
  });

  // ── segmentAngleDegrees tests ────────────────────────────────────────

  group('GeometryEngine.segmentAngleDegrees', () {
    test('east direction = 0 degrees', () {
      final a = GeometryEngine.segmentAngleDegrees(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 1000, y: 0),
      );
      expect(a, closeTo(0.0, 0.1));
    });

    test('north direction = 90 degrees', () {
      final a = GeometryEngine.segmentAngleDegrees(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 0, y: 1000),
      );
      expect(a, closeTo(90.0, 0.1));
    });

    test('west direction = 180 or -180 degrees', () {
      final a = GeometryEngine.segmentAngleDegrees(
        const Point2D(x: 1000, y: 0),
        const Point2D(x: 0, y: 0),
      );
      expect(a.abs(), closeTo(180.0, 0.1));
    });

    test('south direction = -90 degrees', () {
      final a = GeometryEngine.segmentAngleDegrees(
        const Point2D(x: 0, y: 1000),
        const Point2D(x: 0, y: 0),
      );
      expect(a, closeTo(-90.0, 0.1));
    });

    test('45 degree diagonal', () {
      final a = GeometryEngine.segmentAngleDegrees(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 1000, y: 1000),
      );
      expect(a, closeTo(45.0, 0.1));
    });
  });

  // ── polylineLengthMm tests ──────────────────────────────────────────

  group('GeometryEngine.polylineLengthMm', () {
    test('straight line', () {
      final l = GeometryEngine.polylineLengthMm(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 5000, y: 0),
      ]);
      expect(l, closeTo(5000.0, 1.0));
    });

    test('L-shaped path', () {
      final l = GeometryEngine.polylineLengthMm(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 3000, y: 0),
        Point2D(x: 3000, y: 4000),
      ]);
      // 3000 + 4000 = 7000 mm
      expect(l, closeTo(7000.0, 1.0));
    });

    test('single point returns NaN', () {
      final l = GeometryEngine.polylineLengthMm(const [
        Point2D(x: 0, y: 0),
      ]);
      expect(l.isNaN, isTrue);
    });

    test('empty list returns NaN', () {
      final l = GeometryEngine.polylineLengthMm(const []);
      expect(l.isNaN, isTrue);
    });
  });

  // ── segmentsIntersect tests ──────────────────────────────────────────

  group('GeometryEngine.segmentsIntersect', () {
    test('crossing segments: true', () {
      final result = GeometryEngine.segmentsIntersect(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 2000, y: 2000),
        const Point2D(x: 0, y: 2000),
        const Point2D(x: 2000, y: 0),
      );
      expect(result, isTrue);
    });

    test('parallel segments: false', () {
      final result = GeometryEngine.segmentsIntersect(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 2000, y: 0),
        const Point2D(x: 0, y: 1000),
        const Point2D(x: 2000, y: 1000),
      );
      expect(result, isFalse);
    });

    test('non-intersecting segments: false', () {
      final result = GeometryEngine.segmentsIntersect(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 1000, y: 0),
        const Point2D(x: 2000, y: 0),
        const Point2D(x: 3000, y: 0),
      );
      expect(result, isFalse);
    });

    test('T-junction (endpoint touch): implementation-dependent', () {
      // Strict intersection test: shared endpoints are not considered
      // intersections with t > 0 && t < 1 && u > 0 && u < 1.
      final result = GeometryEngine.segmentsIntersect(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 2000, y: 0),
        const Point2D(x: 1000, y: -1000),
        const Point2D(x: 1000, y: 0), // touches midpoint of first segment
      );
      // With strict (t,u) in open interval, endpoint touch = false
      expect(result, isFalse);
    });

    test('collinear overlapping segments: false (parallel)', () {
      final result = GeometryEngine.segmentsIntersect(
        const Point2D(x: 0, y: 0),
        const Point2D(x: 2000, y: 0),
        const Point2D(x: 1000, y: 0),
        const Point2D(x: 3000, y: 0),
      );
      expect(result, isFalse);
    });
  });

  // ── snapToGrid tests ────────────────────────────────────────────────

  group('GeometryEngine.snapToGrid', () {
    test('snaps to nearest grid point', () {
      final snapped = GeometryEngine.snapToGrid(
        const Point2D(x: 123, y: 478),
        100.0,
      );
      expect(snapped.x, closeTo(100.0, 0.01));
      expect(snapped.y, closeTo(500.0, 0.01));
    });

    test('already on grid stays the same', () {
      final snapped = GeometryEngine.snapToGrid(
        const Point2D(x: 500, y: 1000),
        100.0,
      );
      expect(snapped.x, closeTo(500.0, 0.01));
      expect(snapped.y, closeTo(1000.0, 0.01));
    });

    test('zero grid spacing returns original point', () {
      final snapped = GeometryEngine.snapToGrid(
        const Point2D(x: 123, y: 456),
        0.0,
      );
      expect(snapped.x, equals(123.0));
      expect(snapped.y, equals(456.0));
    });

    test('negative grid spacing returns original point', () {
      final snapped = GeometryEngine.snapToGrid(
        const Point2D(x: 123, y: 456),
        -50.0,
      );
      expect(snapped.x, equals(123.0));
      expect(snapped.y, equals(456.0));
    });
  });

  // ── snapToEndpoint tests ────────────────────────────────────────────

  group('GeometryEngine.snapToEndpoint', () {
    test('snaps to closest endpoint within threshold', () {
      final result = GeometryEngine.snapToEndpoint(
        const Point2D(x: 105, y: 95),
        const [
          Point2D(x: 100, y: 100),
          Point2D(x: 500, y: 500),
        ],
        20.0,
      );
      expect(result, isNotNull);
      expect(result!.x, equals(100.0));
      expect(result.y, equals(100.0));
    });

    test('no endpoint within threshold returns null', () {
      final result = GeometryEngine.snapToEndpoint(
        const Point2D(x: 1000, y: 1000),
        const [
          Point2D(x: 100, y: 100),
          Point2D(x: 500, y: 500),
        ],
        20.0,
      );
      expect(result, isNull);
    });

    test('empty endpoints returns null', () {
      final result = GeometryEngine.snapToEndpoint(
        const Point2D(x: 100, y: 100),
        const [],
        20.0,
      );
      expect(result, isNull);
    });

    test('exactly at threshold distance', () {
      // Distance from (0,0) to (20,0) = 20, threshold = 20 → snaps
      final result = GeometryEngine.snapToEndpoint(
        const Point2D(x: 0, y: 0),
        const [Point2D(x: 20, y: 0)],
        20.0,
      );
      expect(result, isNotNull);
      expect(result!.x, equals(20.0));
    });
  });
}
