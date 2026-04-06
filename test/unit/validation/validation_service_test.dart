// Unit tests for ValidationService rules: VR-01, VR-02, VR-03, VR-04, HB-01.
//
// Per agent-test.md §3.1 and §12. Tests override [editorStateProvider] with
// a stub notifier and stub out the calculation family providers so that no
// database or repository access is needed.
//
// Naming convention: RuleId-N (e.g. VR01-1, HB01-3).
// Filter results by r.message.contains(...) to isolate the rule under test.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/heat_output_providers.dart';
import 'package:heating_planner/calculation/providers/hydraulic_balance_providers.dart';
import 'package:heating_planner/calculation/providers/tube_length_providers.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';
import 'package:heating_planner/validation/validation_service.dart';

import '../../helpers/test_factories.dart';

// ── Stub notifier ─────────────────────────────────────────────────────────────

/// Returns a fixed [EditorState]; bypasses all repository dependencies.
class _StubEditorStateNotifier extends EditorStateNotifier {
  _StubEditorStateNotifier(this._fixed);
  final EditorState _fixed;

  @override
  EditorState build() => _fixed;
}

// ── Container helpers ─────────────────────────────────────────────────────────

/// Builds a [ProviderContainer] with all calculation family providers stubbed
/// to neutral values (NaN / empty map) so that only the rule under test fires.
ProviderContainer _containerWith(EditorState state) {
  return ProviderContainer(
    overrides: [
      editorStateProvider
          .overrideWith(() => _StubEditorStateNotifier(state)),
      tubeLengthProvider.overrideWith((ref, _) => double.nan),
      zoneSurfaceTempProvider.overrideWith((ref, _) => double.nan),
      hydraulicBalanceProvider.overrideWith((ref, _) async => {}),
    ],
  );
}

/// Builds a container where [zoneSurfaceTempProvider] returns values from
/// [temps] (keyed by zone id); other calc providers stubbed to neutral.
ProviderContainer _containerWithZoneTemps(
  EditorState state,
  Map<String, double> temps,
) {
  return ProviderContainer(
    overrides: [
      editorStateProvider
          .overrideWith(() => _StubEditorStateNotifier(state)),
      tubeLengthProvider.overrideWith((ref, _) => double.nan),
      zoneSurfaceTempProvider.overrideWith(
        (ref, id) => temps[id] ?? double.nan,
      ),
      hydraulicBalanceProvider.overrideWith((ref, _) async => {}),
    ],
  );
}

/// Builds a container where [tubeLengthProvider] returns values from
/// [lengths] (keyed by circuit id); other calc providers stubbed to neutral.
ProviderContainer _containerWithTubeLengths(
  EditorState state,
  Map<String, double> lengths,
) {
  return ProviderContainer(
    overrides: [
      editorStateProvider
          .overrideWith(() => _StubEditorStateNotifier(state)),
      tubeLengthProvider.overrideWith(
        (ref, id) => lengths[id] ?? double.nan,
      ),
      zoneSurfaceTempProvider.overrideWith((ref, _) => double.nan),
      hydraulicBalanceProvider.overrideWith((ref, _) async => {}),
    ],
  );
}

/// Builds a container for HB-01 tests.
///
/// [tubeLengths] supplies the length per circuit id.
/// [balanceMap] supplies the valve delta-P per circuit id for [distributorId];
/// defaults to an empty map (simulates still-loading state).
ProviderContainer _containerForHB01(
  EditorState state, {
  required Map<String, double> tubeLengths,
  required String distributorId,
  Map<String, double> balanceMap = const {},
}) {
  return ProviderContainer(
    overrides: [
      editorStateProvider
          .overrideWith(() => _StubEditorStateNotifier(state)),
      tubeLengthProvider.overrideWith(
        (ref, id) => tubeLengths[id] ?? double.nan,
      ),
      zoneSurfaceTempProvider.overrideWith((ref, _) => double.nan),
      hydraulicBalanceProvider.overrideWith(
        (ref, id) async => id == distributorId ? balanceMap : {},
      ),
    ],
  );
}

// ── Shared constants ──────────────────────────────────────────────────────────

const _distAtOrigin = Distributor(
  id: 'dist-1',
  floorId: 'floor-1',
  position: Point2D(x: 0, y: 0),
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  // ── VR-01: Missing wall construction ───────────────────────────────────────

  group('VR-01 exterior wall missing construction', () {
    test('VR01-1: exterior wall with no constructionId -> error', () {
      final wall = createTestWall(wallType: WallType.exterior);
      final state = EditorState(walls: [wall]);
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('has no construction assigned'))
          .toList();

      expect(results, hasLength(1));
      expect(results.first.elementId, equals(wall.id));
      expect(results.first.severity, equals(WarningSeverity.error));
      expect(results.first.elementType, equals('wall'));
    });

    test('VR01-2: interior wall with no constructionId -> no error', () {
      final wall = createTestWall(wallType: WallType.interior);
      final state = EditorState(walls: [wall]);
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('has no construction assigned'))
          .toList();

      expect(results, isEmpty);
    });

    test('VR01-3: exterior wall with constructionId -> no error', () {
      final wall = createTestWall(
        wallType: WallType.exterior,
        constructionId: 'constr-1',
      );
      final state = EditorState(walls: [wall]);
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('has no construction assigned'))
          .toList();

      expect(results, isEmpty);
    });

    test(
      'VR01-4: mixed walls, only exterior without construction triggers error',
      () {
        final extNoConstr = createTestWall(
          id: 'w-ext-no-constr',
          wallType: WallType.exterior,
        );
        final extWithConstr = createTestWall(
          id: 'w-ext-with-constr',
          wallType: WallType.exterior,
          constructionId: 'constr-1',
        );
        final intNoConstr = createTestWall(
          id: 'w-int-no-constr',
          wallType: WallType.interior,
        );
        final state =
            EditorState(walls: [extNoConstr, extWithConstr, intNoConstr]);
        final container = _containerWith(state);
        addTearDown(container.dispose);

        final results = container
            .read(validationResultsProvider(''))
            .where((r) => r.message.contains('has no construction assigned'))
            .toList();

        expect(results, hasLength(1));
        expect(results.first.elementId, equals('w-ext-no-constr'));
      },
    );
  });

  // ── VR-02: EN 1264 surface temperature exceeded ────────────────────────────

  group('VR-02 EN 1264 surface temperature limit', () {
    test('VR02-1: zone surface temp is NaN -> no warning', () {
      final zone = createTestZone(circuitId: 'circuit-1');
      final state = EditorState(zones: [zone]);
      final container =
          _containerWithZoneTemps(state, {zone.id: double.nan});
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('exceeds EN 1264'))
          .toList();

      expect(results, isEmpty);
    });

    test('VR02-2: zone surface temp <= 0 -> no warning', () {
      final zone = createTestZone(circuitId: 'circuit-1');
      final state = EditorState(zones: [zone]);
      final container = _containerWithZoneTemps(state, {zone.id: 0.0});
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('exceeds EN 1264'))
          .toList();

      expect(results, isEmpty);
    });

    test('VR02-3: floor zone at 28 C (below 29 C limit) -> no warning', () {
      final zone = createTestZone(
        zoneType: ZoneType.floorHeating,
        circuitId: 'circuit-1',
      );
      final state = EditorState(zones: [zone]);
      final container = _containerWithZoneTemps(state, {zone.id: 28.0});
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('exceeds EN 1264'))
          .toList();

      expect(results, isEmpty);
    });

    test('VR02-4: floor zone at 29 C (exactly at limit) -> no warning', () {
      final zone = createTestZone(
        zoneType: ZoneType.floorHeating,
        circuitId: 'circuit-1',
      );
      final state = EditorState(zones: [zone]);
      final container = _containerWithZoneTemps(state, {zone.id: 29.0});
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('exceeds EN 1264'))
          .toList();

      expect(results, isEmpty);
    });

    test('VR02-5: floor zone at 30 C (above 29 C limit) -> warning', () {
      final zone = createTestZone(
        id: 'zone-floor',
        zoneType: ZoneType.floorHeating,
        circuitId: 'circuit-1',
      );
      final state = EditorState(zones: [zone]);
      final container = _containerWithZoneTemps(state, {zone.id: 30.0});
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('exceeds EN 1264'))
          .toList();

      expect(results, hasLength(1));
      expect(results.first.elementId, equals('zone-floor'));
      expect(results.first.severity, equals(WarningSeverity.warning));
      expect(results.first.elementType, equals('zone'));
      expect(results.first.message, contains('30.0'));
      expect(results.first.message, contains('29'));
      expect(results.first.suggestedFix, isNotNull);
    });

    test('VR02-6: wall zone at 39 C (below 40 C limit) -> no warning', () {
      final zone = createTestZone(
        zoneType: ZoneType.wallHeating,
        circuitId: 'circuit-1',
      );
      final state = EditorState(zones: [zone]);
      final container = _containerWithZoneTemps(state, {zone.id: 39.0});
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('exceeds EN 1264'))
          .toList();

      expect(results, isEmpty);
    });

    test('VR02-7: wall zone at 41 C (above 40 C limit) -> warning', () {
      final zone = createTestZone(
        id: 'zone-wall',
        zoneType: ZoneType.wallHeating,
        circuitId: 'circuit-1',
      );
      final state = EditorState(zones: [zone]);
      final container = _containerWithZoneTemps(state, {zone.id: 41.0});
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('exceeds EN 1264'))
          .toList();

      expect(results, hasLength(1));
      expect(results.first.elementId, equals('zone-wall'));
      expect(results.first.message, contains('41.0'));
      expect(results.first.message, contains('40'));
    });
  });

  // ── VR-03: Circuit tube length exceeded ────────────────────────────────────

  group('VR-03 circuit tube length exceeds hydraulic maximum', () {
    test('VR03-1: circuit tube length is NaN -> no warning', () {
      final circuit = createTestCircuit(
        supplyRoutePath: [const Point2D(x: 0, y: 0)],
      );
      final state =
          EditorState(distributor: _distAtOrigin, circuits: [circuit]);
      final container =
          _containerWithTubeLengths(state, {circuit.id: double.nan});
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('exceeds maximum of'))
          .toList();

      expect(results, isEmpty);
    });

    test(
      'VR03-2: circuit at 100 m (below 120 m limit for 16 mm OD) -> no warning',
      () {
        final circuit = createTestCircuit(
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        final state =
            EditorState(distributor: _distAtOrigin, circuits: [circuit]);
        final container =
            _containerWithTubeLengths(state, {circuit.id: 100.0});
        addTearDown(container.dispose);

        final results = container
            .read(validationResultsProvider(''))
            .where((r) => r.message.contains('exceeds maximum of'))
            .toList();

        expect(results, isEmpty);
      },
    );

    test('VR03-3: circuit exactly at 120 m limit -> no warning', () {
      final circuit = createTestCircuit(
        supplyRoutePath: [const Point2D(x: 0, y: 0)],
      );
      final state =
          EditorState(distributor: _distAtOrigin, circuits: [circuit]);
      final container =
          _containerWithTubeLengths(state, {circuit.id: 120.0});
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('exceeds maximum of'))
          .toList();

      expect(results, isEmpty);
    });

    test(
      'VR03-4: circuit at 121 m (above 120 m limit for 16 mm OD) -> warning',
      () {
        final circuit = createTestCircuit(
          id: 'circuit-long',
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        final state =
            EditorState(distributor: _distAtOrigin, circuits: [circuit]);
        final container =
            _containerWithTubeLengths(state, {circuit.id: 121.0});
        addTearDown(container.dispose);

        final results = container
            .read(validationResultsProvider(''))
            .where((r) => r.message.contains('exceeds maximum of'))
            .toList();

        expect(results, hasLength(1));
        expect(results.first.elementId, equals('circuit-long'));
        expect(results.first.severity, equals(WarningSeverity.warning));
        expect(results.first.elementType, equals('circuit'));
        expect(results.first.message, contains('120'));
        expect(results.first.suggestedFix, contains('Split'));
      },
    );
  });

  // ── VR-04: Zone not connected to a circuit ─────────────────────────────────

  group('VR-04 heating zone not connected to a circuit', () {
    test('VR04-1: zone with circuitId == null -> error', () {
      final zone = createTestZone(id: 'zone-unconnected');
      final state = EditorState(zones: [zone]);
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('has no circuit connected'))
          .toList();

      expect(results, hasLength(1));
      expect(results.first.elementId, equals('zone-unconnected'));
      expect(results.first.severity, equals(WarningSeverity.error));
      expect(results.first.elementType, equals('zone'));
      expect(results.first.suggestedFix, isNotNull);
    });

    test('VR04-2: zone with non-null circuitId -> no error', () {
      final zone = createTestZone(circuitId: 'circuit-1');
      final state = EditorState(zones: [zone]);
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('has no circuit connected'))
          .toList();

      expect(results, isEmpty);
    });

    test('VR04-3: mixed zones, only unconnected ones get errors', () {
      final unconnected = createTestZone(id: 'z-unconnected');
      final connected =
          createTestZone(id: 'z-connected', circuitId: 'c-1');
      final state = EditorState(zones: [unconnected, connected]);
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where((r) => r.message.contains('has no circuit connected'))
          .toList();

      expect(results, hasLength(1));
      expect(results.first.elementId, equals('z-unconnected'));
    });
  });

  // ── HB-01: Hydraulic length imbalance ─────────────────────────────────────

  group('HB-01 hydraulic circuit length imbalance', () {
    test('HB01-1: no distributor -> no HB-01 warning', () {
      final c1 = createTestCircuit(id: 'c-1');
      final c2 = createTestCircuit(id: 'c-2');
      final state = EditorState(circuits: [c1, c2]);
      final container = _containerForHB01(
        state,
        tubeLengths: {'c-1': 70.0, 'c-2': 100.0},
        distributorId: 'dist-1',
      );
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where(
            (r) => r.message.contains('Circuit lengths on this distributor'),
          )
          .toList();

      expect(results, isEmpty);
    });

    test('HB01-2: single circuit -> no HB-01 warning', () {
      final c1 = createTestCircuit(
        id: 'c-1',
        supplyRoutePath: [const Point2D(x: 0, y: 0)],
      );
      final state =
          EditorState(distributor: _distAtOrigin, circuits: [c1]);
      final container = _containerForHB01(
        state,
        tubeLengths: {'c-1': 100.0},
        distributorId: 'dist-1',
      );
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where(
            (r) => r.message.contains('Circuit lengths on this distributor'),
          )
          .toList();

      expect(results, isEmpty);
    });

    test('HB01-3: two circuits both with NaN lengths -> no HB-01 warning', () {
      final c1 = createTestCircuit(
        id: 'c-1',
        supplyRoutePath: [const Point2D(x: 0, y: 0)],
      );
      final c2 = createTestCircuit(
        id: 'c-2',
        supplyRoutePath: [const Point2D(x: 0, y: 0)],
      );
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [c1, c2],
      );
      final container = _containerForHB01(
        state,
        tubeLengths: {},
        distributorId: 'dist-1',
      );
      addTearDown(container.dispose);

      final results = container
          .read(validationResultsProvider(''))
          .where(
            (r) => r.message.contains('Circuit lengths on this distributor'),
          )
          .toList();

      expect(results, isEmpty);
    });

    test(
      'HB01-4: two circuits within 1.3x ratio -> no HB-01 warning',
      () {
        final c1 = createTestCircuit(
          id: 'c-1',
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        final c2 = createTestCircuit(
          id: 'c-2',
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        final state = EditorState(
          distributor: _distAtOrigin,
          circuits: [c1, c2],
        );
        // 100 / 90 ~= 1.11 <= 1.3 -> no warning
        final container = _containerForHB01(
          state,
          tubeLengths: {'c-1': 90.0, 'c-2': 100.0},
          distributorId: 'dist-1',
        );
        addTearDown(container.dispose);

        final results = container
            .read(validationResultsProvider(''))
            .where(
              (r) =>
                  r.message.contains('Circuit lengths on this distributor'),
            )
            .toList();

        expect(results, isEmpty);
      },
    );

    test(
      'HB01-5: two circuits exceeding 1.3x ratio, valve data not loaded '
      '-> distributor-level warning only',
      () {
        final c1 = createTestCircuit(
          id: 'c-short',
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        final c2 = createTestCircuit(
          id: 'c-long',
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        final state = EditorState(
          distributor: _distAtOrigin,
          circuits: [c1, c2],
        );
        // 100 / 70 ~= 1.43 > 1.3 -> HB-01 fires.
        // balanceMap empty (default) -> valveSettings empty -> no per-circuit.
        final container = _containerForHB01(
          state,
          tubeLengths: {'c-short': 70.0, 'c-long': 100.0},
          distributorId: 'dist-1',
        );
        addTearDown(container.dispose);

        final results = container
            .read(validationResultsProvider(''))
            .where(
              (r) =>
                  r.message.contains('Circuit lengths on this distributor'),
            )
            .toList();

        expect(results, hasLength(1));
        expect(results.first.elementId, equals('dist-1'));
        expect(results.first.elementType, equals('distributor'));
        expect(results.first.severity, equals(WarningSeverity.warning));
        expect(results.first.message, contains('70'));
        expect(results.first.message, contains('100'));
        expect(results.first.suggestedFix, isNotNull);
      },
    );

    test(
      'HB01-6: two circuits exceeding ratio with valve delta-P > 2000 Pa '
      '-> distributor warning + per-circuit warning',
      () async {
        final cShort = createTestCircuit(
          id: 'c-short',
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        final cLong = createTestCircuit(
          id: 'c-long',
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        // Third circuit with NaN length: covers the `if (len == null) continue`
        // branch inside the per-circuit loop (not in lengths map).
        final cNan = createTestCircuit(
          id: 'c-nan',
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        final state = EditorState(
          distributor: _distAtOrigin,
          circuits: [cShort, cLong, cNan],
        );
        final container = _containerForHB01(
          state,
          tubeLengths: {'c-short': 70.0, 'c-long': 100.0},
          // c-short needs 5 000 Pa throttling -> > significantValveSettingPa
          balanceMap: {'c-short': 5000.0},
          distributorId: 'dist-1',
        );
        addTearDown(container.dispose);

        // Pre-initialise the FutureProvider and pump one microtask so that
        // the sync validationResultsProvider sees AsyncData instead of loading.
        container.read(hydraulicBalanceProvider('dist-1'));
        await Future<void>.microtask(() {});

        final allResults = container.read(validationResultsProvider(''));

        final distResults = allResults
            .where(
              (r) =>
                  r.message.contains('Circuit lengths on this distributor'),
            )
            .toList();
        final circuitResults = allResults
            .where((r) => r.message.contains('significantly shorter'))
            .toList();

        expect(distResults, hasLength(1));
        expect(distResults.first.elementId, equals('dist-1'));

        expect(circuitResults, hasLength(1));
        expect(circuitResults.first.elementId, equals('c-short'));
        expect(
          circuitResults.first.severity,
          equals(WarningSeverity.warning),
        );
        expect(circuitResults.first.elementType, equals('circuit'));
        // suggestedFix must mention the kPa valve setting (5 000 Pa -> 5.0 kPa).
        expect(circuitResults.first.suggestedFix, contains('5.0 kPa'));
      },
    );

    test(
      'HB01-7: circuits within ratio, valve data present -> no HB-01 warning',
      () async {
        final c1 = createTestCircuit(
          id: 'c-1',
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        final c2 = createTestCircuit(
          id: 'c-2',
          supplyRoutePath: [const Point2D(x: 0, y: 0)],
        );
        final state = EditorState(
          distributor: _distAtOrigin,
          circuits: [c1, c2],
        );
        // 100 / 95 ~= 1.05 <= 1.3 -> no HB-01 at all
        final container = _containerForHB01(
          state,
          tubeLengths: {'c-1': 95.0, 'c-2': 100.0},
          balanceMap: {'c-1': 5000.0},
          distributorId: 'dist-1',
        );
        addTearDown(container.dispose);

        container.read(hydraulicBalanceProvider('dist-1'));
        await Future<void>.microtask(() {});

        final results = container
            .read(validationResultsProvider(''))
            .where(
              (r) =>
                  r.message.contains('Circuit lengths on this distributor') ||
                  r.message.contains('significantly shorter'),
            )
            .toList();

        expect(results, isEmpty);
      },
    );
  });
}
