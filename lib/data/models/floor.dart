import 'package:freezed_annotation/freezed_annotation.dart';

part 'floor.freezed.dart';
part 'floor.g.dart';

/// A storey within a building project.
@freezed
abstract class Floor with _$Floor {
  const factory Floor({
    /// UUID v4 primary key.
    required String id,

    /// Display name (1–100 chars).
    required String name,

    /// Zero-based storey index (0 = ground floor).
    @Default(0) int level,

    /// Clear ceiling height in millimetres. Range: 2000–6000.
    @Default(2600) int heightMm,
  }) = _Floor;

  factory Floor.fromJson(Map<String, dynamic> json) => _$FloorFromJson(json);
}
