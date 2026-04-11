import 'package:freezed_annotation/freezed_annotation.dart';

part 'material_layer.freezed.dart';
part 'material_layer.g.dart';

/// A single homogeneous layer inside a [WallConstruction].
///
/// Layers are ordered from outside to inside via [sortOrder].
/// Thermal properties are copied from the linked [MaterialEntry] at the
/// time of assignment but can be overridden per-layer.
@freezed
abstract class MaterialLayer with _$MaterialLayer {
  const factory MaterialLayer({
    /// UUID v4 primary key.
    required String id,

    /// UUID of the parent [WallConstruction].
    required String constructionId,

    /// Position in the layer stack (0 = outermost). Must be ≥ 0.
    required int sortOrder,

    /// UUID of the [MaterialEntry] this layer is based on.
    required String materialId,

    /// Layer thickness in millimetres. Range: 1.0–1000.0.
    required double thicknessMm,

    /// Thermal conductivity λ in W/(m·K). Range: 0.01–50.0.
    required double thermalConductivity,

    /// Bulk density in kg/m³. Range: 1–10 000.
    required double density,

    /// Specific heat capacity in J/(kg·K). Range: 100–5000.
    required double specificHeat,

    /// Stud width in mm. Non-null → inhomogeneous layer. Range: 1.0–1000.0.
    /// Always set together with [studClearGapMm] and [studLambda].
    double? studWidthMm,

    /// Clear gap between studs in mm (edge-to-edge). Range: 1.0–10000.0.
    double? studClearGapMm,

    /// Thermal conductivity of the stud in W/(m·K). Range: 0.01–50.0.
    /// Defaults to `lambdaTimberDefault` (0.13) when the stud is first added.
    double? studLambda,
  }) = _MaterialLayer;

  factory MaterialLayer.fromJson(Map<String, dynamic> json) =>
      _$MaterialLayerFromJson(json);
}
