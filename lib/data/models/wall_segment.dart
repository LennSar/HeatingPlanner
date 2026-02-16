import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'point2d.dart';

part 'wall_segment.freezed.dart';
part 'wall_segment.g.dart';

/// A single wall edge on the boundary of a [Room].
///
/// [startPoint] and [endPoint] lie on the room polygon.
/// [orientation] is auto-calculated from the segment angle.
@freezed
abstract class WallSegment with _$WallSegment {
  const factory WallSegment({
    /// UUID v4 primary key.
    required String id,

    /// UUID of the owning [Room].
    required String roomId,

    /// Start vertex in millimetre coordinates.
    required Point2D startPoint,

    /// End vertex in millimetre coordinates.
    required Point2D endPoint,

    /// Thermal and structural classification.
    @Default(WallType.exterior) WallType wallType,

    /// UUID of the associated [WallConstruction]; null if unassigned.
    String? constructionId,

    /// UUID of the room on the other side; null for exterior walls.
    String? adjacentRoomId,

    /// Compass orientation derived from segment angle.
    @Default(CardinalDirection.north) CardinalDirection orientation,
  }) = _WallSegment;

  factory WallSegment.fromJson(Map<String, dynamic> json) =>
      _$WallSegmentFromJson(json);
}
