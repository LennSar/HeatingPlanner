// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/heating_repository.dart';
import '../engines/hydraulic_engine.dart';
import 'heat_output_providers.dart';

/// Design mass flow rate for a circuit (kg/h).
///
/// ṁ = Q_zone / (c_w × (T_supply − T_return)) × 3600
///
/// Q_zone (W) is the heat the zone delivers ([zoneHeatOutputWProvider]):
/// the specific heat output from [zoneHeatOutputProvider] (W/m²) times
/// the heated area (m²). The heat lost downwards through the floor
/// (EN 1264-3) is not added; the build-up below the pipes is not
/// modelled.
/// Supply and return temperatures are read from the distributor via
/// the circuit link.
///
/// Watches:
/// - [circuitByIdProvider] for distributor reference and zone reference
/// - [zoneHeatOutputWProvider] for the delivered heat (W)
/// - [distributorByIdProvider] for supply/return temperatures
///
/// Returns [double.nan] while any upstream data is loading or when
/// inputs are otherwise invalid (e.g. zero temperature spread).
final flowRateProvider =
    Provider.family<double, String>((ref, circuitId) {
  final circuit =
      ref.watch(circuitByIdProvider(circuitId)).asData?.value;
  if (circuit == null) return double.nan;

  final zone =
      ref
          .watch(zoneByIdProvider(circuit.heatingZoneId))
          .asData
          ?.value;
  if (zone == null) return double.nan;

  // Heat delivered by the zone (W): EN 1264-2 output × heated area.
  // ADR-038 Rule 3: transit corridors of other circuits emit no zone heat.
  final heatOutputW = ref.watch(zoneHeatOutputWProvider(zone.id));
  if (heatOutputW.isNaN) return double.nan;

  // Distributor supply/return temperatures.
  final distributor =
      ref
          .watch(distributorByIdProvider(circuit.distributorId))
          .asData
          ?.value;
  if (distributor == null) return double.nan;

  return HydraulicEngine.massFlowRateKgH(
    heatOutputW: heatOutputW,
    tSupplyC: distributor.supplyTempC,
    tReturnC: distributor.returnTempC,
  );
});
