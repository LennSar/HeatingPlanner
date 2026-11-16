// Regression: attaching a second room must not detach a corner of the first.
//
// When a new room's edge runs along part of an existing room's wall, that
// host wall is split at the new room's corner (ADR-003). The host room's
// `polygon` must gain the split vertex too, otherwise the polygon's original
// full-length edge no longer matches either wall fragment in
// `GeometryEngine.roomFaceEdges`, the fragments lose their mitred faces, and
// the host room appears to detach at that corner.
//
// Host room — a 6000 × 4000 mm rectangle wound clockwise (y down):
//
//   TL(0,0) ─── top ──▶ TR(6000,0)
//     ▲                    │
//    left                right
//     │                    ▼
//   BL(0,4000) ◀─ bottom ─ BR(6000,4000)
//
// A second room is attached below-left; its top edge runs from BL to
// P(2760,4000), splitting the bottom wall at P.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/geometry_engine.dart';
import 'package:heating_planner/data/database/app_database.dart'
    hide WallSegment, Room;
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

const _tl = Point2D(x: 0, y: 0);
const _tr = Point2D(x: 6000, y: 0);
const _br = Point2D(x: 6000, y: 4000);
const _bl = Point2D(x: 0, y: 4000);
const _p = Point2D(x: 2760, y: 4000);

WallSegment _wall(String id, {required Point2D start, required Point2D end}) =>
    WallSegment(
      id: id,
      roomId: 'room-1',
      startPoint: start,
      endPoint: end,
      wallType: WallType.exterior,
      thicknessMm: 240,
      anchorMode: WallAnchorMode.innerFace,
      constructionId: 'c-ext',
    );

final _overrideWith = appDatabaseProvider.overrideWith((ref) {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  ref.onDispose(db.close);
  return db;
});

bool _eq(Point2D a, Point2D b) => GeometryEngine.distanceMm(a, b) < 1.0;

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test(
    'splitting a host wall inserts the split vertex into the host room polygon '
    'so every fragment keeps a mitred face',
    () {
      final container = ProviderContainer(overrides: [_overrideWith]);
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);

      notifier.state = EditorState(
        walls: [
          _wall('top', start: _tl, end: _tr),
          _wall('right', start: _tr, end: _br),
          _wall('bottom', start: _br, end: _bl),
          _wall('left', start: _bl, end: _tl),
        ],
        rooms: const [
          Room(
            id: 'room-1',
            floorId: 'floor-1',
            name: 'Room 1',
            targetTempC: 20.0,
            polygon: [_tl, _tr, _br, _bl],
          ),
        ],
      );

      // Attach the second room's top edge BL → P: its endpoint P lies on the
      // interior of the bottom wall, so the bottom wall is split at P.
      notifier.commitWallWithSplit(
        const WallSegment(
          id: 'new-top',
          roomId: '',
          startPoint: _bl,
          endPoint: _p,
        ),
      );

      final post = container.read(editorStateProvider);

      // The host room polygon gained P between BR and BL.
      final poly = post.rooms.single.polygon;
      expect(poly.length, 5, reason: 'split vertex inserted into polygon');
      final pIdx = poly.indexWhere((v) => _eq(v, _p));
      expect(pIdx, isNot(-1), reason: 'P is now a polygon vertex');
      expect(_eq(poly[pIdx - 1], _br) || _eq(poly[pIdx - 1], _bl), isTrue);
      expect(
        _eq(poly[(pIdx + 1) % poly.length], _br) ||
            _eq(poly[(pIdx + 1) % poly.length], _bl),
        isTrue,
        reason: 'P sits on the old BR→BL edge',
      );

      // The bottom wall is now two fragments BR→P and P→BL.
      final room1Walls = post.walls.where((w) => w.roomId == 'room-1').toList();
      bool hasFragment(Point2D a, Point2D b) => room1Walls.any(
        (w) =>
            (_eq(w.startPoint, a) && _eq(w.endPoint, b)) ||
            (_eq(w.startPoint, b) && _eq(w.endPoint, a)),
      );
      expect(hasFragment(_br, _p), isTrue, reason: 'BR→P fragment exists');
      expect(hasFragment(_p, _bl), isTrue, reason: 'P→BL fragment exists');

      // Every polygon edge now matches a wall, so roomFaceEdges emits a
      // mitred inner face for all five walls (no corner is dropped).
      final edges = GeometryEngine.roomFaceEdges(
        walls: room1Walls,
        roomPolygon: poly,
        side: RoomFaceSide.inner,
      );
      expect(
        edges.length,
        room1Walls.length,
        reason: 'all fragments matched a polygon edge and got a mitred face',
      );
    },
  );
}
