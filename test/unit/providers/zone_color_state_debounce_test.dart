// ADR-024 debounce contract for [zoneColorStatesProvider].
//
// The zone-colour map is derived from the expensive EN 12831 demand /
// output providers. During a continuous interaction the trigger fires many
// times per second (a project-settings temperature slider invalidates every
// room's demand per tick). The provider must collapse those bursts into a
// single recompute:
//
//   (a) The heavy demand / output providers are evaluated O(1) times across
//       an N-tick burst, not O(N).
//   (b) Mid-burst the map keeps its pre-burst value (no per-tick churn).
//   (c) After the debounce settles the map equals the colour computed
//       directly from the *final* demand / output values — i.e. the
//       committed result is never stale.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heating_planner/calculation/providers/heat_demand_providers.dart';
import 'package:heating_planner/calculation/providers/heat_output_providers.dart';
import 'package:heating_planner/calculation/providers/project_settings_provider.dart';
import 'package:heating_planner/data/database/daos/heating_dao.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/repositories/heating_repository.dart';
import 'package:heating_planner/ui/canvas/painters/heating_zone_painter.dart'
    show ZoneColorState;
import 'package:heating_planner/ui/providers/editor_state_provider.dart';
import 'package:heating_planner/ui/providers/zone_color_state_provider.dart';

/// No-op heating DAO so `addZone` / `addCircuit` / `setDistributor`
/// `unawaited(upsert…)` calls resolve without a real database.
class _NoopHeatingDao implements HeatingDao {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  // A single zone served by a route-connected circuit, so the colour
  // depends purely on the demand-vs-output comparison (priorities 3–5).
  const zone = HeatingZone(
    id: 'zone-1',
    roomId: 'room-1',
    polygon: [
      Point2D(x: 0, y: 0),
      Point2D(x: 1000, y: 0),
      Point2D(x: 1000, y: 1000),
      Point2D(x: 0, y: 1000),
    ],
    tubeTypeId: 'tube-1',
    flooringMaterialId: 'mat-1',
    circuitId: 'circuit-1',
  );
  const distributor = Distributor(
    id: 'dist-1',
    floorId: 'floor-1',
    position: Point2D(x: 500, y: 500),
  );
  const circuit = HeatingCircuit(
    id: 'circuit-1',
    distributorId: 'dist-1',
    heatingZoneId: 'zone-1',
    supplyRoutePath: [Point2D(x: 500, y: 500)],
  );

  /// Builds a container whose demand provider is instrumented to (a) count
  /// its evaluations and (b) react to [designOutdoorTempCProvider] exactly
  /// like the real provider — so a temperature burst *would* recompute it
  /// O(N) times if [zoneColorStatesProvider] still watched it. Output is a
  /// fixed positive value (also counted).
  ///
  /// Zone area is 1.0 m², so the colour is decided by
  /// `output × 1.0` vs `demand`. We map outdoor temperature to demand such
  /// that a warmer outdoor temp lowers demand and flips the colour from
  /// insufficient (cold) to sufficient (warm).
  ProviderContainer makeContainer({
    required List<int> demandEvalCount,
    required List<int> outputEvalCount,
  }) {
    final container = ProviderContainer(
      overrides: [
        heatingDaoProvider.overrideWithValue(_NoopHeatingDao()),
        roomHeatDemandProvider.overrideWith((ref, roomId) {
          demandEvalCount[0]++;
          // Real provider reacts to the outdoor design temp; replicate that
          // so the burst genuinely invalidates this provider each tick.
          final tOutdoor = ref.watch(designOutdoorTempCProvider);
          // Colder outdoor → higher demand. At t = -12 demand = 92 W;
          // at t = +8 demand = 72 W; at t = +10 demand = 70 W. Output is
          // 70 W (see below), so the colour climbs from insufficient
          // (cold) through marginal to sufficient as it warms.
          return 80.0 - tOutdoor;
        }),
        zoneHeatOutputProvider.overrideWith((ref, zoneId) {
          outputEvalCount[0]++;
          return 70.0; // W/m²; × 1.0 m² area = 70 W total output
        }),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(editorStateProvider.notifier);
    notifier.setDistributor(distributor);
    notifier.addCircuit(circuit);
    notifier.addZone(zone);
    return container;
  }

  test(
      'N-tick temperature burst evaluates demand/output O(1), not O(N), '
      'and the map stays at its pre-burst value mid-burst', () async {
    final demandEvals = [0];
    final outputEvals = [0];
    final container = makeContainer(
      demandEvalCount: demandEvals,
      outputEvalCount: outputEvals,
    );
    final settings = container.read(projectSettingsProvider.notifier);

    // Keep an active listener, exactly as the canvas does in production:
    // the debounce only schedules its timer when build() re-runs, which
    // requires the provider to be listened (eagerly rebuilt) rather than
    // merely read.
    container.listen(zoneColorStatesProvider, (_, __) {});

    // First synchronous build at the default outdoor temp (-12 °C):
    // demand = 80 - (-12) = 92 W vs output 70 W → ratio 0.76 → insufficient.
    final initial = container.read(zoneColorStatesProvider);
    expect(initial['zone-1'], ZoneColorState.insufficient);
    expect(demandEvals[0], 1, reason: 'one demand eval on first build');
    expect(outputEvals[0], 1, reason: 'one output eval on first build');

    // Simulate a 10-tick slider sweep toward a warm outdoor temp.
    for (var i = 1; i <= 10; i++) {
      settings.setDesignOutdoorTempCTransient(-12.0 + i * 2.0);
    }

    // Mid-burst (before the debounce fires) the colour map is unchanged and
    // the heavy providers have not been re-evaluated: the burst only
    // rescheduled the trailing timer.
    expect(container.read(zoneColorStatesProvider)['zone-1'],
        ZoneColorState.insufficient,
        reason: 'colours hold their settled value during the burst');
    expect(demandEvals[0], 1,
        reason: 'demand NOT re-evaluated per tick (O(1), not O(N))');
    expect(outputEvals[0], 1, reason: 'output NOT re-evaluated per tick');

    // Let the trailing debounce fire.
    await Future<void>.delayed(
      zoneColorDebounceDuration + const Duration(milliseconds: 50),
    );

    // Final outdoor temp = -12 + 20 = +8 °C → demand = 80 - 8 = 72 W vs
    // output 70 W → ratio 0.97 → marginal.
    expect(container.read(zoneColorStatesProvider)['zone-1'],
        ZoneColorState.marginal,
        reason: 'settled colour reflects the final, committed temperature');
    // The whole 10-tick burst caused exactly ONE extra demand evaluation
    // (it is invalidated each tick but only re-read once, at debounce-fire),
    // i.e. O(1) not O(11). Output is never invalidated, so it stays cached.
    expect(demandEvals[0], 2,
        reason: 'one demand eval for the whole burst (O(1))');
    expect(outputEvals[0], 1, reason: 'output cached — never recomputed');
  });

  test('settled map matches the colour computed directly at the final value',
      () async {
    final demandEvals = [0];
    final outputEvals = [0];
    final container = makeContainer(
      demandEvalCount: demandEvals,
      outputEvalCount: outputEvals,
    );
    final settings = container.read(projectSettingsProvider.notifier);
    container.listen(zoneColorStatesProvider, (_, __) {}); // canvas-like

    // Drive a burst that settles at the warmest allowed outdoor temp
    // (+10 °C, the slider clamp): demand = 80 - 10 = 70 W vs output 70 W →
    // ratio 1.0 → sufficient.
    for (var i = 1; i <= 5; i++) {
      settings.setDesignOutdoorTempCTransient(i * 2.0);
    }
    await Future<void>.delayed(
      zoneColorDebounceDuration + const Duration(milliseconds: 50),
    );

    // Independently compute the expected colour from the final demand /
    // output the provider would read now (the "non-debounced" reference).
    final demand = container.read(roomHeatDemandProvider('room-1'));
    final output = container.read(zoneHeatOutputProvider('zone-1'));
    final ratio = output * 1.0 / demand;
    final expected = ratio >= 1.0
        ? ZoneColorState.sufficient
        : ratio >= 0.9
            ? ZoneColorState.marginal
            : ZoneColorState.insufficient;

    expect(container.read(zoneColorStatesProvider)['zone-1'], expected);
    expect(expected, ZoneColorState.sufficient);
  });
}
