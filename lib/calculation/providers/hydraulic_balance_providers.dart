// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/heating_repository.dart';
import '../engines/hydraulic_engine.dart';
import 'pressure_loss_providers.dart';

/// Required valve throttling (Pa) per circuit for hydraulic balancing.
///
/// Delegates to [HydraulicEngine.hydraulicBalance]:
/// - The reference circuit (highest pressure loss) receives Δp_valve = 0.
/// - All other circuits receive Δp_valve = max_loss − circuit_loss.
///
/// Circuits whose [pressureLossProvider] is still loading or returns
/// [double.nan] are excluded from the balance calculation. Their
/// entries are omitted from the result map.
///
/// Implemented as [FutureProvider] to allow future offloading to an
/// [Isolate] for full-building calculations (architect Section 6.3).
///
/// Watches:
/// - [circuitsProvider] for the list of circuits on the distributor
/// - [pressureLossProvider] for each circuit's total pressure loss
///
/// Returns an empty map while circuits are loading or none exist.
final hydraulicBalanceProvider =
    FutureProvider.family<Map<String, double>, String>(
  (ref, distributorId) async {
    final circuits =
        ref.watch(circuitsProvider(distributorId)).asData?.value;
    if (circuits == null || circuits.isEmpty) return {};

    // Resolve all pressure losses in parallel.
    final futures = circuits
        .map((c) => ref.watch(pressureLossProvider(c.id).future));
    final results = await Future.wait(futures);

    // Build circuitId → pressure loss map; exclude NaN entries.
    final validLosses = <String, double>{};
    for (var i = 0; i < circuits.length; i++) {
      if (!results[i].isNaN) {
        validLosses[circuits[i].id] = results[i];
      }
    }
    if (validLosses.isEmpty) return {};

    return HydraulicEngine.hydraulicBalance(
      circuitPressureLosses: validLosses,
    );
  },
);
