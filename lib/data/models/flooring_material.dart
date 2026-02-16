import 'package:freezed_annotation/freezed_annotation.dart';

part 'flooring_material.freezed.dart';
part 'flooring_material.g.dart';

/// A floor covering with its thermal resistance.
///
/// Used by the heating-output engine to calculate the temperature
/// reduction across the floor structure (EN 1264-2 R_λB term).
@freezed
abstract class FlooringMaterial with _$FlooringMaterial {
  const factory FlooringMaterial({
    /// UUID v4 primary key.
    required String id,

    /// Display name (1–200 chars).
    required String name,

    /// Total thermal resistance of the covering in m²·K/W.
    required double thermalResistance,
  }) = _FlooringMaterial;

  factory FlooringMaterial.fromJson(Map<String, dynamic> json) =>
      _$FlooringMaterialFromJson(json);
}
