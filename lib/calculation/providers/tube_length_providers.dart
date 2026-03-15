// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/hydraulic_engine.dart';
import '../../data/models/enums.dart';
import '../../repositories/heating_repository.dart';
import '../../ui/providers/editor_state_provider.dart';
import 'project_settings_provider.dart';

/// Zone tube length (m) for [zoneId].
///
/// For floor-heating zones, watches the zone's polygon,
/// [HeatingZone.tubeSpacingMm], and [HeatingZone.borderDistanceMm]
/// via [editorStateProvider].
///
/// For wall-heating zones, derives area from the wall segment
/// geometry: area = widthMm × heightMm / 1e6, where widthMm is
/// [HeatingZone.widthMm] (or the full wall length when null) and
/// heightMm is [HeatingZone.heightMm] (or [floorHeightMmProvider]
/// when null).
///
/// Returns [double.nan] when the zone is not found, the wall
/// segment is missing, or inputs are otherwise invalid.
/// Returns 0.0 when the effective area after border subtraction
/// is non-positive.
final zoneTubeLengthProvider =
    Provider.family<double, String>((ref, zoneId) {
  final zones = ref.watch(
    editorStateProvider.select((s) => s.zones),
  );

  final zone = zones.where((z) => z.id == zoneId).firstOrNull;
  if (zone == null) return double.nan;

  final double areaM2;
  final double perimeterM;

  if (zone.zoneType == ZoneType.wallHeating) {
    if (zone.wallSegmentId == null) return double.nan;

    final walls = ref.watch(
      editorStateProvider.select((s) => s.walls),
    );
    final wall =
        walls.where((w) => w.id == zone.wallSegmentId).firstOrNull;
    if (wall == null) return double.nan;

    final wallLengthMm =
        GeometryEngine.distanceMm(wall.startPoint, wall.endPoint);
    final int effectiveWidthMm =
        zone.widthMm ?? wallLengthMm.round();
    final int effectiveHeightMm =
        zone.heightMm ?? ref.watch(floorHeightMmProvider);
    final widthMm = effectiveWidthMm.toDouble();
    final heightMm = effectiveHeightMm.toDouble();

    areaM2 = widthMm * heightMm / 1e6;
    perimeterM = 2.0 * (widthMm + heightMm) / 1000.0;
  } else {
    if (zone.polygon.length < 3) return double.nan;
    areaM2 = GeometryEngine.polygonAreaM2(zone.polygon);
    perimeterM = GeometryEngine.polygonPerimeterM(zone.polygon);
  }

  return HydraulicEngine.zoneTubeLength(
    zoneAreaM2: areaM2,
    perimeterM: perimeterM,
    tubeSpacingMm: zone.tubeSpacingMm,
    borderDistanceMm: zone.borderDistanceMm,
  );
});

/// Total tube length for a circuit (m): zone loop + supply + return routes.
///
/// L_total = L_zone + L_supply + L_return
///
/// Zone loop length is derived from the zone polygon (floor heating) or from
/// [HeatingZone.widthMm] × [HeatingZone.heightMm] (wall heating). Supply and
/// return route lengths are the polyline lengths of
/// [HeatingCircuit.supplyRoutePath] and [HeatingCircuit.returnRoutePath];
/// an empty or single-point path (not yet drawn) contributes 0 m.
///
/// Watches:
/// - [circuitByIdProvider] for route paths and zone reference
/// - [zoneByIdProvider] for polygon, spacingMm, borderDistanceMm
///
/// Returns [double.nan] while any upstream data is loading or when
/// a wall-heating zone has unset [HeatingZone.widthMm]/[HeatingZone.heightMm].
final tubeLengthProvider =
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

  final double areaM2;
  final double perimeterM;

  if (zone.zoneType == ZoneType.wallHeating) {
    final w = zone.widthMm;
    final h = zone.heightMm;
    if (w == null || h == null) return double.nan;
    areaM2 = w * h / 1e6;
    perimeterM = 2.0 * (w + h) / 1000.0;
  } else {
    if (zone.polygon.length < 3) return double.nan;
    areaM2 = GeometryEngine.polygonAreaM2(zone.polygon);
    perimeterM = GeometryEngine.polygonPerimeterM(zone.polygon);
    if (areaM2.isNaN || perimeterM.isNaN) return double.nan;
  }

  final zoneLengthM = HydraulicEngine.zoneTubeLength(
    zoneAreaM2: areaM2,
    perimeterM: perimeterM,
    tubeSpacingMm: zone.tubeSpacingMm,
    borderDistanceMm: zone.borderDistanceMm,
  );
  if (zoneLengthM.isNaN) return double.nan;

  // Empty or single-point route paths (not yet drawn) contribute 0 m.
  final supplyLengthM = circuit.supplyRoutePath.length >= 2
      ? HydraulicEngine.polylineLengthM(circuit.supplyRoutePath)
      : 0.0;
  final returnLengthM = circuit.returnRoutePath.length >= 2
      ? HydraulicEngine.polylineLengthM(circuit.returnRoutePath)
      : 0.0;

  return HydraulicEngine.totalTubeLength(
    zoneTubeLengthM: zoneLengthM,
    supplyRouteLengthM: supplyLengthM,
    returnRouteLengthM: returnLengthM,
  );
});
