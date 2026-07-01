// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../repositories/building_repository.dart';
import 'geometry_providers.dart';
import 'project_settings_provider.dart';
import '../engines/geometry_engine.dart';
import '../engines/thermal_engine.dart';
import 'u_value_providers.dart';

/// Component breakdown of a room's EN 12831 design heat demand, in watts (W).
///
/// Every loss component plus their sum, produced by one computation so a UI
/// can show a breakdown that always reconciles with [totalW] (there is no
/// second, parallel calculation that could diverge).
///
/// - [transmissionW]: transmission loss through the room's walls, windows and
///   doors (Q_T).
/// - [floorW] / [ceilingW]: transmission loss through the floor slab / ceiling
///   slab. [double.nan] when the corresponding construction is not assigned —
///   the term is *not applicable*, distinct from a computed 0.
/// - [ventilationW]: ventilation loss (Q_V). [double.nan] when the room outline
///   is degenerate so no volume is available.
/// - [totalW]: the design heat demand — the sum of the applicable components,
///   or [double.nan] to signal incomplete data (see
///   [roomHeatDemandBreakdownProvider]).
///
/// When [totalW] is [double.nan] every component is also [double.nan].
typedef RoomHeatDemand = ({
  double transmissionW,
  double floorW,
  double ceilingW,
  double ventilationW,
  double totalW,
});

/// Incomplete-data sentinel: total and every component are NaN.
const RoomHeatDemand _uncomputableDemand = (
  transmissionW: double.nan,
  floorW: double.nan,
  ceilingW: double.nan,
  ventilationW: double.nan,
  totalW: double.nan,
);

/// Genuine zero demand (e.g. an unheated room): total 0, refinement terms
/// not applicable.
const RoomHeatDemand _zeroDemand = (
  transmissionW: 0.0,
  floorW: double.nan,
  ceilingW: double.nan,
  ventilationW: double.nan,
  totalW: 0.0,
);

/// Component breakdown of a single room's EN 12831 design heat demand.
///
/// EN 12831 design heat demand:
///   Q_total = Q_T (transmission: walls + floor + ceiling) + Q_V (ventilation)
///
/// Iterates all [WallSegment]s owned by the room per ADR-001. Interior
/// and partition walls use [ThermalEngine.interiorCorrectionFactor] per
/// ADR-002. When [WallSegment.adjacentRoomId] is null the correction
/// factor defaults to 0.0 (safe over-estimate, per ADR-002).
///
/// Per ADR-017 Rule 5, room area / volume come from
/// [roomInnerPolygonProvider] (the EN 12831 *Lichtmaß* polygon) and
/// per-wall net heat-loss area uses [wallInnerEdgeLengthProvider] ×
/// floor height minus opening areas — never the raw centerline polygon
/// or centerline segment length.
///
/// Returns [_uncomputableDemand] (all NaN) when any exterior wall has no
/// [WallSegment.constructionId] assigned — this signals incomplete data
/// (as opposed to a genuinely zero demand) so that downstream consumers
/// (e.g. zone colour logic) can distinguish the two cases.
///
/// Depends on [roomProvider], [wallSegmentsProvider],
/// [roomInnerPolygonProvider], [wallInnerEdgeLengthProvider],
/// [windowsProvider], [doorsProvider], [floorProvider],
/// [uValueProvider], and [designOutdoorTempCProvider].
final roomHeatDemandBreakdownProvider =
    Provider.family<RoomHeatDemand, String>((ref, roomId) {
  final room = ref.watch(roomProvider(roomId)).asData?.value;
  if (room == null) return _zeroDemand;

  // ADR-036: an unheated room (staircase, hallway) carries no heating
  // demand of its own. Its effect on neighbours is already captured by the
  // adjacent rooms reading this room's (low) targetTempC for their
  // interior-wall correction factor. Return a genuine 0.0 — not NaN — so it
  // simply drops out of the building total and never expects a zone.
  if (!room.isHeated) return _zeroDemand;

  final walls =
      ref.watch(wallSegmentsProvider(roomId)).asData?.value;
  if (walls == null) return _uncomputableDemand;

  // If any exterior wall lacks a construction the demand cannot be
  // accurately computed — signal incomplete data.
  final hasIncompleteExteriorWall = walls.any(
    (w) =>
        w.wallType == WallType.exterior &&
        w.constructionId == null,
  );
  if (hasIncompleteExteriorWall) return _uncomputableDemand;

  final tOutdoor = ref.watch(designOutdoorTempCProvider);
  final tThis = room.targetTempC;
  final tUnheatedDefault = ref.watch(unheatedSpaceTempCProvider);
  final tIndoorDefault = ref.watch(defaultIndoorTempCProvider);

  // Ceiling height: read from floor, fall back to 2600 mm.
  final ceilingHeightMm = ref
          .watch(floorProvider(room.floorId))
          .asData
          ?.value
          ?.heightMm
          .toDouble() ??
      2600.0;

  var transmissionW = 0.0;

  for (final wall in walls) {
    if (wall.constructionId == null) continue;

    final uVal =
        ref.watch(uValueProvider(wall.constructionId!));
    if (uVal.isNaN) continue;

    // Read openings; treat missing data as empty lists.
    final windows =
        ref.watch(windowsProvider(wall.id)).asData?.value ??
            const [];
    final doors =
        ref.watch(doorsProvider(wall.id)).asData?.value ??
            const [];

    // Correction factor (EN 12831 §6.3.3, ADR-002).
    final double correctionF;
    if (wall.wallType == WallType.exterior) {
      correctionF = 1.0;
    } else {
      // WallType.interior or WallType.partition.
      if (wall.adjacentRoomId != null) {
        final tAdj = ref
                .watch(roomProvider(wall.adjacentRoomId!))
                .asData
                ?.value
                ?.targetTempC ??
            tThis;
        final f = ThermalEngine.interiorCorrectionFactor(
          tThisRoomC: tThis,
          tAdjacentRoomC: tAdj,
          tOutdoorC: tOutdoor,
        );
        correctionF = f.isNaN ? 0.0 : f;
      } else {
        // ADR-002: safe default — adjacentRoomId not yet linked.
        correctionF = 0.0;
      }
    }

    // Net opaque wall area after subtracting openings.
    //
    // ADR-017 Rule 5: the wall's heat-loss length is its inner-edge
    // length along the room's *Lichtmaß* polygon, not the centerline
    // length. NaN means the inner polygon is degenerate — skip the wall
    // (the room is unbuildable; downstream validation surfaces it).
    final wallLengthMm =
        ref.watch(wallInnerEdgeLengthProvider(wall.id));
    if (wallLengthMm.isNaN || wallLengthMm <= 0) continue;
    final openings = <({int widthMm, int heightMm})>[];
    for (final w in windows) {
      openings.add((widthMm: w.widthMm, heightMm: w.heightMm));
    }
    for (final d in doors) {
      openings.add((widthMm: d.widthMm, heightMm: d.heightMm));
    }
    final netArea = ThermalEngine.netWallAreaM2(
      wallLengthMm: wallLengthMm,
      wallHeightMm: ceilingHeightMm,
      openings: openings,
    );
    if (!netArea.isNaN && netArea > 0) {
      final wallQ = ThermalEngine.transmissionLoss(
        uValue: uVal,
        areaM2: netArea,
        correctionF: correctionF,
        tIndoorC: tThis,
        tOutdoorC: tOutdoor,
      );
      if (!wallQ.isNaN) transmissionW += wallQ;
    }

    // Transmission loss through each window opening.
    for (final w in windows) {
      final q = ThermalEngine.transmissionLoss(
        uValue: w.uValue,
        areaM2: w.widthMm * w.heightMm / 1e6,
        correctionF: correctionF,
        tIndoorC: tThis,
        tOutdoorC: tOutdoor,
      );
      if (!q.isNaN) transmissionW += q;
    }

    // Transmission loss through each door opening.
    for (final d in doors) {
      final q = ThermalEngine.transmissionLoss(
        uValue: d.uValue,
        areaM2: d.widthMm * d.heightMm / 1e6,
        correctionF: correctionF,
        tIndoorC: tThis,
        tOutdoorC: tOutdoor,
      );
      if (!q.isNaN) transmissionW += q;
    }
  }

  // Ventilation heat loss (EN 12831 Q_V).
  //
  // ADR-017 Rule 5: room area / volume come from the inner clear
  // polygon — the *Lichtmaß* polygon — not the centerline polygon.
  // An empty inner polygon means the room is degenerate; treat it as
  // having no floor area and skip the floor/ventilation/ceiling terms
  // (each is guarded by floorAreaM2 > 0 below).
  final innerPolygon = ref.watch(roomInnerPolygonProvider(roomId));
  final floorAreaM2 = innerPolygon.isEmpty
      ? double.nan
      : GeometryEngine.polygonAreaM2(innerPolygon);

  var ventilationW = double.nan;
  if (!floorAreaM2.isNaN && floorAreaM2 > 0) {
    final volumeM3 = ThermalEngine.roomVolumeM3(
      floorAreaM2: floorAreaM2,
      ceilingHeightMm: ceilingHeightMm,
    );
    if (!volumeM3.isNaN) {
      final qV = ThermalEngine.ventilationLoss(
        roomVolumeM3: volumeM3,
        airChangeRate: room.airChangeRate,
        tIndoorC: tThis,
        tOutdoorC: tOutdoor,
      );
      if (!qV.isNaN) ventilationW = qV;
    }
  }

  // Floor heat loss — optional refinement.
  //
  // Only included when room.floorConstructionId is set. Missing
  // floor construction does NOT cause NaN in the total — the term is
  // simply not applicable (floor/ceiling are additive refinements, not
  // required inputs).
  var floorW = double.nan;
  if (room.floorConstructionId != null &&
      !floorAreaM2.isNaN &&
      floorAreaM2 > 0) {
    final uFloor =
        ref.watch(uValueProvider(room.floorConstructionId!));
    if (!uFloor.isNaN) {
      final tFloorAdjacent = room.floorAdjacentTempC ??
          (room.floorBoundary == BoundaryCondition.interior
              ? tIndoorDefault
              : tUnheatedDefault);
      final fFloor = ThermalEngine.boundaryCorrectionFactor(
        condition: room.floorBoundary,
        tRoomC: tThis,
        tOutdoorC: tOutdoor,
        tAdjacentC: tFloorAdjacent,
      );
      if (!fFloor.isNaN) {
        final qFloor = ThermalEngine.transmissionLoss(
          uValue: uFloor,
          areaM2: floorAreaM2,
          correctionF: fFloor,
          tIndoorC: tThis,
          tOutdoorC: tOutdoor,
        );
        if (!qFloor.isNaN) floorW = qFloor;
      }
    }
  }

  // Ceiling heat loss — optional refinement (same pattern as floor).
  var ceilingW = double.nan;
  if (room.ceilingConstructionId != null &&
      !floorAreaM2.isNaN &&
      floorAreaM2 > 0) {
    final uCeiling =
        ref.watch(uValueProvider(room.ceilingConstructionId!));
    if (!uCeiling.isNaN) {
      final tCeilingAdjacent = room.ceilingAdjacentTempC ??
          (room.ceilingBoundary == BoundaryCondition.interior
              ? tIndoorDefault
              : tUnheatedDefault);
      final fCeiling = ThermalEngine.boundaryCorrectionFactor(
        condition: room.ceilingBoundary,
        tRoomC: tThis,
        tOutdoorC: tOutdoor,
        tAdjacentC: tCeilingAdjacent,
      );
      if (!fCeiling.isNaN) {
        final qCeiling = ThermalEngine.transmissionLoss(
          uValue: uCeiling,
          areaM2: floorAreaM2,
          correctionF: fCeiling,
          tIndoorC: tThis,
          tOutdoorC: tOutdoor,
        );
        if (!qCeiling.isNaN) ceilingW = qCeiling;
      }
    }
  }

  // Sum the applicable components (NaN = not applicable → contributes 0).
  final totalW = transmissionW +
      (ventilationW.isNaN ? 0.0 : ventilationW) +
      (floorW.isNaN ? 0.0 : floorW) +
      (ceilingW.isNaN ? 0.0 : ceilingW);

  return (
    transmissionW: transmissionW,
    floorW: floorW,
    ceilingW: ceilingW,
    ventilationW: ventilationW,
    totalW: totalW,
  );
});

/// Heat demand for a single room in watts (W).
///
/// Thin accessor for [roomHeatDemandBreakdownProvider]'s [RoomHeatDemand.totalW].
/// Returns [double.nan] when the demand cannot be computed (any exterior wall
/// missing a construction, or data still loading) so downstream consumers can
/// distinguish incomplete data from a genuine zero.
final roomHeatDemandProvider =
    Provider.family<double, String>((ref, roomId) {
  return ref.watch(roomHeatDemandBreakdownProvider(roomId)).totalW;
});

/// Total heat demand for all rooms in a project in watts (W).
///
/// Sums [roomHeatDemandProvider] across every room on every floor.
/// Returns [double.nan] while any floor's room list is still loading.
/// Individual room demands that are NaN (e.g. no constructions
/// assigned) are excluded from the sum.
///
/// Depends on [floorsProvider], [roomsProvider], and
/// [roomHeatDemandProvider].
final buildingHeatDemandProvider =
    Provider.family<double, String>((ref, projectId) {
  final floors =
      ref.watch(floorsProvider(projectId)).asData?.value;
  if (floors == null) return double.nan;

  var totalW = 0.0;
  for (final floor in floors) {
    final rooms =
        ref.watch(roomsProvider(floor.id)).asData?.value;
    if (rooms == null) return double.nan;
    for (final room in rooms) {
      final demand =
          ref.watch(roomHeatDemandProvider(room.id));
      if (!demand.isNaN) totalW += demand;
    }
  }
  return totalW;
});
