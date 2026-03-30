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

    /// Optional geographic location used for climate data lookup.
    GeoLocation? location,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
}
