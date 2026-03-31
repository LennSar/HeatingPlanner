// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/heating_repository.dart';
import '../engines/hydraulic_engine.dart';
import 'flow_rate_providers.dart';
import 'tube_length_providers.dart';

/// Flow velocity inside the tube for a circuit (m/s).
///
/// Extracts the velocity step from the Darcy-Weisbach pipeline so the
/// result is available to the UI without duplicating the calculation.
///
/// Returns [double.nan] while any upstream data is loading or when
/// inputs are otherwise invalid (zero flow, unknown tube type).
final flowVelocityProvider =
    Provider.family<double, String>((ref, circuitId) {
  final flowRateKgH = ref.watch(flowRateProvider(circuitId));
  if (flowRateKgH.isNaN) return double.nan;

  final circuit =
      ref.watch(circuitByIdProvider(circuitId)).asData?.value;
  if (circuit == null) return double.nan;

  final zone =
      ref
          .watch(zoneByIdProvider(circuit.heatingZoneId))
          .asData
          ?.value;
  if (zone == null) return double.nan;

  final tubeType =
      ref.watch(tubeTypeByIdProvider(zone.tubeTypeId)).asData?.value;
  if (tubeType == null) return double.nan;

  return HydraulicEngine.flowVelocity(
    massFlowRateKgH: flowRateKgH,
    innerDiameterMm: tubeType.innerDiameterMm,
  );
});

/// Total pressure loss for a circuit (Pa) — full Darcy-Weisbach pipeline.
///
/// Pipeline:
///   v  = flowVelocity(ṁ, d_i)
///   Re = reynoldsNumber(v, d_i)
///   f  = darcyFrictionFactor(Re, ε, d_i)
///   Δp_friction = frictionPressureLoss(f, L, d_i, v)
///   Δp_fittings = fittingPressureLoss(Δp_friction, 40 %)
///   Δp_total    = Δp_friction + Δp_fittings
///
/// Implemented as [FutureProvider] to allow future offloading to an
/// [Isolate] for full-building calculations (architect Section 6.3).
///
/// Watches:
/// - [tubeLengthProvider] for total circuit length
/// - [flowRateProvider] for mass flow rate
/// - [circuitByIdProvider] → [zoneByIdProvider] → [tubeTypeByIdProvider]
///   for inner diameter and roughness
///
/// Returns [double.nan] while any upstream data is loading or when
/// inputs are otherwise invalid.
final pressureLossProvider =
    FutureProvider.family<double, String>((ref, circuitId) async {
  final tubeLengthM = ref.watch(tubeLengthProvider(circuitId));
  if (tubeLengthM.isNaN) return double.nan;

  final flowRateKgH = ref.watch(flowRateProvider(circuitId));
  if (flowRateKgH.isNaN) return double.nan;

  final circuit =
      ref.watch(circuitByIdProvider(circuitId)).asData?.value;
  if (circuit == null) return double.nan;

  final zone =
      ref
          .watch(zoneByIdProvider(circuit.heatingZoneId))
          .asData
          ?.value;
  if (zone == null) return double.nan;

  final tubeType =
      ref.watch(tubeTypeByIdProvider(zone.tubeTypeId)).asData?.value;
  if (tubeType == null) return double.nan;

  final velocity = HydraulicEngine.flowVelocity(
    massFlowRateKgH: flowRateKgH,
    innerDiameterMm: tubeType.innerDiameterMm,
  );
  if (velocity.isNaN) return double.nan;

  final re = HydraulicEngine.reynoldsNumber(
    velocityMs: velocity,
    innerDiameterMm: tubeType.innerDiameterMm,
  );
  if (re.isNaN) return double.nan;

  // tubeType.roughness is in mm (spec default: 0.007 mm for PE-Xa).
  final f = HydraulicEngine.darcyFrictionFactor(
    reynoldsNumber: re,
    roughnessMm: tubeType.roughness,
    innerDiameterMm: tubeType.innerDiameterMm,
  );
  if (f.isNaN) return double.nan;

  final frictionLoss = HydraulicEngine.frictionPressureLoss(
    frictionFactor: f,
    tubeLengthM: tubeLengthM,
    innerDiameterMm: tubeType.innerDiameterMm,
    velocityMs: velocity,
  );
  if (frictionLoss.isNaN) return double.nan;

  final fittingLoss = HydraulicEngine.fittingPressureLoss(
    frictionLossPa: frictionLoss,
  );

  return HydraulicEngine.totalPressureLoss(
    frictionLossPa: frictionLoss,
    fittingLossPa: fittingLoss,
  );
});
