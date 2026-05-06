import 'package:freezed_annotation/freezed_annotation.dart';

part 'material_entry.freezed.dart';
part 'material_entry.g.dart';

/// A material record in the application's material database.
///
/// Built-in entries ([isBuiltIn] == true) are seeded on first launch
/// and cannot be deleted. User-created entries have [isBuiltIn] == false.
@freezed
abstract class MaterialEntry with _$MaterialEntry {
  const factory MaterialEntry({
    /// UUID v4 primary key.
    required String id,

    /// Canonical English display name (1–200 chars).
    required String name,

    /// Optional German display name. Falls back to [name] when absent.
    String? nameDe,

    /// Material category string (e.g. "Masonry", "Insulation boards").
    required String category,

    /// Material subcategory string (e.g. "Historic brick", "Stone wool board").
    @Default('') String subcategory,

    /// Default thermal conductivity λ in W/(m·K).
    required double lambdaDefault,

    /// Default bulk density in kg/m³.
    required double densityDefault,

    /// Default specific heat capacity in J/(kg·K).
    required double specificHeatDefault,

    /// True for seed/built-in materials that ship with the application.
    @Default(true) bool isBuiltIn,
  }) = _MaterialEntry;

  factory MaterialEntry.fromJson(Map<String, dynamic> json) =>
      _$MaterialEntryFromJson(json);
}
