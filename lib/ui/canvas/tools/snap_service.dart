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

  /// Snapped to an interior point on an existing wall segment.
  ///
  /// Used when the cursor is within [SnapService.wallSnapThresholdMm]
  /// of a wall's surface but not within [SnapService.endpointThresholdMm]
  /// of any endpoint. The snapped point lies exactly on the wall,
  /// enabling [EditorStateNotifier.commitWallWithSplit] to split the
  /// host wall at the junction.
  wallPoint,

  /// Snapped to the grid.
  grid,

  /// No snap applied (raw position).
  none,
}

/// Service for snapping cursor positions to wall endpoints,
/// wall interiors, and the grid.
abstract final class SnapService {
  /// Endpoint snap threshold in mm.
  static const double endpointThresholdMm = 200.0;

  /// Wall-interior snap threshold (perpendicular distance) in mm.
  ///
  /// Lower than [endpointThresholdMm] so endpoint snap takes
  /// priority when the cursor is near a wall corner.
  static const double wallSnapThresholdMm = 150.0;

  /// Default grid spacing in mm.
  static const double gridSpacingMm = 100.0;

  /// Snap [rawPoint] to the nearest endpoint, wall interior, or
  /// grid intersection, in that priority order.
  static SnapResult snap(
    Point2D rawPoint,
    List<WallSegment> walls,
  ) {
    // 1. Endpoint snap (highest priority).
    final endpoints = <Point2D>[];
    for (final wall in walls) {
      endpoints.add(wall.startPoint);
      endpoints.add(wall.endPoint);
    }
    final epSnap = GeometryEngine.snapToEndpoint(
      rawPoint,
      endpoints,
      endpointThresholdMm,
    );
    if (epSnap != null) {
      return SnapResult(point: epSnap, type: SnapType.endpoint);
    }

    // 2. Wall-interior snap.
    final wallSnap = _snapToWallInterior(rawPoint, walls);
    if (wallSnap != null) {
      return SnapResult(point: wallSnap, type: SnapType.wallPoint);
    }

    // 3. Grid snap (fallback).
    final gridSnap = GeometryEngine.snapToGrid(
      rawPoint,
      gridSpacingMm,
    );
    return SnapResult(point: gridSnap, type: SnapType.grid);
  }

  /// Snap [rawPoint] to the nearest grid-aligned point that lies on
  /// any wall segment within [wallSnapThresholdMm] of perpendicular
  /// distance.
  ///
  /// Prefers a grid-aligned point on the wall so the split point
  /// stays on the 100 mm grid. Falls back to the raw nearest point
  /// on the wall when grid alignment moves the point off the wall
  /// (e.g. for diagonal walls).
  ///
  /// Returns null if no wall is within the threshold.
  static Point2D? _snapToWallInterior(
    Point2D rawPoint,
    List<WallSegment> walls,
  ) {
    Point2D? best;
    double bestDist = wallSnapThresholdMm;

    for (final wall in walls) {
      final nearest = _nearestPointOnSegment(
        rawPoint,
        wall.startPoint,
        wall.endPoint,
      );
      final dist = GeometryEngine.distanceMm(rawPoint, nearest);
      if (dist < bestDist) {
        bestDist = dist;
        best = nearest;
      }
    }

    if (best == null) return null;

    // Try grid-aligning the result and confirm it still lies on a wall.
    final gridPt = GeometryEngine.snapToGrid(best, gridSpacingMm);
    for (final wall in walls) {
      if (GeometryEngine.isPointOnSegment(
          gridPt, wall.startPoint, wall.endPoint)) {
        return gridPt;
      }
    }

    // Grid snap is off-wall (diagonal wall); use raw nearest point.
    return best;
  }

  /// Nearest point on segment [a]→[b] to [p], clamped to segment
  /// bounds.
  static Point2D _nearestPointOnSegment(
    Point2D p,
    Point2D a,
    Point2D b,
  ) {
    final abx = b.x - a.x;
    final aby = b.y - a.y;
    final len2 = abx * abx + aby * aby;
    if (len2 < 1e-9) return a;
    final t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2;
    final tc = t.clamp(0.0, 1.0);
    return Point2D(x: a.x + tc * abx, y: a.y + tc * aby);
  }
}
