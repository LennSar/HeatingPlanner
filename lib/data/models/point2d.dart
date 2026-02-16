import 'package:freezed_annotation/freezed_annotation.dart';

part 'point2d.freezed.dart';
part 'point2d.g.dart';

/// An immutable 2-D point in millimetre canvas coordinates.
@freezed
abstract class Point2D with _$Point2D {
  const factory Point2D({
    /// X coordinate in millimetres.
    required double x,

    /// Y coordinate in millimetres.
    required double y,
  }) = _Point2D;

  factory Point2D.fromJson(Map<String, dynamic> json) =>
      _$Point2DFromJson(json);
}
