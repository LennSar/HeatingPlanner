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

    /// Optional rated capacity of the user's pump (Pa).
    ///
    /// When provided, the system warns if this value falls below the
    /// calculated minimum required pump pressure (ADR-007).
    double? pumpCapacityPa,

    /// Width of the distributor body in millimetres. Default 500 mm.
    @Default(500) int widthMm,

    /// Rotation of the distributor in degrees (0–359, clockwise).
    ///
    /// 0° = outlet stubs on the upper long side (default).
    /// 90° = rotated 90° clockwise.
    @Default(0) int rotationDeg,

    /// Number of heating circuits the distributor can hold — one outlet
    /// stub each, equally spaced across [widthMm] (ADR-044). Supply and
    /// return of a circuit share one stub. Range: 1–24; never fewer than
    /// the highest outlet in use.
    @Default(4) int outletCount,
  }) = _Distributor;

  factory Distributor.fromJson(Map<String, dynamic> json) =>
      _$DistributorFromJson(json);
}
