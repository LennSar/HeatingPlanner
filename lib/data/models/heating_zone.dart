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

    /// UUID of the host [WallSegment].
    ///
    /// Required when [zoneType] is [ZoneType.wallHeating]; null for
    /// [ZoneType.floorHeating].
    String? wallSegmentId,

    /// Height of the wall heating zone in millimetres.
    ///
    /// Required when [zoneType] is [ZoneType.wallHeating]. Must be in
    /// the range 300 to the parent floor's [Floor.heightMm].
    /// Defaults to the floor's [Floor.heightMm] when not set.
    int? heightMm,

    /// Offset from the wall start endpoint to the zone's left edge (mm).
    ///
    /// Null for [ZoneType.floorHeating]. For wall zones, defaults to 0.0
    /// (zone starts at the wall start). Range: 0 to wallLength − [widthMm].
    double? positionOnWallMm,

    /// Length of the zone along the wall in millimetres.
    ///
    /// Null for [ZoneType.floorHeating]. For wall zones, null means
    /// the zone spans the full wall length. Range: 50 to wallLength.
    int? widthMm,
  }) = _HeatingZone;

  factory HeatingZone.fromJson(Map<String, dynamic> json) =>
      _$HeatingZoneFromJson(json);
}
