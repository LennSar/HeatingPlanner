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

  /// Snap [point] to the nearest grid intersection anchored at
  /// world origin (0, 0).
  ///
  /// Formula (mirrors [GridPainter] dot positions exactly):
  /// ```
  /// x_snapped = (point.x / spacingMm).round() * spacingMm
  /// y_snapped = (point.y / spacingMm).round() * spacingMm
  /// ```
  ///
  /// Pan offset, zoom level, and any drag state must NOT be passed
  /// here — the result depends only on [point] and [spacingMm].
  static Point2D snapToGrid(
    Point2D point, [
    double spacingMm = gridSpacingMm,
  ]) {
    if (spacingMm <= 0) return point;
    return Point2D(
      x: (point.x / spacingMm).round() * spacingMm,
      y: (point.y / spacingMm).round() * spacingMm,
    );
  }

  /// Snap [rawPoint] to the nearest endpoint, wall interior, or
  /// grid intersection, in that priority order.
  ///
  /// [spacingMm] overrides [gridSpacingMm] for the grid and wall-interior
  /// snap steps.
  static SnapResult snap(
    Point2D rawPoint,
    List<WallSegment> walls, [
    double spacingMm = gridSpacingMm,
  ]) {
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
    final wallSnap = _snapToWallInterior(rawPoint, walls, spacingMm);
    if (wallSnap != null) {
      return SnapResult(point: wallSnap, type: SnapType.wallPoint);
    }

    // 3. Grid snap (fallback).
    return SnapResult(
      point: snapToGrid(rawPoint, spacingMm),
      type: SnapType.grid,
    );
  }

  /// Snap [rawPoint] to the nearest grid-aligned point that lies on
  /// any wall segment within [wallSnapThresholdMm] of perpendicular
  /// distance.
  ///
  /// Prefers a grid-aligned point on the wall so the split point
  /// stays on the active grid. Falls back to the raw nearest point
  /// on the wall when grid alignment moves the point off the wall
  /// (e.g. for diagonal walls).
  ///
  /// Returns null if no wall is within the threshold.
  static Point2D? _snapToWallInterior(
    Point2D rawPoint,
    List<WallSegment> walls,
    double spacingMm,
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
    final gridPt = snapToGrid(best, spacingMm);
    for (final wall in walls) {
      if (GeometryEngine.isPointOnSegment(
          gridPt, wall.startPoint, wall.endPoint)) {
        return gridPt;
      }
    }

    // Grid snap is off-wall (diagonal wall); use raw nearest point.
    return best;
  }


  /// Snap [point] to the nearest existing wall endpoint within
  /// `2 × gridSpacingMm`. Returns the nearest endpoint when one
  /// qualifies, otherwise returns [point] unchanged.
  ///
  /// Used by [WallDrawTool] in rect mode (ADR-009 §Rule 1) so that
  /// the drag-start and drag-end corners snap to existing room
  /// corners automatically. The snap radius is intentionally wider
  /// than [endpointThresholdMm] to compensate for the coarser
  /// cursor control inherent in a click-drag gesture.
  static Point2D snapRectCorner(
    Point2D point,
    List<WallSegment> walls,
    double gridSpacingMm,
  ) {
    final radius = 2.0 * gridSpacingMm;
    Point2D? nearest;
    var minDist = double.infinity;

    for (final wall in walls) {
      for (final ep in [wall.startPoint, wall.endPoint]) {
        final d = GeometryEngine.distanceMm(point, ep);
        if (d < minDist) {
          minDist = d;
          nearest = ep;
        }
      }
    }

    if (nearest != null && minDist <= radius) return nearest;
    return point;
  }

  /// Tolerance for the room-draw edge-match used by rect-mode and the
  /// ADR-016 room-move drop (ADR-009 §Rule 2): each endpoint of a
  /// candidate edge must be within this distance of the corresponding
  /// existing-wall endpoint (forward or reversed) for the edge to be
  /// considered shared.
  static const double edgeMatchToleranceMm = 50.0;

  /// Returns the first room-assigned wall in [candidates] whose geometry
  /// matches the edge `a → b` within [toleranceMm] on **both** endpoints
  /// (direction-agnostic).
  ///
  /// Shared implementation of the room-draw shared-wall deduplication
  /// (ADR-009 §Rule 2). Used by both `WallDrawTool` rect mode and the
  /// ADR-016 room-move reconciliation in `SelectTool` so a single edge
  /// matcher backs both pipelines — there is no second, parallel
  /// "move-aware" matcher.
  static WallSegment? matchExistingWall(
    Point2D a,
    Point2D b,
    List<WallSegment> candidates, {
    double toleranceMm = edgeMatchToleranceMm,
  }) {
    for (final w in candidates) {
      if (w.roomId.isEmpty) continue;
      final fwd = GeometryEngine.distanceMm(w.startPoint, a) <= toleranceMm &&
          GeometryEngine.distanceMm(w.endPoint, b) <= toleranceMm;
      final rev = GeometryEngine.distanceMm(w.startPoint, b) <= toleranceMm &&
          GeometryEngine.distanceMm(w.endPoint, a) <= toleranceMm;
      if (fwd || rev) return w;
    }
    return null;
  }

  /// Snap [dragEnd] so that the new room's height and/or width matches that
  /// of an adjacent room whose shared wall is anchored at [dragStart]
  /// (ADR-010).
  ///
  /// **Algorithm (two independent axes):**
  ///
  /// 1. Collect *axis candidates* from [dragStart] `S`:
  ///    - Any wall endpoint `E` with `|E.x − S.x| ≤ 1 mm` contributes
  ///      `E.y` as a y-snap candidate (same x-column).
  ///    - Any endpoint `E` with `|E.y − S.y| ≤ 1 mm` contributes `E.x`
  ///      as an x-snap candidate (same y-row).
  ///
  /// 2. For each y-candidate `cy`: if `|dragEnd.y − cy| ≤ 100 mm`, the
  ///    nearest candidate overrides `dragEnd.y`. Same logic for x.
  ///
  /// Returns [dragEnd] unchanged when no candidate is within the threshold.
  static Point2D snapRectDimension(
    Point2D dragStart,
    Point2D dragEnd,
    List<WallSegment> walls,
  ) {
    const axisTolMm = 1.0;   // same-column / same-row tolerance (mm)
    const snapTolMm = 100.0; // ADR-010 snap threshold (mm)

    double newX = dragEnd.x;
    double newY = dragEnd.y;
    double bestYDist = double.infinity;
    double bestXDist = double.infinity;

    for (final wall in walls) {
      for (final ep in [wall.startPoint, wall.endPoint]) {
        // y-snap: endpoint is in the same x-column as dragStart.
        if ((ep.x - dragStart.x).abs() <= axisTolMm) {
          final dist = (dragEnd.y - ep.y).abs();
          if (dist <= snapTolMm && dist < bestYDist) {
            bestYDist = dist;
            newY = ep.y;
          }
        }
        // x-snap: endpoint is in the same y-row as dragStart.
        if ((ep.y - dragStart.y).abs() <= axisTolMm) {
          final dist = (dragEnd.x - ep.x).abs();
          if (dist <= snapTolMm && dist < bestXDist) {
            bestXDist = dist;
            newX = ep.x;
          }
        }
      }
    }

    if (newX == dragEnd.x && newY == dragEnd.y) return dragEnd;
    return Point2D(x: newX, y: newY);
  }

  /// Default wall-hover threshold for opening placement (mm).
  ///
  /// Wider than [wallSnapThresholdMm] so the user can hover
  /// slightly off the wall and still see a highlight.
  static const double wallHoverThresholdMm = 300.0;

  /// Find the [WallSegment] nearest to [point] within
  /// [thresholdMm] perpendicular distance.
  ///
  /// Returns null if no wall is within range.
  static WallSegment? nearestWall(
    Point2D point,
    List<WallSegment> walls, {
    double thresholdMm = wallHoverThresholdMm,
  }) {
    WallSegment? best;
    double bestDist = thresholdMm;

    for (final wall in walls) {
      final nearest = _nearestPointOnSegment(
        point,
        wall.startPoint,
        wall.endPoint,
      );
      final dist = GeometryEngine.distanceMm(point, nearest);
      if (dist < bestDist) {
        bestDist = dist;
        best = wall;
      }
    }
    return best;
  }

  /// Project [point] onto [wall] and return the distance in
  /// mm from the wall's start point.
  ///
  /// The result is clamped to [0, wallLength].
  static double positionOnWallMm(
    Point2D point,
    WallSegment wall,
  ) {
    final abx = wall.endPoint.x - wall.startPoint.x;
    final aby = wall.endPoint.y - wall.startPoint.y;
    final len2 = abx * abx + aby * aby;
    if (len2 < 1e-9) return 0.0;
    final t =
        ((point.x - wall.startPoint.x) * abx +
                (point.y - wall.startPoint.y) * aby) /
            len2;
    final tc = t.clamp(0.0, 1.0);
    return tc *
        GeometryEngine.distanceMm(
          wall.startPoint,
          wall.endPoint,
        );
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
