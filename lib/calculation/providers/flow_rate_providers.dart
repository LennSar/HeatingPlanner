// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/heating_repository.dart';
import '../engines/geometry_engine.dart';
import '../engines/hydraulic_engine.dart';
import 'heat_output_providers.dart';

/// Design mass flow rate for a circuit (kg/h).
///
/// ṁ = Q_zone / (c_w × (T_supply − T_return)) × 3600
///
/// Q_zone (W) is the product of the specific heat output from
/// [zoneHeatOutputProvider] (W/m²) and the zone polygon area (m²).
/// Supply and return temperatures are read from the distributor via
/// the circuit link.
///
/// Watches:
/// - [circuitByIdProvider] for distributor reference and zone reference
/// - [zoneByIdProvider] for polygon area
/// - [zoneHeatOutputProvider] for specific heat output (W/m²)
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

  // Specific heat output from EN 1264 (W/m²).
  final specificOutputWPerM2 =
      ref.watch(zoneHeatOutputProvider(zone.id));
  if (specificOutputWPerM2.isNaN) return double.nan;

  // Zone area (m²) — used to convert W/m² to total W.
  final areaM2 = GeometryEngine.polygonAreaM2(zone.polygon);
  if (areaM2.isNaN || areaM2 <= 0) return double.nan;

  final heatOutputW = specificOutputWPerM2 * areaM2;

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
