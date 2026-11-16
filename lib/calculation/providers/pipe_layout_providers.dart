// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../data/models/heating_circuit.dart';
import '../../data/models/heating_zone.dart';
import '../../data/models/point2d.dart';
import '../../data/models/wall_segment.dart';
import '../../repositories/heating_repository.dart';
import '../../ui/providers/editor_state_provider.dart';
import '../engines/geometry_engine.dart';
import '../engines/pipe_layout_engine.dart';

/// Circuits whose connection pipes take up room in [zone]'s screed
/// (ADR-038 Rule 3).
///
/// A circuit routed in the insulation layer
/// ([SupplyPipeInsulationType.insulationLayer]) runs beneath the heating
/// area and is skipped — the zone lies over it unchanged. A circuit with
/// no insulation choice yet is treated as embedded in the screed. The
/// zone's own circuit never counts.
List<HeatingCircuit> transitCircuitsForZone(
  HeatingZone zone,
  List<HeatingCircuit> circuits,
) => [
  for (final c in circuits)
    if (c.heatingZoneId != zone.id &&
        c.id != zone.circuitId &&
        c.supplyPipeInsulationType != SupplyPipeInsulationType.insulationLayer)
      c,
];

/// Corridor quads of the transit circuits through [zone].
///
/// - A circuit drawn as one route (ADR-040) gets one corridor around its
///   centerline. For the heated area ([forLayout] false) it reaches half
///   of [HeatingCircuit.zoneClearanceMm] beyond each pipe — the gap is
///   shared between the pipe and the zone tube. For the tube layout
///   ([forLayout] true) it reaches the full clearance, so no zone tube
///   comes closer to a pipe than that.
/// - A circuit drawn as two separate pipes gets one corridor per pipe:
///   half a zone tube spacing on each side for the area, a full spacing
///   for the layout (ADR-038 Rule 3).
List<List<Point2D>> _corridors(
  HeatingZone zone,
  List<HeatingCircuit> circuits, {
  required bool forLayout,
}) {
  if (zone.zoneType != ZoneType.floorHeating || zone.polygon.length < 3) {
    return const [];
  }
  final out = <List<Point2D>>[];
  for (final c in transitCircuitsForZone(zone, circuits)) {
    if (c.centerlinePath.length >= 2) {
      out.addAll(
        PipeLayoutEngine.transitCorridors(
          routes: [c.centerlinePath],
          halfWidthMm:
              c.pipeSpacingMm / 2.0 +
              (forLayout ? c.zoneClearanceMm : c.zoneClearanceMm / 2.0),
          polygon: zone.polygon,
        ),
      );
    } else {
      out.addAll(
        PipeLayoutEngine.transitCorridors(
          routes: [
            if (c.supplyRoutePath.length >= 2) c.supplyRoutePath,
            if (c.returnRoutePath.length >= 2) c.returnRoutePath,
          ],
          halfWidthMm: forLayout
              ? zone.tubeSpacingMm.toDouble()
              : zone.tubeSpacingMm / 2.0,
          polygon: zone.polygon,
        ),
      );
    }
  }
  return out;
}

/// Strips of [zone] that belong to the connection pipes of other
/// circuits and are cut out of its heated area (ADR-038 Rule 3,
/// ADR-040 Rule 3).
List<List<Point2D>> transitCorridorsForZone(
  HeatingZone zone,
  List<HeatingCircuit> circuits,
) => _corridors(zone, circuits, forLayout: false);

/// Strips of [zone] its own tubes must stay out of: the connection pipes
/// of other circuits plus the full clearance to them.
List<List<Point2D>> transitKeepOutForZone(
  HeatingZone zone,
  List<HeatingCircuit> circuits,
) => _corridors(zone, circuits, forLayout: true);

/// [walls] as the plain centerline-plus-thickness records
/// [PipeLayoutEngine.snapRouteToWalls] works on.
List<({Point2D start, Point2D end, double thicknessMm})> wallLinesOf(
  List<WallSegment> walls,
) =>
    [
      for (final w in walls)
        (start: w.startPoint, end: w.endPoint, thicknessMm: w.thicknessMm),
    ];

/// Returns [circuit] with its connection pipes laid out again from its
/// route and its three distances (ADR-040).
///
/// [centerline] replaces the stored route when given. A circuit that was
/// drawn as two separate pipes has no route yet; its supply pipe is taken
/// as the route, which converts it to a parallel pair. [captureMm] is
/// how far beyond the wall distance a section is still pulled to a wall.
///
/// Returns [circuit] unchanged when the route has fewer than 2 distinct
/// points.
HeatingCircuit relaidConnectionPipes(
  HeatingCircuit circuit,
  List<WallSegment> walls, {
  List<Point2D>? centerline,
  double captureMm = PipeLayoutEngine.wallCaptureMm,
}) {
  final route = centerline ??
      (circuit.centerlinePath.length >= 2
          ? circuit.centerlinePath
          : circuit.supplyRoutePath);
  final laid = PipeLayoutEngine.layOutConnectionPipes(
    centerline: route,
    pipeSpacingMm: circuit.pipeSpacingMm,
    wallClearanceMm: circuit.wallClearanceMm,
    walls: wallLinesOf(walls),
    captureMm: captureMm,
    supplyOnRight: circuit.supplyOnRight,
  );
  if (laid.centerline.length < 2) return circuit;
  return circuit.copyWith(
    centerlinePath: laid.centerline,
    supplyRoutePath: laid.supply,
    returnRoutePath: laid.back,
  );
}

/// Returns [circuit] with supply and return swapped (ADR-041).
///
/// - A circuit drawn as one route keeps its route; the two pipes trade
///   sides ([HeatingCircuit.supplyOnRight] is toggled and the pair is laid
///   out again).
/// - A circuit drawn as two separate pipes trades the two polylines:
///   the old return, reversed, becomes the supply and vice versa.
///
/// The zone's tube layout follows by itself: it starts at whichever pipe
/// is now the supply and picks a direction whose leads do not cross.
HeatingCircuit withSupplyAndReturnSwapped(
  HeatingCircuit circuit,
  List<WallSegment> walls,
) {
  if (circuit.centerlinePath.length >= 2) {
    return relaidConnectionPipes(
      circuit.copyWith(supplyOnRight: !circuit.supplyOnRight),
      walls,
    );
  }
  return circuit.copyWith(
    supplyRoutePath: circuit.returnRoutePath.reversed.toList(),
    returnRoutePath: circuit.supplyRoutePath.reversed.toList(),
  );
}

/// Allowed range of [HeatingCircuit.pipeSpacingMm].
const int minPipeSpacingMm = 30;

/// Allowed range of [HeatingCircuit.pipeSpacingMm].
const int maxPipeSpacingMm = 500;

/// Upper limit of [HeatingCircuit.zoneClearanceMm] and
/// [HeatingCircuit.wallClearanceMm] (the lower limit is 0).
const int maxPipeClearanceMm = 1000;

/// Returns [circuit] with new connection-pipe distances **applied**
/// (ADR-040 Rule 4): the two pipes are laid out again at the new
/// spacing, and every section that runs along a wall moves to the new
/// wall distance. The zone distance takes effect through the corridors
/// derived from the circuit ([transitCorridorsForZone]).
///
/// Omitted distances keep their value. Values are clamped to their
/// allowed range. When the wall distance shrinks, sections sitting at
/// the old distance are still recognised as following their wall.
HeatingCircuit withConnectionPipeDistances(
  HeatingCircuit circuit,
  List<WallSegment> walls, {
  int? pipeSpacingMm,
  int? zoneClearanceMm,
  int? wallClearanceMm,
}) {
  final next = circuit.copyWith(
    pipeSpacingMm: (pipeSpacingMm ?? circuit.pipeSpacingMm)
        .clamp(minPipeSpacingMm, maxPipeSpacingMm),
    zoneClearanceMm: (zoneClearanceMm ?? circuit.zoneClearanceMm)
        .clamp(0, maxPipeClearanceMm),
    wallClearanceMm: (wallClearanceMm ?? circuit.wallClearanceMm)
        .clamp(0, maxPipeClearanceMm),
  );
  // Distance from a wall face to the route at the old and new settings.
  double routeOffset(HeatingCircuit c) =>
      c.wallClearanceMm + c.pipeSpacingMm / 2.0;
  final moveIn = routeOffset(circuit) - routeOffset(next);
  return relaidConnectionPipes(
    next,
    walls,
    captureMm:
        PipeLayoutEngine.wallCaptureMm + (moveIn > 0 ? moveIn : 0.0),
  );
}

/// Heated area of [zone] in m²: the polygon area minus the transit
/// corridors of other circuits (ADR-038 Rule 3).
double zoneEffectiveAreaM2(HeatingZone zone, List<HeatingCircuit> circuits) {
  if (zone.polygon.length < 3) return double.nan;
  final corridors = transitCorridorsForZone(zone, circuits);
  if (corridors.isEmpty) return GeometryEngine.polygonAreaM2(zone.polygon);
  return PipeLayoutEngine.effectiveAreaM2(
    polygon: zone.polygon,
    exclusions: corridors,
  );
}

/// Heated area (m²) of the zone with [zoneId] after subtracting transit
/// corridors (ADR-038 Rule 3).
///
/// Watches the zone and circuit lists of [editorStateProvider]. Returns
/// [double.nan] when the zone is unknown or has fewer than 3 vertices.
final zoneEffectiveAreaM2Provider = Provider.family<double, String>((
  ref,
  zoneId,
) {
  final zones = ref.watch(editorStateProvider.select((s) => s.zones));
  final zone = zones.where((z) => z.id == zoneId).firstOrNull;
  if (zone == null) return double.nan;
  final circuits = ref.watch(editorStateProvider.select((s) => s.circuits));
  return zoneEffectiveAreaM2(zone, circuits);
});

/// Outer diameter assumed while the tube catalogue is still loading or a
/// zone references an unknown tube type, in mm.
const double fallbackTubeOuterDiameterMm = 16.0;

/// Minimum bending radius (mm) of the tube laid in each zone, keyed by
/// zone id: 5 × the outer diameter of the zone's tube type (ADR-039
/// Rule 3). The connection pipes of a zone's circuit are the same tube,
/// so they bend with the same radius.
final zoneBendRadiiMmProvider = Provider<Map<String, double>>((ref) {
  final zones = ref.watch(editorStateProvider.select((s) => s.zones));
  final tubes = ref.watch(tubeTypesProvider).asData?.value ?? const [];
  final diameterById = {for (final t in tubes) t.id: t.outerDiameterMm};
  return {
    for (final z in zones)
      z.id: PipeLayoutEngine.minBendRadiusMm(
        diameterById[z.tubeTypeId] ?? fallbackTubeOuterDiameterMm,
      ),
  };
});

/// Bending radius (mm) used for a connection pipe that is still being
/// drawn and has no zone yet: that of the default (first) tube type.
final defaultBendRadiusMmProvider = Provider<double>((ref) {
  final tubes = ref.watch(tubeTypesProvider).asData?.value ?? const [];
  return PipeLayoutEngine.minBendRadiusMm(
    tubes.isEmpty ? fallbackTubeOuterDiameterMm : tubes.first.outerDiameterMm,
  );
});

/// Lengths in metres of a circuit's two connection pipes as drawn
/// (ADR-042 Rule 4): corners rounded with [bendRadiusMm], and — for a
/// floor [zone] — only up to the zone boundary, because the zone's tube
/// layout starts and ends exactly there. Passing no [zone] measures the
/// full polylines.
({double supplyM, double returnM}) connectionPipeLengthsM(
  HeatingCircuit circuit, {
  HeatingZone? zone,
  required double bendRadiusMm,
}) {
  var supply = PipeLayoutEngine.filletPolyline(
    circuit.supplyRoutePath,
    bendRadiusMm,
  );
  var back = PipeLayoutEngine.filletPolyline(
    circuit.returnRoutePath,
    bendRadiusMm,
  );
  if (zone != null &&
      zone.zoneType == ZoneType.floorHeating &&
      zone.polygon.length >= 3) {
    supply = PipeLayoutEngine.supplyRouteOutsideZone(supply, zone.polygon);
    back = PipeLayoutEngine.returnRouteOutsideZone(back, zone.polygon);
  }
  double metres(List<Point2D> path) =>
      path.length < 2 ? 0.0 : GeometryEngine.polylineLengthMm(path) / 1000.0;
  return (supplyM: metres(supply), returnM: metres(back));
}

/// Number of identity colours zones are distinguished by (ADR-042
/// Rule 3) — the length of `HeatingPlannerColors.zonePalette`.
const int zoneIdentityColorCount = 10;

/// Identity colour index per zone id (ADR-042 Rule 3): neighbouring
/// zones never share an index; while the palette lasts every zone has
/// its own.
final zoneColorIndicesProvider = Provider<Map<String, int>>((ref) {
  final zones = ref.watch(editorStateProvider.select((s) => s.zones));
  final indices = GeometryEngine.distinctColorIndices(
    [for (final z in zones) z.polygon],
    paletteSize: zoneIdentityColorCount,
  );
  return {
    for (var i = 0; i < zones.length; i++) zones[i].id: indices[i],
  };
});

/// Tube layout per floor zone id for the active floor (ADR-038).
///
/// Each entry carries the tube path in the zone's layout pattern —
/// starting where the zone's supply line enters it, with bend radii —
/// and the transit corridors cut out of the zone.
final zonePipeLayoutsProvider = Provider<Map<String, ZonePipeLayout>>((ref) {
  final zones = ref.watch(editorStateProvider.select((s) => s.zones));
  final circuits = ref.watch(editorStateProvider.select((s) => s.circuits));
  final distributor = ref.watch(
    editorStateProvider.select((s) => s.distributor),
  );

  final bendRadii = ref.watch(zoneBendRadiiMmProvider);

  final circuitById = {for (final c in circuits) c.id: c};
  final result = <String, ZonePipeLayout>{};
  for (final zone in zones) {
    if (zone.zoneType != ZoneType.floorHeating || zone.polygon.length < 3) {
      continue;
    }
    final corridors = transitCorridorsForZone(zone, circuits);
    final circuit = circuitById[zone.circuitId];
    final entry = PipeLayoutEngine.zoneEntryPoint(
      polygon: zone.polygon,
      supplyRoutePath: circuit?.supplyRoutePath ?? const [],
      distributorPosition: distributor?.position,
    );
    final exit = PipeLayoutEngine.zoneExitPoint(
      polygon: zone.polygon,
      returnRoutePath: circuit?.returnRoutePath ?? const [],
    );
    final keepOut = transitKeepOutForZone(zone, circuits);
    final tube = PipeLayoutEngine.tubePath(
      pattern: zone.layoutPattern,
      polygon: zone.polygon,
      tubeSpacingMm: zone.tubeSpacingMm,
      borderDistanceMm: zone.borderDistanceMm,
      entryPoint: entry,
      exitPoint: exit,
      exclusions: keepOut,
    );
    result[zone.id] = (
      // ADR-039 Rule 3: turns are drawn with the tube's bend radius.
      pipePath: PipeLayoutEngine.filletPolyline(
        tube,
        bendRadii[zone.id] ??
            PipeLayoutEngine.minBendRadiusMm(fallbackTubeOuterDiameterMm),
      ),
      corridors: corridors,
    );
  }
  return result;
});
