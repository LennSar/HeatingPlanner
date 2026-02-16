import 'package:freezed_annotation/freezed_annotation.dart';

import 'point2d.dart';

part 'distributor.freezed.dart';
part 'distributor.g.dart';

/// A manifold/distributor unit placed on a floor.
///
/// Supplies and collects water for all [HeatingCircuit]s connected to it.
@freezed
abstract class Distributor with _$Distributor {
  const factory Distributor({
    /// UUID v4 primary key.
    required String id,

    /// UUID of the [Floor] this distributor is placed on.
    required String floorId,

    /// Position of the distributor on the floor plan in millimetres.
    required Point2D position,

    /// Supply water temperature in °C. Range: 20–55.
    @Default(35.0) double supplyTempC,

    /// Return water temperature in °C. Must be < [supplyTempC].
    @Default(28.0) double returnTempC,

    /// Available pump head pressure in Pa. Must be > 0.
    @Default(25000.0) double pumpHeadPa,
  }) = _Distributor;

  factory Distributor.fromJson(Map<String, dynamic> json) =>
      _$DistributorFromJson(json);
}
