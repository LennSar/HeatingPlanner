import 'dart:math' show min, max;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calculation/engines/geometry_engine.dart';
import '../calculation/providers/heat_output_providers.dart';
import '../calculation/providers/hydraulic_balance_providers.dart';
import '../calculation/providers/tube_length_providers.dart';
import '../core/constants/validation_limits.dart';
import '../data/models/enums.dart';
import '../data/models/validation_result.dart';
import '../ui/providers/editor_state_provider.dart';
import '../ui/providers/transient_warnings_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Runs all validation rules for the active editor state and returns a flat
/// list of [ValidationResult] items ordered by severity (errors first).
///
/// Watches [editorStateProvider] so it rebuilds whenever the canvas changes.
///
/// The [projectId] parameter is accepted for forward-compatibility with the
/// architect's provider registry (Section 6.2). When the project-repository
/// layer is complete, this provider will be scoped to a real project UUID.
/// Until then the parameter is ignored and all rules operate on the in-memory
/// [editorStateProvider].
///
/// Currently implemented rules:
/// - **HB-01** Hydraulic length imbalance: longest circuit > 1.5 × shortest
///   circuit on the same distributor → [WarningSeverity.warning] on both
///   the distributor element and each circuit that needs significant
///   balancing.
/// - **VR-01** Exterior wall missing construction assignment.
/// - **VR-02** EN 1264 surface temperature limit exceeded.
/// - **VR-03** Heating circuit tube length exceeds hydraulic maximum.
/// - **VR-04** Heating zone not connected to any circuit.
/// - **VR-05** Circuit supply route not connected to the distributor.
/// - **GE-01** Two room-assigned wall segments are geometrically coincident
///   (overlapping walls).
final validationResultsProvider =
    Provider.family<List<ValidationResult>, String>(
  (ref, projectId) {
    final results = <ValidationResult>[];
    results.addAll(_hydraulicImbalanceResults(ref));
    results.addAll(_missingConstructionResults(ref));
    results.addAll(_surfaceTempResults(ref));
    results.addAll(_circuitLengthResults(ref));
    results.addAll(_unconnectedZoneResults(ref));
    results.addAll(_disconnectedCircuitResults(ref));
    results.addAll(_overlappingWallResults(ref));
    // ADR-017 Rule 8d: shared-wall promotion conflicts emitted by
    // EditorStateNotifier.addRoomFromDetection are picked up here so
    // they appear alongside derived rules without blocking promotion.
    results.addAll(ref.watch(transientWarningsProvider));
    // Sort: errors before warnings before info.
    results.sort(
      (a, b) => a.severity.index.compareTo(b.severity.index),
    );
    return results;
  },
);

// ── Rule HB-01: Hydraulic length imbalance ────────────────────────────────────

/// Returns [ValidationResult]s for circuits whose tube length diverges beyond
/// [maxCircuitLengthImbalanceRatio] relative to the longest circuit on the
/// same distributor.
///
/// Algorithm:
/// 1. Collect all circuits from [editorStateProvider].
/// 2. Resolve each circuit's total tube length via [tubeLengthProvider].
/// 3. Compute min / max lengths; if max / min ≤ threshold → no issue.
/// 4. Fetch required valve throttling from [hydraulicBalanceProvider];
///    while the async result is still loading the valve Pa values default
///    to null and the suggested fix omits the valve-setting figure.
/// 5. Emit one distributor-level warning (overview) and one per-circuit
///    warning for every circuit that needs more than
///    [significantValveSettingPa] of throttling.
List<ValidationResult> _hydraulicImbalanceResults(Ref ref) {
  final state = ref.watch(editorStateProvider);
  final distributor = state.distributor;
  final circuits = state.circuits;

  if (distributor == null || circuits.length < 2) return const [];

  // Resolve tube lengths; skip circuits whose length is not yet available.
  final lengths = <String, double>{};
  for (final circuit in circuits) {
    final len = ref.watch(tubeLengthProvider(circuit.id));
    if (!len.isNaN && len > 0) lengths[circuit.id] = len;
  }
  if (lengths.length < 2) return const [];

  final minLen = lengths.values.reduce(min);
  final maxLen = lengths.values.reduce(max);

  if (maxLen / minLen <= maxCircuitLengthImbalanceRatio) return const [];

  // Retrieve valve Δp values; null while hydraulicBalanceProvider is loading.
  final valveSettings =
      ref.watch(hydraulicBalanceProvider(distributor.id)).asData?.value ??
          const <String, double>{};

  final results = <ValidationResult>[];

  // Distributor-level overview warning.
  results.add(
    ValidationResult(
      severity: WarningSeverity.warning,
      elementId: distributor.id,
      elementType: 'distributor',
      message: 'Circuit lengths on this distributor vary by more than '
          '$maxCircuitLengthImbalanceRatio× '
          '(shortest: ${minLen.toStringAsFixed(0)} m, '
          'longest: ${maxLen.toStringAsFixed(0)} m). '
          'Without balancing, shorter circuits will carry more flow '
          'than designed.',
      suggestedFix: 'Option 1: Add balancing valves '
          '(Strangregulierventile) to throttle the shorter circuits. '
          'Option 2: Redesign the layout so all circuits are within '
          '${((maxCircuitLengthImbalanceRatio - 1) * 100).toStringAsFixed(0)}% '
          'of the longest circuit length '
          '(target ≥ ${(maxLen / maxCircuitLengthImbalanceRatio).toStringAsFixed(0)} m).',
    ),
  );

  // Per-circuit warnings for every circuit that needs significant throttling.
  for (final circuit in circuits) {
    final len = lengths[circuit.id];
    if (len == null) continue;

    final valvePa = valveSettings[circuit.id];
    // Reference circuit has valvePa == 0; circuits not yet resolved have null.
    if (valvePa == null || valvePa < significantValveSettingPa) continue;

    final valveKPa = valvePa / 1000;
    results.add(
      ValidationResult(
        severity: WarningSeverity.warning,
        elementId: circuit.id,
        elementType: 'circuit',
        message: 'Circuit length ${len.toStringAsFixed(0)} m is '
            'significantly shorter than the longest circuit '
            '(${maxLen.toStringAsFixed(0)} m) on the same distributor. '
            'Without balancing this circuit will carry excess flow, '
            'reducing output in longer circuits.',
        suggestedFix: 'Option 1: Install a balancing valve set to '
            '${valveKPa.toStringAsFixed(1)} kPa throttling on this '
            'circuit. '
            'Option 2: Increase the circuit pipe length to approximately '
            '${maxLen.toStringAsFixed(0)} m by adding more heating area '
            'or rerouting supply/return runs.',
      ),
    );
  }

  return results;
}

// ── Rule VR-01: Missing wall construction ─────────────────────────────────────

/// Returns [ValidationResult]s for exterior [WallSegment]s that have no
/// [WallSegment.constructionId] assigned.
///
/// Without a construction the thermal engine cannot compute a U-value, so
/// heat demand for the room cannot be calculated at all.
List<ValidationResult> _missingConstructionResults(Ref ref) {
  final state = ref.watch(editorStateProvider);
  final results = <ValidationResult>[];

  for (final wall in state.walls) {
    if (wall.wallType == WallType.exterior &&
        wall.constructionId == null) {
      results.add(
        ValidationResult(
          severity: WarningSeverity.error,
          elementId: wall.id,
          elementType: 'wall',
          message: 'Exterior wall has no construction assigned — '
              'heat demand cannot be calculated.',
          suggestedFix: 'Open wall properties and assign a wall '
              'construction.',
        ),
      );
    }
  }

  return results;
}

// ── Rule VR-02: EN 1264 surface temperature exceeded ─────────────────────────

/// Returns [ValidationResult]s for heating zones whose calculated mean
/// surface temperature exceeds the EN 1264 limit for their zone type.
///
/// Limits (from [validation_limits.dart]):
/// - Floor heating ([ZoneType.floorHeating]): ≤ [maxSurfaceTempOccupiedFloor]
///   (29 °C)
/// - Wall heating ([ZoneType.wallHeating]): ≤ [maxSurfaceTempWall] (40 °C)
///
/// Zones whose surface temperature is [double.nan] or ≤ 0 (not yet
/// calculable) are silently skipped.
List<ValidationResult> _surfaceTempResults(Ref ref) {
  final state = ref.watch(editorStateProvider);
  final results = <ValidationResult>[];

  for (final zone in state.zones) {
    final surfaceTemp = ref.watch(zoneSurfaceTempProvider(zone.id));

    if (surfaceTemp.isNaN || surfaceTemp <= 0) continue;

    final double limit = zone.zoneType == ZoneType.wallHeating
        ? maxSurfaceTempWall
        : maxSurfaceTempOccupiedFloor;

    if (surfaceTemp > limit) {
      results.add(
        ValidationResult(
          severity: WarningSeverity.warning,
          elementId: zone.id,
          elementType: 'zone',
          message: 'Floor surface temperature '
              '${surfaceTemp.toStringAsFixed(1)}°C exceeds EN 1264 '
              'limit of ${limit.toStringAsFixed(0)}°C for this zone '
              'type.',
          suggestedFix: 'Reduce supply temperature, increase tube '
              'spacing, or use a flooring material with lower thermal '
              'resistance.',
        ),
      );
    }
  }

  return results;
}

// ── Rule VR-03: Circuit length exceeded ──────────────────────────────────────

/// Returns [ValidationResult]s for heating circuits whose total tube length
/// exceeds the hydraulic maximum for the zone's tube outer diameter.
///
/// Thresholds (from [validation_limits.dart]):
/// - OD ≤ 14 mm → max [maxTubeLength12mm] (90 m)
/// - OD > 14 mm → max [maxTubeLength16mm] (120 m)
///
/// The tube OD is read from the zone's [HeatingZone.tubeTypeId] via
/// [editorStateProvider]. Because [EditorState] does not yet carry the full
/// [TubeType] catalogue, the outer diameter defaults to 16.0 mm (the spec
/// default) when the zone cannot be resolved.
///
/// Circuits whose [tubeLengthProvider] returns [double.nan] are skipped.
List<ValidationResult> _circuitLengthResults(Ref ref) {
  final state = ref.watch(editorStateProvider);
  final results = <ValidationResult>[];

  for (final circuit in state.circuits) {
    final tubeLength = ref.watch(tubeLengthProvider(circuit.id));
    if (tubeLength.isNaN) continue;

    // EditorState does not yet carry TubeType objects, so the OD
    // defaults to 16.0 mm (spec default — the most common tube size).
    // TODO(HVAC): resolve actual OD once state.tubeTypes is available.
    const double outerDiamMm = 16.0;

    const double maxLength = outerDiamMm <= 14.0
        ? maxTubeLength12mm
        : maxTubeLength16mm;

    if (tubeLength > maxLength) {
      results.add(
        ValidationResult(
          severity: WarningSeverity.warning,
          elementId: circuit.id,
          elementType: 'circuit',
          message: 'Circuit length ${tubeLength.toStringAsFixed(0)} m '
              'exceeds maximum of ${maxLength.toStringAsFixed(0)} m '
              'for ${outerDiamMm.toStringAsFixed(0)} mm OD tube.',
          suggestedFix: 'Split the zone into two smaller zones with '
              'separate circuits.',
        ),
      );
    }
  }

  return results;
}

// ── Rule VR-05: Circuit supply route not connected to distributor ─────────────

/// Returns [ValidationResult]s for [HeatingCircuit]s whose supply route is
/// either empty or does not start within 50 mm of the distributor's position.
///
/// A circuit whose [HeatingCircuit.supplyRoutePath] is empty has no drawn
/// route at all. A circuit whose first supply-route point is more than 50 mm
/// from [state.distributor.position] was drawn independently and is not
/// physically connected to the manifold.
///
/// If no distributor exists on the floor every circuit fails this check,
/// because there is no manifold to connect to.
List<ValidationResult> _disconnectedCircuitResults(Ref ref) {
  final state = ref.watch(editorStateProvider);
  final distributor = state.distributor;
  final results = <ValidationResult>[];

  for (final circuit in state.circuits) {
    final bool disconnected;
    if (distributor == null || circuit.supplyRoutePath.isEmpty) {
      disconnected = true;
    } else {
      final dist = GeometryEngine.distanceMm(
        circuit.supplyRoutePath.first,
        distributor.position,
      );
      disconnected = dist > 50.0;
    }

    if (disconnected) {
      results.add(
        ValidationResult(
          severity: WarningSeverity.error,
          elementId: circuit.id,
          elementType: 'circuit',
          message: 'Circuit supply route is not connected to the '
              'distributor.',
          suggestedFix: 'Use the Route Pipe tool to redraw this circuit '
              'from the distributor.',
        ),
      );
    }
  }

  return results;
}

// ── Rule GE-01: Overlapping (coincident) walls ────────────────────────────────

/// Returns [ValidationResult]s for pairs of room-assigned [WallSegment]s that
/// are geometrically coincident (same start/end points within 1 mm tolerance,
/// in either direction).
///
/// Overlapping walls indicate a data-integrity problem — typically caused by
/// drawing a rectangle on top of an existing room boundary — and prevent room
/// detection and heat-demand calculations from working correctly.
///
/// Only room-assigned walls (`roomId` non-empty) are checked. Unassigned walls
/// (not yet part of a room) are excluded because duplicate unassigned segments
/// are transient and harmless during drawing.
///
/// Each coincident *pair* emits one [ValidationResult] on the wall with the
/// lower-sorted ID so the same pair is never reported twice.
List<ValidationResult> _overlappingWallResults(Ref ref) {
  final state = ref.watch(editorStateProvider);
  const tol = 1.0; // mm

  // Only consider walls that belong to a room.
  final assigned = state.walls.where((w) => w.roomId.isNotEmpty).toList();
  final results = <ValidationResult>[];
  final reported = <String>{};

  for (var i = 0; i < assigned.length; i++) {
    final a = assigned[i];
    for (var j = i + 1; j < assigned.length; j++) {
      final b = assigned[j];

      final fwdMatch =
          GeometryEngine.distanceMm(a.startPoint, b.startPoint) <= tol &&
          GeometryEngine.distanceMm(a.endPoint, b.endPoint) <= tol;
      final revMatch =
          GeometryEngine.distanceMm(a.startPoint, b.endPoint) <= tol &&
          GeometryEngine.distanceMm(a.endPoint, b.startPoint) <= tol;

      if (!fwdMatch && !revMatch) continue;

      // Report on the wall with the lexicographically smaller ID so each
      // pair is emitted exactly once.
      final reportId = a.id.compareTo(b.id) <= 0 ? a.id : b.id;
      if (reported.add(reportId)) {
        results.add(
          ValidationResult(
            severity: WarningSeverity.error,
            elementId: reportId,
            elementType: 'wall',
            message: 'Two walls are stacked on top of each other at the '
                'same position. This causes incorrect room detection and '
                'heat-demand calculations.',
            suggestedFix: 'Delete one of the overlapping walls. Use the '
                'Select tool to click the wall and press Delete.',
          ),
        );
      }
    }
  }

  return results;
}

// ── Rule VR-04: Zone not connected to a circuit ───────────────────────────────

/// Returns [ValidationResult]s for [HeatingZone]s that have no circuit
/// connected ([HeatingZone.circuitId] == null).
///
/// A zone without a circuit produces no heat output and is excluded from
/// all hydraulic calculations.
List<ValidationResult> _unconnectedZoneResults(Ref ref) {
  final state = ref.watch(editorStateProvider);
  final results = <ValidationResult>[];

  for (final zone in state.zones) {
    if (zone.circuitId == null) {
      results.add(
        ValidationResult(
          severity: WarningSeverity.error,
          elementId: zone.id,
          elementType: 'zone',
          message: 'Heating zone has no circuit connected.',
          suggestedFix: 'Use the Route Pipe tool to connect this zone '
              'to a distributor.',
        ),
      );
    }
  }

  return results;
}
