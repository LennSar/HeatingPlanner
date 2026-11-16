// Adjacent-room corner integrity (regression for the "attaching a room
// detaches a corner / loses geometry" screenshots).
//
// Three scenarios, all with SQUARE rooms, exercised through the real draw
// flow (commitWallWithSplit → RoomDetection → addRoomFromDetection):
//
//   A. Connect a SMALLER room to a LARGER one.
//   B. Connect a LARGER room to a SMALLER one (reverse-split path).
//   C. Alter the shared wall's construction so its thickness changes.
//
// After each, every room must:
//   * keep a valid polygon with a positive floor area — the exact value the
//     properties panel shows (`GeometryEngine.polygonAreaM2(room.polygon)`),
//     so the geometry measurements stay available;
//   * give every wall a mitred inner AND outer face (no dropped corner);
//   * have NO enclosed rendering gap in the wall band — corners are fused,
//     not notched like in the screenshot.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/geometry_engine.dart';
import 'package:heating_planner/core/utils/id_generator.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/ui/canvas/tools/room_detection.dart';
import 'package:heating_planner/ui/canvas/tools/snap_service.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Draw-flow helper ────────────────────────────────────────────────────────

/// Draws a rectangular room [tl,tr,br,bl] the way `WallDrawTool` rect mode
/// does: reuse an existing wall that matches an edge, otherwise commit the
/// edge (splitting any host wall), then detect + promote the room.
void _drawRect(
  EditorStateNotifier n,
  Point2D tl,
  Point2D tr,
  Point2D br,
  Point2D bl,
  String roomId,
  String name,
) {
  final before = n.state.walls.toList();
  WallSegment? firstNew;
  WallSegment? last;
  for (final (a, b) in [(tl, tr), (tr, br), (br, bl), (bl, tl)]) {
    final match = SnapService.matchExistingWall(a, b, before);
    if (match != null) {
      last = match;
    } else {
      final seed = n.commitWallWithSplit(
        WallSegment(
          id: IdGenerator.newId(),
          roomId: '',
          startPoint: a,
          endPoint: b,
        ),
      );
      last = seed;
      firstNew ??= seed;
    }
  }
  final res = RoomDetection.detectRoom(
    n.state.walls,
    firstNew ?? last!,
    existingRooms: n.state.rooms,
  );
  for (final rm in res.rooms) {
    n.addRoomFromDetection(
      room: Room(
        id: roomId,
        floorId: 'floor-1',
        name: name,
        targetTempC: 20,
        polygon: rm.polygon,
      ),
      wallIds: rm.wallIds,
    );
  }
}

// ── Geometry checks ─────────────────────────────────────────────────────────

/// Every wall-body quad WallPainter would draw (inner+outer mitred faces).
List<List<Point2D>> _wallQuads(EditorState st) {
  final quads = <List<Point2D>>[];
  for (final room in st.rooms) {
    if (room.polygon.length < 3) continue;
    final rw = st.walls.where((w) => w.roomId == room.id).toList();
    final inner = GeometryEngine.roomFaceEdges(
      walls: rw,
      roomPolygon: room.polygon,
      side: RoomFaceSide.inner,
    );
    final outer = GeometryEngine.roomFaceEdges(
      walls: rw,
      roomPolygon: room.polygon,
      side: RoomFaceSide.outer,
    );
    for (final w in rw) {
      final i = inner[w.id];
      final o = outer[w.id];
      if (i == null || o == null) continue;
      quads.add([i.start, o.start, o.end, i.end]);
    }
  }
  return quads;
}

/// Points inside a wall's own body (its centerline rectangle, sampled up to
/// the corners) that are NOT covered by the union of ALL wall quads — i.e. a
/// part of a wall that fails to render, which reads as a corner notch/gap
/// like the screenshot. Sampling each wall's true rectangle (rather than a
/// per-room offset polygon) makes this independent of the corner-mitre logic,
/// so a mismatch between two rooms' corner miters is caught.
List<Point2D> _uncoveredWallCore(EditorState st, List<List<Point2D>> quads) {
  bool covered(Point2D pt) {
    for (final q in quads) {
      if (GeometryEngine.isPointInPolygon(pt, q)) return true;
    }
    return false;
  }

  final gaps = <Point2D>[];
  for (final w in st.walls) {
    if (w.roomId.isEmpty) continue;
    final dx = w.endPoint.x - w.startPoint.x;
    final dy = w.endPoint.y - w.startPoint.y;
    final len = GeometryEngine.distanceMm(w.startPoint, w.endPoint);
    if (len < 1) continue;
    final ux = dx / len, uy = dy / len; // along
    final nx = -uy, ny = ux; // perpendicular (unit)
    final h = w.thicknessMm / 2.0;
    // Sample the core: along the full length (right up to the corners) and
    // across ±0.8·half-thickness (stay just inside the faces so legitimate
    // 45° mitre clips at the extreme outer corner are not flagged).
    for (var ta = 0.03; ta <= 0.97; ta += 0.03) {
      final cx = w.startPoint.x + dx * ta;
      final cy = w.startPoint.y + dy * ta;
      for (final pf in const [-0.8, -0.4, 0.0, 0.4, 0.8]) {
        final off = pf * h;
        final p = Point2D(x: cx + nx * off, y: cy + ny * off);
        if (!covered(p)) gaps.add(p);
      }
    }
  }
  return gaps;
}

/// Assert both rooms keep usable geometry and fused corners.
void _assertHealthy(
  EditorState st, {
  required double bigAreaM2,
  required double smallAreaM2,
}) {
  expect(st.rooms, hasLength(2));
  for (final room in st.rooms) {
    // Geometry available in the properties pane (same call the panel makes).
    expect(
      room.polygon.length,
      greaterThanOrEqualTo(3),
      reason: 'room ${room.name} lost its polygon',
    );
    final area = GeometryEngine.polygonAreaM2(room.polygon);
    expect(area, greaterThan(0), reason: 'room ${room.name} area unavailable');

    // Every wall resolves a mitred inner and outer face (no dropped corner).
    final rw = st.walls.where((w) => w.roomId == room.id).toList();
    final inner = GeometryEngine.roomFaceEdges(
      walls: rw,
      roomPolygon: room.polygon,
      side: RoomFaceSide.inner,
    );
    final outer = GeometryEngine.roomFaceEdges(
      walls: rw,
      roomPolygon: room.polygon,
      side: RoomFaceSide.outer,
    );
    expect(
      inner.length,
      rw.length,
      reason: 'room ${room.name} missing inner faces',
    );
    expect(
      outer.length,
      rw.length,
      reason: 'room ${room.name} missing outer faces',
    );
  }

  // Corners fused — every wall's body renders, with no notch/hole.
  final gaps = _uncoveredWallCore(st, _wallQuads(st));
  expect(
    gaps,
    isEmpty,
    reason:
        '${gaps.length} wall-body gap(s), first at ${gaps.isEmpty ? '' : gaps.first}',
  );

  final areas = {
    for (final r in st.rooms) r.id: GeometryEngine.polygonAreaM2(r.polygon),
  };
  expect(areas['room-1'], closeTo(bigAreaM2, 0.01));
  expect(areas['room-2'], closeTo(smallAreaM2, 0.01));
}

// ── Fixtures ────────────────────────────────────────────────────────────────

// Big square 4000×4000; small square 2000×2000 sharing part of the big room's
// bottom wall, flush with its left edge.
const _bTL = Point2D(x: 0, y: 0);
const _bTR = Point2D(x: 4000, y: 0);
const _bBR = Point2D(x: 4000, y: 4000);
const _bBL = Point2D(x: 0, y: 4000);
const _sTR = Point2D(x: 2000, y: 4000);
const _sBR = Point2D(x: 2000, y: 6000);
const _sBL = Point2D(x: 0, y: 6000);

const _bigAreaM2 = 16.0; // 4000×4000 mm²
const _smallAreaM2 = 4.0; // 2000×2000 mm²

ProviderContainer _container() {
  final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
  final c = ProviderContainer(
    overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
  );
  addTearDown(db.close);
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('A: connecting a smaller room to a larger one keeps corners fused', () {
    final c = _container();
    final n = c.read(editorStateProvider.notifier);
    _drawRect(n, _bTL, _bTR, _bBR, _bBL, 'room-1', 'Big');
    _drawRect(n, _bBL, _sTR, _sBR, _sBL, 'room-2', 'Small');
    _assertHealthy(
      c.read(editorStateProvider),
      bigAreaM2: _bigAreaM2,
      smallAreaM2: _smallAreaM2,
    );
  });

  test('B: connecting a larger room to a smaller one keeps corners fused', () {
    final c = _container();
    final n = c.read(editorStateProvider.notifier);
    _drawRect(n, _bBL, _sTR, _sBR, _sBL, 'room-2', 'Small');
    _drawRect(n, _bTL, _bTR, _bBR, _bBL, 'room-1', 'Big');
    _assertHealthy(
      c.read(editorStateProvider),
      bigAreaM2: _bigAreaM2,
      smallAreaM2: _smallAreaM2,
    );
  });

  test(
    'C: changing the shared wall construction thickness keeps corners fused',
    () {
      final c = _container();
      final n = c.read(editorStateProvider.notifier);
      _drawRect(n, _bTL, _bTR, _bBR, _bBL, 'room-1', 'Big');
      _drawRect(n, _bBL, _sTR, _sBR, _sBL, 'room-2', 'Small');

      // Thicken the shared wall's construction (120 → 200 mm).
      final st0 = c.read(editorStateProvider);
      final shared = st0.walls.firstWhere(
        (w) => w.wallType == WallType.interior && w.roomId == 'room-1',
      );
      final cid = shared.constructionId!;
      for (final l in st0.materialLayers.where(
        (l) => l.constructionId == cid,
      )) {
        n.updateMaterialLayer(l.copyWith(thicknessMm: 200));
      }
      n.recomputeWallsForConstruction(cid);

      final st = c.read(editorStateProvider);
      expect(
        st.walls.firstWhere((w) => w.id == shared.id).thicknessMm,
        200,
        reason: 'shared wall thickness followed the construction change',
      );
      _assertHealthy(st, bigAreaM2: _bigAreaM2, smallAreaM2: _smallAreaM2);
    },
  );
}
