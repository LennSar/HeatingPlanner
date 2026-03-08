// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../repositories/building_repository.dart';
import 'project_settings_provider.dart';
import '../engines/geometry_engine.dart';
import '../engines/thermal_engine.dart';
import 'u_value_providers.dart';

/// Heat demand for a single room in watts (W).
///
/// EN 12831 design heat demand:
///   Q_total = Q_T (transmission) + Q_V (ventilation)
///
/// Iterates all [WallSegment]s owned by the room per ADR-001. Walls
/// without a [WallSegment.constructionId] are skipped. Interior and
/// partition walls use [ThermalEngine.interiorCorrectionFactor] per
/// ADR-002. When [WallSegment.adjacentRoomId] is null the correction
/// factor defaults to 0.0 (safe over-estimate, per ADR-002).
///
/// Depends on [roomProvider], [wallSegmentsProvider],
/// [windowsProvider], [doorsProvider], [floorProvider],
/// [uValueProvider], and [designOutdoorTempCProvider].
final roomHeatDemandProvider =
    Provider.family<double, String>((ref, roomId) {
  final room = ref.watch(roomProvider(roomId)).asData?.value;
  if (room == null) return double.nan;

  final walls =
      ref.watch(wallSegmentsProvider(roomId)).asData?.value;
  if (walls == null) return double.nan;

  final tOutdoor = ref.watch(designOutdoorTempCProvider);
  final tThis = room.targetTempC;

  // Ceiling height: read from floor, fall back to 2600 mm.
  final ceilingHeightMm = ref
          .watch(floorProvider(room.floorId))
          .asData
          ?.value
          ?.heightMm
          .toDouble() ??
      2600.0;

  var totalW = 0.0;

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
    final wallLengthMm = GeometryEngine.segmentLengthMm(
      wall.startPoint,
      wall.endPoint,
    );
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
      if (!wallQ.isNaN) totalW += wallQ;
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
      if (!q.isNaN) totalW += q;
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
      if (!q.isNaN) totalW += q;
    }
  }

  // Ventilation heat loss (EN 12831 Q_V).
  final floorAreaM2 =
      GeometryEngine.polygonAreaM2(room.polygon);
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
      if (!qV.isNaN) totalW += qV;
    }
  }

  return totalW;
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
