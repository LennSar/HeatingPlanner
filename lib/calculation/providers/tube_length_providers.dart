// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/hydraulic_engine.dart';
import '../../data/models/enums.dart';
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
