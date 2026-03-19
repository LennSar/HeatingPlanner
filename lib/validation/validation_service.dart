import 'dart:math' show min, max;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calculation/providers/hydraulic_balance_providers.dart';
import '../calculation/providers/tube_length_providers.dart';
import '../core/constants/validation_limits.dart';
import '../data/models/enums.dart';
import '../data/models/validation_result.dart';
import '../ui/providers/editor_state_provider.dart';

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
final validationResultsProvider =
    Provider.family<List<ValidationResult>, String>(
  (ref, projectId) {
    final results = <ValidationResult>[];
    results.addAll(_hydraulicImbalanceResults(ref));
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
