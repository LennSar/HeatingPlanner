import 'package:freezed_annotation/freezed_annotation.dart';

part 'window_element.freezed.dart';
part 'window_element.g.dart';

/// A window opening within a [WallSegment].
///
/// Named [WindowElement] to avoid collision with [dart:ui.Window].
@freezed
abstract class WindowElement with _$WindowElement {
  const factory WindowElement({
    /// UUID v4 primary key.
    required String id,

    /// UUID of the parent [WallSegment].
    required String wallSegmentId,

    /// Distance from the wall's start point to the window's left edge, in mm.
    required double positionOnWallMm,

    /// Opening width in millimetres. Range: 300–5000.
    @Default(1200) int widthMm,

    /// Opening height in millimetres. Range: 300–3000.
    @Default(1400) int heightMm,

    /// Sill height above finished floor level, in millimetres. Range: 0–2500.
    @Default(900) int sillHeightMm,

    /// Thermal transmittance of the glazing unit in W/(m²·K). Range: 0.5–6.0.
    @Default(1.3) double uValue,
  }) = _WindowElement;

  factory WindowElement.fromJson(Map<String, dynamic> json) =>
      _$WindowElementFromJson(json);
}
