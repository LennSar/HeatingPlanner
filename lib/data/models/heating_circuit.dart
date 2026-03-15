import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'point2d.dart';

part 'heating_circuit.freezed.dart';
part 'heating_circuit.g.dart';

/// A single pipe loop that connects a [Distributor] to a [HeatingZone].
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
  }) = _HeatingCircuit;

  factory HeatingCircuit.fromJson(Map<String, dynamic> json) =>
      _$HeatingCircuitFromJson(json);
}
