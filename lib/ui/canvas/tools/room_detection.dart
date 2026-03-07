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
  /// Uses BFS to find the **minimum-hop** cycle that
  /// contains [newWall], which corresponds to the smallest
  /// enclosed polygon.  Returns null if no closed polygon
  /// with ≥ 3 vertices is found.
  ///
  /// A depth-first search is not used here because the DFS
  /// returns the first cycle it encounters in adjacency-list
  /// order, which can be the large room-1 polygon when a
  /// shorter cycle also exists (e.g. after an ADR-003 split
  /// where the new wall ends at a corner of the split host
  /// wall).  BFS guarantees the shortest path is returned
  /// regardless of adjacency ordering.
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

    final startKey = _pointKey(newWall.startPoint);
    final endKey = _pointKey(newWall.endPoint);

    // BFS from endPoint trying to reach startPoint,
    // without re-using newWall itself.
    final result = _bfs(
      adjacency: adjacency,
      bfsStartKey: endKey,
      bfsStartPoint: newWall.endPoint,
      targetKey: startKey,
      excludeWallId: newWall.id,
      maxNodes: allWalls.length,
    );

    if (result == null) return null;

    // Build polygon from path.
    // result.path[0] is the BFS start node (newWall.endPoint);
    // subsequent nodes are the intermediate hops.
    // result.closingWallId is the edge that connects the
    // last path node back to newWall.startPoint.
    final polygon = <Point2D>[newWall.startPoint];
    final wallIds = <String>[newWall.id];

    for (final node in result.path) {
      polygon.add(node.point);
      if (node.wallId != newWall.id) {
        wallIds.add(node.wallId);
      }
    }

    if (result.closingWallId != newWall.id) {
      wallIds.add(result.closingWallId);
    }

    // Minimum 3 vertices for a valid room.
    if (polygon.length < 3) return null;

    return DetectedRoom(polygon: polygon, wallIds: wallIds);
  }

  /// BFS to find the shortest path (minimum hops) from
  /// [bfsStartKey] to [targetKey], excluding any edge with
  /// [excludeWallId].
  ///
  /// Returns a [_CycleResult] whose [_CycleResult.path]
  /// lists nodes from [bfsStartKey] to the node immediately
  /// before [targetKey], and whose
  /// [_CycleResult.closingWallId] is the wall that connects
  /// the last path node back to [targetKey].
  ///
  /// Returns null when no such path exists or when the node
  /// count exceeds [maxNodes].
  static _CycleResult? _bfs({
    required Map<String, List<_AdjEntry>> adjacency,
    required String bfsStartKey,
    required Point2D bfsStartPoint,
    required String targetKey,
    required String excludeWallId,
    required int maxNodes,
  }) {
    // cameFrom[nodeKey] records how BFS reached that node.
    final cameFrom = <String, _BfsEdge>{};
    final queue = <String>[];

    cameFrom[bfsStartKey] = _BfsEdge(
      parentKey: null,
      wallId: excludeWallId, // placeholder — skipped by caller
      point: bfsStartPoint,
    );
    queue.add(bfsStartKey);

    var head = 0;
    while (head < queue.length) {
      // Guard against pathological graphs.
      if (head > maxNodes) break;

      final currentKey = queue[head++];
      final neighbors = adjacency[currentKey];
      if (neighbors == null) continue;

      for (final neighbor in neighbors) {
        // Never traverse the new wall again.
        if (neighbor.wallId == excludeWallId) continue;

        // Found the target — shortest path located.
        if (neighbor.key == targetKey) {
          return _CycleResult(
            path: _reconstructPath(
              cameFrom: cameFrom,
              fromKey: currentKey,
              startKey: bfsStartKey,
              startPoint: bfsStartPoint,
              placeholderWallId: excludeWallId,
            ),
            closingWallId: neighbor.wallId,
          );
        }

        // Each node is visited at most once.
        if (cameFrom.containsKey(neighbor.key)) continue;

        cameFrom[neighbor.key] = _BfsEdge(
          parentKey: currentKey,
          wallId: neighbor.wallId,
          point: neighbor.point,
        );
        queue.add(neighbor.key);
      }
    }

    return null;
  }

  /// Walk the [cameFrom] map from [fromKey] back to
  /// [startKey] and return the path in forward order
  /// (startKey → … → fromKey).
  static List<_PathNode> _reconstructPath({
    required Map<String, _BfsEdge> cameFrom,
    required String fromKey,
    required String startKey,
    required Point2D startPoint,
    required String placeholderWallId,
  }) {
    final reversed = <_PathNode>[];
    var key = fromKey;

    while (key != startKey) {
      final edge = cameFrom[key]!;
      reversed.add(_PathNode(
        key: key,
        point: edge.point,
        wallId: edge.wallId,
      ));
      key = edge.parentKey!;
    }

    // Append the start node (wallId skipped by the caller
    // because it equals excludeWallId / newWall.id).
    reversed.add(_PathNode(
      key: startKey,
      point: startPoint,
      wallId: placeholderWallId,
    ));

    return reversed.reversed.toList();
  }
}

/// Result returned by the BFS traversal.
class _CycleResult {
  const _CycleResult({
    required this.path,
    required this.closingWallId,
  });

  /// Nodes from the BFS start up to (but not including)
  /// the target.  The first node's wallId equals the
  /// excluded new-wall ID and is skipped by the caller.
  final List<_PathNode> path;

  /// ID of the wall that connects the last path node back
  /// to the target (newWall.startPoint).
  final String closingWallId;
}

/// BFS book-keeping: how a node was reached.
class _BfsEdge {
  const _BfsEdge({
    required this.parentKey,
    required this.wallId,
    required this.point,
  });

  /// Key of the node from which this node was reached,
  /// or null for the BFS start node.
  final String? parentKey;

  /// Wall used to reach this node from its parent.
  final String wallId;

  /// World coordinates of this node.
  final Point2D point;
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
