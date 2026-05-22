import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/providers/heat_demand_providers.dart';
import '../../calculation/providers/heat_output_providers.dart';
import '../canvas/painters/heating_zone_painter.dart' show ZoneColorState;
import 'editor_state_provider.dart';

/// ADR-004 display state for every heating zone on the active floor.
///
/// Derives a `Map<zoneId, ZoneColorState>` from [editorStateProvider] plus
/// the upstream heat-demand and heat-output providers. Riverpod memoises the
/// result, so the map is rebuilt only when one of those dependencies
/// changes — *not* on every canvas rebuild. Pointer hover and drag, which
/// no longer cause widget rebuilds (see the [`ValueNotifier`][1] in
/// `floor_plan_canvas.dart`), are insulated from this work entirely.
///
/// Priority order (strict, mirrors ADR-004 / DECISIONS.md):
///  1. No circuit assigned → [ZoneColorState.unconnected] (red hatched).
///  1b. Circuit's supply route does not reach the distributor → same.
///  2. Room demand is NaN (incomplete data) → [ZoneColorState.noDemand].
///  3–5. Compare `output × area` to demand:
///       - ≥ 100 % → [ZoneColorState.sufficient]
///       - ≥ 90 %  → [ZoneColorState.marginal]
///       - <  90 % → [ZoneColorState.insufficient]
final zoneColorStatesProvider =
    Provider<Map<String, ZoneColorState>>((ref) {
  final state = ref.watch(editorStateProvider);
  final result = <String, ZoneColorState>{};

  // O(1) circuit lookup; avoids O(zones × circuits) for the route-connected
  // check below.
  final circuitById = {for (final c in state.circuits) c.id: c};
  final distributor = state.distributor;

  for (final zone in state.zones) {
    // Priority 1: no circuit assigned → red hatched.
    if (zone.circuitId == null) {
      result[zone.id] = ZoneColorState.unconnected;
      continue;
    }

    // Priority 1b: circuit route not connected to the distributor
    // (mirrors VR-05). Catches the case where the distributor was
    // moved but circuitId was not yet cleared, leaving the zone with
    // a stale circuit reference whose route no longer reaches the
    // manifold.
    final circuit = circuitById[zone.circuitId];
    final bool routeConnected = circuit != null &&
        circuit.supplyRoutePath.isNotEmpty &&
        distributor != null &&
        GeometryEngine.distanceMm(
              circuit.supplyRoutePath.first,
              distributor.position,
            ) <=
            50.0;
    if (!routeConnected) {
      result[zone.id] = ZoneColorState.unconnected;
      continue;
    }

    // Priority 2: room demand is NaN (incomplete data, e.g. an exterior
    // wall has no construction) → grey. This check MUST come before the
    // output check so a valid output value cannot mask missing demand
    // data.
    final demandW = ref.watch(roomHeatDemandProvider(zone.roomId));
    if (demandW.isNaN) {
      result[zone.id] = ZoneColorState.noDemand;
      continue;
    }

    // Specific heat output (W/m²). Falls back to unconnected if it
    // cannot be determined (e.g. distributor not yet configured).
    final specificOutput = ref.watch(zoneHeatOutputProvider(zone.id));
    if (specificOutput.isNaN) {
      result[zone.id] = ZoneColorState.unconnected;
      continue;
    }

    final areaM2 = zone.polygon.length >= 3
        ? GeometryEngine.polygonAreaM2(zone.polygon)
        : 0.0;
    if (areaM2 <= 0) {
      result[zone.id] = ZoneColorState.unconnected;
      continue;
    }

    final totalOutputW = specificOutput * areaM2;

    // Genuinely zero demand (e.g. interior room with equal adjacent
    // temperatures): no heating needed, so the zone is sufficient.
    if (demandW <= 0) {
      result[zone.id] = ZoneColorState.sufficient;
      continue;
    }

    // Priorities 3–5: compare output to demand.
    final ratio = totalOutputW / demandW;
    result[zone.id] = ratio >= 1.0
        ? ZoneColorState.sufficient
        : ratio >= 0.9
            ? ZoneColorState.marginal
            : ZoneColorState.insufficient;
  }

  return result;
});

// [1]: lib/ui/canvas/floor_plan_canvas.dart `_interactionState`
