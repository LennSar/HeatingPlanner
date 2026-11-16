// Unit tests for PipeLayoutEngine (ADR-038) and the polygon helpers it
// relies on in GeometryEngine.

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/geometry_engine.dart';
import 'package:heating_planner/calculation/engines/pipe_layout_engine.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/point2d.dart';

const _rect = [
  Point2D(x: 1000, y: 1000),
  Point2D(x: 5000, y: 1000),
  Point2D(x: 5000, y: 4000),
  Point2D(x: 1000, y: 4000),
];

// 4000 × 3000 with the top-right 2000 × 2000 removed.
const _lShape = [
  Point2D(x: 1000, y: 1000),
  Point2D(x: 3000, y: 1000),
  Point2D(x: 3000, y: 3000),
  Point2D(x: 5000, y: 3000),
  Point2D(x: 5000, y: 4000),
  Point2D(x: 1000, y: 4000),
];

/// Distinct row coordinates of the long (≥ 1 m) runs of [path]; rows run
/// along X when [alongX].
List<double> _rowCoords(List<Point2D> path, {required bool alongX}) {
  final rows = <double>[];
  for (var i = 0; i + 1 < path.length; i++) {
    final a = path[i];
    final b = path[i + 1];
    final isRow = alongX
        ? (a.y - b.y).abs() < 1e-6 && (a.x - b.x).abs() >= 1000
        : (a.x - b.x).abs() < 1e-6 && (a.y - b.y).abs() >= 1000;
    if (!isRow) continue;
    final c = alongX ? a.y : a.x;
    if (!rows.any((r) => (r - c).abs() < 1e-6)) rows.add(c);
  }
  return rows..sort();
}

void main() {
  group('PipeLayoutEngine.meanderPath', () {
    test('rectangle: starts at the entry, ends at the exit, stays inside '
        'the border and keeps the pitch at or below the spacing', () {
      const entry = Point2D(x: 1200, y: 1000);
      final path = PipeLayoutEngine.meanderPath(
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: entry,
      );

      expect(path, isNotEmpty);
      expect(path.first, entry);
      expect(path.last, entry, reason: 'exit defaults to the entry');

      for (final p in path.sublist(1, path.length - 1)) {
        expect(p.x, inInclusiveRange(1100 - 1e-6, 4900 + 1e-6));
        expect(p.y, inInclusiveRange(1100 - 1e-6, 3900 + 1e-6));
      }

      // 4000 wide × 3000 high → rows run along X.
      final rows = _rowCoords(path, alongX: true);
      expect(
        rows.length.isEven,
        isTrue,
        reason: 'an even row count returns the tube to the lane side',
      );
      expect(rows.first, closeTo(1100, 1e-6));
      expect(rows.last, closeTo(3900, 1e-6));
      for (var i = 0; i + 1 < rows.length; i++) {
        expect(rows[i + 1] - rows[i], lessThanOrEqualTo(150 + 1e-6));
        expect(rows[i + 1] - rows[i], greaterThan(120));
      }
    });

    test('the first row starts at the corner nearest the entry', () {
      const entry = Point2D(x: 4800, y: 4000); // bottom edge, right end
      final path = PipeLayoutEngine.meanderPath(
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: entry,
      );
      final start = path[1];
      expect(GeometryEngine.distanceMm(start, entry), lessThan(400));
      // Return lane ends next to the start, one spacing apart.
      final laneEnd = path[path.length - 2];
      expect(GeometryEngine.distanceMm(laneEnd, start), closeTo(150, 1e-6));
    });

    test('an entry on a short side turns the rows so the leads stay in '
        'the border strip', () {
      const entry = Point2D(x: 1000, y: 2500); // middle of the left edge
      final path = PipeLayoutEngine.meanderPath(
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: entry,
      );
      // Rows now run along Y, the first one next to the left edge.
      final rows = _rowCoords(path, alongX: false);
      expect(rows, isNotEmpty);
      expect(path[1].x, closeTo(1100, 1e-6));
    });

    test('without an entry the rows run along the longer side', () {
      final path = PipeLayoutEngine.meanderPath(
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
      );
      expect(_rowCoords(path, alongX: true), isNotEmpty);
      expect(_rowCoords(path, alongX: false), isEmpty);
    });

    test('L-shape: every vertex of the path lies inside the zone', () {
      final path = PipeLayoutEngine.meanderPath(
        polygon: _lShape,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: const Point2D(x: 1000, y: 3800),
      );
      expect(path.length, greaterThan(10));
      for (final p in path) {
        expect(
          GeometryEngine.isPointInPolygon(p, _lShape),
          isTrue,
          reason: '$p must be inside the L-shaped zone',
        );
      }
    });

    test('rows stop short of an exclusion strip', () {
      // Keep-out strip along the right edge: x ∈ [4500, 5200].
      const strip = [
        Point2D(x: 4500, y: 0),
        Point2D(x: 5200, y: 0),
        Point2D(x: 5200, y: 5000),
        Point2D(x: 4500, y: 5000),
      ];
      final path = PipeLayoutEngine.meanderPath(
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: const Point2D(x: 1000, y: 1000),
        exclusions: const [strip],
      );
      expect(path, isNotEmpty);
      for (final p in path) {
        expect(p.x, lessThanOrEqualTo(4500 + 1e-6));
      }
    });

    test('a corridor through the middle is jumped, not a reason to leave '
        'half the zone cold', () {
      // Keep-out strip across the zone: x ∈ [2850, 3150], full height.
      const strip = [
        Point2D(x: 2850, y: 0),
        Point2D(x: 3150, y: 0),
        Point2D(x: 3150, y: 5000),
        Point2D(x: 2850, y: 5000),
      ];
      final path = PipeLayoutEngine.meanderPath(
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: const Point2D(x: 1000, y: 3800),
        exclusions: const [strip],
      );
      // Rows run parallel to the corridor, on both sides of it …
      final rows = _rowCoords(path, alongX: false);
      expect(rows.first, lessThan(1200));
      expect(rows.last, greaterThan(4800));
      // … and none inside it.
      expect(rows.where((x) => x > 2850 && x < 3150), isEmpty);
    });

    test('a corridor along one edge shortens the layout instead of being '
        'jumped', () {
      // Keep-out strip along the top: y ∈ [1150, 1450], full width.
      const strip = [
        Point2D(x: 0, y: 1150),
        Point2D(x: 6000, y: 1150),
        Point2D(x: 6000, y: 1450),
        Point2D(x: 0, y: 1450),
      ];
      final path = PipeLayoutEngine.meanderPath(
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: const Point2D(x: 1000, y: 3800),
        exclusions: const [strip],
      );
      expect(path, isNotEmpty);
      for (final p in path) {
        expect(p.y, greaterThanOrEqualTo(1450 - 1e-6));
      }
    });

    test('returns an empty path for invalid input or a zone too small', () {
      expect(
        PipeLayoutEngine.meanderPath(
          polygon: const [Point2D(x: 0, y: 0), Point2D(x: 1, y: 1)],
          tubeSpacingMm: 150,
          borderDistanceMm: 100,
        ),
        isEmpty,
      );
      expect(
        PipeLayoutEngine.meanderPath(
          polygon: _rect,
          tubeSpacingMm: 0,
          borderDistanceMm: 100,
        ),
        isEmpty,
      );
      // 250 × 250 with a 100 mm border leaves 50 mm — nothing fits.
      expect(
        PipeLayoutEngine.meanderPath(
          polygon: const [
            Point2D(x: 0, y: 0),
            Point2D(x: 250, y: 0),
            Point2D(x: 250, y: 250),
            Point2D(x: 0, y: 250),
          ],
          tubeSpacingMm: 150,
          borderDistanceMm: 100,
        ),
        isEmpty,
      );
    });
  });

  group('PipeLayoutEngine zone entry / exit', () {
    const supply = [
      Point2D(x: 0, y: 0),
      Point2D(x: 0, y: 2000),
      Point2D(x: 3000, y: 2000), // ends inside the zone
    ];

    test('entry is where the supply route crosses the zone boundary', () {
      final entry = PipeLayoutEngine.zoneEntryPoint(
        polygon: _rect,
        supplyRoutePath: supply,
        distributorPosition: const Point2D(x: 9000, y: 9000),
      );
      expect(entry, const Point2D(x: 1000, y: 2000));
    });

    test('without a route the entry is the boundary point nearest the '
        'distributor', () {
      final entry = PipeLayoutEngine.zoneEntryPoint(
        polygon: _rect,
        distributorPosition: const Point2D(x: 3000, y: 0),
      );
      expect(entry, const Point2D(x: 3000, y: 1000));
    });

    test('without a route and a distributor there is no entry', () {
      expect(PipeLayoutEngine.zoneEntryPoint(polygon: _rect), isNull);
    });

    test('exit is where the return route leaves the zone', () {
      final exit = PipeLayoutEngine.zoneExitPoint(
        polygon: _rect,
        returnRoutePath: const [
          Point2D(x: 3000, y: 2000),
          Point2D(x: 3000, y: 0),
          Point2D(x: 0, y: 0),
        ],
      );
      expect(exit, const Point2D(x: 3000, y: 1000));
    });

    test('routes are trimmed at the zone boundary', () {
      expect(PipeLayoutEngine.supplyRouteOutsideZone(supply, _rect), const [
        Point2D(x: 0, y: 0),
        Point2D(x: 0, y: 2000),
        Point2D(x: 1000, y: 2000),
      ]);
      expect(
        PipeLayoutEngine.returnRouteOutsideZone(const [
          Point2D(x: 3000, y: 2000),
          Point2D(x: 3000, y: 0),
          Point2D(x: 0, y: 0),
        ], _rect),
        const [
          Point2D(x: 3000, y: 1000),
          Point2D(x: 3000, y: 0),
          Point2D(x: 0, y: 0),
        ],
      );
      // A route that never touches the zone is returned unchanged.
      const outside = [Point2D(x: 0, y: 0), Point2D(x: 500, y: 0)];
      expect(
        PipeLayoutEngine.supplyRouteOutsideZone(outside, _rect),
        same(outside),
      );
    });
  });

  group('PipeLayoutEngine transit corridors', () {
    // Straight transit line across the full width of the 4 m × 3 m zone.
    const through = [Point2D(x: 0, y: 2500), Point2D(x: 6000, y: 2500)];

    test('a line through the zone removes a strip one spacing wide', () {
      final corridors = PipeLayoutEngine.transitCorridors(
        routes: const [through],
        halfWidthMm: 75,
        polygon: _rect,
      );
      expect(corridors, hasLength(1));
      final area = PipeLayoutEngine.effectiveAreaM2(
        polygon: _rect,
        exclusions: corridors,
      );
      // 12 m² − 4 m × 0.15 m = 11.4 m².
      expect(area, closeTo(11.4, 0.02));
    });

    test('overlapping corridors are counted once', () {
      final corridors = PipeLayoutEngine.transitCorridors(
        routes: const [through, through],
        halfWidthMm: 75,
        polygon: _rect,
      );
      expect(corridors, hasLength(2));
      expect(
        PipeLayoutEngine.effectiveAreaM2(polygon: _rect, exclusions: corridors),
        closeTo(11.4, 0.02),
      );
    });

    test('a diagonal line removes its length × width', () {
      final corridors = PipeLayoutEngine.transitCorridors(
        routes: const [
          [Point2D(x: 0, y: 0), Point2D(x: 6000, y: 6000)],
        ],
        halfWidthMm: 75,
        polygon: _rect,
      );
      final area = PipeLayoutEngine.effectiveAreaM2(
        polygon: _rect,
        exclusions: corridors,
      );
      // Inside the zone from (1000,1000) to (4000,4000): 4.243 m × 0.15 m.
      expect(12.0 - area, closeTo(0.636, 0.02));
    });

    test('a line that misses the zone leaves the area exact', () {
      final corridors = PipeLayoutEngine.transitCorridors(
        routes: const [
          [Point2D(x: 0, y: 0), Point2D(x: 6000, y: 0)],
        ],
        halfWidthMm: 75,
        polygon: _rect,
      );
      expect(corridors, isEmpty);
      expect(
        PipeLayoutEngine.effectiveAreaM2(polygon: _rect),
        GeometryEngine.polygonAreaM2(_rect),
      );
    });

    test('invalid inputs', () {
      expect(
        PipeLayoutEngine.transitCorridors(
          routes: const [through],
          halfWidthMm: 0,
        ),
        isEmpty,
      );
      expect(
        PipeLayoutEngine.effectiveAreaM2(
          polygon: const [Point2D(x: 0, y: 0)],
        ).isNaN,
        isTrue,
      );
    });
  });

  group('PipeLayoutEngine crossing-free leads (ADR-041)', () {
    /// Every pair of non-neighbouring segments of [path] that cross or
    /// touch — the tube must have none.
    int allCrossings(List<Point2D> path) {
      var count = 0;
      for (var i = 0; i + 1 < path.length; i++) {
        for (var j = i + 2; j + 1 < path.length; j++) {
          if (i == 0 &&
              j == path.length - 2 &&
              GeometryEngine.distanceMm(path.first, path.last) < 1) {
            continue;
          }
          if (GeometryEngine.segmentsIntersect(
            path[i],
            path[i + 1],
            path[j],
            path[j + 1],
          )) {
            count++;
          }
        }
      }
      return count;
    }

    test('the case from the bug report: both pipes enter through the same '
        'edge, return above supply — the leads do not cross', () {
      // Pipes come in horizontally through the left edge of the zone,
      // return 100 mm above the supply.
      final path = PipeLayoutEngine.meanderPath(
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: const Point2D(x: 1000, y: 1500),
        exitPoint: const Point2D(x: 1000, y: 1400),
      );
      expect(path.first, const Point2D(x: 1000, y: 1500));
      expect(path.last, const Point2D(x: 1000, y: 1400));
      expect(PipeLayoutEngine.leadCrossings(path), 0);
      expect(allCrossings(path), 0);
    });

    test('swapping supply and return still gives a crossing-free tube', () {
      final path = PipeLayoutEngine.meanderPath(
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: const Point2D(x: 1000, y: 1400),
        exitPoint: const Point2D(x: 1000, y: 1500),
      );
      expect(PipeLayoutEngine.leadCrossings(path), 0);
      expect(allCrossings(path), 0);
    });

    test('every entry position on every outer edge, both orders, rectangle '
        'and L-shape: no crossing', () {
      for (final polygon in const [_rect, _lShape]) {
        final n = polygon.length;
        for (var e = 0; e < n; e++) {
          // The two inner-corner edges of the L are a known limitation
          // (ADR-041 "Not covered").
          if (identical(polygon, _lShape) && (e == 1 || e == 2)) continue;
          final a = polygon[e];
          final b = polygon[(e + 1) % n];
          final len = GeometryEngine.distanceMm(a, b);
          final ux = (b.x - a.x) / len;
          final uy = (b.y - a.y) / len;
          for (var d = 150.0; d + 250 < len; d += 250) {
            final p1 = Point2D(x: a.x + ux * d, y: a.y + uy * d);
            final p2 = Point2D(
              x: a.x + ux * (d + 100),
              y: a.y + uy * (d + 100),
            );
            for (final order in [(p1, p2), (p2, p1)]) {
              final path = PipeLayoutEngine.meanderPath(
                polygon: polygon,
                tubeSpacingMm: 150,
                borderDistanceMm: 100,
                entryPoint: order.$1,
                exitPoint: order.$2,
              );
              expect(path, isNotEmpty);
              expect(
                PipeLayoutEngine.leadCrossings(path),
                0,
                reason: 'edge $e, entry ${order.$1}, exit ${order.$2}',
              );
            }
          }
        }
      }
    });

    test('entering an L through an inner-corner edge falls back to the '
        'layout with the fewest crossings', () {
      final path = PipeLayoutEngine.meanderPath(
        polygon: _lShape,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: const Point2D(x: 3000, y: 1500),
        exitPoint: const Point2D(x: 3000, y: 1400),
      );
      expect(path, isNotEmpty);
      expect(PipeLayoutEngine.leadCrossings(path), lessThanOrEqualTo(1));
    });

    test('leadCrossings counts a lead that crosses the tube, and one that '
        'only touches a corner of it', () {
      const crossing = [
        Point2D(x: 0, y: 0), // lead …
        Point2D(x: 1000, y: 1000), // … across the next-but-one segment
        Point2D(x: 1000, y: 0),
        Point2D(x: 0, y: 1000),
        Point2D(x: 0, y: 2000),
      ];
      expect(PipeLayoutEngine.leadCrossings(crossing), greaterThan(0));
      const touching = [
        Point2D(x: 0, y: 500), // lead runs through the corner (500, 500)
        Point2D(x: 1000, y: 500),
        Point2D(x: 1000, y: 1000),
        Point2D(x: 500, y: 1000),
        Point2D(x: 500, y: 500),
        Point2D(x: 500, y: 0),
      ];
      expect(PipeLayoutEngine.leadCrossings(touching), greaterThan(0));
      const clean = [
        Point2D(x: 0, y: 0),
        Point2D(x: 1000, y: 0),
        Point2D(x: 1000, y: 1000),
        Point2D(x: 0, y: 1000),
      ];
      expect(PipeLayoutEngine.leadCrossings(clean), 0);
    });

    test('connectionPipePair with supplyOnRight swaps the sides', () {
      const route = [Point2D(x: 0, y: 0), Point2D(x: 1000, y: 0)];
      final normal = PipeLayoutEngine.connectionPipePair(
        centerline: route,
        pipeSpacingMm: 100,
      );
      final swapped = PipeLayoutEngine.connectionPipePair(
        centerline: route,
        pipeSpacingMm: 100,
        supplyOnRight: true,
      );
      expect(normal.supply.last, const Point2D(x: 1000, y: 50));
      expect(swapped.supply.last, const Point2D(x: 1000, y: -50));
      expect(swapped.supply, normal.back.reversed.toList());
      expect(swapped.back, normal.supply.reversed.toList());
    });
  });

  group('PipeLayoutEngine.tubePath layout patterns (ADR-042)', () {
    const entry = Point2D(x: 1000, y: 1500);
    const exit = Point2D(x: 1000, y: 1400);

    List<Point2D> path(
      LayoutPattern pattern, [
      List<Point2D> polygon = _rect,
    ]) => PipeLayoutEngine.tubePath(
      pattern: pattern,
      polygon: polygon,
      tubeSpacingMm: 150,
      borderDistanceMm: 100,
      entryPoint: entry,
      exitPoint: exit,
    );

    /// Proper crossings between any two non-neighbouring segments.
    int selfCrossings(List<Point2D> p) {
      var count = 0;
      for (var i = 0; i + 1 < p.length; i++) {
        for (var j = i + 2; j + 1 < p.length; j++) {
          if (GeometryEngine.segmentsIntersect(
            p[i],
            p[i + 1],
            p[j],
            p[j + 1],
          )) {
            count++;
          }
        }
      }
      return count;
    }

    for (final pattern in LayoutPattern.values) {
      test('${pattern.name}: one continuous tube from the supply to the '
          'return that stays in the zone, never crosses itself and covers '
          'the zone', () {
        final p = path(pattern);
        expect(p.length, greaterThan(10));
        expect(p.first, entry);
        expect(p.last, exit);
        for (final q in p) {
          expect(
            GeometryEngine.isPointInPolygon(q, _rect),
            isTrue,
            reason: '$q must be inside the zone',
          );
        }
        expect(PipeLayoutEngine.leadCrossings(p), 0);
        expect(selfCrossings(p), 0);
        // Tube length × spacing ≈ zone area (12 m²), less the border.
        final coveredM2 = GeometryEngine.polylineLengthMm(p) * 150 / 1e6;
        expect(coveredM2, inInclusiveRange(9.0, 12.6));
      });
    }

    test('the four patterns are four different tubes', () {
      // Without an entry: the bare tubes, each in its own direction.
      final paths = [
        // The edge zone needs an exterior wall to differ from the meander
        // (tested in its own group).
        for (final p in LayoutPattern.values)
          if (p != LayoutPattern.edgeZoneMeander)
            PipeLayoutEngine.tubePath(
              pattern: p,
              polygon: _rect,
              tubeSpacingMm: 150,
              borderDistanceMm: 100,
            ),
      ];
      for (var i = 0; i < paths.length; i++) {
        for (var j = i + 1; j < paths.length; j++) {
          expect(paths[i], isNot(paths[j]));
        }
      }
    });

    test(
      'counterflow is a spiral, not a serpentine: the supply coils in '
      'along all four sides, the return coils back out between its turns',
      () {
        final body = PipeLayoutEngine.tubePath(
          pattern: LayoutPattern.counterflow,
          polygon: _rect,
          tubeSpacingMm: 150,
          borderDistanceMm: 100,
        );
        // First turn runs all the way round the zone.
        final firstTurn = body.take(5).toList();
        expect(firstTurn.map((p) => p.x).reduce((a, b) => a < b ? a : b), 1100);
        expect(firstTurn.map((p) => p.x).reduce((a, b) => a > b ? a : b), 4900);
        expect(firstTurn.map((p) => p.y).reduce((a, b) => a < b ? a : b), 1100);
        expect(firstTurn.map((p) => p.y).reduce((a, b) => a > b ? a : b), 3900);
        // Both ends lie side by side on the outer rings.
        expect(
          GeometryEngine.distanceMm(body.first, body.last),
          closeTo(150, 1e-6),
        );
        // The U-turn in the middle of the tube is near the zone centre.
        final mid = body[body.length ~/ 2];
        expect((mid.x - 3000).abs(), lessThan(1600));
        expect((mid.y - 2500).abs(), lessThan(600));
        // A serpentine has no turn that changes direction by 90° four times
        // in a row in the same sense; a spiral does.
        var sameSenseRun = 0;
        var best = 0;
        double? lastSign;
        for (var k = 1; k + 1 < body.length ~/ 2; k++) {
          final a = body[k - 1];
          final b = body[k];
          final c = body[k + 1];
          final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
          if (cross.abs() < 1e-6) continue;
          final sign = cross.sign;
          sameSenseRun = sign == lastSign ? sameSenseRun + 1 : 1;
          lastSign = sign;
          if (sameSenseRun > best) best = sameSenseRun;
        }
        expect(best, greaterThanOrEqualTo(4));
      },
    );

    test('counterflow is no longer the meander run backwards', () {
      List<Point2D> body(LayoutPattern pattern) => PipeLayoutEngine.tubePath(
        pattern: pattern,
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
      );
      expect(
        body(LayoutPattern.counterflow),
        isNot(body(LayoutPattern.meander).reversed.toList()),
      );
    });

    test('double meander: the tube starts and ends side by side, one pitch '
        'apart, and supply and return rows alternate', () {
      final body = PipeLayoutEngine.tubePath(
        pattern: LayoutPattern.doubleMeander,
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
      );
      final gap = GeometryEngine.distanceMm(body.first, body.last);
      expect(gap, inInclusiveRange(120, 150 + 1e-6));
      expect((body[1].y - body.first.y).abs(), lessThan(1e-6));
      expect((body.last.y - body[body.length - 2].y).abs(), lessThan(1e-6));
      expect((body.first.y - body.last.y).abs(), closeTo(gap, 1e-6));
    });

    test('counterflow in an L-shaped zone, where rings would leave most of '
        'it empty, uses the double meander instead', () {
      expect(
        path(LayoutPattern.counterflow, _lShape),
        path(LayoutPattern.doubleMeander, _lShape),
      );
    });

    group('edge zone', () {
      // Exterior wall along the right edge of the zone (x = 5000).
      const exterior = (
        start: Point2D(x: 5000, y: 1000),
        end: Point2D(x: 5000, y: 4000),
      );

      List<Point2D> edgePath({
        Point2D? entry,
        Point2D? exit,
        List<({Point2D start, Point2D end})> edges = const [exterior],
      }) => PipeLayoutEngine.tubePath(
        pattern: LayoutPattern.edgeZoneMeander,
        polygon: _rect,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
        entryPoint: entry,
        exitPoint: exit,
        exteriorEdges: edges,
      );

      /// Distinct x of the vertical rows (≥ 1 m long) of [p], sorted.
      List<double> columns(List<Point2D> p) {
        final xs = <double>{};
        for (var i = 0; i + 1 < p.length; i++) {
          if ((p[i].x - p[i + 1].x).abs() < 1e-6 &&
              (p[i].y - p[i + 1].y).abs() >= 1000) {
            xs.add(double.parse(p[i].x.toStringAsFixed(3)));
          }
        }
        return xs.toList()..sort();
      }

      test('rows run parallel to the exterior wall, at half the spacing '
          'within 1 m of it and at most the spacing elsewhere', () {
        final cols = columns(edgePath());
        expect(cols.last, closeTo(4900, 1e-6), reason: 'first row at wall');
        final gaps = [
          for (var i = 0; i + 1 < cols.length; i++) cols[i + 1] - cols[i],
        ];
        for (var i = 0; i < cols.length - 1; i++) {
          // Both rows of the gap within the edge zone.
          final distFromWall = 4900 - cols[i];
          if (distFromWall < 1000 - 1e-6) {
            expect(
              gaps[i],
              closeTo(75, 1e-6),
              reason: 'edge zone at ${cols[i + 1]}',
            );
          } else {
            expect(gaps[i], lessThanOrEqualTo(150 + 1e-6));
            expect(gaps[i], greaterThan(100));
          }
        }
        expect(cols.length.isEven, isTrue);
      });

      test('the supply reaches the edge zone first', () {
        for (final (entry, exit) in [
          (const Point2D(x: 5000, y: 3000), const Point2D(x: 5000, y: 2900)),
          (const Point2D(x: 1000, y: 1500), const Point2D(x: 1000, y: 1400)),
        ]) {
          final p = edgePath(entry: entry, exit: exit);
          expect(p.first, entry);
          expect(p.last, exit);
          expect(PipeLayoutEngine.leadCrossings(p), 0);
          // First vertical run of the tube is the row next to the wall.
          for (var i = 0; i + 1 < p.length; i++) {
            if ((p[i].x - p[i + 1].x).abs() < 1e-6 &&
                (p[i].y - p[i + 1].y).abs() >= 1000) {
              expect(
                p[i].x,
                closeTo(4900, 1e-6),
                reason: 'entry $entry: supply must start at the wall',
              );
              break;
            }
          }
        }
      });

      test('the edge zone holds more tube than the same strip elsewhere', () {
        final p = edgePath();
        double tubeIn(double x0, double x1) {
          var sum = 0.0;
          for (var i = 0; i + 1 < p.length; i++) {
            final mx = (p[i].x + p[i + 1].x) / 2;
            if (mx >= x0 && mx <= x1) {
              sum += GeometryEngine.distanceMm(p[i], p[i + 1]);
            }
          }
          return sum;
        }

        expect(tubeIn(3900, 5000), greaterThan(1.6 * tubeIn(2000, 3100)));
      });

      test('without an exterior wall it is a plain serpentine', () {
        expect(
          edgePath(edges: const []),
          PipeLayoutEngine.tubePath(
            pattern: LayoutPattern.meander,
            polygon: _rect,
            tubeSpacingMm: 150,
            borderDistanceMm: 100,
          ),
        );
      });

      test('edgeZoneSpacingMm is half the spacing, at least 50 mm', () {
        expect(PipeLayoutEngine.edgeZoneSpacingMm(200), 100);
        expect(PipeLayoutEngine.edgeZoneSpacingMm(150), 75);
        expect(PipeLayoutEngine.edgeZoneSpacingMm(80), 50);
      });
    });

    test('LayoutPattern.fromName maps names from before ADR-043', () {
      expect(LayoutPattern.fromName('spiral'), LayoutPattern.counterflow);
      expect(LayoutPattern.fromName('counterflow'), LayoutPattern.counterflow);
      expect(LayoutPattern.fromName('bifilar'), LayoutPattern.doubleMeander);
      expect(LayoutPattern.fromName('meander'), LayoutPattern.meander);
      expect(
        LayoutPattern.fromName('edgeZoneMeander'),
        LayoutPattern.edgeZoneMeander,
      );
      expect(LayoutPattern.fromName('nonsense'), LayoutPattern.meander);
      expect(LayoutPattern.fromName(null), LayoutPattern.meander);
    });

    test('L-shape: no turn runs outside the zone in any pattern', () {
      for (final pattern in LayoutPattern.values) {
        final p = PipeLayoutEngine.filletPolyline(
          PipeLayoutEngine.tubePath(
            pattern: pattern,
            polygon: _lShape,
            tubeSpacingMm: 150,
            borderDistanceMm: 100,
            entryPoint: const Point2D(x: 1000, y: 3800),
            exitPoint: const Point2D(x: 1000, y: 3700),
          ),
          80,
        );
        expect(p, isNotEmpty);
        for (var i = 0; i + 1 < p.length; i++) {
          final mid = Point2D(
            x: (p[i].x + p[i + 1].x) / 2,
            y: (p[i].y + p[i + 1].y) / 2,
          );
          expect(
            GeometryEngine.isPointInPolygon(mid, _lShape),
            isTrue,
            reason: '${pattern.name}: segment $i leaves the zone',
          );
        }
      }
    });

    test('a zone too small for the pattern falls back, and one too small '
        'for any tube stays empty', () {
      const small = [
        Point2D(x: 0, y: 0),
        Point2D(x: 800, y: 0),
        Point2D(x: 800, y: 700),
        Point2D(x: 0, y: 700),
      ];
      final spiral = PipeLayoutEngine.tubePath(
        pattern: LayoutPattern.counterflow,
        polygon: small,
        tubeSpacingMm: 150,
        borderDistanceMm: 100,
      );
      expect(spiral, isNotEmpty);
      const tiny = [
        Point2D(x: 0, y: 0),
        Point2D(x: 250, y: 0),
        Point2D(x: 250, y: 250),
        Point2D(x: 0, y: 250),
      ];
      for (final pattern in LayoutPattern.values) {
        expect(
          PipeLayoutEngine.tubePath(
            pattern: pattern,
            polygon: tiny,
            tubeSpacingMm: 150,
            borderDistanceMm: 100,
          ),
          isEmpty,
        );
      }
    });
  });

  group('GeometryEngine.distinctColorIndices (ADR-042)', () {
    List<Point2D> box(double x, double y, [double w = 1000, double h = 1000]) =>
        [
          Point2D(x: x, y: y),
          Point2D(x: x + w, y: y),
          Point2D(x: x + w, y: y + h),
          Point2D(x: x, y: y + h),
        ];

    test('while the palette lasts every zone gets its own colour', () {
      final indices = GeometryEngine.distinctColorIndices([
        box(0, 0),
        box(1000, 0),
        box(0, 1000),
        box(1000, 1000),
        box(9000, 9000),
      ], paletteSize: 10);
      expect(indices.toSet(), hasLength(5));
    });

    test('with more zones than colours, colours repeat — but never on '
        'zones next to each other', () {
      // 12 zones in a row, 3 colours.
      final polygons = [for (var i = 0; i < 12; i++) box(i * 1000.0, 0)];
      final indices = GeometryEngine.distinctColorIndices(
        polygons,
        paletteSize: 3,
      );
      expect(indices.every((c) => c >= 0 && c < 3), isTrue);
      for (var i = 0; i + 1 < indices.length; i++) {
        expect(
          indices[i],
          isNot(indices[i + 1]),
          reason: 'zones $i and ${i + 1} share an edge',
        );
      }
    });

    test('zones on either side of a wall count as neighbours; zones '
        'far apart do not', () {
      // 300 mm apart (a wall between them) vs. 5 m apart, 2 colours.
      final near = GeometryEngine.distinctColorIndices([
        box(0, 0),
        box(1300, 0),
      ], paletteSize: 1);
      // One colour only: neighbours cannot differ, both get colour 0.
      expect(near, [0, 0]);
      final grid = GeometryEngine.distinctColorIndices([
        box(0, 0),
        box(1300, 0),
        box(2600, 0),
        box(8000, 0),
      ], paletteSize: 2);
      expect(grid[0], isNot(grid[1]));
      expect(grid[1], isNot(grid[2]));
    });

    test('a 4 × 4 grid of zones with 4 colours: no two touching zones '
        'match', () {
      final polygons = [
        for (var r = 0; r < 4; r++)
          for (var c = 0; c < 4; c++) box(c * 1000.0, r * 1000.0),
      ];
      // Edge- and corner-neighbours all lie within the adjacency limit.
      final indices = GeometryEngine.distinctColorIndices(
        polygons,
        paletteSize: 4,
      );
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          final me = indices[r * 4 + c];
          if (c + 1 < 4) expect(me, isNot(indices[r * 4 + c + 1]));
          if (r + 1 < 4) expect(me, isNot(indices[(r + 1) * 4 + c]));
        }
      }
    });

    test('adding a zone never changes the colours of the zones before it', () {
      final before = [box(0, 0), box(1000, 0), box(2000, 0)];
      final a = GeometryEngine.distinctColorIndices(before, paletteSize: 3);
      final b = GeometryEngine.distinctColorIndices([
        ...before,
        box(0, 1000),
      ], paletteSize: 3);
      expect(b.sublist(0, 3), a);
    });

    test('an empty palette yields no indices', () {
      expect(
        GeometryEngine.distinctColorIndices([box(0, 0)], paletteSize: 0),
        isEmpty,
      );
    });
  });

  group('PipeLayoutEngine bends (ADR-039)', () {
    // Right-angle corner at (1000, 0).
    const corner = [
      Point2D(x: 0, y: 0),
      Point2D(x: 1000, y: 0),
      Point2D(x: 1000, y: 1000),
    ];

    test('minimum bend radius is five outer diameters', () {
      expect(PipeLayoutEngine.minBendRadiusMm(16), 80.0);
      expect(PipeLayoutEngine.minBendRadiusMm(20), 100.0);
      expect(PipeLayoutEngine.minBendRadiusMm(0).isNaN, isTrue);
    });

    test('a corner becomes an arc of the requested radius, tangent to '
        'both segments', () {
      final rounded = PipeLayoutEngine.filletPolyline(corner, 80);
      expect(rounded.first, corner.first);
      expect(rounded.last, corner.last);
      // The sharp corner point itself is gone.
      expect(rounded.contains(const Point2D(x: 1000, y: 0)), isFalse);
      // Every arc point is 80 mm from the centre (920, 80).
      const centre = Point2D(x: 920, y: 80);
      final arc = rounded.sublist(1, rounded.length - 1);
      for (final p in arc) {
        expect(GeometryEngine.distanceMm(p, centre), closeTo(80, 1e-6));
      }
      // Tangent points: 80 mm before and after the corner.
      expect(arc.first.x, closeTo(920, 1e-6));
      expect(arc.first.y, closeTo(0, 1e-6));
      expect(arc.last.x, closeTo(1000, 1e-6));
      expect(arc.last.y, closeTo(80, 1e-6));
    });

    test('a left turn and a right turn bend to opposite sides', () {
      final right = PipeLayoutEngine.filletPolyline(corner, 80);
      final left = PipeLayoutEngine.filletPolyline(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 1000, y: 0),
        Point2D(x: 1000, y: -1000),
      ], 80);
      expect(right[2].y, greaterThan(0));
      expect(left[2].y, lessThan(0));
    });

    test('a segment too short for the radius gets a tighter bend, and '
        'tightestBendRadiusMm reports it', () {
      // Two corners only 100 mm apart: each may use 50 mm of tangent.
      const jog = [
        Point2D(x: 0, y: 0),
        Point2D(x: 1000, y: 0),
        Point2D(x: 1000, y: 100),
        Point2D(x: 2000, y: 100),
      ];
      expect(PipeLayoutEngine.tightestBendRadiusMm(jog, 80), closeTo(50, 1e-6));
      expect(PipeLayoutEngine.tightestBendRadiusMm(corner, 80), 80.0);
      final rounded = PipeLayoutEngine.filletPolyline(jog, 80);
      for (final p in rounded) {
        expect(p.y, inInclusiveRange(-1e-6, 100 + 1e-6));
      }
    });

    test('straight runs, reversals and short inputs are left alone', () {
      const straight = [
        Point2D(x: 0, y: 0),
        Point2D(x: 500, y: 0),
        Point2D(x: 1000, y: 0),
      ];
      expect(PipeLayoutEngine.filletPolyline(straight, 80), straight);
      const two = [Point2D(x: 0, y: 0), Point2D(x: 500, y: 0)];
      expect(PipeLayoutEngine.filletPolyline(two, 80), same(two));
      expect(PipeLayoutEngine.filletPolyline(corner, 0), same(corner));
    });
  });

  group('PipeLayoutEngine connection pipe pair (ADR-040)', () {
    // Route: right 1000, then down 1000.
    const route = [
      Point2D(x: 0, y: 0),
      Point2D(x: 1000, y: 0),
      Point2D(x: 1000, y: 1000),
    ];

    test('offsetPolyline keeps every section at the offset and mitres '
        'the corner', () {
      expect(PipeLayoutEngine.offsetPolyline(route, 50), const [
        Point2D(x: 0, y: 50),
        Point2D(x: 950, y: 50),
        Point2D(x: 950, y: 1000),
      ]);
      expect(PipeLayoutEngine.offsetPolyline(route, -50), const [
        Point2D(x: 0, y: -50),
        Point2D(x: 1050, y: -50),
        Point2D(x: 1050, y: 1000),
      ]);
    });

    test('offsetPolyline drops coincident points and rejects a single '
        'point', () {
      expect(
        PipeLayoutEngine.offsetPolyline(const [
          Point2D(x: 0, y: 0),
          Point2D(x: 0, y: 0),
          Point2D(x: 1000, y: 0),
        ], 50),
        const [Point2D(x: 0, y: 50), Point2D(x: 1000, y: 50)],
      );
      expect(
        PipeLayoutEngine.offsetPolyline(const [Point2D(x: 0, y: 0)], 50),
        isEmpty,
      );
    });

    test('offsetPolyline does not run away at a hairpin', () {
      final out = PipeLayoutEngine.offsetPolyline(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 1000, y: 0),
        Point2D(x: 0, y: 1),
      ], 50);
      expect(out, hasLength(3));
      expect(
        GeometryEngine.distanceMm(out[1], const Point2D(x: 1000, y: 0)),
        lessThan(51),
      );
    });

    test('connectionPipePair: both pipes start and end on the distributor '
        'and run one spacing apart', () {
      final pair = PipeLayoutEngine.connectionPipePair(
        centerline: route,
        pipeSpacingMm: 100,
      );
      expect(pair.supply, const [
        Point2D(x: 0, y: 0),
        Point2D(x: 0, y: 50),
        Point2D(x: 950, y: 50),
        Point2D(x: 950, y: 1000),
      ]);
      expect(pair.back, const [
        Point2D(x: 1050, y: 1000),
        Point2D(x: 1050, y: -50),
        Point2D(x: 0, y: -50),
        Point2D(x: 0, y: 0),
      ]);
      // Parallel sections are exactly one spacing apart.
      expect(pair.back[1].y - pair.supply[2].y, -100);
      expect(pair.back.first.x - pair.supply.last.x, 100);
    });

    test('connectionPipePair rejects a degenerate route or spacing', () {
      expect(
        PipeLayoutEngine.connectionPipePair(
          centerline: const [Point2D(x: 0, y: 0)],
          pipeSpacingMm: 100,
        ).supply,
        isEmpty,
      );
      expect(
        PipeLayoutEngine.connectionPipePair(
          centerline: route,
          pipeSpacingMm: 0,
        ).back,
        isEmpty,
      );
    });
  });

  group('PipeLayoutEngine.snapRouteToWalls (ADR-040)', () {
    // Horizontal wall along y = 0 and vertical wall along x = 5000,
    // both 200 mm thick (faces at y = 100 and x = 4900).
    const top = (
      start: Point2D(x: 0, y: 0),
      end: Point2D(x: 5000, y: 0),
      thicknessMm: 200.0,
    );
    const right = (
      start: Point2D(x: 5000, y: 0),
      end: Point2D(x: 5000, y: 5000),
      thicknessMm: 200.0,
    );

    List<Point2D> snap(
      List<Point2D> path, {
      double wallClearanceMm = 100,
      double pipeSpacingMm = 100,
    }) => PipeLayoutEngine.snapRouteToWalls(
      path: path,
      walls: const [top, right],
      wallClearanceMm: wallClearanceMm,
      pipeSpacingMm: pipeSpacingMm,
    );

    test('a section running along a wall moves to the wall distance; the '
        'outer pipe ends up exactly that far from the face', () {
      final out = snap(const [
        Point2D(x: 1000, y: 1000),
        Point2D(x: 1000, y: 300),
        Point2D(x: 4000, y: 300),
      ]);
      // face 100 + clearance 100 + half spacing 50 = 250.
      expect(out, const [
        Point2D(x: 1000, y: 1000), // on the distributor — never moves
        Point2D(x: 1000, y: 250),
        Point2D(x: 4000, y: 250),
      ]);
      final pair = PipeLayoutEngine.connectionPipePair(
        centerline: out,
        pipeSpacingMm: 100,
      );
      // The pipe nearer the wall runs at y = 200: 100 mm off the face.
      final nearest = [
        pair.supply[2].y,
        pair.back[1].y,
      ].reduce((a, b) => a < b ? a : b);
      expect(nearest, 200.0);
    });

    test('a corner between two walls takes both distances', () {
      final out = snap(const [
        Point2D(x: 1000, y: 1000),
        Point2D(x: 1000, y: 300),
        Point2D(x: 4700, y: 300),
        Point2D(x: 4700, y: 3000),
      ]);
      expect(out, const [
        Point2D(x: 1000, y: 1000),
        Point2D(x: 1000, y: 250),
        Point2D(x: 4750, y: 250),
        Point2D(x: 4750, y: 3000),
      ]);
    });

    test('a larger wall distance and a wider pair push the route further '
        'out', () {
      final out = snap(
        const [
          Point2D(x: 1000, y: 1000),
          Point2D(x: 1000, y: 300),
          Point2D(x: 4000, y: 300),
        ],
        wallClearanceMm: 200,
        pipeSpacingMm: 200,
      );
      // 100 + 200 + 100 = 400.
      expect(out[1].y, 400.0);
      expect(out[2].y, 400.0);
    });

    test('a section far from any wall is left alone', () {
      const free = [
        Point2D(x: 1000, y: 2000),
        Point2D(x: 1000, y: 900),
        Point2D(x: 4000, y: 900),
      ];
      expect(snap(free), free);
    });

    test('a section that crosses a wall is left alone', () {
      const crossing = [Point2D(x: 1000, y: 1000), Point2D(x: 1000, y: -1000)];
      expect(snap(crossing), crossing);
    });

    test('a section in line with a wall but beyond its end is left alone', () {
      const beyond = [
        Point2D(x: 7000, y: 1000),
        Point2D(x: 7000, y: 300),
        Point2D(x: 9000, y: 300),
      ];
      expect(snap(beyond), beyond);
    });

    test('applying it twice changes nothing more', () {
      final once = snap(const [
        Point2D(x: 1000, y: 1000),
        Point2D(x: 1000, y: 300),
        Point2D(x: 4700, y: 300),
        Point2D(x: 4700, y: 3000),
      ]);
      expect(snap(once), once);
    });

    test('layOutConnectionPipes combines de-duplication, wall distance and '
        'the pipe pair', () {
      final laid = PipeLayoutEngine.layOutConnectionPipes(
        centerline: const [
          Point2D(x: 1000, y: 1000),
          Point2D(x: 1000, y: 300),
          Point2D(x: 1000, y: 300),
          Point2D(x: 4000, y: 300),
        ],
        pipeSpacingMm: 100,
        wallClearanceMm: 100,
        walls: const [top, right],
      );
      expect(laid.centerline, const [
        Point2D(x: 1000, y: 1000),
        Point2D(x: 1000, y: 250),
        Point2D(x: 4000, y: 250),
      ]);
      expect(laid.supply.first, laid.centerline.first);
      expect(laid.back.last, laid.centerline.first);
      expect(laid.supply, hasLength(4));
      expect(laid.back, hasLength(4));

      final none = PipeLayoutEngine.layOutConnectionPipes(
        centerline: const [Point2D(x: 0, y: 0)],
        pipeSpacingMm: 100,
        wallClearanceMm: 100,
      );
      expect(none.centerline, isEmpty);
      expect(none.supply, isEmpty);
    });
  });

  group('GeometryEngine polygon helpers', () {
    test('clipPolygonToHalfPlane keeps the requested side', () {
      final left = GeometryEngine.clipPolygonToHalfPlane(
        polygon: _rect,
        alongX: true,
        at: 2000,
        keepLower: true,
      );
      expect(GeometryEngine.polygonAreaM2(left), closeTo(3.0, 1e-9));
      final bottom = GeometryEngine.clipPolygonToHalfPlane(
        polygon: _rect,
        alongX: false,
        at: 3000,
        keepLower: false,
      );
      expect(GeometryEngine.polygonAreaM2(bottom), closeTo(4.0, 1e-9));
      expect(
        GeometryEngine.clipPolygonToHalfPlane(
          polygon: _rect,
          alongX: true,
          at: 500,
          keepLower: true,
        ),
        isEmpty,
      );
    });

    test('removeCollinearVertices drops straight-through vertices only', () {
      const withExtra = [
        Point2D(x: 0, y: 0),
        Point2D(x: 500, y: 0),
        Point2D(x: 1000, y: 0),
        Point2D(x: 1000, y: 1000),
        Point2D(x: 0, y: 1000),
      ];
      expect(GeometryEngine.removeCollinearVertices(withExtra), const [
        Point2D(x: 0, y: 0),
        Point2D(x: 1000, y: 0),
        Point2D(x: 1000, y: 1000),
        Point2D(x: 0, y: 1000),
      ]);
      expect(GeometryEngine.removeCollinearVertices(_lShape), _lShape);
    });
  });
}
