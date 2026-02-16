import 'package:freezed_annotation/freezed_annotation.dart';

part 'door.freezed.dart';
part 'door.g.dart';

/// A door opening within a [WallSegment].
@freezed
abstract class Door with _$Door {
  const factory Door({
    /// UUID v4 primary key.
    required String id,

    /// UUID of the parent [WallSegment].
    required String wallSegmentId,

    /// Distance from the wall's start point to the door's left edge, in mm.
    required double positionOnWallMm,

    /// Opening width in millimetres. Range: 300–5000.
    @Default(900) int widthMm,

    /// Opening height in millimetres. Range: 300–3000.
    @Default(2100) int heightMm,

    /// Sill height above finished floor level (usually 0 for doors).
    @Default(0) int sillHeightMm,

    /// Effective thermal transmittance of the door leaf in W/(m²·K).
    /// Range: 0.5–6.0.
    @Default(2.0) double uValue,
  }) = _Door;

  factory Door.fromJson(Map<String, dynamic> json) => _$DoorFromJson(json);
}
