import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'flooring_material.freezed.dart';
part 'flooring_material.g.dart';

/// ID of the built-in 'Custom' [FlooringMaterial] sentinel.
///
/// When a zone's `flooringMaterialId` equals this value, the zone's
/// `customFlooringResistance` field is used for calculations instead
/// of this row's placeholder R value of 0.
const kCustomFlooringMaterialId = '20000000-0000-4000-8000-000000000099';

/// A surface covering with its thermal resistance.
///
/// Used by the heating-output engine to calculate the temperature
/// reduction across the floor or wall structure (EN 1264-2 R_λB term).
@freezed
abstract class FlooringMaterial with _$FlooringMaterial {
  const factory FlooringMaterial({
    /// UUID v4 primary key.
    required String id,

    /// Display name (1–200 chars).
    required String name,

    /// Total thermal resistance of the covering in m²·K/W.
    required double thermalResistance,

    /// Which zone surface this material is applicable to.
    @Default(SurfaceType.floor) SurfaceType surfaceType,
  }) = _FlooringMaterial;

  factory FlooringMaterial.fromJson(Map<String, dynamic> json) =>
      _$FlooringMaterialFromJson(json);
}
