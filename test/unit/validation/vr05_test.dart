// Unit tests for validation rule VR-05: Circuit supply route not connected
// to the distributor.
//
// Per agent-test.md §3.1 and §12. Tests override [editorStateProvider] with
// a stub notifier and stub out the calculation family providers so that no
// database or repository access is needed.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/heat_output_providers.dart';
import 'package:heating_planner/calculation/providers/hydraulic_balance_providers.dart';
import 'package:heating_planner/calculation/providers/tube_length_providers.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/validation_result.dart';
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

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a [ProviderContainer] with [editorStateProvider] overridden to the
/// given [state] and all calculation family providers stubbed to neutral values
/// so that no database or DAO access is triggered.
///
/// - [tubeLengthProvider] → [double.nan] (skips HB-01 and VR-03 rules)
/// - [zoneSurfaceTempProvider] → [double.nan] (skips VR-02 rule)
/// - [hydraulicBalanceProvider] → empty map (skips per-circuit HB-01 rows)
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

/// Returns only the VR-05 errors (elementType == 'circuit' && severity == error)
/// from [validationResultsProvider].
///
/// Filters out errors from other rules (e.g. VR-04 for unconnected zones)
/// by matching the specific VR-05 message substring.
List<ValidationResult> _vr05Results(ProviderContainer c) {
  return c
      .read(validationResultsProvider(''))
      .where(
        (r) =>
            r.severity == WarningSeverity.error &&
            r.elementType == 'circuit' &&
            r.message.contains('supply route is not connected'),
      )
      .toList();
}

// ── Default distributor at origin ─────────────────────────────────────────────

const _distAtOrigin = Distributor(
  id: 'dist-1',
  floorId: 'floor-1',
  position: Point2D(x: 0, y: 0),
);

void main() {
  // Drift and path_provider need Flutter service bindings even in unit tests.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);
  // ── No distributor ─────────────────────────────────────────────────────────

  group('VR-05 — no distributor', () {
    test('VR05-1: circuit present but no distributor → VR-05 error', () {
      final circuit = createTestCircuit(
        supplyRoutePath: [const Point2D(x: 0, y: 0)],
      );
      final state = EditorState(circuits: [circuit]);
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = _vr05Results(container);
      expect(results, hasLength(1));
      expect(results.first.elementId, equals(circuit.id));
      expect(results.first.severity, equals(WarningSeverity.error));
    });

    test('VR05-2: no circuits and no distributor → no VR-05 errors', () {
      final container = _containerWith(const EditorState());
      addTearDown(container.dispose);

      expect(_vr05Results(container), isEmpty);
    });
  });

  // ── Empty supply route ─────────────────────────────────────────────────────

  group('VR-05 — empty supply route', () {
    test('VR05-3: circuit with empty supplyRoutePath → error even with distributor', () {
      final circuit = createTestCircuit(supplyRoutePath: []);
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [circuit],
      );
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = _vr05Results(container);
      expect(results, hasLength(1));
      expect(results.first.elementId, equals(circuit.id));
    });
  });

  // ── Within 50 mm ──────────────────────────────────────────────────────────

  group('VR-05 — supply route within 50 mm of distributor', () {
    test('VR05-4: first route point exactly at distributor → no error', () {
      final circuit = createTestCircuit(
        supplyRoutePath: [const Point2D(x: 0, y: 0)],
      );
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [circuit],
      );
      final container = _containerWith(state);
      addTearDown(container.dispose);

      expect(_vr05Results(container), isEmpty);
    });

    test('VR05-5: first route point 49 mm from distributor → no error', () {
      final circuit = createTestCircuit(
        supplyRoutePath: [const Point2D(x: 49, y: 0)],
      );
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [circuit],
      );
      final container = _containerWith(state);
      addTearDown(container.dispose);

      expect(_vr05Results(container), isEmpty);
    });

    test('VR05-6: first route point exactly 50 mm from distributor → no error', () {
      final circuit = createTestCircuit(
        supplyRoutePath: [const Point2D(x: 50, y: 0)],
      );
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [circuit],
      );
      final container = _containerWith(state);
      addTearDown(container.dispose);

      expect(_vr05Results(container), isEmpty);
    });
  });

  // ── Beyond 50 mm ──────────────────────────────────────────────────────────

  group('VR-05 — supply route beyond 50 mm of distributor', () {
    test('VR05-7: first route point 51 mm from distributor → error', () {
      final circuit = createTestCircuit(
        supplyRoutePath: [const Point2D(x: 51, y: 0)],
      );
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [circuit],
      );
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = _vr05Results(container);
      expect(results, hasLength(1));
      expect(results.first.elementId, equals(circuit.id));
    });

    test('VR05-8: circuit drawn 2 000 mm from distributor → error', () {
      final circuit = createTestCircuit(
        id: 'circuit-far',
        supplyRoutePath: [const Point2D(x: 2000, y: 0)],
      );
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [circuit],
      );
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = _vr05Results(container);
      expect(results, hasLength(1));
      expect(results.first.elementId, equals('circuit-far'));
    });
  });

  // ── Multiple circuits ──────────────────────────────────────────────────────

  group('VR-05 — multiple circuits mixed', () {
    test('VR05-9: one connected and one disconnected → one error for the disconnected', () {
      final connected = createTestCircuit(
        id: 'c-connected',
        supplyRoutePath: [const Point2D(x: 10, y: 10)],
      );
      final disconnected = createTestCircuit(
        id: 'c-disconnected',
        supplyRoutePath: [const Point2D(x: 3000, y: 3000)],
      );
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [connected, disconnected],
      );
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = _vr05Results(container);
      expect(results, hasLength(1));
      expect(results.first.elementId, equals('c-disconnected'));
    });

    test('VR05-10: two disconnected circuits → two errors', () {
      final c1 = createTestCircuit(
        id: 'c1',
        supplyRoutePath: [const Point2D(x: 500, y: 0)],
      );
      final c2 = createTestCircuit(
        id: 'c2',
        supplyRoutePath: [],
      );
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [c1, c2],
      );
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final results = _vr05Results(container);
      expect(results, hasLength(2));
      expect(results.map((r) => r.elementId), containsAll(['c1', 'c2']));
    });
  });

  // ── Suggested fix and metadata ─────────────────────────────────────────────

  group('VR-05 — result metadata', () {
    test('VR05-11: error has suggestedFix containing "Route Pipe"', () {
      final circuit = createTestCircuit(supplyRoutePath: []);
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [circuit],
      );
      final container = _containerWith(state);
      addTearDown(container.dispose);

      final result = _vr05Results(container).first;
      expect(result.suggestedFix, isNotNull);
      expect(result.suggestedFix, contains('Route Pipe'));
    });

    test('VR05-12: error elementType is "circuit"', () {
      final circuit = createTestCircuit(supplyRoutePath: []);
      final state = EditorState(
        distributor: _distAtOrigin,
        circuits: [circuit],
      );
      final container = _containerWith(state);
      addTearDown(container.dispose);

      expect(_vr05Results(container).first.elementType, equals('circuit'));
    });
  });
}
