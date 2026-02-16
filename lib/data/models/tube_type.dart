import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'tube_type.freezed.dart';
part 'tube_type.g.dart';

/// Specification record for a type of heating pipe.
@freezed
abstract class TubeType with _$TubeType {
  const factory TubeType({
    /// UUID v4 primary key.
    required String id,

    /// Display name (1–100 chars).
    required String name,

    /// Pipe material.
    required TubeMaterial material,

    /// Outer diameter in millimetres. Range: 8.0–32.0.
    @Default(16.0) double outerDiameterMm,

    /// Inner (bore) diameter in millimetres. Must be < [outerDiameterMm].
    @Default(13.0) double innerDiameterMm,

    /// Wall thickness in millimetres (may be derived or explicitly set).
    @Default(1.5) double wallThicknessMm,

    /// Thermal conductivity of the pipe wall in W/(m·K).
    @Default(0.35) double thermalConductivity,

    /// Absolute roughness of the bore surface in mm. Range: 0.001–0.1.
    @Default(0.007) double roughness,

    /// Maximum allowable fluid temperature in °C.
    @Default(60.0) double maxOperatingTempC,

    /// Maximum allowable operating pressure in bar.
    @Default(6.0) double maxOperatingPressure,
  }) = _TubeType;

  factory TubeType.fromJson(Map<String, dynamic> json) =>
      _$TubeTypeFromJson(json);
}
