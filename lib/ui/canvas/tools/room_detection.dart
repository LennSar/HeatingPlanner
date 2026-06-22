import 'dart:math' as math;

import '../../../core/utils/geometry_utils.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';

/// Result of room detection: the polygon vertices and the
/// wall IDs that form the boundary.
class DetectedRoom {
  /// Creates a [DetectedRoom].
  const DetectedRoom({
    required this.polygon,
    required this.wallIds,
  });

  /// Closed polygon vertices (first != last).
  final List<Point2D> polygon;

  /// IDs of the walls forming this room boundary.
  final List<String> wallIds;
}

/// Outcome of attempting to detect a room after a new wall was drawn.
enum RoomDetectionOutcome {
  /// A unique room was found whose floor area is not shared with any
  /// existing room.
  detected,

  /// No closed cycle through the new wall exists yet — nothing to do.
  none,

  /// One or more closed cycles exist, but every reasonable wall
  /// constellation overlaps the floor area of an existing room. The
  /// constellation is ambiguous and no unique room can be created.
  overlapsExistingRoom,
}

/// Outcome plus the detected room(s) (empty unless [outcome] is
/// [RoomDetectionOutcome.detected]).
class RoomDetectionResult {
  /// Creates a [RoomDetectionResult].
  const RoomDetectionResult(this.outcome, this.rooms);

  /// What happened during detection.
  final RoomDetectionOutcome outcome;

  /// The detected rooms. Empty unless [outcome] is
  /// [RoomDetectionOutcome.detected]. A single wall can close a room on
  /// each of its two sides at once, so this may hold up to two entries.
  final List<DetectedRoom> rooms;

  /// The first detected room, or null. Convenience for single-room
  /// callers and tests.
  DetectedRoom? get room => rooms.isEmpty ? null : rooms.first;
}

/// Detects closed rooms from a wall graph.
///
/// After a new wall is added, checks whether the wall graph contains a
/// closed cycle that forms a room.
///
/// Detection walks the **planar face** on each side of the new wall
/// (angular next-edge traversal). Each undirected wall borders exactly
/// two faces; the two faces adjacent to the new wall are the only
/// reasonable room constellations the new wall can bound. This avoids
/// the historical minimum-hop ambiguity where a larger cycle that
/// *encloses* an existing room could be returned instead of the small
/// adjacent room (see the screenshot bug: a new room that wrapped the
/// previously drawn room).
abstract final class RoomDetection {
  /// Point matching tolerance in mm.
  ///
  /// Walls are snapped to a 100mm grid, so 1mm tolerance
  /// is sufficient.
  static const double _tolerance = 1.0;

  /// Minimum bounded-face area (mm²) to be considered a real room.
  /// Filters out degenerate slivers produced by dangling walls.
  static const double _minAreaMm2 = 100.0 * 100.0;

  /// Distance (mm) under which a point counts as lying *on* a polygon
  /// edge rather than strictly inside it.
  static const double _onEdgeTolerance = 1.0;

  /// Canonical key for a point (rounded to tolerance).
  static String _pointKey(Point2D p) {
    final x = (p.x / _tolerance).round();
    final y = (p.y / _tolerance).round();
    return '$x,$y';
  }

  /// Detect a closed room after [newWall] is added to [allWalls]
  /// (which must already include [newWall]).
  ///
  /// Returns the smallest bounded face adjacent to [newWall], or null
  /// when no closed polygon with ≥ 3 vertices is found. This overload
  /// performs **no** overlap verification and is retained for callers
  /// that do not have the existing-room list; prefer [detectRoom].
  static DetectedRoom? detectClosedRoom(
    List<WallSegment> allWalls,
    WallSegment newWall,
  ) {
    final candidates = _candidateFaces(allWalls, newWall);
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Detect a room after [newWall] is added to [allWalls], verifying
  /// that the result does not share floor area with any room in
  /// [existingRooms].
  ///
  /// The two faces adjacent to [newWall] are considered in order of
  /// increasing area. The first whose floor area is not (partially or
  /// wholly) shared with an existing room is returned
  /// ([RoomDetectionOutcome.detected]). If a closed cycle exists but
  /// every candidate overlaps an existing room, the result is
  /// [RoomDetectionOutcome.overlapsExistingRoom] so the caller can show
  /// an error instead of the room-creation dialog. If no closed cycle
  /// exists at all, the result is [RoomDetectionOutcome.none].
  static RoomDetectionResult detectRoom(
    List<WallSegment> allWalls,
    WallSegment newWall, {
    List<Room> existingRooms = const [],
  }) {
    final candidates = _candidateFaces(allWalls, newWall);
    if (candidates.isEmpty) {
      return const RoomDetectionResult(RoomDetectionOutcome.none, []);
    }

    // Each bounded face whose floor area is not shared with an existing
    // room is a unique new room. The two faces of [newWall] are
    // interior-disjoint, so both may be returned — a single wall draw can
    // create two rooms at once.
    final unique = [
      for (final candidate in candidates)
        if (!_overlapsAnyRoom(candidate.polygon, existingRooms)) candidate,
    ];

    if (unique.isEmpty) {
      // A closed cycle exists, but no constellation yields a unique room.
      return const RoomDetectionResult(
        RoomDetectionOutcome.overlapsExistingRoom,
        [],
      );
    }

    return RoomDetectionResult(RoomDetectionOutcome.detected, unique);
  }

  /// Build the list of bounded faces adjacent to [newWall], sorted by
  /// ascending area (smallest first). Each undirected wall borders two
  /// faces; tracing from both directed half-edges of [newWall] yields
  /// them. The unbounded outer face (negative signed area) is discarded.
  static List<DetectedRoom> _candidateFaces(
    List<WallSegment> allWalls,
    WallSegment newWall,
  ) {
    final adjacency = _buildAdjacency(allWalls);

    final faces = <DetectedRoom>[];
    final seenKeys = <String>{};

    for (final (a, b) in [
      (newWall.startPoint, newWall.endPoint),
      (newWall.endPoint, newWall.startPoint),
    ]) {
      final face = _traceFace(adjacency, newWall, a, b);
      if (face == null) continue;
      if (face.polygon.length < 3) continue;

      // Keep only bounded faces with a meaningful area. The outer
      // (unbounded) face has clockwise winding → negative signed area.
      final signedArea = GeometryUtils.signedArea(face.polygon);
      if (signedArea <= _minAreaMm2) continue;

      // De-duplicate (both half-edges can rarely trace the same face).
      final key = (face.wallIds.toList()..sort()).join(',');
      if (!seenKeys.add(key)) continue;

      faces.add(face);
    }

    faces.sort((a, b) => GeometryUtils.area(a.polygon)
        .compareTo(GeometryUtils.area(b.polygon)));
    return faces;
  }

  /// Build adjacency map: point key → outgoing edges.
  static Map<String, List<_AdjEntry>> _buildAdjacency(
    List<WallSegment> allWalls,
  ) {
    final adjacency = <String, List<_AdjEntry>>{};
    for (final wall in allWalls) {
      final startKey = _pointKey(wall.startPoint);
      final endKey = _pointKey(wall.endPoint);

      adjacency.putIfAbsent(startKey, () => []).add(_AdjEntry(
            point: wall.endPoint,
            key: endKey,
            wallId: wall.id,
          ));
      adjacency.putIfAbsent(endKey, () => []).add(_AdjEntry(
            point: wall.startPoint,
            key: startKey,
            wallId: wall.id,
          ));
    }
    return adjacency;
  }

  /// Trace the planar face that lies to the **left** of the directed
  /// half-edge [aPoint] → [bPoint] (the first edge being [newWall]).
  ///
  /// At each vertex the next edge is chosen as the one immediately
  /// clockwise from the reverse of the incoming direction, which keeps
  /// the interior on the left and so encloses a single minimal face.
  /// Returns null if the walk fails to close (dangling chain) or
  /// revisits a half-edge (malformed graph).
  static DetectedRoom? _traceFace(
    Map<String, List<_AdjEntry>> adjacency,
    WallSegment newWall,
    Point2D aPoint,
    Point2D bPoint,
  ) {
    final startKey = _pointKey(aPoint);

    final polygon = <Point2D>[aPoint];
    final wallIds = <String>[newWall.id];
    final seenHalfEdges = <String>{};

    var prevPoint = aPoint;
    var currPoint = bPoint;
    var currKey = _pointKey(bPoint);

    // Upper bound on edges traversable in one face.
    final maxSteps =
        adjacency.values.fold<int>(0, (sum, l) => sum + l.length) + 4;

    for (var step = 0; step < maxSteps; step++) {
      // Record the half-edge we just walked (prev → curr); a repeat
      // means the graph is malformed for this face.
      final heKey = '${_pointKey(prevPoint)}>$currKey';
      if (!seenHalfEdges.add(heKey)) return null;

      if (currKey == startKey) {
        // Returned to the start vertex: the face is closed. The closing
        // edge's wallId was appended in the previous iteration.
        return DetectedRoom(polygon: polygon, wallIds: wallIds);
      }

      polygon.add(currPoint);

      final next = _nextEdge(adjacency, prevPoint, currPoint);
      if (next == null) return null;

      if (next.wallId != newWall.id) wallIds.add(next.wallId);

      prevPoint = currPoint;
      currPoint = next.point;
      currKey = next.key;
    }

    return null;
  }

  /// Pick the outgoing edge from [atPoint] that continues the face when
  /// arriving from [fromPoint] — the edge immediately clockwise from
  /// the reverse direction (atPoint → fromPoint).
  static _AdjEntry? _nextEdge(
    Map<String, List<_AdjEntry>> adjacency,
    Point2D fromPoint,
    Point2D atPoint,
  ) {
    final neighbors = adjacency[_pointKey(atPoint)];
    if (neighbors == null || neighbors.isEmpty) return null;

    // Reverse of the incoming direction.
    final revAngle = math.atan2(
      fromPoint.y - atPoint.y,
      fromPoint.x - atPoint.x,
    );

    const twoPi = 2 * math.pi;
    _AdjEntry? best;
    var bestTurn = double.infinity;

    for (final n in neighbors) {
      final nAngle = math.atan2(
        n.point.y - atPoint.y,
        n.point.x - atPoint.x,
      );
      // Clockwise turn from the reverse direction, in (0, 2π].
      var cw = (revAngle - nAngle) % twoPi;
      if (cw <= 1e-9) cw += twoPi; // back-edge / numerical → last resort
      if (cw < bestTurn) {
        bestTurn = cw;
        best = n;
      }
    }

    return best;
  }

  /// True if [polygon] shares floor area (interiors intersect) with any
  /// room in [existingRooms]. Rooms that only touch along a shared wall
  /// or at a corner do **not** count as overlapping.
  static bool _overlapsAnyRoom(
    List<Point2D> polygon,
    List<Room> existingRooms,
  ) {
    for (final room in existingRooms) {
      if (room.polygon.length < 3) continue;
      if (_polygonsOverlap(polygon, room.polygon)) return true;
    }
    return false;
  }

  /// True if the interiors of simple polygons [a] and [b] intersect.
  ///
  /// Detects both containment (one room inside the other) and partial
  /// overlap (crossing edges), while treating shared-wall adjacency
  /// (collinear edges, shared vertices) as non-overlapping.
  static bool _polygonsOverlap(List<Point2D> a, List<Point2D> b) {
    for (final p in a) {
      if (_strictlyInside(b, p)) return true;
    }
    for (final p in b) {
      if (_strictlyInside(a, p)) return true;
    }
    // Vertex checks miss the case where one polygon equals or fully
    // contains the other while sharing the whole boundary (every vertex
    // lies on an edge). Interior sample points catch it.
    for (final p in _interiorSamplePoints(a)) {
      if (_strictlyInside(b, p)) return true;
    }
    for (final p in _interiorSamplePoints(b)) {
      if (_strictlyInside(a, p)) return true;
    }
    for (var i = 0; i < a.length; i++) {
      final a1 = a[i];
      final a2 = a[(i + 1) % a.length];
      for (var j = 0; j < b.length; j++) {
        final b1 = b[j];
        final b2 = b[(j + 1) % b.length];
        if (_segmentsProperlyCross(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  /// A few points guaranteed to lie strictly inside [polygon].
  ///
  /// For each edge, the midpoint is nudged a small distance along the
  /// inward normal. Real rooms are far wider than the nudge, so at least
  /// one sample per edge lands strictly inside — robust for convex and
  /// non-convex (e.g. L-shaped) rooms alike.
  static List<Point2D> _interiorSamplePoints(List<Point2D> polygon) {
    const eps = _onEdgeTolerance * 5;
    final samples = <Point2D>[];
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      final mx = (a.x + b.x) / 2;
      final my = (a.y + b.y) / 2;
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      // Both unit normals; the inward one yields a strictly-inside point.
      final nx = -dy / len;
      final ny = dx / len;
      for (final s in [1.0, -1.0]) {
        final candidate = Point2D(x: mx + s * eps * nx, y: my + s * eps * ny);
        if (_strictlyInside(polygon, candidate)) {
          samples.add(candidate);
          break;
        }
      }
    }
    return samples;
  }

  /// True if [point] is inside [polygon] and not on its boundary.
  static bool _strictlyInside(List<Point2D> polygon, Point2D point) {
    if (!GeometryUtils.containsPoint(polygon, point)) return false;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if (GeometryUtils.distanceToSegment(point, a, b) <= _onEdgeTolerance) {
        return false;
      }
    }
    return true;
  }

  /// True if segments [a1]→[a2] and [b1]→[b2] cross at a single point
  /// interior to both (excludes collinear overlap and endpoint touches).
  static bool _segmentsProperlyCross(
    Point2D a1,
    Point2D a2,
    Point2D b1,
    Point2D b2,
  ) {
    final d1 = _cross(b1, b2, a1);
    final d2 = _cross(b1, b2, a2);
    final d3 = _cross(a1, a2, b1);
    final d4 = _cross(a1, a2, b2);

    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  /// Cross product (b − a) × (c − a); sign gives orientation.
  static double _cross(Point2D a, Point2D b, Point2D c) {
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  }
}

class _AdjEntry {
  const _AdjEntry({
    required this.point,
    required this.key,
    required this.wallId,
  });

  final Point2D point;
  final String key;
  final String wallId;
}
