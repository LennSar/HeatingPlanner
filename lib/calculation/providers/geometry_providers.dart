// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/point2d.dart';
import '../../data/models/wall_segment.dart';
import '../../repositories/building_repository.dart';
import '../engines/geometry_engine.dart';

/// Per-edge offsets `±thicknessMm / 2` for [polygon] paired against
/// [walls] by endpoint (1 mm tolerance, direction-agnostic).
///
/// [sideSign] is `-1.0` for the inner clear polygon and `+1.0` for the
/// outer envelope. Returns `null` if any polygon edge has no matching
/// wall — callers must treat that as a degenerate case (empty polygon).
List<double>? _buildEdgeOffsets({
  required List<Point2D> polygon,
  required List<WallSegment> walls,
  required double sideSign,
}) {
  final n = polygon.length;
  if (n < 3) return null;
  final out = List<double>.filled(n, 0.0);
  for (var i = 0; i < n; i++) {
    final pa = polygon[i];
    final pb = polygon[(i + 1) % n];
    WallSegment? match;
    for (final w in walls) {
      if ((_almostEq(w.startPoint, pa) && _almostEq(w.endPoint, pb)) ||
          (_almostEq(w.startPoint, pb) && _almostEq(w.endPoint, pa))) {
        match = w;
        break;
      }
    }
    if (match == null) return null;
    out[i] = sideSign * match.thicknessMm / 2.0;
  }
  return out;
}

bool _almostEq(Point2D a, Point2D b) =>
    (a.x - b.x).abs() <= 1.0 && (a.y - b.y).abs() <= 1.0;

/// Inner clear polygon of [roomId] (ADR-017 Rule 4).
///
/// Offsets the room's centerline polygon inward by `½ thicknessMm` per
/// edge using each wall's stored thickness, with corners mitered along
/// the angle bisector. The result is the *Lichtmaß* polygon used by
/// EN 12831 for area, volume, and per-wall heat-loss-area derivations
/// (ADR-017 Rule 5).
///
/// Returns an empty list when the room is still loading, the wall list
/// cannot be matched edge-for-edge against the polygon, or
/// [GeometryEngine.offsetPolygonPerEdge] reports a degenerate offset
/// (e.g. opposite walls too thick to fit). Callers must treat the empty
/// return as a validation error (the room geometry is not usable for
/// heat-load calculation).
///
/// Depends on [roomProvider] and [wallSegmentsProvider].
final roomInnerPolygonProvider =
    Provider.family<List<Point2D>, String>((ref, roomId) {
  final room = ref.watch(roomProvider(roomId)).asData?.value;
  if (room == null) return const [];
  final walls = ref.watch(wallSegmentsProvider(roomId)).asData?.value;
  if (walls == null || walls.isEmpty) return const [];

  final offsets = _buildEdgeOffsets(
    polygon: room.polygon,
    walls: walls,
    sideSign: -1.0,
  );
  if (offsets == null) return const [];

  return GeometryEngine.offsetPolygonPerEdge(
    centerline: room.polygon,
    edgeOffsetsMm: offsets,
  );
});

/// Outer envelope polygon of [roomId] (ADR-017 Rule 4).
///
/// Offsets the room's centerline polygon outward by `½ thicknessMm` per
/// edge. Used for rendering the wall body and for exports — never as an
/// input dimension (ADR-017 introductory section).
///
/// Returns an empty list under the same conditions as
/// [roomInnerPolygonProvider]. Neither polygon is persisted.
///
/// Depends on [roomProvider] and [wallSegmentsProvider].
final roomOuterPolygonProvider =
    Provider.family<List<Point2D>, String>((ref, roomId) {
  final room = ref.watch(roomProvider(roomId)).asData?.value;
  if (room == null) return const [];
  final walls = ref.watch(wallSegmentsProvider(roomId)).asData?.value;
  if (walls == null || walls.isEmpty) return const [];

  final offsets = _buildEdgeOffsets(
    polygon: room.polygon,
    walls: walls,
    sideSign: 1.0,
  );
  if (offsets == null) return const [];

  return GeometryEngine.offsetPolygonPerEdge(
    centerline: room.polygon,
    edgeOffsetsMm: offsets,
  );
});

/// Inner edge length (mm) of the wall [wallId] along its owning room's
/// inner clear polygon (ADR-017 Rule 5).
///
/// Resolves the wall via [wallSegmentProvider], then derives the per-wall
/// inner edge via [GeometryEngine.roomFaceEdges] against the room's
/// centerline polygon and wall thickness. The returned value is the
/// distance between the offset edge's start and end points in mm — what
/// EN 12831 calls the *Lichtmaß* wall length, the dimension consumed by
/// `roomHeatDemandProvider` for the wall's net heat-loss area.
///
/// Returns [double.nan] when the wall, room, or wall list is still
/// loading, the polygon-to-walls match fails, or the inner offset is
/// degenerate. Annotation painters and heat-demand consumers must check
/// `.isNaN` before using the value.
///
/// Depends on [wallSegmentProvider], [roomProvider], and
/// [wallSegmentsProvider].
final wallInnerEdgeLengthProvider =
    Provider.family<double, String>((ref, wallId) {
  final wall = ref.watch(wallSegmentProvider(wallId)).asData?.value;
  if (wall == null) return double.nan;
  final room = ref.watch(roomProvider(wall.roomId)).asData?.value;
  if (room == null) return double.nan;
  final walls =
      ref.watch(wallSegmentsProvider(wall.roomId)).asData?.value;
  if (walls == null || walls.isEmpty) return double.nan;

  final edges = GeometryEngine.roomFaceEdges(
    walls: walls,
    roomPolygon: room.polygon,
    side: RoomFaceSide.inner,
  );
  final edge = edges[wallId];
  if (edge == null) return double.nan;
  return GeometryEngine.distanceMm(edge.start, edge.end);
});
