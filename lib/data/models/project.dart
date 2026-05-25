import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

/// Optional geographic location attached to a project.
@freezed
abstract class GeoLocation with _$GeoLocation {
  const factory GeoLocation({
    required double latitude,
    required double longitude,
    String? cityName,
  }) = _GeoLocation;

  factory GeoLocation.fromJson(Map<String, dynamic> json) =>
      _$GeoLocationFromJson(json);
}

/// Top-level container for a heating-planner project.
///
/// Holds design parameters that apply to the whole building.
@freezed
abstract class Project with _$Project {
  const factory Project({
    /// UUID v4 primary key.
    required String id,

    /// Human-readable project name (1–255 chars).
    required String name,

    /// Timestamp when the project was first created (immutable).
    required DateTime createdAt,

    /// Timestamp of the last modification.
    required DateTime modifiedAt,

    /// Outdoor design temperature in °C for heat-demand calculations.
    @Default(-12.0) double designOutdoorTempC,

    /// Default indoor target temperature in °C (applied to new rooms).
    @Default(20.0) double defaultIndoorTempC,

    /// Default floor-to-ceiling height in mm (2000–6000).
    @Default(2600) int floorHeightMm,

    /// Default temperature of unheated adjacent spaces in °C (0–25).
    @Default(10.0) double unheatedSpaceTempC,

    /// Default total thickness in mm for exterior walls (ADR-017).
    ///
    /// Used as the fallback `WallSegment.thicknessMm` for exterior walls
    /// whose `constructionId` is null. Constraint: 50–1000.
    @Default(240) int defaultExteriorWallThicknessMm,

    /// Default total thickness in mm for interior (shared) walls (ADR-017).
    ///
    /// Used as the fallback `WallSegment.thicknessMm` for interior walls
    /// whose `constructionId` is null. Constraint: 50–1000.
    @Default(120) int defaultInteriorWallThicknessMm,

    /// Default total thickness in mm for partition walls (ADR-017).
    ///
    /// Used as the fallback `WallSegment.thicknessMm` for partition walls
    /// whose `constructionId` is null. Constraint: 50–1000.
    @Default(100) int defaultPartitionWallThicknessMm,

    /// Default material catalog entry ID used for the single auto-default
    /// layer of every freshly drawn exterior wall (ADR-020 Rule 1).
    ///
    /// Initial value points at the "Vertical coring brick" entry
    /// (`mat-016`) in `assets/materials.json`. Editing this field in the
    /// project settings cascades to every wall whose construction has
    /// `isAutoDefault = true` per ADR-020 Rule 6.
    @Default('mat-016') String defaultExteriorMaterialId,

    /// Default material catalog entry ID for new interior (shared) walls.
    ///
    /// See [defaultExteriorMaterialId] for cascade semantics.
    @Default('mat-016') String defaultInteriorMaterialId,

    /// Default material catalog entry ID for new partition walls.
    ///
    /// See [defaultExteriorMaterialId] for cascade semantics.
    @Default('mat-016') String defaultPartitionMaterialId,

    /// Optional geographic location used for climate data lookup.
    GeoLocation? location,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
}
