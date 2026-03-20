import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'point2d.dart';

part 'room.freezed.dart';
part 'room.g.dart';

/// A thermally bounded room on a floor.
///
/// The room boundary is defined by [polygon], a closed list of
/// [Point2D] vertices in millimetre coordinates (≥ 3 points).
@freezed
abstract class Room with _$Room {
  const factory Room({
    /// UUID v4 primary key.
    required String id,

    /// UUID of the parent [Floor].
    required String floorId,

    /// Display name (1–100 chars).
    required String name,

    /// Target indoor temperature in °C. Range: 15.0–30.0.
    @Default(20.0) double targetTempC,

    /// Ventilation air-change rate in h⁻¹. Range: 0.1–5.0.
    @Default(0.5) double airChangeRate,

    /// Room boundary polygon. Must be closed (last vertex = first vertex)
    /// and contain at least 3 distinct vertices.
    @Default([]) List<Point2D> polygon,

    /// UUID of the [WallConstruction] used for floor/slab.
    /// Null = not assigned.
    String? floorConstructionId,

    /// UUID of the [WallConstruction] used for ceiling/roof.
    /// Null = not assigned.
    String? ceilingConstructionId,

    /// Boundary condition below the floor slab.
    @Default(BoundaryCondition.ground)
    BoundaryCondition floorBoundary,

    /// Boundary condition above the ceiling slab.
    @Default(BoundaryCondition.exterior)
    BoundaryCondition ceilingBoundary,

    /// User-supplied correction factor (0.0–1.0) for floor, when
    /// [floorBoundary] == [BoundaryCondition.unheatedSpace].
    /// Null means the engine will return NaN (user must set it).
    double? floorUnheatedCorrectionFactor,

    /// User-supplied correction factor (0.0–1.0) for ceiling, when
    /// [ceilingBoundary] == [BoundaryCondition.unheatedSpace].
    /// Null means the engine will return NaN (user must set it).
    double? ceilingUnheatedCorrectionFactor,
  }) = _Room;

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
}
