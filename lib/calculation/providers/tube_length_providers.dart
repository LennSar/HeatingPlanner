// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/hydraulic_engine.dart';
import '../../ui/providers/editor_state_provider.dart';

/// Zone tube length (m) for [zoneId].
///
/// Watches the zone's polygon, [HeatingZone.tubeSpacingMm], and
/// [HeatingZone.borderDistanceMm] via [editorStateProvider].
/// Re-evaluates whenever any of those fields change, so the
/// properties panel and any other consumer updates in real time.
///
/// Returns [double.nan] when the zone is not found or the polygon
/// has fewer than 3 vertices. Returns 0.0 when the effective area
/// after border subtraction is non-positive.
final zoneTubeLengthProvider =
    Provider.family<double, String>((ref, zoneId) {
  final zones = ref.watch(
    editorStateProvider.select((s) => s.zones),
  );

  final zone = zones.where((z) => z.id == zoneId).firstOrNull;
  if (zone == null || zone.polygon.length < 3) return double.nan;

  final areaM2 = GeometryEngine.polygonAreaM2(zone.polygon);
  final perimeterM = GeometryEngine.polygonPerimeterM(zone.polygon);

  return HydraulicEngine.zoneTubeLength(
    zoneAreaM2: areaM2,
    perimeterM: perimeterM,
    tubeSpacingMm: zone.tubeSpacingMm,
    borderDistanceMm: zone.borderDistanceMm,
  );
});
