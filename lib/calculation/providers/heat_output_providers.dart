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
import '../../ui/providers/editor_state_provider.dart';
import '../engines/geometry_engine.dart';
import '../engines/heating_output_engine.dart';
import 'pipe_layout_providers.dart';
import 'project_settings_provider.dart';

/// Specific heat output (W/m²) for a heating zone — EN 1264-2.
///
/// `q = K_H × Δθ_H` with
/// `K_H = B × a_B × a_T^m_T × a_U^m_U × a_D^m_D` (floor, system type A)
/// or its EN 1264-5 conversion (wall). The screed above the pipes is
/// not modelled; the [EN1264Tables] defaults apply (45 mm cement screed,
/// 1.2 W/(m·K)).
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

  // Δθ_H: logarithmic mean of the heating-medium over-temperature.
  final deltaT = HeatingOutputEngine.logMeanTempDifference(
    tSupplyC: distributor.supplyTempC,
    tReturnC: distributor.returnTempC,
    tRoomC: tRoomC,
  );
  if (deltaT.isNaN) return double.nan;

  // K_H per EN 1264-2 (floor) / EN 1264-5 (wall), ADR-045.
  final isWall = zone.zoneType == ZoneType.wallHeating;
  final kH = isWall
      ? HeatingOutputEngine.heatTransferCoefficientWall(
          tubeSpacingMm: zone.tubeSpacingMm,
          tubeOuterDiameterMm: tubeType.outerDiameterMm,
          tubeWallThicknessMm: tubeType.wallThicknessMm,
          tubeConductivityWPerMK: tubeType.thermalConductivity,
          coveringResistanceM2KPerW: rCoveringM2KW,
        )
      : HeatingOutputEngine.heatTransferCoefficientTypeA(
          tubeSpacingMm: zone.tubeSpacingMm,
          tubeOuterDiameterMm: tubeType.outerDiameterMm,
          tubeWallThicknessMm: tubeType.wallThicknessMm,
          tubeConductivityWPerMK: tubeType.thermalConductivity,
          coveringResistanceM2KPerW: rCoveringM2KW,
        );

  return HeatingOutputEngine.heatFluxDensity(
    heatTransferCoefficientWPerM2K: kH,
    deltaT: deltaT,
  );
});

/// Heat-emitting area of a zone in m².
///
/// Floor zones: the polygon minus the transit corridors of other
/// circuits ([zoneEffectiveAreaM2Provider], ADR-038 Rule 3). Wall zones:
/// [HeatingZone.widthMm] (or the full wall length) ×
/// [HeatingZone.heightMm] (or [floorHeightMmProvider]).
///
/// Returns [double.nan] when the zone is unknown or its geometry is
/// incomplete.
final zoneHeatedAreaM2Provider =
    Provider.family<double, String>((ref, zoneId) {
  final zone = ref
      .watch(editorStateProvider.select((s) => s.zones))
      .where((z) => z.id == zoneId)
      .firstOrNull;
  if (zone == null) {
    // Not on the open floor: fall back to the stored polygon.
    final stored = ref.watch(zoneByIdProvider(zoneId)).asData?.value;
    if (stored == null || stored.polygon.length < 3) return double.nan;
    return GeometryEngine.polygonAreaM2(stored.polygon);
  }
  if (zone.zoneType != ZoneType.wallHeating) {
    return ref.watch(zoneEffectiveAreaM2Provider(zoneId));
  }
  final wall = ref
      .watch(editorStateProvider.select((s) => s.walls))
      .where((w) => w.id == zone.wallSegmentId)
      .firstOrNull;
  if (wall == null) return double.nan;
  final int floorHeightMm = ref.watch(floorHeightMmProvider);
  final int widthMm = zone.widthMm ??
      GeometryEngine.distanceMm(wall.startPoint, wall.endPoint).round();
  final int heightMm = zone.heightMm ?? floorHeightMm;
  return widthMm * heightMm / 1e6;
});

/// Heat delivered by a zone in watts: `Q = q × A`, with q from
/// [zoneHeatOutputProvider] and A from [zoneHeatedAreaM2Provider].
///
/// Returns [double.nan] when either is unavailable (zone not connected,
/// data still loading).
final zoneHeatOutputWProvider =
    Provider.family<double, String>((ref, zoneId) {
  return HeatingOutputEngine.zoneHeatOutput(
    specificOutputWPerM2: ref.watch(zoneHeatOutputProvider(zoneId)),
    zoneAreaM2: ref.watch(zoneHeatedAreaM2Provider(zoneId)),
  );
});

/// Mean surface temperature (°C) of a heating zone.
///
/// Floor zones: EN 1264-2 basic characteristic curve
/// (`θ_F,m = θ_i + (q / 8.92)^(1/1.1)`). Wall zones: `θ_i + q / 8`
/// (EN 1264-5).
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

  if (zone.zoneType == ZoneType.wallHeating) {
    return HeatingOutputEngine.surfaceTemperature(
      tRoomC: tRoomC,
      specificOutputWPerM2: specificOutput,
      alphaTotal: EN1264Tables.alphaWallWPerM2K,
    );
  }
  return HeatingOutputEngine.floorSurfaceTemperature(
    tRoomC: tRoomC,
    specificOutputWPerM2: specificOutput,
  );
});
