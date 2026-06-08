import 'dart:async' show Timer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/providers/heat_demand_providers.dart';
import '../../calculation/providers/heat_output_providers.dart';
import '../../calculation/providers/project_settings_provider.dart';
import '../canvas/painters/heating_zone_painter.dart' show ZoneColorState;
import 'editor_state_provider.dart';

/// Trailing-debounce window for the [zoneColorStatesProvider] recompute
/// (ADR-024). A continuous interaction — a zone drag, or a project-settings
/// temperature / floor-height slider sweep — fires its trigger many times
/// per second; collapsing the bursts into a single recompute this far after
/// the last change keeps the heavy EN 12831 heat-load graph off the hot
/// path while the user is still moving.
const Duration zoneColorDebounceDuration = Duration(milliseconds: 100);

/// ADR-004 / ADR-024 display state for every heating zone on the active
/// floor.
///
/// Derives a `Map<zoneId, ZoneColorState>` from [editorStateProvider] plus
/// the upstream heat-demand and heat-output providers.
///
/// **ADR-024 — debounced recompute.** The colour result is expensive: each
/// zone reads [roomHeatDemandProvider] (the full EN 12831 transmission +
/// ventilation graph) and [zoneHeatOutputProvider]. During a continuous
/// interaction the trigger fires every frame/tick — a zone drag mutates
/// [editorStateProvider]; a project-settings temperature slider mutates
/// [designOutdoorTempCProvider], which invalidates *every* room's demand.
/// Recomputing the colour map on each tick reran that graph many times per
/// second even though only the settled value affects the colours.
///
/// This notifier therefore **watches only the cheap trigger signals**
/// (editor state + the project-settings temperatures / floor height) and
/// **reads — never watches —** the heavy demand / output providers. Because
/// nothing subscribes to those providers during a burst they are not
/// eagerly recomputed each tick; they are evaluated once, lazily, when the
/// debounced [_compute] reads them after the interaction settles. The first
/// build computes synchronously so the canvas paints correct colours
/// immediately at rest / on load; every subsequent trigger schedules a
/// trailing [zoneColorDebounceDuration] timer and keeps the previous map
/// (same instance → no spurious canvas rebuild) until the timer fires.
///
/// Geometry still renders live every frame: the canvas watches
/// [editorStateProvider] directly for wall / room / zone outlines and does
/// not depend on this notifier for shape — only for fill colour.
///
/// Priority order (strict, mirrors ADR-004 / DECISIONS.md):
///  1. No circuit assigned → [ZoneColorState.unconnected] (red hatched).
///  1b. Circuit's supply route does not reach the distributor → same.
///  2. Room demand is NaN (incomplete data) → [ZoneColorState.noDemand].
///  3–5. Compare `output × area` to demand:
///       - ≥ 100 % → [ZoneColorState.sufficient]
///       - ≥ 90 %  → [ZoneColorState.marginal]
///       - <  90 % → [ZoneColorState.insufficient]
class ZoneColorStatesNotifier
    extends Notifier<Map<String, ZoneColorState>> {
  Timer? _debounce;
  Map<String, ZoneColorState> _last = const {};
  bool _initialised = false;

  @override
  Map<String, ZoneColorState> build() {
    // Cheap trigger watches. A change to any of these reruns build(); the
    // heavy demand / output providers are deliberately *not* watched so a
    // burst on these triggers does not keep them subscribed (and therefore
    // does not recompute them) — see the class doc.
    ref.watch(editorStateProvider);
    ref.watch(designOutdoorTempCProvider);
    ref.watch(defaultIndoorTempCProvider);
    ref.watch(unheatedSpaceTempCProvider);
    ref.watch(floorHeightMmProvider);

    ref.onDispose(() {
      _debounce?.cancel();
      _debounce = null;
    });

    if (!_initialised) {
      // First build: compute synchronously so colours are correct at rest
      // and the canvas does not flash uncoloured for a debounce window.
      _initialised = true;
      _last = _compute();
      return _last;
    }

    // A trigger changed → debounce the heavy recompute. Keep the previous
    // map (returned below, same instance so listeners are not notified)
    // until the trailing timer fires with the settled value.
    _debounce?.cancel();
    _debounce = Timer(zoneColorDebounceDuration, () {
      _last = _compute();
      state = _last;
    });
    return _last;
  }

  /// Runs the ADR-004 priority machine over the current state, reading the
  /// heavy demand / output providers exactly once each.
  ///
  /// Uses [Ref.read] throughout: this runs both during the synchronous
  /// first build and from the debounce timer callback (outside a build),
  /// so it must not establish provider subscriptions.
  Map<String, ZoneColorState> _compute() {
    final state = ref.read(editorStateProvider);
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
      final demandW = ref.read(roomHeatDemandProvider(zone.roomId));
      if (demandW.isNaN) {
        result[zone.id] = ZoneColorState.noDemand;
        continue;
      }

      // Specific heat output (W/m²). Falls back to unconnected if it
      // cannot be determined (e.g. distributor not yet configured).
      final specificOutput = ref.read(zoneHeatOutputProvider(zone.id));
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
  }
}

/// Debounced map of `zoneId → ZoneColorState` for the active floor.
///
/// See [ZoneColorStatesNotifier] for the debounce contract (ADR-024).
final zoneColorStatesProvider = NotifierProvider<ZoneColorStatesNotifier,
    Map<String, ZoneColorState>>(ZoneColorStatesNotifier.new);

// [1]: lib/ui/canvas/floor_plan_canvas.dart `_interactionState`
