// Widget tests for the connection-pipe distances in CircuitProperties
// (ADR-040 Rule 4).
//
//   CP-1  the three distances are shown
//   CP-2  wall distance: stored and applied to the route
//   CP-3  pipe spacing: stored and applied to both pipes
//   CP-4  zone distance: stored, pipes unchanged
//   CP-5  out-of-range input is rejected
//   CP-6  "Swap supply and return" trades the pipes (ADR-041)
//
// Heavy providers are overridden with stubs — no database access.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/flow_rate_providers.dart';
import 'package:heating_planner/calculation/providers/heat_demand_providers.dart';
import 'package:heating_planner/calculation/providers/heat_output_providers.dart';
import 'package:heating_planner/calculation/providers/pipe_layout_providers.dart';
import 'package:heating_planner/calculation/providers/pressure_loss_providers.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/repositories/heating_repository.dart';
import 'package:heating_planner/ui/panels/properties_panel.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Stub notifiers ────────────────────────────────────────────────────────────

/// Stub [SelectedElementNotifier] that always returns a fixed selection.
class _StubSelectionNotifier extends SelectedElementNotifier {
  _StubSelectionNotifier(this._fixed);
  final SelectedElement? _fixed;

  @override
  SelectedElement? build() => _fixed;
}

/// Stub [EditorStateNotifier] that works purely in memory — no DB access.
class _StubEditorNotifier extends EditorStateNotifier {
  _StubEditorNotifier(this._initial);
  final EditorState _initial;

  @override
  EditorState build() => _initial;

  @override
  void updateRoom(Room room) {
    state = state.copyWith(
      rooms: state.rooms.map((r) => r.id == room.id ? room : r).toList(),
    );
  }

  @override
  void updateZone(HeatingZone zone) {
    state = state.copyWith(
      zones: state.zones.map((z) => z.id == zone.id ? zone : z).toList(),
    );
  }

  @override
  void updateCircuit(HeatingCircuit circuit) {
    state = state.copyWith(
      circuits: state.circuits
          .map((c) => c.id == circuit.id ? circuit : c)
          .toList(),
    );
  }

  @override
  void markProjectDirty() {}
}

// ── Shared test data ──────────────────────────────────────────────────────────

// Wall along y = 0, 200 mm thick: its face is at y = 100.
const _wall = WallSegment(
  id: 'wall-1',
  roomId: 'room-1',
  startPoint: Point2D(x: 0, y: 0),
  endPoint: Point2D(x: 8000, y: 0),
  thicknessMm: 200,
);

const _zone = HeatingZone(
  id: 'zone-1',
  roomId: 'room-1',
  tubeTypeId: 'tube-1',
  flooringMaterialId: 'floor-mat-1',
  circuitId: 'circuit-1',
  polygon: [
    Point2D(x: 3000, y: 150),
    Point2D(x: 7000, y: 150),
    Point2D(x: 7000, y: 4000),
    Point2D(x: 3000, y: 4000),
  ],
);

/// A pair of connection pipes running along the wall into the zone, laid
/// out with the default distances (100 / 100 / 100 mm).
HeatingCircuit _circuit() => relaidConnectionPipes(
  const HeatingCircuit(
    id: 'circuit-1',
    distributorId: 'dist-1',
    heatingZoneId: 'zone-1',
  ),
  const [_wall],
  centerline: const [
    Point2D(x: 1000, y: 1000),
    Point2D(x: 1000, y: 250),
    Point2D(x: 4000, y: 250),
  ],
);

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _buildPanel({
  required SelectedElement? selection,
  required EditorState editorState,
}) {
  return ProviderScope(
    overrides: [
      selectedElementProvider.overrideWith(
        () => _StubSelectionNotifier(selection),
      ),
      editorStateProvider.overrideWith(() => _StubEditorNotifier(editorState)),
      // Calculation providers — return NaN / empty so rows show "—"
      roomHeatDemandProvider.overrideWith((ref, _) => double.nan),
      roomHeatDemandBreakdownProvider.overrideWith(
        (ref, _) => (
          transmissionW: double.nan,
          floorW: double.nan,
          ceilingW: double.nan,
          ventilationW: double.nan,
          totalW: double.nan,
        ),
      ),
      zoneHeatOutputProvider.overrideWith((ref, _) => double.nan),
      zoneSurfaceTempProvider.overrideWith((ref, _) => double.nan),
      flowRateProvider.overrideWith((ref, _) => double.nan),
      flowVelocityProvider.overrideWith((ref, _) => double.nan),
      pressureLossProvider.overrideWith((ref, _) async => double.nan),
      // Stream providers — return empty lists
      tubeTypesProvider.overrideWith((ref) => Stream.value([])),
      flooringMaterialsProvider.overrideWith((ref) => Stream.value([])),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: const Scaffold(body: PropertiesPanel()),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildPanel(
        selection: const SelectedElement(type: 'circuit', id: 'circuit-1'),
        editorState: EditorState(
          circuits: [_circuit()],
          zones: const [_zone],
          walls: const [_wall],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(PropertiesPanel)),
    );
  }

  HeatingCircuit current(ProviderContainer c) =>
      c.read(editorStateProvider).circuits.single;

  testWidgets(
    'CP-1: selecting a circuit shows its three connection-pipe distances',
    (tester) async {
      await pump(tester);

      expect(find.text('Connection pipes'), findsOneWidget);
      expect(find.text('Distance between supply and return'), findsOneWidget);
      expect(find.text('Distance to heating zones'), findsOneWidget);
      expect(find.text('Distance to walls'), findsOneWidget);
      for (final key in const [
        'circuit-pipe-spacing',
        'circuit-zone-clearance',
        'circuit-wall-clearance',
      ]) {
        expect(tester.widget<TextField>(_field(key)).controller!.text, '100');
      }
    },
  );

  testWidgets(
    'CP-2: a new wall distance is stored and applied to the route at once',
    (tester) async {
      final container = await pump(tester);
      expect(current(container).centerlinePath[1].y, 250.0);

      await tester.enterText(_field('circuit-wall-clearance'), '300');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final c = current(container);
      expect(c.wallClearanceMm, 300);
      // face 100 + distance 300 + half spacing 50.
      expect(c.centerlinePath[1].y, 450.0);
      expect(c.centerlinePath[2].y, 450.0);
    },
  );

  testWidgets('CP-3: a new pipe spacing moves supply and return apart', (
    tester,
  ) async {
    final container = await pump(tester);

    await tester.enterText(_field('circuit-pipe-spacing'), '200');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final c = current(container);
    expect(c.pipeSpacingMm, 200);
    final supplyY = c.supplyRoutePath[2].y;
    final returnY = c.returnRoutePath[1].y;
    expect((supplyY - returnY).abs(), 200.0);
  });

  testWidgets('CP-4: a new zone distance is stored without moving the pipes', (
    tester,
  ) async {
    final container = await pump(tester);
    final before = current(container);

    await tester.enterText(_field('circuit-zone-clearance'), '250');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final c = current(container);
    expect(c.zoneClearanceMm, 250);
    expect(c.centerlinePath, before.centerlinePath);
    expect(c.supplyRoutePath, before.supplyRoutePath);
  });

  testWidgets(
    'CP-5: a value outside the allowed range is rejected with the range '
    'shown',
    (tester) async {
      final container = await pump(tester);
      final before = current(container);

      await tester.enterText(_field('circuit-pipe-spacing'), '5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('30–500 mm'), findsOneWidget);
      expect(current(container), before);
    },
  );

  testWidgets(
    'CP-6: "Swap supply and return" trades the two pipes and keeps the '
    'route',
    (tester) async {
      final container = await pump(tester);
      final before = current(container);

      await tester.tap(
        find.byKey(const ValueKey('circuit-swap-supply-return')),
      );
      await tester.pumpAndSettle();

      final c = current(container);
      expect(c.supplyOnRight, isTrue);
      expect(c.centerlinePath, before.centerlinePath);
      expect(c.supplyRoutePath, before.returnRoutePath.reversed);
      expect(c.returnRoutePath, before.supplyRoutePath.reversed);

      await tester.tap(
        find.byKey(const ValueKey('circuit-swap-supply-return')),
      );
      await tester.pumpAndSettle();
      expect(current(container), before);
    },
  );

  testWidgets(
    'CP-7: panel edits are undo steps — undo restores the pipes, redo '
    'applies the change again (ADR-042)',
    (tester) async {
      final container = await pump(tester);
      final before = current(container);
      final undo = container.read(undoRedoProvider);

      await tester.enterText(_field('circuit-wall-clearance'), '300');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final changed = current(container);
      expect(changed.wallClearanceMm, 300);

      await tester.tap(
        find.byKey(const ValueKey('circuit-swap-supply-return')),
      );
      await tester.pumpAndSettle();
      expect(current(container).supplyOnRight, isTrue);

      undo.undo(); // the swap
      expect(current(container), changed);
      undo.undo(); // the wall distance
      expect(current(container), before);
      undo.redo();
      expect(current(container), changed);
    },
  );
}
