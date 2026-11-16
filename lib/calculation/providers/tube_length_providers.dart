// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/hydraulic_engine.dart';
import '../../calculation/engines/pipe_layout_engine.dart';
import '../../data/models/enums.dart';
import '../../ui/providers/editor_state_provider.dart';
import 'pipe_layout_providers.dart';
import 'project_settings_provider.dart';

/// Tube length (m) laid inside the zone with [zoneId].
///
/// **Floor zones:** the length of the tube as it is drawn (ADR-042
/// Rule 4) — the zone's layout path from [zonePipeLayoutsProvider], from
/// the point where the supply pipe enters the zone to the point where
/// the return pipe leaves it, bends included. It therefore follows the
/// layout pattern, the zone shape, the border distance, transit
/// corridors and the entry position. 0.0 when no tube fits.
///
/// **Wall zones** have no drawn layout; their length is still estimated
/// as area ÷ spacing from [HeatingZone.widthMm] (or the full wall
/// length) × [HeatingZone.heightMm] (or [floorHeightMmProvider]).
///
/// Returns [double.nan] when the zone is not found, has fewer than 3
/// vertices, or its wall segment is missing.
final zoneTubeLengthProvider =
    Provider.family<double, String>((ref, zoneId) {
  final zones = ref.watch(
    editorStateProvider.select((s) => s.zones),
  );

  final zone = zones.where((z) => z.id == zoneId).firstOrNull;
  if (zone == null) return double.nan;

  if (zone.zoneType != ZoneType.wallHeating) {
    if (zone.polygon.length < 3) return double.nan;
    final path = ref.watch(zonePipeLayoutsProvider)[zone.id]?.pipePath;
    if (path == null || path.length < 2) return 0.0;
    return GeometryEngine.polylineLengthMm(path) / 1000.0;
  }

  if (zone.wallSegmentId == null) return double.nan;
  final walls = ref.watch(
    editorStateProvider.select((s) => s.walls),
  );
  final wall =
      walls.where((w) => w.id == zone.wallSegmentId).firstOrNull;
  if (wall == null) return double.nan;

  final wallLengthMm =
      GeometryEngine.distanceMm(wall.startPoint, wall.endPoint);
  final widthMm = (zone.widthMm ?? wallLengthMm.round()).toDouble();
  final int floorHeightMm = ref.watch(floorHeightMmProvider);
  final heightMm = (zone.heightMm ?? floorHeightMm).toDouble();

  return HydraulicEngine.zoneTubeLength(
    zoneAreaM2: widthMm * heightMm / 1e6,
    perimeterM: 2.0 * (widthMm + heightMm) / 1000.0,
    tubeSpacingMm: zone.tubeSpacingMm,
    borderDistanceMm: zone.borderDistanceMm,
  );
});

/// Total tube length of a circuit (m), measured along the drawing
/// (ADR-042 Rule 4):
///
/// `supply connection pipe + tube in the zone + return connection pipe`
///
/// The connection pipes are measured with their bend radii and only up
/// to the zone boundary ([connectionPipeLengthsM]); the tube in the zone
/// comes from [zoneTubeLengthProvider] and starts and ends at that
/// boundary, so nothing is counted twice and nothing is left out.
///
/// Reads the circuit and its zone from [editorStateProvider], so the
/// value follows every edit immediately. Returns [double.nan] when the
/// circuit or its zone is unknown or the zone length is undefined.
final tubeLengthProvider =
    Provider.family<double, String>((ref, circuitId) {
  final circuit = ref
      .watch(editorStateProvider.select((s) => s.circuits))
      .where((c) => c.id == circuitId)
      .firstOrNull;
  if (circuit == null) return double.nan;

  final zone = ref
      .watch(editorStateProvider.select((s) => s.zones))
      .where((z) => z.id == circuit.heatingZoneId)
      .firstOrNull;
  if (zone == null) return double.nan;

  final zoneLengthM = ref.watch(zoneTubeLengthProvider(zone.id));
  if (zoneLengthM.isNaN) return double.nan;

  final pipes = connectionPipeLengthsM(
    circuit,
    zone: zone,
    bendRadiusMm: ref.watch(zoneBendRadiiMmProvider)[zone.id] ??
        PipeLayoutEngine.minBendRadiusMm(fallbackTubeOuterDiameterMm),
  );

  return HydraulicEngine.totalTubeLength(
    zoneTubeLengthM: zoneLengthM,
    supplyRouteLengthM: pipes.supplyM,
    returnRouteLengthM: pipes.returnM,
  );
});
