import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'point2d.dart';

part 'heating_zone.freezed.dart';
part 'heating_zone.g.dart';

/// A heated area within a [Room], served by a single pipe circuit.
///
/// The zone polygon must lie entirely inside the parent room polygon.
@freezed
abstract class HeatingZone with _$HeatingZone {
  const factory HeatingZone({
    /// UUID v4 primary key.
    required String id,

    /// UUID of the parent [Room].
    required String roomId,

    /// Whether this is a floor-heating or wall-heating zone.
    @Default(ZoneType.floorHeating) ZoneType zoneType,

    /// Zone boundary polygon in millimetre coordinates (≥ 3 vertices).
    @Default([]) List<Point2D> polygon,

    /// Centre-to-centre pipe spacing in millimetres. Range: 50–400.
    @Default(150) int tubeSpacingMm,

    /// UUID of the [TubeType] used in this zone.
    required String tubeTypeId,

    /// UUID of the [FlooringMaterial] covering this zone.
    required String flooringMaterialId,

    /// Minimum distance from wall edge to first pipe run, in mm.
    /// Range: 50–300.
    @Default(100) int borderDistanceMm,

    /// Pipe routing pattern within the zone.
    @Default(LayoutPattern.meander) LayoutPattern layoutPattern,

    /// UUID of the assigned [HeatingCircuit]; null until connected.
    String? circuitId,
  }) = _HeatingZone;

  factory HeatingZone.fromJson(Map<String, dynamic> json) =>
      _$HeatingZoneFromJson(json);
}
