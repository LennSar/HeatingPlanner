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

    /// Descriptive name (1–200 chars).
    required String name,

    /// Interior surface resistance in m²·K/W (default per ISO 6946).
    @Default(0.13) double rsi,

    /// Exterior surface resistance in m²·K/W (default per ISO 6946).
    @Default(0.04) double rse,
  }) = _WallConstruction;

  factory WallConstruction.fromJson(Map<String, dynamic> json) =>
      _$WallConstructionFromJson(json);
}
