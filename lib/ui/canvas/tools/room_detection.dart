import '../../../data/models/point2d.dart';
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

/// Detects closed rooms from a wall graph.
///
/// After a new wall is added, checks whether the wall
/// graph contains a closed cycle that forms a room.
abstract final class RoomDetection {
  /// Point matching tolerance in mm.
  ///
  /// Walls are snapped to a 100mm grid, so 1mm tolerance
  /// is sufficient.
  static const double _tolerance = 1.0;

  /// Canonical key for a point (rounded to tolerance).
  static String _pointKey(Point2D p) {
    final x = (p.x / _tolerance).round();
    final y = (p.y / _tolerance).round();
    return '$x,$y';
  }

  /// Detect a closed room after [newWall] is added to
  /// [allWalls] (which must already include [newWall]).
  ///
  /// Returns null if no closed polygon is found.
  static DetectedRoom? detectClosedRoom(
    List<WallSegment> allWalls,
    WallSegment newWall,
  ) {
    // Build adjacency map: point → list of (neighborPoint, wallId).
    final adjacency =
        <String, List<_AdjEntry>>{};

    for (final wall in allWalls) {
      final startKey = _pointKey(wall.startPoint);
      final endKey = _pointKey(wall.endPoint);

      adjacency
          .putIfAbsent(startKey, () => [])
          .add(_AdjEntry(
            point: wall.endPoint,
            key: endKey,
            wallId: wall.id,
          ));
      adjacency
          .putIfAbsent(endKey, () => [])
          .add(_AdjEntry(
            point: wall.startPoint,
            key: startKey,
            wallId: wall.id,
          ));
    }

    // Try to find a cycle starting from newWall's endpoint
    // back to newWall's startpoint.
    final startKey = _pointKey(newWall.startPoint);
    final endKey = _pointKey(newWall.endPoint);

    // DFS from endPoint trying to reach startPoint,
    // without re-using the newWall itself.
    final visited = <String>{endKey};
    final path = <_PathNode>[
      _PathNode(
        key: endKey,
        point: newWall.endPoint,
        wallId: newWall.id,
      ),
    ];

    final result = _dfs(
      adjacency: adjacency,
      targetKey: startKey,
      visited: visited,
      path: path,
      excludeWallId: newWall.id,
      maxDepth: allWalls.length,
    );

    if (result == null) return null;

    // Build polygon from path.
    final polygon = <Point2D>[newWall.startPoint];
    final wallIds = <String>[newWall.id];

    for (final node in result) {
      polygon.add(node.point);
      if (node.wallId != newWall.id) {
        wallIds.add(node.wallId);
      }
    }

    // Minimum 3 vertices for a valid room.
    if (polygon.length < 3) return null;

    return DetectedRoom(polygon: polygon, wallIds: wallIds);
  }

  /// DFS to find a path from current position back to
  /// [targetKey].
  static List<_PathNode>? _dfs({
    required Map<String, List<_AdjEntry>> adjacency,
    required String targetKey,
    required Set<String> visited,
    required List<_PathNode> path,
    required String excludeWallId,
    required int maxDepth,
  }) {
    if (path.length > maxDepth) return null;

    final currentKey = path.last.key;
    final neighbors = adjacency[currentKey];
    if (neighbors == null) return null;

    for (final neighbor in neighbors) {
      // Don't traverse the new wall again.
      if (neighbor.wallId == excludeWallId) continue;

      // Found the target — cycle complete.
      if (neighbor.key == targetKey) {
        return [...path];
      }

      // Don't revisit nodes.
      if (visited.contains(neighbor.key)) continue;

      visited.add(neighbor.key);
      path.add(_PathNode(
        key: neighbor.key,
        point: neighbor.point,
        wallId: neighbor.wallId,
      ));

      final result = _dfs(
        adjacency: adjacency,
        targetKey: targetKey,
        visited: visited,
        path: path,
        excludeWallId: excludeWallId,
        maxDepth: maxDepth,
      );

      if (result != null) return result;

      path.removeLast();
      visited.remove(neighbor.key);
    }

    return null;
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

class _PathNode {
  const _PathNode({
    required this.key,
    required this.point,
    required this.wallId,
  });

  final String key;
  final Point2D point;
  final String wallId;
}
