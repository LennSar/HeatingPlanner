import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'point2d.dart';

part 'wall_segment.freezed.dart';
part 'wall_segment.g.dart';

/// A single wall edge on the boundary of a [Room].
///
/// [startPoint] and [endPoint] are the wall **centerline** (ADR-017).
/// [orientation] is auto-calculated from the segment angle.
@freezed
abstract class WallSegment with _$WallSegment {
  const factory WallSegment({
    /// UUID v4 primary key.
    required String id,

    /// UUID of the owning [Room].
    required String roomId,

    /// Centerline start vertex in millimetre coordinates (ADR-017).
    required Point2D startPoint,

    /// Centerline end vertex in millimetre coordinates (ADR-017).
    required Point2D endPoint,

    /// Thermal and structural classification.
    @Default(WallType.exterior) WallType wallType,

    /// Total wall thickness in mm (ADR-017).
    ///
    /// Constraint: 50.0–1000.0. Stored denormalized; source-of-truth is
    /// `sum(MaterialLayer.thicknessMm)` when `constructionId != null`,
    /// otherwise the matching `Project.default<WallType>WallThicknessMm`.
    @Default(0.0) double thicknessMm,

    /// Which face stays fixed when [thicknessMm] changes (ADR-017).
    ///
    /// Defaults per ADR-017 Rule 2: `innerFace` for exterior walls,
    /// `centerline` for interior and partition walls. Forced to
    /// `centerline` whenever `mirrorId != null` (ADR-017 Rule 3).
    @Default(WallAnchorMode.centerline) WallAnchorMode anchorMode,

    /// UUID of the associated [WallConstruction]; null if unassigned.
    String? constructionId,

    /// UUID of the room on the other side; null for exterior walls.
    String? adjacentRoomId,

    /// Compass orientation derived from segment angle.
    @Default(CardinalDirection.north) CardinalDirection orientation,

    /// UUID of the mirror wall in an ADR-001 shared-wall pair.
    ///
    /// Set by [addRoomFromDetection] when the interior copy is created.
    /// Null for exterior and unassigned walls.
    String? mirrorId,
  }) = _WallSegment;

  factory WallSegment.fromJson(Map<String, dynamic> json) =>
      _$WallSegmentFromJson(json);
}
