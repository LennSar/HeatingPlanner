// ADR-038 Rule 3: which circuits reduce a heating zone, and by how much.

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/pipe_layout_providers.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/calculation/engines/pipe_layout_engine.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/wall_segment.dart';

const _zone = HeatingZone(
  id: 'zone-1',
  roomId: 'room-1',
  polygon: [
    Point2D(x: 1000, y: 1000),
    Point2D(x: 5000, y: 1000),
    Point2D(x: 5000, y: 4000),
    Point2D(x: 1000, y: 4000),
  ],
  tubeSpacingMm: 150,
  tubeTypeId: 'tube-1',
  flooringMaterialId: 'mat-1',
  circuitId: 'own',
);

// Runs straight through the zone at y = 2500, supply only.
HeatingCircuit _transit(SupplyPipeInsulationType? type) => HeatingCircuit(
  id: 'transit',
  distributorId: 'dist-1',
  heatingZoneId: 'zone-2',
  supplyRoutePath: const [Point2D(x: 0, y: 2500), Point2D(x: 6000, y: 2500)],
  supplyPipeInsulationType: type,
);

void main() {
  test('a transit line in the screed reduces the zone by one tube spacing '
      'along its length', () {
    for (final type in [
      SupplyPipeInsulationType.none,
      SupplyPipeInsulationType.corrugatedConduit,
      null, // not chosen yet → treated as in the screed
    ]) {
      final area = zoneEffectiveAreaM2(_zone, [_transit(type)]);
      // 12 m² − 4 m × 0.15 m.
      expect(area, closeTo(11.4, 0.02), reason: 'insulation type $type');
      expect(transitCorridorsForZone(_zone, [_transit(type)]), isNotEmpty);
    }
  });

  test('a transit line laid in the insulation layer beneath the heating '
      'area leaves the zone unchanged', () {
    final circuits = [_transit(SupplyPipeInsulationType.insulationLayer)];
    expect(zoneEffectiveAreaM2(_zone, circuits), 12.0);
    expect(transitCorridorsForZone(_zone, circuits), isEmpty);
  });

  test("the zone's own circuit never reduces it", () {
    const own = HeatingCircuit(
      id: 'own',
      distributorId: 'dist-1',
      heatingZoneId: 'zone-1',
      supplyRoutePath: [Point2D(x: 0, y: 2500), Point2D(x: 3000, y: 2500)],
      returnRoutePath: [Point2D(x: 3000, y: 2500), Point2D(x: 0, y: 2600)],
      supplyPipeInsulationType: SupplyPipeInsulationType.none,
    );
    expect(zoneEffectiveAreaM2(_zone, const [own]), 12.0);
  });

  test('a zone with fewer than three vertices has no area', () {
    expect(
      zoneEffectiveAreaM2(_zone.copyWith(polygon: const []), const []).isNaN,
      isTrue,
    );
  });

  group('ADR-040 connection pipe distances', () {
    // Wall along y = 0, 200 mm thick (face at y = 100).
    const wall = WallSegment(
      id: 'w-top',
      roomId: 'room-1',
      startPoint: Point2D(x: 0, y: 0),
      endPoint: Point2D(x: 8000, y: 0),
      thicknessMm: 200,
    );
    const drawn = [
      Point2D(x: 1000, y: 1000),
      Point2D(x: 1000, y: 300),
      Point2D(x: 4000, y: 300),
    ];
    HeatingCircuit laid() => relaidConnectionPipes(
      const HeatingCircuit(
        id: 'c1',
        distributorId: 'dist-1',
        heatingZoneId: 'zone-2',
      ),
      const [wall],
      centerline: drawn,
    );

    test('relaidConnectionPipes stores the route and both derived pipes', () {
      final c = laid();
      expect(c.centerlinePath, const [
        Point2D(x: 1000, y: 1000),
        Point2D(x: 1000, y: 250),
        Point2D(x: 4000, y: 250),
      ]);
      final pair = PipeLayoutEngine.connectionPipePair(
        centerline: c.centerlinePath,
        pipeSpacingMm: 100,
      );
      expect(c.supplyRoutePath, pair.supply);
      expect(c.returnRoutePath, pair.back);
    });

    test('a new pipe spacing is applied: the pipes move apart and the '
        'route keeps the wall distance', () {
      final c = withConnectionPipeDistances(laid(), const [
        wall,
      ], pipeSpacingMm: 200);
      expect(c.pipeSpacingMm, 200);
      // face 100 + clearance 100 + half spacing 100.
      expect(c.centerlinePath[1].y, 300.0);
      // Along the wall the two pipes are 200 mm apart …
      final supplyY = c.supplyRoutePath[2].y;
      final returnY = c.returnRoutePath[1].y;
      expect((supplyY - returnY).abs(), 200.0);
      // … and the nearer one is still 100 mm off the face.
      expect([supplyY, returnY].reduce((a, b) => a < b ? a : b), 200.0);
    });

    test('a larger wall distance is applied', () {
      final c = withConnectionPipeDistances(laid(), const [
        wall,
      ], wallClearanceMm: 300);
      expect(c.wallClearanceMm, 300);
      expect(c.centerlinePath[1].y, 450.0);
      expect(c.centerlinePath[2].y, 450.0);
    });

    test('a smaller wall distance is applied too, even far below the old '
        'one', () {
      final wide = withConnectionPipeDistances(laid(), const [
        wall,
      ], wallClearanceMm: 600);
      expect(wide.centerlinePath[1].y, 750.0);
      final tight = withConnectionPipeDistances(wide, const [
        wall,
      ], wallClearanceMm: 0);
      expect(tight.centerlinePath[1].y, 150.0);
    });

    test('values are clamped to their allowed range', () {
      final c = withConnectionPipeDistances(
        laid(),
        const [wall],
        pipeSpacingMm: 5,
        zoneClearanceMm: 5000,
        wallClearanceMm: -20,
      );
      expect(c.pipeSpacingMm, minPipeSpacingMm);
      expect(c.zoneClearanceMm, maxPipeClearanceMm);
      expect(c.wallClearanceMm, 0);
    });

    test('a circuit drawn as two separate pipes is converted: its supply '
        'pipe becomes the route', () {
      const legacy = HeatingCircuit(
        id: 'old',
        distributorId: 'dist-1',
        heatingZoneId: 'zone-2',
        supplyRoutePath: [Point2D(x: 1000, y: 3000), Point2D(x: 3000, y: 3000)],
        returnRoutePath: [
          Point2D(x: 3000, y: 3000),
          Point2D(x: 3000, y: 3500),
          Point2D(x: 1000, y: 3000),
        ],
      );
      final c = withConnectionPipeDistances(
        legacy,
        const [],
        pipeSpacingMm: 120,
      );
      expect(c.centerlinePath, legacy.supplyRoutePath);
      expect(c.supplyRoutePath.last, const Point2D(x: 3000, y: 3060));
      expect(c.returnRoutePath.first, const Point2D(x: 3000, y: 2940));
    });

    test('the zone distance sets how much of a crossed zone the pipes '
        'take', () {
      // Pair through the 4 m wide zone at y = 2500, pipes 100 mm apart.
      HeatingCircuit through(int zoneClearanceMm) => relaidConnectionPipes(
        HeatingCircuit(
          id: 'transit',
          distributorId: 'dist-1',
          heatingZoneId: 'zone-2',
          zoneClearanceMm: zoneClearanceMm,
        ),
        const [],
        centerline: const [Point2D(x: 0, y: 2500), Point2D(x: 6000, y: 2500)],
      );
      // Strip = spacing + clearance (half of it on each side).
      expect(
        zoneEffectiveAreaM2(_zone, [through(100)]),
        closeTo(12.0 - 4.0 * 0.2, 0.02),
      );
      expect(
        zoneEffectiveAreaM2(_zone, [through(300)]),
        closeTo(12.0 - 4.0 * 0.4, 0.02),
      );
      expect(
        zoneEffectiveAreaM2(_zone, [through(0)]),
        closeTo(12.0 - 4.0 * 0.1, 0.02),
      );
    });

    test('zone tubes keep the full zone distance from the nearer pipe', () {
      final transit = relaidConnectionPipes(
        const HeatingCircuit(
          id: 'transit',
          distributorId: 'dist-1',
          heatingZoneId: 'zone-2',
          zoneClearanceMm: 300,
        ),
        const [],
        centerline: const [Point2D(x: 0, y: 2500), Point2D(x: 6000, y: 2500)],
      );
      final keepOut = transitKeepOutForZone(_zone, [transit]);
      final ys = keepOut.single.map((p) => p.y).toList()..sort();
      // 50 (half spacing) + 300 either side of y = 2500.
      expect(ys.first, 2150.0);
      expect(ys.last, 2850.0);

      final path = PipeLayoutEngine.meanderPath(
        polygon: _zone.polygon,
        tubeSpacingMm: _zone.tubeSpacingMm,
        borderDistanceMm: _zone.borderDistanceMm,
        exclusions: keepOut,
      );
      expect(path, isNotEmpty);
      // No tube row runs inside the keep-out band.
      for (var i = 0; i + 1 < path.length; i++) {
        final a = path[i];
        final b = path[i + 1];
        final isRow = (a.y - b.y).abs() < 1e-6 && (a.x - b.x).abs() > 500;
        if (isRow) {
          expect(
            a.y > 2150 && a.y < 2850,
            isFalse,
            reason: 'row at y=${a.y} is inside the keep-out band',
          );
        }
      }
    });
  });

  group('ADR-041 swapping supply and return', () {
    const route = [Point2D(x: 0, y: 2500), Point2D(x: 3000, y: 2500)];
    final circuit = relaidConnectionPipes(
      const HeatingCircuit(
        id: 'c1',
        distributorId: 'dist-1',
        heatingZoneId: 'zone-1',
      ),
      const [],
      centerline: route,
    );

    test('a drawn pair keeps its route; the pipes trade sides', () {
      final swapped = withSupplyAndReturnSwapped(circuit, const []);
      expect(swapped.supplyOnRight, isTrue);
      expect(swapped.centerlinePath, circuit.centerlinePath);
      expect(swapped.supplyRoutePath, circuit.returnRoutePath.reversed);
      expect(swapped.returnRoutePath, circuit.supplyRoutePath.reversed);
      // Supply still starts and return still ends on the distributor.
      expect(swapped.supplyRoutePath.first, route.first);
      expect(swapped.returnRoutePath.last, route.first);
    });

    test('swapping twice restores the original', () {
      final twice = withSupplyAndReturnSwapped(
        withSupplyAndReturnSwapped(circuit, const []),
        const [],
      );
      expect(twice, circuit);
    });

    test('the swap survives a later change of distances', () {
      final swapped = withSupplyAndReturnSwapped(circuit, const []);
      final wider = withConnectionPipeDistances(
        swapped,
        const [],
        pipeSpacingMm: 200,
      );
      expect(wider.supplyOnRight, isTrue);
      // Default supply side of an eastward route is +y (see RDT-11), so
      // the swapped supply runs at −y, half the new spacing away.
      expect(wider.supplyRoutePath.last.y, 2400.0);
      expect(wider.returnRoutePath.first.y, 2600.0);
    });

    test('a circuit drawn as two separate pipes trades the two polylines', () {
      const legacy = HeatingCircuit(
        id: 'old',
        distributorId: 'dist-1',
        heatingZoneId: 'zone-1',
        supplyRoutePath: [Point2D(x: 0, y: 0), Point2D(x: 2000, y: 2000)],
        returnRoutePath: [
          Point2D(x: 2000, y: 2000),
          Point2D(x: 2000, y: 0),
          Point2D(x: 0, y: 0),
        ],
      );
      final swapped = withSupplyAndReturnSwapped(legacy, const []);
      expect(swapped.supplyRoutePath, const [
        Point2D(x: 0, y: 0),
        Point2D(x: 2000, y: 0),
        Point2D(x: 2000, y: 2000),
      ]);
      expect(swapped.returnRoutePath, const [
        Point2D(x: 2000, y: 2000),
        Point2D(x: 0, y: 0),
      ]);
      expect(swapped.supplyOnRight, isFalse);
    });

    test('the zone tube follows the swap and stays crossing-free', () {
      // Pair enters the 4 m × 3 m zone through its left edge.
      for (final c in [
        circuit,
        withSupplyAndReturnSwapped(circuit, const []),
      ]) {
        final entry = PipeLayoutEngine.zoneEntryPoint(
          polygon: _zone.polygon,
          supplyRoutePath: c.supplyRoutePath,
        )!;
        final exit = PipeLayoutEngine.zoneExitPoint(
          polygon: _zone.polygon,
          returnRoutePath: c.returnRoutePath,
        )!;
        final path = PipeLayoutEngine.meanderPath(
          polygon: _zone.polygon,
          tubeSpacingMm: _zone.tubeSpacingMm,
          borderDistanceMm: _zone.borderDistanceMm,
          entryPoint: entry,
          exitPoint: exit,
        );
        expect(path.first, entry, reason: 'tube starts at the supply');
        expect(path.last, exit, reason: 'tube ends at the return');
        expect(PipeLayoutEngine.leadCrossings(path), 0);
      }
    });
  });
}
