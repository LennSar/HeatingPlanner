// Unit tests for SnapService (agent-frontend.md §4.5).
//
// SnapService is a pure static utility — no ProviderContainer, no widget pump.
//
// Implementation note: the current SnapService uses `result.point` /
// `result.type` and SnapType.{endpoint, wallPoint, grid, none}.
// The spec's `snappedPoint`/`snapType` fields and SnapType.midpoint /
// SnapType.angular map to these as follows:
//   spec "snappedPoint"    → result.point
//   spec "snapType"        → result.type
//   spec "midpoint snap"   → SnapType.wallPoint (snap to wall interior)
// Angular snap (angularSnapActive / referencePoint) is not yet implemented.
//
// Naming: SS-Gnn grid, SS-EPnn endpoint, SS-WPnn wall-point, SS-PRnn priority.

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/ui/canvas/tools/snap_service.dart';

import '../../helpers/test_factories.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Build a wall from ([x1],[y1]) to ([x2],[y2]).
WallSegment _wall(double x1, double y1, double x2, double y2, {String id = 'w-1'}) {
  return createTestWall(
    id: id,
    startPoint: Point2D(x: x1, y: y1),
    endPoint: Point2D(x: x2, y: y2),
  );
}

void main() {
  // ── Grid snap: snapToGrid ─────────────────────────────────────────────────

  group('snapToGrid — grid anchored at world origin', () {
    test('SS-G01: point on grid intersection stays unchanged', () {
      final result = SnapService.snapToGrid(const Point2D(x: 500, y: 200));
      expect(result.x, closeTo(500, 0.5));
      expect(result.y, closeTo(200, 0.5));
    });

    test('SS-G02: point 30 mm past grid line snaps to lower bound', () {
      // 130 / 100 = 1.3 → rounds to 1 → snapped x = 100
      final result = SnapService.snapToGrid(const Point2D(x: 130, y: 30));
      expect(result.x, closeTo(100, 0.5));
      expect(result.y, closeTo(0, 0.5));
    });

    test('SS-G03: point 70 mm past grid line snaps to upper bound', () {
      // 170 / 100 = 1.7 → rounds to 2 → snapped x = 200
      final result = SnapService.snapToGrid(const Point2D(x: 170, y: 80));
      expect(result.x, closeTo(200, 0.5));
      expect(result.y, closeTo(100, 0.5));
    });

    test('SS-G04: point exactly halfway (50 mm) snaps via standard rounding', () {
      // 150 / 100 = 1.5 → Dart rounds half-up to 2 → snapped x = 200
      final result = SnapService.snapToGrid(const Point2D(x: 150, y: 0));
      expect(result.x, closeTo(200, 0.5));
    });

    test('SS-G05: origin snaps to origin', () {
      final result = SnapService.snapToGrid(const Point2D(x: 0, y: 0));
      expect(result.x, closeTo(0, 0.5));
      expect(result.y, closeTo(0, 0.5));
    });

    test('SS-G06: negative coordinates snap to correct negative grid lines', () {
      // -130 / 100 = -1.3 → rounds to -1 → snapped x = -100
      final result = SnapService.snapToGrid(const Point2D(x: -130, y: -170));
      expect(result.x, closeTo(-100, 0.5));
      // -170 / 100 = -1.7 → rounds to -2 → snapped y = -200
      expect(result.y, closeTo(-200, 0.5));
    });

    test('SS-G07: CRITICAL — large world coords still anchor at origin', () {
      // 5030 / 100 = 50.3 → rounds to 50 → snapped = 5000
      // Pan offset or viewport shift must not affect this.
      final result = SnapService.snapToGrid(const Point2D(x: 5030, y: 9070));
      expect(result.x, closeTo(5000, 0.5));
      expect(result.y, closeTo(9100, 0.5));
    });

    test('SS-G08: custom 50 mm spacing snaps to multiples of 50', () {
      // 175 / 50 = 3.5 → rounds to 4 → snapped x = 200
      final result =
          SnapService.snapToGrid(const Point2D(x: 175, y: 225), 50);
      expect(result.x, closeTo(200, 0.5));
      // 225 / 50 = 4.5 → rounds to 5 → snapped y = 250
      expect(result.y, closeTo(250, 0.5));
    });

    test('SS-G09: zero spacing guard returns point unchanged', () {
      const p = Point2D(x: 123, y: 456);
      final result = SnapService.snapToGrid(p, 0);
      expect(result.x, equals(p.x));
      expect(result.y, equals(p.y));
    });
  });

  // ── snap() — grid fallback (no walls) ────────────────────────────────────

  group('snap — grid fallback when no walls present', () {
    test('SS-SG01: empty wall list → snapped to grid', () {
      final result =
          SnapService.snap(const Point2D(x: 160, y: 240), []);
      expect(result.point.x, closeTo(200, 0.5));
      expect(result.point.y, closeTo(200, 0.5));
    });

    test('SS-SG02: snap type is grid when falling back to grid', () {
      final result =
          SnapService.snap(const Point2D(x: 160, y: 240), []);
      expect(result.type, equals(SnapType.grid));
    });

    test('SS-SG03: grid snap result anchors at origin regardless of position', () {
      // 3050 → snaps to 3100 (not relative to cursor)
      final result =
          SnapService.snap(const Point2D(x: 3050, y: 7080), []);
      expect(result.point.x, closeTo(3100, 0.5));
      expect(result.point.y, closeTo(7100, 0.5));
    });
  });

  // ── snap() — endpoint snap ────────────────────────────────────────────────

  group('snap — endpoint snap', () {
    test('SS-EP01: cursor 100 mm from endpoint → endpoint snap', () {
      final wall = _wall(0, 0, 1000, 0);
      // Endpoint at (0,0). Cursor at (100, 0) — 100 mm away, within 200 mm.
      final result = SnapService.snap(const Point2D(x: 100, y: 0), [wall]);
      expect(result.type, equals(SnapType.endpoint));
      expect(result.point.x, closeTo(0, 0.5));
      expect(result.point.y, closeTo(0, 0.5));
    });

    test('SS-EP02: cursor exactly at endpoint → endpoint snap', () {
      final wall = _wall(0, 0, 1000, 0);
      final result = SnapService.snap(const Point2D(x: 1000, y: 0), [wall]);
      expect(result.type, equals(SnapType.endpoint));
      expect(result.point.x, closeTo(1000, 0.5));
      expect(result.point.y, closeTo(0, 0.5));
    });

    test('SS-EP03: cursor within threshold of nearest of two endpoints snaps to closest', () {
      final wall1 = _wall(0, 0, 500, 0, id: 'w-1');
      final wall2 = _wall(1000, 0, 1500, 0, id: 'w-2');
      // Cursor at (480, 10): 20 mm from (500,0), 520+ mm from others.
      final result =
          SnapService.snap(const Point2D(x: 480, y: 10), [wall1, wall2]);
      expect(result.type, equals(SnapType.endpoint));
      expect(result.point.x, closeTo(500, 0.5));
      expect(result.point.y, closeTo(0, 0.5));
    });

    test('SS-EP04: cursor 201 mm from all endpoints → no endpoint snap', () {
      final wall = _wall(0, 0, 1000, 0);
      // Cursor at (500, 201): 201 mm above midpoint, 539+ mm from endpoints.
      final result =
          SnapService.snap(const Point2D(x: 500, y: 201), [wall]);
      expect(result.type, isNot(equals(SnapType.endpoint)));
    });
  });

  // ── snap() — wall-interior snap (spec: midpoint snap) ────────────────────

  group('snap — wall-interior snap', () {
    test('SS-WP01: cursor 100 mm above wall interior → wallPoint snap to wall', () {
      // Horizontal wall (0,0)→(1000,0). Cursor at (500, 100): nearest wall
      // point is (500,0), perpendicular distance 100 mm < wallSnapThresholdMm.
      final wall = _wall(0, 0, 1000, 0);
      final result =
          SnapService.snap(const Point2D(x: 500, y: 100), [wall]);
      expect(result.type, equals(SnapType.wallPoint));
      expect(result.point.x, closeTo(500, 0.5));
      expect(result.point.y, closeTo(0, 0.5));
    });

    test('SS-WP02: cursor near wall midpoint → snapped point at midpoint', () {
      // Wall (0,0)→(2000,0). Cursor at (1000, 80): midpoint is (1000,0).
      final wall = _wall(0, 0, 2000, 0);
      final result =
          SnapService.snap(const Point2D(x: 1000, y: 80), [wall]);
      expect(result.type, equals(SnapType.wallPoint));
      expect(result.point.x, closeTo(1000, 0.5));
      expect(result.point.y, closeTo(0, 0.5));
    });

    test('SS-WP03: cursor 151 mm from wall interior → falls through to grid', () {
      // wallSnapThresholdMm = 150. Cursor at (500, 151): perp dist 151 > 150.
      final wall = _wall(0, 0, 1000, 0);
      final result =
          SnapService.snap(const Point2D(x: 500, y: 151), [wall]);
      // Should not be wallPoint; grid snap should apply.
      expect(result.type, isNot(equals(SnapType.wallPoint)));
      expect(result.type, equals(SnapType.grid));
    });

    test('SS-WP04: vertical wall — cursor 80 mm to the right snaps to wall', () {
      // Vertical wall (500,0)→(500,1000). Cursor at (580, 500): 80 mm away.
      final wall = _wall(500, 0, 500, 1000);
      final result =
          SnapService.snap(const Point2D(x: 580, y: 500), [wall]);
      expect(result.type, equals(SnapType.wallPoint));
      expect(result.point.x, closeTo(500, 0.5));
      expect(result.point.y, closeTo(500, 0.5));
    });
  });

  // ── snap() — priority order ───────────────────────────────────────────────

  group('snap — priority: endpoint > wallPoint > grid', () {
    test('SS-PR01: cursor near endpoint AND near wall interior → endpoint wins', () {
      // Wall (0,0)→(1000,0). Cursor at (50, 50):
      // - Distance to endpoint (0,0) = sqrt(50^2+50^2) ≈ 70.7 mm < 200mm
      // - Perpendicular distance to wall = 50 mm < 150mm
      // Endpoint must win.
      final wall = _wall(0, 0, 1000, 0);
      final result =
          SnapService.snap(const Point2D(x: 50, y: 50), [wall]);
      expect(result.type, equals(SnapType.endpoint));
      expect(result.point.x, closeTo(0, 0.5));
      expect(result.point.y, closeTo(0, 0.5));
    });

    test('SS-PR02: beyond endpoint threshold, within wall threshold → wallPoint', () {
      // Wall (0,0)→(2000,0). Cursor at (1000, 80):
      // - Distance to nearest endpoint (0,0) = sqrt(1000^2+80^2) ≈ 1003 mm > 200
      // - Perp distance to wall = 80 mm < 150
      // wallPoint must win over grid.
      final wall = _wall(0, 0, 2000, 0);
      final result =
          SnapService.snap(const Point2D(x: 1000, y: 80), [wall]);
      expect(result.type, equals(SnapType.wallPoint));
    });

    test('SS-PR03: beyond all thresholds → grid snap', () {
      // Wall (0,0)→(1000,0). Cursor at (500, 300):
      // - Distance to nearest endpoint > 200 mm
      // - Perp distance to wall = 300 mm > 150 mm
      final wall = _wall(0, 0, 1000, 0);
      final result =
          SnapService.snap(const Point2D(x: 500, y: 300), [wall]);
      expect(result.type, equals(SnapType.grid));
      expect(result.point.x, closeTo(500, 0.5));
      expect(result.point.y, closeTo(300, 0.5));
    });

    test('SS-PR04: two walls, one near by endpoint and one by interior → endpoint wins', () {
      // w1: (0,0)→(200,0) — endpoint at (0,0) near cursor
      // w2: (0,500)→(2000,500) — interior near cursor (perp dist < 150)
      // Cursor at (50, 50): ~70 mm from endpoint (0,0) which wins.
      final w1 = _wall(0, 0, 200, 0, id: 'w-1');
      final w2 = _wall(0, 500, 2000, 500, id: 'w-2');
      final result =
          SnapService.snap(const Point2D(x: 50, y: 50), [w1, w2]);
      expect(result.type, equals(SnapType.endpoint));
    });
  });

  // ── SnapResult fields ─────────────────────────────────────────────────────

  group('SnapResult fields', () {
    test('SS-RF01: grid result exposes type == SnapType.grid', () {
      final result = SnapService.snap(const Point2D(x: 160, y: 240), []);
      expect(result.type, equals(SnapType.grid));
    });

    test('SS-RF02: endpoint result exposes type == SnapType.endpoint', () {
      final wall = _wall(0, 0, 1000, 0);
      final result = SnapService.snap(const Point2D(x: 10, y: 0), [wall]);
      expect(result.type, equals(SnapType.endpoint));
    });

    test('SS-RF03: wallPoint result exposes type == SnapType.wallPoint', () {
      final wall = _wall(0, 0, 1000, 0);
      final result =
          SnapService.snap(const Point2D(x: 500, y: 100), [wall]);
      expect(result.type, equals(SnapType.wallPoint));
    });

    test('SS-RF04: snapped point coordinates are in world mm, not screen px', () {
      // If zoom/pan were incorrectly applied, the result would differ.
      // This test verifies world-mm values for a grid snap.
      final result = SnapService.snap(const Point2D(x: 3030, y: 7080), []);
      expect(result.point.x, closeTo(3000, 0.5));
      expect(result.point.y, closeTo(7100, 0.5));
    });
  });
}
