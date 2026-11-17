// Distributor outlet stubs (ADR-044): the stub geometry, the choice of a
// free outlet, re-anchoring a circuit's pipes to its stub, assigning
// outlets to circuits saved before ADR-044, and the editor state keeping
// every circuit on its stub when the distributor changes.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/pipe_layout_engine.dart';
import 'package:heating_planner/calculation/providers/pipe_layout_providers.dart';
import 'package:heating_planner/data/database/daos/heating_dao.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/repositories/heating_repository.dart';
import 'package:heating_planner/ui/canvas/tools/snap_service.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

/// Counts DAO calls without a database.
class _CountingHeatingDao implements HeatingDao {
  final Map<Symbol, int> calls = {};
  int countOf(Symbol member) => calls[member] ?? 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.update(invocation.memberName, (v) => v + 1, ifAbsent: () => 1);
    return Future<void>.value();
  }
}

void _expectPoint(Point2D actual, double x, double y) {
  expect(actual.x, closeTo(x, 1e-6));
  expect(actual.y, closeTo(y, 1e-6));
}

/// 500 mm wide at (1000, 1000), 4 outlets: tips at x = 812.5, 937.5,
/// 1062.5, 1187.5 on y = 760 (240 mm in front of the centre).
const _dist = Distributor(
  id: 'dist-1',
  floorId: 'floor-1',
  position: Point2D(x: 1000, y: 1000),
  outletCount: 4,
);

/// A circuit drawn as one route from outlet [outlet] of [_dist].
HeatingCircuit _routed(String id, int? outlet, Point2D start) =>
    relaidConnectionPipes(
      HeatingCircuit(
        id: id,
        distributorId: 'dist-1',
        heatingZoneId: 'zone-$id',
        outletIndex: outlet,
      ),
      const [],
      centerline: [
        start,
        Point2D(x: start.x, y: 300),
        const Point2D(x: 4000, y: 300),
      ],
    );

void main() {
  group('outlet geometry', () {
    test('O-1: outlets are equally spaced across the front of the body', () {
      final pts = distributorOutlets(_dist);
      expect(pts, hasLength(4));
      _expectPoint(pts[0], 812.5, 760);
      _expectPoint(pts[1], 937.5, 760);
      _expectPoint(pts[2], 1062.5, 760);
      _expectPoint(pts[3], 1187.5, 760);
    });

    test('O-2: outlets turn with the distributor', () {
      // 90° clockwise: width along +y, front towards +x.
      final pts = distributorOutlets(_dist.copyWith(rotationDeg: 90));
      _expectPoint(pts.first, 1240, 812.5);
      _expectPoint(pts.last, 1240, 1187.5);
      // 180°: front towards +y, outlet 0 on the right.
      final flipped = distributorOutlets(_dist.copyWith(rotationDeg: 180));
      _expectPoint(flipped.first, 1187.5, 1240);
    });

    test('O-3: invalid inputs give no outlets', () {
      expect(
        PipeLayoutEngine.distributorOutletPoints(
          center: const Point2D(x: 0, y: 0),
          widthMm: 500,
          rotationDeg: 0,
          outletCount: 0,
        ),
        isEmpty,
      );
      expect(
        PipeLayoutEngine.distributorOutletPoints(
          center: const Point2D(x: 0, y: 0),
          widthMm: double.nan,
          rotationDeg: 0,
          outletCount: 4,
        ),
        isEmpty,
      );
    });

    test('O-4: the nearest free outlet is chosen; -1 when none is free', () {
      final pts = distributorOutlets(_dist);
      const click = Point2D(x: 1200, y: 900);
      expect(PipeLayoutEngine.nearestFreeOutletIndex(pts, click), 3);
      expect(
        PipeLayoutEngine.nearestFreeOutletIndex(pts, click, occupied: {3}),
        2,
      );
      expect(
        PipeLayoutEngine.nearestFreeOutletIndex(
          pts,
          click,
          occupied: {0, 1, 2, 3},
        ),
        -1,
      );
    });
  });

  group('anchoring a circuit to its outlet', () {
    test('O-5: only the start moves; supply and return both leave the '
        'stub; moving back restores the circuit exactly', () {
      final c = _routed('a', 0, const Point2D(x: 812.5, y: 760));
      const moved = Point2D(x: 1500, y: 900);
      final a = anchoredAtOutlet(c, moved);

      expect(a.centerlinePath.first, moved);
      expect(a.centerlinePath.skip(1), c.centerlinePath.skip(1));
      expect(a.supplyRoutePath.first, moved);
      expect(a.returnRoutePath.last, moved);
      final pair = PipeLayoutEngine.connectionPipePair(
        centerline: a.centerlinePath,
        pipeSpacingMm: a.pipeSpacingMm.toDouble(),
      );
      expect(a.supplyRoutePath, pair.supply);
      expect(a.returnRoutePath, pair.back);

      expect(anchoredAtOutlet(a, c.centerlinePath.first), c);
      expect(identical(anchoredAtOutlet(c, c.centerlinePath.first), c), isTrue);
    });

    test('O-6: a circuit drawn as two pipes gets the stub as supply start '
        'and return end', () {
      const c = HeatingCircuit(
        id: 'old',
        distributorId: 'dist-1',
        heatingZoneId: 'z',
        supplyRoutePath: [Point2D(x: 1000, y: 1000), Point2D(x: 3000, y: 0)],
        returnRoutePath: [Point2D(x: 3000, y: 100), Point2D(x: 1000, y: 1000)],
      );
      const tip = Point2D(x: 812.5, y: 760);
      final a = anchoredAtOutlet(c, tip);
      expect(a.supplyRoutePath, const [tip, Point2D(x: 3000, y: 0)]);
      expect(a.returnRoutePath, const [Point2D(x: 3000, y: 100), tip]);
      expect(identical(anchoredAtOutlet(a, tip), a), isTrue);
    });
  });

  group('putting circuits on outlets', () {
    test('O-7: circuits saved before ADR-044 get the free outlet nearest '
        'their start — each a different one — and start there', () {
      // Both started at the distributor centre.
      final circuits = [
        _routed('a', null, const Point2D(x: 1000, y: 1000)),
        _routed('b', null, const Point2D(x: 1000, y: 1000)),
      ];
      final r = withCircuitsOnOutlets(_dist, circuits);
      final outlets = distributorOutlets(_dist);
      expect(r.circuits.map((c) => c.outletIndex), [1, 2]);
      expect(r.circuits[0].centerlinePath.first, outlets[1]);
      expect(r.circuits[1].centerlinePath.first, outlets[2]);
      expect(r.distributor, _dist);
    });

    test('O-8: more circuits than outlets raises the outlet count', () {
      final circuits = [
        for (var i = 0; i < 6; i++)
          _routed('c$i', null, const Point2D(x: 1000, y: 1000)),
      ];
      final r = withCircuitsOnOutlets(_dist, circuits);
      expect(r.distributor.outletCount, 6);
      expect(r.circuits.map((c) => c.outletIndex).toSet(), hasLength(6));
    });

    test('O-9: a duplicate or out-of-range outlet is reassigned; circuits '
        'of other distributors are left alone', () {
      final other = _routed('x', null, const Point2D(x: 0, y: 0))
          .copyWith(distributorId: 'dist-2');
      final circuits = [
        _routed('a', 2, const Point2D(x: 1062.5, y: 760)),
        _routed('b', 2, const Point2D(x: 1062.5, y: 760)),
        _routed('c', 9, const Point2D(x: 1062.5, y: 760)),
        other,
      ];
      final r = withCircuitsOnOutlets(_dist, circuits);
      expect(r.circuits[0].outletIndex, 2);
      expect(r.circuits[1].outletIndex, isNot(2));
      expect(r.circuits[2].outletIndex, isNot(anyOf(2, 9)));
      expect(r.circuits[1].outletIndex, isNot(r.circuits[2].outletIndex));
      expect(identical(r.circuits[3], other), isTrue);
    });

    test('O-10: nothing to change returns the very same list', () {
      final circuits = [_routed('a', 0, distributorOutlets(_dist)[0])];
      final r = withCircuitsOnOutlets(_dist, circuits);
      expect(identical(r.circuits, circuits), isTrue);
    });
  });

  group('placement faces the room', () {
    const wall = WallSegment(
      id: 'w',
      roomId: 'r',
      startPoint: Point2D(x: 0, y: 0),
      endPoint: Point2D(x: 4000, y: 0),
    );

    test('O-11: the outlets face away from the wall the distributor is '
        'placed against', () {
      // Below the wall (y grows downwards): outlets must face +y.
      final below = SnapService.distributorRotationAlongWall(
        const Point2D(x: 2000, y: 300),
        wall,
      );
      expect(below, 180);
      // Above it: outlets face −y, the default.
      final above = SnapService.distributorRotationAlongWall(
        const Point2D(x: 2000, y: -300),
        wall,
      );
      expect(above, 0);
    });
  });

  group('editor state', () {
    late _CountingHeatingDao dao;
    late ProviderContainer container;
    late EditorStateNotifier notifier;

    setUp(() {
      dao = _CountingHeatingDao();
      container = ProviderContainer(
        overrides: [heatingDaoProvider.overrideWithValue(dao)],
      );
      addTearDown(container.dispose);
      notifier = container.read(editorStateProvider.notifier);
      notifier.setDistributor(_dist);
      notifier.addCircuit(_routed('a', 3, distributorOutlets(_dist)[3]));
      dao.calls.clear();
    });

    test('O-12: moving the distributor carries the pipes along; the drag '
        'writes nothing until it commits', () {
      final moved = _dist.copyWith(position: const Point2D(x: 1500, y: 1200));
      notifier.updateDistributorTransient(moved);
      final tip = distributorOutlets(moved)[3];
      final c = container.read(editorStateProvider).circuits.single;
      expect(c.centerlinePath.first, tip);
      expect(c.supplyRoutePath.first, tip);
      expect(c.returnRoutePath.last, tip);
      expect(dao.calls, isEmpty);

      notifier.updateDistributor(moved);
      expect(dao.countOf(#upsertDistributor), 1);
      expect(dao.countOf(#upsertCircuit), 1);
    });

    test('O-13: changing the outlet count re-spaces the stubs and the pipes '
        'follow', () {
      final eight = _dist.copyWith(outletCount: 8);
      notifier.updateDistributor(eight);
      final c = container.read(editorStateProvider).circuits.single;
      expect(c.outletIndex, 3);
      expect(c.centerlinePath.first, distributorOutlets(eight)[3]);
    });

    test('O-14: a temperature change leaves the circuit list untouched', () {
      final before = container.read(editorStateProvider).circuits;
      notifier.updateDistributorTransient(_dist.copyWith(supplyTempC: 40));
      expect(
        identical(container.read(editorStateProvider).circuits, before),
        isTrue,
      );
    });
  });
}
