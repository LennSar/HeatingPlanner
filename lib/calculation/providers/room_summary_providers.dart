// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../repositories/heating_repository.dart';
import '../../ui/providers/editor_state_provider.dart';
import 'flow_rate_providers.dart';
import 'heat_demand_providers.dart';
import 'heat_output_providers.dart';
import 'pressure_loss_providers.dart';
import 'tube_length_providers.dart';

/// Design values of one heating zone and the circuit that feeds it
/// (ADR-045). Every `double` is [double.nan] when it cannot be
/// calculated yet — most of them while the zone has no circuit.
typedef ZoneSummary = ({
  /// Id of the zone.
  String zoneId,

  /// Id of the circuit feeding the zone; null while unconnected.
  String? circuitId,

  /// 1-based position of the circuit on the floor; null while
  /// unconnected.
  int? circuitNumber,

  /// Floor or wall heating.
  ZoneType zoneType,

  /// Heat-emitting area.
  double areaM2,

  /// Supply temperature at the distributor.
  double supplyTempC,

  /// Return temperature at the distributor.
  double returnTempC,

  /// Heat flux density q (EN 1264-2).
  double specificOutputWPerM2,

  /// Heat delivered by the zone, q × A.
  double outputW,

  /// Mean surface temperature.
  double surfaceTempC,

  /// Design mass flow rate of the circuit.
  double flowRateKgH,

  /// Water velocity in the tube.
  double velocityMPerS,

  /// Tube outer diameter.
  double tubeOuterDiameterMm,

  /// Tube wall thickness.
  double tubeWallThicknessMm,

  /// Pressure loss of the whole circuit.
  double pressureLossPa,

  /// Tube laid inside the zone.
  double zoneTubeLengthM,

  /// Tube laid inside the zone plus both connection pipes.
  double totalTubeLengthM,
});

/// Heat balance and hydraulics of one room (ADR-045).
typedef RoomSummary = ({
  /// Id of the room.
  String roomId,

  /// Room name.
  String name,

  /// False for an unheated room (ADR-036).
  bool isHeated,

  /// Design room temperature.
  double targetTempC,

  /// Heat demand (EN 12831); NaN while it cannot be calculated.
  double demandW,

  /// Heat delivered by all connected zones of the room.
  double outputW,

  /// [outputW] − [demandW]; negative when the room is under-supplied.
  /// NaN while the demand is unknown.
  double balanceW,

  /// Sum of the circuit flow rates; NaN without a connected zone.
  double flowRateKgH,

  /// Highest circuit pressure loss; NaN without a connected zone.
  double maxPressureLossPa,

  /// Tube laid inside the room's zones; NaN without a zone.
  double zoneTubeLengthM,

  /// Tube of the room's circuits including connection pipes; NaN
  /// without a connected zone.
  double totalTubeLengthM,

  /// The room's zones in drawing order.
  List<ZoneSummary> zones,
});

/// All rooms of the open floor with the floor totals (ADR-045).
typedef FloorSummary = ({
  /// One entry per room, in drawing order.
  List<RoomSummary> rooms,

  /// Sum of the room demands that could be calculated.
  double demandW,

  /// True when at least one room's demand could not be calculated and
  /// is therefore missing from [demandW] and [balanceW].
  bool demandIncomplete,

  /// Heat delivered by all connected zones.
  double outputW,

  /// [outputW] − [demandW].
  double balanceW,

  /// Total flow rate at the distributor; NaN without a connected zone.
  double flowRateKgH,

  /// Highest circuit pressure loss — the pressure the pump must supply
  /// for the circuits. NaN without a connected zone.
  double maxPressureLossPa,

  /// Tube laid inside all zones; NaN without a zone.
  double zoneTubeLengthM,

  /// All tube including connection pipes; NaN without a connected zone.
  double totalTubeLengthM,
});

/// Sum of the finite values, or [double.nan] when there are none.
double _sumOrNaN(Iterable<double> values) {
  final finite = values.where((v) => v.isFinite);
  return finite.isEmpty ? double.nan : finite.fold(0.0, (a, b) => a + b);
}

/// Largest finite value, or [double.nan] when there are none.
double _maxOrNaN(Iterable<double> values) {
  final finite = values.where((v) => v.isFinite);
  return finite.isEmpty ? double.nan : finite.reduce((a, b) => a > b ? a : b);
}

/// Combines the [zones] of one room with its [demandW].
///
/// A zone whose output is unknown (not connected) delivers nothing, so
/// the room's balance shows what is actually supplied.
RoomSummary summariseRoom({
  required String roomId,
  required String name,
  required bool isHeated,
  required double targetTempC,
  required double demandW,
  required List<ZoneSummary> zones,
}) {
  final outputW = zones
      .map((z) => z.outputW)
      .where((v) => v.isFinite)
      .fold(0.0, (a, b) => a + b);
  return (
    roomId: roomId,
    name: name,
    isHeated: isHeated,
    targetTempC: targetTempC,
    demandW: demandW,
    outputW: outputW,
    balanceW: demandW.isNaN ? double.nan : outputW - demandW,
    flowRateKgH: _sumOrNaN(zones.map((z) => z.flowRateKgH)),
    maxPressureLossPa: _maxOrNaN(zones.map((z) => z.pressureLossPa)),
    zoneTubeLengthM: _sumOrNaN(zones.map((z) => z.zoneTubeLengthM)),
    totalTubeLengthM: _sumOrNaN(zones.map((z) => z.totalTubeLengthM)),
    zones: zones,
  );
}

/// Combines [rooms] into the floor totals.
FloorSummary summariseFloor(List<RoomSummary> rooms) {
  final demandW = rooms
      .map((r) => r.demandW)
      .where((v) => v.isFinite)
      .fold(0.0, (a, b) => a + b);
  final outputW = rooms.fold(0.0, (a, r) => a + r.outputW);
  return (
    rooms: rooms,
    demandW: demandW,
    demandIncomplete: rooms.any((r) => r.demandW.isNaN),
    outputW: outputW,
    balanceW: outputW - demandW,
    flowRateKgH: _sumOrNaN(rooms.map((r) => r.flowRateKgH)),
    maxPressureLossPa: _maxOrNaN(rooms.map((r) => r.maxPressureLossPa)),
    zoneTubeLengthM: _sumOrNaN(rooms.map((r) => r.zoneTubeLengthM)),
    totalTubeLengthM: _sumOrNaN(rooms.map((r) => r.totalTubeLengthM)),
  );
}

/// Per-room summary of the open floor: heat demand, heat delivered at
/// the design flow rate and water temperatures, their difference,
/// pressure loss and tube lengths (ADR-045).
///
/// Collects existing results only — it calculates nothing itself:
/// - demand: [roomHeatDemandProvider] (EN 12831)
/// - output and surface temperature: [zoneHeatOutputProvider],
///   [zoneHeatOutputWProvider], [zoneSurfaceTempProvider] (EN 1264-2)
/// - flow rate, velocity, pressure loss: [flowRateProvider],
///   [flowVelocityProvider], [pressureLossProvider] (Darcy–Weisbach)
/// - lengths: [zoneTubeLengthProvider], [tubeLengthProvider] (measured
///   along the drawing, ADR-042 Rule 4)
final floorSummaryProvider = Provider<FloorSummary>((ref) {
  final rooms = ref.watch(editorStateProvider.select((s) => s.rooms));
  final zones = ref.watch(editorStateProvider.select((s) => s.zones));
  final circuits = ref.watch(editorStateProvider.select((s) => s.circuits));
  final distributor = ref.watch(
    editorStateProvider.select((s) => s.distributor),
  );

  ZoneSummary zoneSummary(String zoneId) {
    final zone = zones.firstWhere((z) => z.id == zoneId);
    final circuitIndex = circuits.indexWhere((c) => c.heatingZoneId == zone.id);
    final circuit = circuitIndex < 0 ? null : circuits[circuitIndex];
    final feeds = circuit != null && distributor?.id == circuit.distributorId;
    final tubeType = ref
        .watch(tubeTypeByIdProvider(zone.tubeTypeId))
        .asData
        ?.value;

    return (
      zoneId: zone.id,
      circuitId: circuit?.id,
      circuitNumber: circuit == null ? null : circuitIndex + 1,
      zoneType: zone.zoneType,
      areaM2: ref.watch(zoneHeatedAreaM2Provider(zone.id)),
      supplyTempC: feeds ? distributor!.supplyTempC : double.nan,
      returnTempC: feeds ? distributor!.returnTempC : double.nan,
      specificOutputWPerM2: ref.watch(zoneHeatOutputProvider(zone.id)),
      outputW: ref.watch(zoneHeatOutputWProvider(zone.id)),
      surfaceTempC: ref.watch(zoneSurfaceTempProvider(zone.id)),
      flowRateKgH: circuit == null
          ? double.nan
          : ref.watch(flowRateProvider(circuit.id)),
      velocityMPerS: circuit == null
          ? double.nan
          : ref.watch(flowVelocityProvider(circuit.id)),
      tubeOuterDiameterMm: tubeType?.outerDiameterMm ?? double.nan,
      tubeWallThicknessMm: tubeType?.wallThicknessMm ?? double.nan,
      pressureLossPa: circuit == null
          ? double.nan
          : ref.watch(pressureLossProvider(circuit.id)).asData?.value ??
                double.nan,
      zoneTubeLengthM: ref.watch(zoneTubeLengthProvider(zone.id)),
      totalTubeLengthM: circuit == null
          ? double.nan
          : ref.watch(tubeLengthProvider(circuit.id)),
    );
  }

  return summariseFloor([
    for (final room in rooms)
      summariseRoom(
        roomId: room.id,
        name: room.name,
        isHeated: room.isHeated,
        targetTempC: room.targetTempC,
        demandW: ref.watch(roomHeatDemandProvider(room.id)),
        zones: [
          for (final zone in zones)
            if (zone.roomId == room.id) zoneSummary(zone.id),
        ],
      ),
  ]);
});
