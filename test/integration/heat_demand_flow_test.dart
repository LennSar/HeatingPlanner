// Integration test: room heat-demand breakdown reconciles with the total,
// and the same total value flows into the downstream heating-system
// planning calculations.
//
// Unlike the widget tests (which stub the calculation providers), this test
// drives the REAL provider chain against an in-memory Drift database:
//
//   seeded DB rows
//     → roomProvider / wallSegmentsProvider / constructionProvider / layers
//     → uValueProvider + roomInnerPolygonProvider + wallInnerEdgeLengthProvider
//     → roomHeatDemandBreakdownProvider   (components + total)
//     → roomHeatDemandProvider            (the value every consumer reads)
//     → buildingHeatDemandProvider        (building-level planning aggregate)
//
// HD-1  The breakdown components sum to the total (no "total < sum of parts").
// HD-2  roomHeatDemandProvider — the value read by the heating-system
//       planning consumers (zone adequacy in zone_color_state_provider,
//       building total in the properties panel) — equals the reconciled
//       breakdown total.
// HD-3  buildingHeatDemandProvider (a real downstream planning calculation)
//       is built from that same reconciled total.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heating_planner/calculation/providers/heat_demand_providers.dart';
import 'package:heating_planner/calculation/providers/project_settings_provider.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/floor.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/repositories/building_repository.dart';
import 'package:heating_planner/repositories/construction_repository.dart';

import '../helpers/test_factories.dart';

void main() {
  const projectId = 'project-1';
  const floorId = 'floor-1';
  const roomId = 'room-1';
  const constrId = 'constr-1';

  late $db.AppDatabase db;

  // The default 5 m × 4 m room. Four exterior walls, one per polygon edge,
  // all carrying the same brick construction.
  final polygon = rectanglePolygon5x4();
  final walls = <WallSegment>[
    createTestWall(
      id: 'wall-s',
      startPoint: const Point2D(x: 0, y: 0),
      endPoint: const Point2D(x: 5000, y: 0),
      orientation: CardinalDirection.south,
      constructionId: constrId,
    ),
    createTestWall(
      id: 'wall-e',
      startPoint: const Point2D(x: 5000, y: 0),
      endPoint: const Point2D(x: 5000, y: 4000),
      orientation: CardinalDirection.east,
      constructionId: constrId,
    ),
    createTestWall(
      id: 'wall-n',
      startPoint: const Point2D(x: 5000, y: 4000),
      endPoint: const Point2D(x: 0, y: 4000),
      orientation: CardinalDirection.north,
      constructionId: constrId,
    ),
    createTestWall(
      id: 'wall-w',
      startPoint: const Point2D(x: 0, y: 4000),
      endPoint: const Point2D(x: 0, y: 0),
      orientation: CardinalDirection.west,
      constructionId: constrId,
    ),
  ];

  setUp(() async {
    db = $db.AppDatabase.forTesting(NativeDatabase.memory());
    final bDao = db.buildingDao;
    final cDao = db.constructionDao;

    await upsertFloor(bDao, const Floor(id: floorId, name: 'Floor 1'),
        projectId);
    await upsertRoom(
      bDao,
      createTestRoom(id: roomId, floorId: floorId, polygon: polygon),
    );
    await upsertConstruction(cDao, createTestConstruction(id: constrId));
    await upsertLayer(cDao, createBrickLayer(constructionId: constrId));
    for (final wall in walls) {
      await upsertWallSegment(bDao, wall);
    }
  });

  tearDown(() async {
    await db.close();
  });

  /// Builds a container backed by the seeded in-memory DB, with the
  /// project-level design temperatures pinned so the demand is deterministic.
  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        $db.appDatabaseProvider.overrideWithValue(db),
        designOutdoorTempCProvider.overrideWithValue(-12.0),
        defaultIndoorTempCProvider.overrideWithValue(20.0),
        unheatedSpaceTempCProvider.overrideWithValue(10.0),
      ],
    );
  }

  /// Subscribes to every DB-backed stream the demand chain depends on and
  /// pumps the event loop until they resolve, so the synchronous breakdown
  /// provider computes against real data.
  ///
  /// (Reading a StreamProvider's `.future` alone does not drive Drift's
  /// query stream in a plain unit test — an active `listen` does.)
  Future<void> warmUp(ProviderContainer c) async {
    c.listen(roomHeatDemandBreakdownProvider(roomId), (_, __) {});
    c.listen(floorsProvider(projectId), (_, __) {});
    c.listen(roomsProvider(floorId), (_, __) {});
    c.listen(roomProvider(roomId), (_, __) {});
    c.listen(floorProvider(floorId), (_, __) {});
    c.listen(wallSegmentsProvider(roomId), (_, __) {});
    c.listen(constructionProvider(constrId), (_, __) {});
    c.listen(layersProvider(constrId), (_, __) {});
    for (final wall in walls) {
      c.listen(wallSegmentProvider(wall.id), (_, __) {});
      c.listen(windowsProvider(wall.id), (_, __) {});
      c.listen(doorsProvider(wall.id), (_, __) {});
    }

    bool ready() =>
        c.read(floorsProvider(projectId)).hasValue &&
        c.read(roomsProvider(floorId)).hasValue &&
        c.read(roomProvider(roomId)).hasValue &&
        c.read(floorProvider(floorId)).hasValue &&
        c.read(wallSegmentsProvider(roomId)).hasValue &&
        c.read(constructionProvider(constrId)).hasValue &&
        c.read(layersProvider(constrId)).hasValue &&
        walls.every(
          (w) => c.read(wallSegmentProvider(w.id)).hasValue,
        );

    var tries = 0;
    while (!ready() && tries < 400) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      tries++;
    }
    expect(ready(), isTrue, reason: 'DB streams did not resolve in time');
  }

  test(
    'HD-1: breakdown components sum to the total (real DB-backed chain)',
    () async {
      final c = buildContainer();
      addTearDown(c.dispose);
      await warmUp(c);

      final demand = c.read(roomHeatDemandBreakdownProvider(roomId));

      // A genuine demand was computed (not NaN, not zero).
      expect(demand.totalW, isNot(isNaN));
      expect(demand.transmissionW, greaterThan(0));
      expect(demand.ventilationW, greaterThan(0));
      expect(demand.totalW, greaterThan(0));

      // No floor / ceiling construction assigned → those terms are N/A.
      expect(demand.floorW, isNaN);
      expect(demand.ceilingW, isNaN);

      // The invariant the fix guarantees: the applicable components add up
      // to the total (previously the panel's parallel calc broke this).
      expect(
        demand.totalW,
        closeTo(demand.transmissionW + demand.ventilationW, 1e-6),
      );
    },
  );

  test(
    'HD-2: the value planning consumers read equals the reconciled total',
    () async {
      final c = buildContainer();
      addTearDown(c.dispose);
      await warmUp(c);

      final breakdownTotal =
          c.read(roomHeatDemandBreakdownProvider(roomId)).totalW;

      // roomHeatDemandProvider is exactly what zone_color_state_provider
      // (zone adequacy: output ÷ demand) and the properties panel consume.
      final consumedDemand = c.read(roomHeatDemandProvider(roomId));

      expect(consumedDemand, equals(breakdownTotal));
    },
  );

  test(
    'HD-3: building planning total is built from the reconciled room total',
    () async {
      final c = buildContainer();
      addTearDown(c.dispose);
      await warmUp(c);
      // buildingHeatDemandProvider walks floors → rooms → roomHeatDemand.
      c.listen(buildingHeatDemandProvider(projectId), (_, __) {});

      final roomTotal =
          c.read(roomHeatDemandBreakdownProvider(roomId)).totalW;
      final buildingTotal = c.read(buildingHeatDemandProvider(projectId));

      // Single seeded room → the building planning total is that room's
      // reconciled demand, proving the corrected value propagates downstream.
      expect(buildingTotal, closeTo(roomTotal, 1e-6));
    },
  );
}
