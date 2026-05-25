import 'package:freezed_annotation/freezed_annotation.dart';

part 'wall_construction.freezed.dart';
part 'wall_construction.g.dart';

/// A named layer-stack definition used to compute U-values.
///
/// Surface resistances [rsi] (interior) and [rse] (exterior) follow
/// ISO 6946 defaults. Layers are stored separately as [MaterialLayer]
/// records linked by [id].
@freezed
abstract class WallConstruction with _$WallConstruction {
  const factory WallConstruction({
    /// UUID v4 primary key.
    required String id,

    /// Canonical English descriptive name (1–200 chars).
    required String name,

    /// Optional German display name. Falls back to [name] when absent.
    String? nameDe,

    /// Interior surface resistance in m²·K/W (default per ISO 6946).
    @Default(0.13) double rsi,

    /// Exterior surface resistance in m²·K/W (default per ISO 6946).
    @Default(0.04) double rse,

    /// Whether this construction is a saved user preset.
    ///
    /// Presets are stored in the same table and shown in the
    /// "Load preset" picker inside the construction editor.
    /// Loading a preset always deep-copies all layers so edits
    /// never mutate the saved preset.
    @Default(false) bool isPreset,

    /// ADR-020 Rule 2: true when this construction was auto-created by
    /// a wall-creation path with the project default material + thickness
    /// for the wall's [WallType]. Flips to false on the first mutation
    /// through the construction editor (ADR-020 Rule 4) and is mutually
    /// exclusive with [isPreset].
    @Default(false) bool isAutoDefault,
  }) = _WallConstruction;

  factory WallConstruction.fromJson(Map<String, dynamic> json) =>
      _$WallConstructionFromJson(json);
}
