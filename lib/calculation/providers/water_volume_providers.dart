// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/heating_repository.dart';
import '../engines/hydraulic_engine.dart';
import 'tube_length_providers.dart';

/// Water volume in a heating circuit (litres).
///
/// V = π × (d_i / 2)² × L_total × 1000
///
/// Uses [tubeLengthProvider] for the total tube length and the inner
/// diameter of the [TubeType] assigned to the zone.
///
/// Watches:
/// - [tubeLengthProvider] for total circuit length
/// - [circuitByIdProvider] → [zoneByIdProvider] → [tubeTypeByIdProvider]
///   for inner diameter
///
/// Returns [double.nan] while any upstream data is loading.
final waterVolumeProvider =
    Provider.family<double, String>((ref, circuitId) {
  final totalLengthM = ref.watch(tubeLengthProvider(circuitId));
  if (totalLengthM.isNaN) return double.nan;

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

  return HydraulicEngine.waterVolumeLitres(
    innerDiameterMm: tubeType.innerDiameterMm,
    tubeLengthM: totalLengthM,
  );
});
