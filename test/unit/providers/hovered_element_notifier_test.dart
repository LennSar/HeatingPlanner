// Unit tests for HoveredElementNotifier and hoveredElementProvider.
//
// Per agent-test.md §3.1. Uses ProviderContainer directly — no widget pump
// needed. Confirms that set() and clear() update state as documented.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/ui/providers/selection_provider.dart';

void main() {
  group('HoveredElementNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    // ── Initial state ──────────────────────────────────────────────────────────

    test('HE-1: initial state is null', () {
      expect(container.read(hoveredElementProvider), isNull);
    });

    // ── set() ──────────────────────────────────────────────────────────────────

    test('HE-2: set() updates state to the given element', () {
      container.read(hoveredElementProvider.notifier).set(
            const SelectedElement(type: 'circuit', id: 'circuit-42'),
          );

      final state = container.read(hoveredElementProvider);
      expect(state, isNotNull);
      expect(state!.type, equals('circuit'));
      expect(state.id, equals('circuit-42'));
    });

    test('HE-3: set() with a different element overwrites the previous one', () {
      container.read(hoveredElementProvider.notifier).set(
            const SelectedElement(type: 'wall', id: 'wall-1'),
          );
      container.read(hoveredElementProvider.notifier).set(
            const SelectedElement(type: 'zone', id: 'zone-99'),
          );

      final state = container.read(hoveredElementProvider);
      expect(state!.type, equals('zone'));
      expect(state.id, equals('zone-99'));
    });

    // ── clear() ────────────────────────────────────────────────────────────────

    test('HE-4: clear() resets state to null', () {
      container.read(hoveredElementProvider.notifier).set(
            const SelectedElement(type: 'distributor', id: 'dist-1'),
          );
      container.read(hoveredElementProvider.notifier).clear();

      expect(container.read(hoveredElementProvider), isNull);
    });

    test('HE-5: clear() on already-null state stays null (no error)', () {
      expect(container.read(hoveredElementProvider), isNull);
      container.read(hoveredElementProvider.notifier).clear();
      expect(container.read(hoveredElementProvider), isNull);
    });

    // ── Element types ──────────────────────────────────────────────────────────

    test('HE-6: all domain element types can be stored', () {
      const types = ['wall', 'room', 'zone', 'circuit', 'distributor'];
      for (final type in types) {
        container.read(hoveredElementProvider.notifier).set(
              SelectedElement(type: type, id: 'id-$type'),
            );
        final state = container.read(hoveredElementProvider);
        expect(state!.type, equals(type), reason: 'Failed for type: $type');
        expect(state.id, equals('id-$type'));
      }
    });
  });
}
