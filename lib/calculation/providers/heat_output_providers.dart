// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/en1264_tables.dart';
import '../../data/models/enums.dart';
import '../../data/models/flooring_material.dart'
    show kCustomFlooringMaterialId;
import '../../repositories/building_repository.dart';
import '../../repositories/heating_repository.dart';
import '../engines/heating_output_engine.dart';
import 'project_settings_provider.dart';

/// Specific heat output (W/m²) for a heating zone — EN 1264.
///
/// q = B × a_B × a_T × a_U × a_D × ΔT^n
///
/// Watches:
/// - [zoneByIdProvider] for zone geometry and references
/// - [tubeTypeByIdProvider] for outer diameter and conductivity
/// - [flooringMaterialByIdProvider] for covering thermal resistance
/// - [roomProvider] for room target temperature
/// - [circuitByIdProvider] → [distributorByIdProvider] for supply/return temps
///
/// Returns [double.nan] while any upstream data is loading, or when
/// the zone has no connected circuit (and therefore no distributor temps).
final zoneHeatOutputProvider =
    Provider.family<double, String>((ref, zoneId) {
  final zone = ref.watch(zoneByIdProvider(zoneId)).asData?.value;
  if (zone == null) return double.nan;

  // Tube-type correction factors.
  final tubeType =
      ref.watch(tubeTypeByIdProvider(zone.tubeTypeId)).asData?.value;
  if (tubeType == null) return double.nan;

  // Covering thermal resistance — custom value overrides catalogue entry.
  final double rCoveringM2KW;
  if (zone.flooringMaterialId == kCustomFlooringMaterialId) {
    rCoveringM2KW = zone.customFlooringResistance ?? 0.0;
  } else {
    final flooring = ref
        .watch(flooringMaterialByIdProvider(zone.flooringMaterialId))
        .asData
        ?.value;
    if (flooring == null) return double.nan;
    rCoveringM2KW = flooring.thermalResistance;
  }

  // Room target temperature; fall back to project default if not loaded.
  final double tRoomC =
      ref.watch(roomProvider(zone.roomId)).asData?.value?.targetTempC ??
          ref.watch(defaultIndoorTempCProvider);

  // Distributor temps via circuit link.
  final circuitId = zone.circuitId;
  if (circuitId == null) return double.nan;

  final circuit =
      ref.watch(circuitByIdProvider(circuitId)).asData?.value;
  if (circuit == null) return double.nan;

  final distributor = ref
      .watch(distributorByIdProvider(circuit.distributorId))
      .asData
      ?.value;
  if (distributor == null) return double.nan;

  // LMTD per EN 1264.
  final deltaT = HeatingOutputEngine.logMeanTempDifference(
    tSupplyC: distributor.supplyTempC,
    tReturnC: distributor.returnTempC,
    tRoomC: tRoomC,
  );
  if (deltaT.isNaN) return double.nan;

  // EN 1264 correction factors.
  final aB = EN1264Tables.coveringFactor(rCoveringM2KW);
  final aT = EN1264Tables.spacingFactor(zone.tubeSpacingMm);
  final aU = EN1264Tables.diameterFactor(tubeType.outerDiameterMm);
  final aD = EN1264Tables.conductivityFactor(tubeType.thermalConductivity);
  final exponent = zone.zoneType == ZoneType.wallHeating
      ? EN1264Tables.exponentWall
      : EN1264Tables.exponentFloor;

  return HeatingOutputEngine.specificHeatOutput(
    deltaT: deltaT,
    systemConstantB: EN1264Tables.systemConstantB,
    coveringFactorAB: aB,
    spacingFactorAT: aT,
    diameterFactorAU: aU,
    conductFactorAD: aD,
    exponentN: exponent,
  );
});

/// Estimated mean surface temperature (°C) of a heating zone.
///
/// T_surface ≈ T_room + q / α_total
///
/// Uses the specific heat output from [zoneHeatOutputProvider] and the
/// room's target temperature. Falls back to [defaultIndoorTempCProvider]
/// if the room record is not yet loaded.
///
/// Returns [double.nan] while any upstream data is loading.
final zoneSurfaceTempProvider =
    Provider.family<double, String>((ref, zoneId) {
  final specificOutput = ref.watch(zoneHeatOutputProvider(zoneId));
  if (specificOutput.isNaN) return double.nan;

  final zone = ref.watch(zoneByIdProvider(zoneId)).asData?.value;
  if (zone == null) return double.nan;

  final double tRoomC =
      ref.watch(roomProvider(zone.roomId)).asData?.value?.targetTempC ??
          ref.watch(defaultIndoorTempCProvider);

  return HeatingOutputEngine.surfaceTemperature(
    tRoomC: tRoomC,
    specificOutputWPerM2: specificOutput,
  );
});
