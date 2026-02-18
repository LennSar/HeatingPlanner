import 'package:flutter/foundation.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/wall_segment.dart';

/// Result of a snap operation.
@immutable
class SnapResult {
  /// Creates a [SnapResult].
  const SnapResult({
    required this.point,
    required this.type,
  });

  /// The snapped point in world coordinates (mm).
  final Point2D point;

  /// The type of snap that was applied.
  final SnapType type;
}

/// The kind of snap applied.
enum SnapType {
  /// Snapped to an existing wall endpoint.
  endpoint,

  /// Snapped to the grid.
  grid,

  /// No snap applied (raw position).
  none,
}

/// Service for snapping cursor positions to grid and
/// existing wall endpoints.
abstract final class SnapService {
  /// Endpoint snap threshold in mm.
  static const double endpointThresholdMm = 200.0;

  /// Default grid spacing in mm.
  static const double gridSpacingMm = 100.0;

  /// Snap [rawPoint] to the nearest endpoint or grid
  /// intersection.
  ///
  /// Priority: endpoint snap first, then grid snap.
  static SnapResult snap(
    Point2D rawPoint,
    List<WallSegment> walls,
  ) {
    // Collect all wall endpoints.
    final endpoints = <Point2D>[];
    for (final wall in walls) {
      endpoints.add(wall.startPoint);
      endpoints.add(wall.endPoint);
    }

    // Try endpoint snap first.
    final epSnap = GeometryEngine.snapToEndpoint(
      rawPoint,
      endpoints,
      endpointThresholdMm,
    );
    if (epSnap != null) {
      return SnapResult(point: epSnap, type: SnapType.endpoint);
    }

    // Fall back to grid snap.
    final gridSnap = GeometryEngine.snapToGrid(
      rawPoint,
      gridSpacingMm,
    );
    return SnapResult(point: gridSnap, type: SnapType.grid);
  }
}
