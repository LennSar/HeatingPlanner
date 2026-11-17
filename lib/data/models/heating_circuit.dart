import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'point2d.dart';

part 'heating_circuit.freezed.dart';
part 'heating_circuit.g.dart';

/// A single pipe loop that connects a [Distributor] to a [HeatingZone].
///
/// The connection pipes are drawn as one route: [centerlinePath]. The
/// supply and return pipes run parallel to it, [pipeSpacingMm] apart, and
/// are stored in [supplyRoutePath] / [returnRoutePath] so every consumer
/// (lengths, zone entry, painters) reads plain polylines (ADR-040).
///
/// Calculated fields ([tubeLengthM], [flowRateKgH], [pressureLossPa],
/// [valveSetting]) are derived by the hydraulic engine and stored here
/// as a snapshot for reporting and export.
@freezed
abstract class HeatingCircuit with _$HeatingCircuit {
  const factory HeatingCircuit({
    /// UUID v4 primary key.
    required String id,

    /// UUID of the parent [Distributor].
    required String distributorId,

    /// UUID of the [HeatingZone] served by this circuit.
    required String heatingZoneId,

    /// Continuous polyline from distributor to zone entry, in mm coords.
    @Default([]) List<Point2D> supplyRoutePath,

    /// Continuous polyline from zone exit back to distributor, in mm coords.
    @Default([]) List<Point2D> returnRoutePath,

    /// Total pipe length in metres (calculated).
    @Default(0.0) double tubeLengthM,

    /// Design flow rate in kg/h (calculated).
    @Default(0.0) double flowRateKgH,

    /// Pressure drop across this circuit in Pa (calculated).
    @Default(0.0) double pressureLossPa,

    /// Valve pre-setting for hydraulic balancing (calculated).
    @Default(0.0) double valveSetting,

    /// Supply/return run insulation strategy (ADR-008). Null = not yet chosen.
    SupplyPipeInsulationType? supplyPipeInsulationType,

    /// Route the connection pipes follow, distributor → zone, in mm
    /// coords (ADR-040). The supply and return pipes are derived from it.
    /// Empty for circuits whose two pipes were drawn separately.
    @Default([]) List<Point2D> centerlinePath,

    /// Centre-to-centre distance between the supply and the return
    /// connection pipe in millimetres. Range: 30–500.
    @Default(100) int pipeSpacingMm,

    /// Distance kept between a connection pipe and the nearest tube of a
    /// heating zone it runs through, in millimetres. Range: 0–1000.
    @Default(100) int zoneClearanceMm,

    /// Distance kept between the outer connection pipe and the face of a
    /// wall the route runs along, in millimetres. Range: 0–1000.
    @Default(100) int wallClearanceMm,

    /// True when the supply pipe runs on the right of [centerlinePath]
    /// (seen from the distributor) and the return on the left; false for
    /// the default, supply on the left (ADR-041).
    @Default(false) bool supplyOnRight,

    /// Zero-based outlet stub of the distributor this circuit is
    /// connected to (ADR-044). The route starts at that stub's tip and
    /// follows it when the distributor moves, turns, is resized or changes
    /// its outlet count. Null only for circuits saved before ADR-044; they
    /// get the next free outlet when the floor is loaded.
    int? outletIndex,
  }) = _HeatingCircuit;

  factory HeatingCircuit.fromJson(Map<String, dynamic> json) =>
      _$HeatingCircuitFromJson(json);
}
