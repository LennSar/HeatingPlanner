/// Tests for the shared-wall room scenario.
///
/// Layout (all coordinates in mm):
///
///   A(0,0)------B(5000,0)------C(10000,0)
///     |                              |
///   D(0,4000)--E(5000,4000)--F(10000,4000)
///
/// Room 1 (Living Room, 20 °C): A-B-E-D
///   walls: AB, BE, ED, DA          last drawn: DA
///
/// Room 2 (Bathroom, 24 °C): B-C-F-E
///   walls: BC, CF, FE, + mirror_EB  last drawn: FE
///
/// Shared wall: BE (belongs to Room 1 before Room 2 is created).
/// After Room 2 is created a mirror segment EB is created for
/// Room 2, and both copies are marked WallType.interior with
/// cross-referenced adjacentRoomId.
///
/// Tests are organised in three groups:
///
/// 1. [RoomDetection.detectClosedRoom] — all 4 wall IDs returned,
///    including the closing wall (regression for the dropped-edge bug).
///
/// 2. [EditorStateNotifier.addRoomFromDetection] — shared wall
///    handling: both rooms have exactly 4 wall segments, the shared
///    wall is marked interior on both sides, adjacentRoomId is
///    cross-referenced.
///
/// 3. Heat-demand correctness — [ThermalEngine.transmissionLoss]
///    combined with [ThermalEngine.interiorCorrectionFactor] for the
///    shared wall yields the correct reduced heat demand, and the
///    heat flow is symmetric across both room perspectives.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/thermal_engine.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/ui/canvas/tools/room_detection.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Shared geometry constants ──────────────────────────────────────────────

const _ptA = Point2D(x: 0, y: 0);
const _ptB = Point2D(x: 5000, y: 0);
const _ptC = Point2D(x: 10000, y: 0);
const _ptD = Point2D(x: 0, y: 4000);
const _ptE = Point2D(x: 5000, y: 4000);
const _ptF = Point2D(x: 10000, y: 4000);

// Room 1 walls
const _wallAb = WallSegment(
  id: 'wall-ab',
  roomId: 'room-1',
  startPoint: _ptA,
  endPoint: _ptB,
);
const _wallBe = WallSegment(
  id: 'wall-be',
  roomId: 'room-1',
  startPoint: _ptB,
  endPoint: _ptE,
);
const _wallEd = WallSegment(
  id: 'wall-ed',
  roomId: 'room-1',
  startPoint: _ptE,
  endPoint: _ptD,
);
const _wallDa = WallSegment(
  id: 'wall-da',
  roomId: 'room-1',
  startPoint: _ptD,
  endPoint: _ptA,
);

// Room 2 walls (unassigned before detection)
const _wallBc = WallSegment(
  id: 'wall-bc',
  roomId: '',
  startPoint: _ptB,
  endPoint: _ptC,
);
const _wallCf = WallSegment(
  id: 'wall-cf',
  roomId: '',
  startPoint: _ptC,
  endPoint: _ptF,
);
const _wallFe = WallSegment(
  id: 'wall-fe',
  roomId: '',
  startPoint: _ptF,
  endPoint: _ptE,
);

// All walls present when Room 2 is being detected.
final _allWallsForRoom2Detection = [
  _wallAb,
  _wallBe,
  _wallEd,
  _wallDa,
  _wallBc,
  _wallCf,
  _wallFe,
];

// Rooms
const _room1 = Room(
  id: 'room-1',
  floorId: 'floor-1',
  name: 'Living Room',
  targetTempC: 20.0,
);
const _room2 = Room(
  id: 'room-2',
  floorId: 'floor-1',
  name: 'Bathroom',
  targetTempC: 24.0,
);

// Shared wall physical properties
//   4 000 mm × 2 600 mm ceiling height = 10.4 m²
const _sharedWallAreaM2 = 4.0 * 2.6; // 10.4
const _sharedWallUValue = 0.5; // W/(m²·K) — insulated partition
const _outdoorTempC = -12.0;

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // ── Group 1: Room detection ──────────────────────────────────────────────

  group('RoomDetection.detectClosedRoom — shared wall scenario', () {
    test('SH-D-1: detecting Room 1 (4 new walls) '
        'returns exactly 4 wall IDs', () {
      // Room 1 walls are drawn in order AB, BE, ED, DA.
      // DA is the closing wall.  The DFS must traverse AB, BE, ED
      // and include ED as the closing edge.
      final allWalls = [_wallAb, _wallBe, _wallEd, _wallDa];
      final result = RoomDetection.detectClosedRoom(allWalls, _wallDa);

      expect(result, isNotNull);
      expect(result!.wallIds, hasLength(4));
      expect(
        result.wallIds,
        containsAll(['wall-da', 'wall-ab', 'wall-be', 'wall-ed']),
      );
    });

    test('SH-D-2: closing wall (ED) is present in Room 1 wallIds '
        '— regression for dropped-final-edge bug', () {
      // Before the fix, the DFS returned path = [A, B, E] with
      // closingWall = ED silently discarded.  wallIds would have
      // been [DA, AB, BE] (only 3).  After the fix the DfsResult
      // carries closingWallId and detectClosedRoom appends it.
      final allWalls = [_wallAb, _wallBe, _wallEd, _wallDa];
      final result = RoomDetection.detectClosedRoom(allWalls, _wallDa);

      expect(result, isNotNull);
      expect(
        result!.wallIds,
        contains('wall-ed'),
        reason:
            'wall-ed connects the last traversed node (E) back to the '
            "start point (D) — it is the 'closing edge' that was previously "
            'dropped from wallIds.',
      );
    });

    test('SH-D-3: detecting Room 2 returns 4 wall IDs including '
        'the shared wall BE', () {
      // At the time Room 2 is detected, walls AB, BE, ED, DA already
      // exist (belonging to Room 1).  The user has just drawn FE.
      // The DFS should find the minimal cycle:
      //   E → B (via BE) → C (via BC) → F (closing: CF).
      final result = RoomDetection.detectClosedRoom(
        _allWallsForRoom2Detection,
        _wallFe,
      );

      expect(result, isNotNull);
      expect(result!.wallIds, hasLength(4));
      expect(
        result.wallIds,
        containsAll(['wall-fe', 'wall-be', 'wall-bc', 'wall-cf']),
      );
    });

    test('SH-D-4: Room 2 detection includes BE (shared wall) specifically '
        '— verifies DFS crosses into existing room territory', () {
      final result = RoomDetection.detectClosedRoom(
        _allWallsForRoom2Detection,
        _wallFe,
      );

      expect(result, isNotNull);
      expect(
        result!.wallIds,
        contains('wall-be'),
        reason:
            'wall-be already belongs to Room 1 but lies on the boundary '
            'of Room 2.  The DFS must traverse it to close the cycle.',
      );
    });

    test('SH-D-5: detected Room 2 polygon has 4 vertices', () {
      final result = RoomDetection.detectClosedRoom(
        _allWallsForRoom2Detection,
        _wallFe,
      );

      expect(result, isNotNull);
      // Polygon: [F, E, B, C]  — 4 vertices, first != last per spec.
      expect(result!.polygon, hasLength(4));
    });
  });

  // ── Group 1b: detectRoom — overlap verification (screenshot bug) ──────────
  //
  // Regression for the bug where attaching a new room to an existing one
  // produced a constellation that *enclosed* the first room instead of the
  // small adjacent room. detectRoom must:
  //   • return the small adjacent room when one exists (RD-1),
  //   • skip a candidate constellation that overlaps an existing room and
  //     return the other one (RD-2 — "try another wall constellation"),
  //   • error when every constellation overlaps an existing room (RD-3),
  //   • report `none` when no cycle exists yet (RD-4).

  group('RoomDetection.detectRoom — overlap verification', () {
    test('RD-1: adjacent Room 2 is detected and does NOT enclose Room 1', () {
      final result = RoomDetection.detectRoom(
        _allWallsForRoom2Detection,
        _wallFe,
        existingRooms: const [
          Room(
            id: 'room-1',
            floorId: 'floor-1',
            name: 'Living Room',
            polygon: [_ptA, _ptB, _ptE, _ptD],
          ),
        ],
      );

      expect(result.outcome, equals(RoomDetectionOutcome.detected));
      // The detected polygon is the small right-hand square [F,E,B,C] —
      // it must NOT contain corner A or D of Room 1.
      expect(result.room!.polygon, isNot(contains(_ptA)));
      expect(result.room!.polygon, isNot(contains(_ptD)));
      expect(
        result.room!.wallIds,
        containsAll(['wall-fe', 'wall-be', 'wall-bc', 'wall-cf']),
      );
    });

    // Two squares share the divider wall BE. The face on BE's left is the
    // left square (== existing Room 1, an overlap); the face on its right
    // is the clean Room 2. detectRoom must skip the overlapping side and
    // return the clean side.
    const dividerBe = WallSegment(
      id: 'wall-be',
      roomId: 'room-1',
      startPoint: _ptB,
      endPoint: _ptE,
    );
    final twoSquareWalls = [
      _wallAb, // A→B
      dividerBe, // B→E (shared divider / new wall)
      _wallEd, // E→D
      _wallDa, // D→A
      _wallBc, // B→C
      _wallCf, // C→F
      _wallFe, // F→E
    ];

    test('RD-2: when one constellation overlaps Room 1, the other '
        '(clean) constellation is returned', () {
      // Room 1 sits inside the left square; the left face of BE would
      // re-enclose it. The right face (B,C,F,E) is clean.
      final result = RoomDetection.detectRoom(
        twoSquareWalls,
        dividerBe,
        existingRooms: const [
          Room(
            id: 'room-1',
            floorId: 'floor-1',
            name: 'Living Room',
            polygon: [_ptA, _ptB, _ptE, _ptD],
          ),
        ],
      );

      expect(result.outcome, equals(RoomDetectionOutcome.detected));
      // Must be the right square — contains C and F, not A or D.
      expect(result.room!.polygon, contains(_ptC));
      expect(result.room!.polygon, contains(_ptF));
      expect(result.room!.polygon, isNot(contains(_ptA)));
    });

    test('RD-3: a loop that encloses a floating existing room yields '
        'overlapsExistingRoom (error, no dialog)', () {
      // Outer square A,B',F',D closing with newWall; a small Room 1 floats
      // inside with no shared walls. The only bounded face encloses it.
      const p0 = Point2D(x: 0, y: 0);
      const p1 = Point2D(x: 6000, y: 0);
      const p2 = Point2D(x: 6000, y: 6000);
      const p3 = Point2D(x: 0, y: 6000);

      const wTop = WallSegment(
        id: 'w-top',
        roomId: '',
        startPoint: p0,
        endPoint: p1,
      );
      const wRight = WallSegment(
        id: 'w-right',
        roomId: '',
        startPoint: p1,
        endPoint: p2,
      );
      const wBottom = WallSegment(
        id: 'w-bottom',
        roomId: '',
        startPoint: p2,
        endPoint: p3,
      );
      const wClose = WallSegment(
        id: 'w-close',
        roomId: '',
        startPoint: p3,
        endPoint: p0,
      );

      final result = RoomDetection.detectRoom(
        [wTop, wRight, wBottom, wClose],
        wClose,
        existingRooms: const [
          Room(
            id: 'room-1',
            floorId: 'floor-1',
            name: 'Floating',
            polygon: [
              Point2D(x: 1000, y: 1000),
              Point2D(x: 2000, y: 1000),
              Point2D(x: 2000, y: 2000),
              Point2D(x: 1000, y: 2000),
            ],
          ),
        ],
      );

      expect(result.outcome, equals(RoomDetectionOutcome.overlapsExistingRoom));
      expect(result.room, isNull);
    });

    test('RD-5: one wall closing a room on each side detects TWO rooms', () {
      // No existing rooms: the divider BE bounds a clean square on each
      // side, so both must be returned for sequential naming.
      final result = RoomDetection.detectRoom(
        twoSquareWalls,
        dividerBe,
        existingRooms: const [],
      );

      expect(result.outcome, equals(RoomDetectionOutcome.detected));
      expect(result.rooms, hasLength(2));

      // The two rooms are the left and right squares — disjoint wall sets
      // apart from the shared divider BE.
      final leftWalls = result.rooms
          .firstWhere((r) => r.wallIds.contains('wall-da'))
          .wallIds;
      final rightWalls = result.rooms
          .firstWhere((r) => r.wallIds.contains('wall-bc'))
          .wallIds;
      expect(
        leftWalls,
        containsAll(['wall-be', 'wall-ab', 'wall-ed', 'wall-da']),
      );
      expect(
        rightWalls,
        containsAll(['wall-be', 'wall-bc', 'wall-cf', 'wall-fe']),
      );
    });

    test('RD-4: a non-closing wall yields outcome none', () {
      const a = Point2D(x: 0, y: 0);
      const b = Point2D(x: 1000, y: 0);
      const wall = WallSegment(
        id: 'lonely',
        roomId: '',
        startPoint: a,
        endPoint: b,
      );

      final result = RoomDetection.detectRoom([wall], wall);
      expect(result.outcome, equals(RoomDetectionOutcome.none));
      expect(result.room, isNull);
    });
  });

  // ── Group 2: EditorStateNotifier.addRoomFromDetection ───────────────────

  group('EditorStateNotifier.addRoomFromDetection — shared wall handling', () {
    /// Build a ProviderContainer seeded with Room 1 (4 walls) and
    /// the three unassigned walls for Room 2 (BC, CF, FE).
    ///
    /// In the real app [WallDrawTool] commits each wall to state
    /// before room detection fires, so all seven walls are present
    /// when [addRoomFromDetection] is called.
    (ProviderContainer, EditorStateNotifier) makeContainer() {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);
      final notifier = container.read(editorStateProvider.notifier);

      // Room 1 and its four assigned walls.
      notifier.addRoom(_room1);
      notifier.addWall(_wallAb);
      notifier.addWall(_wallBe);
      notifier.addWall(_wallEd);
      notifier.addWall(_wallDa);

      // Three new walls drawn for Room 2 — unassigned (roomId='')
      // as they would be after drawing but before the room dialog.
      notifier.addWall(_wallBc);
      notifier.addWall(_wallCf);
      notifier.addWall(_wallFe);

      return (container, notifier);
    }

    test('SH-S-1: after adding Room 2, state contains exactly 2 rooms', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.addRoomFromDetection(
        room: _room2,
        wallIds: ['wall-fe', 'wall-be', 'wall-bc', 'wall-cf'],
      );

      final rooms = container.read(editorStateProvider).rooms;
      expect(rooms, hasLength(2));
      expect(rooms.map((r) => r.id), containsAll(['room-1', 'room-2']));
    });

    test('SH-S-2: Room 1 still has exactly 4 wall segments after '
        'Room 2 is added', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.addRoomFromDetection(
        room: _room2,
        wallIds: ['wall-fe', 'wall-be', 'wall-bc', 'wall-cf'],
      );

      final walls = container.read(editorStateProvider).walls;
      final room1Walls = walls.where((w) => w.roomId == 'room-1').toList();
      expect(
        room1Walls,
        hasLength(4),
        reason:
            'Room 1 must keep AB, BE (updated), ED, DA — '
            'the shared wall stays in Room 1 (roomId unchanged).',
      );
    });

    test('SH-S-3: Room 2 has exactly 4 wall segments '
        '(3 new + 1 mirror of shared wall)', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.addRoomFromDetection(
        room: _room2,
        wallIds: ['wall-fe', 'wall-be', 'wall-bc', 'wall-cf'],
      );

      final walls = container.read(editorStateProvider).walls;
      final room2Walls = walls.where((w) => w.roomId == 'room-2').toList();
      expect(
        room2Walls,
        hasLength(4),
        reason:
            'Room 2 must have FE, BC, CF (new) and a mirror of '
            'BE (created by addRoomFromDetection).',
      );
    });

    test('SH-S-4: shared wall BE is marked WallType.interior on '
        "Room 1's side", () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.addRoomFromDetection(
        room: _room2,
        wallIds: ['wall-fe', 'wall-be', 'wall-bc', 'wall-cf'],
      );

      final walls = container.read(editorStateProvider).walls;
      final be = walls.firstWhere((w) => w.id == 'wall-be');
      expect(be.wallType, equals(WallType.interior));
    });

    test('SH-S-5: shared wall BE has adjacentRoomId = room-2 '
        "on Room 1's side", () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.addRoomFromDetection(
        room: _room2,
        wallIds: ['wall-fe', 'wall-be', 'wall-bc', 'wall-cf'],
      );

      final walls = container.read(editorStateProvider).walls;
      final be = walls.firstWhere((w) => w.id == 'wall-be');
      expect(
        be.adjacentRoomId,
        equals('room-2'),
        reason:
            'ThermalEngine.interiorCorrectionFactor needs adjacentRoomId '
            'to look up the neighbouring room temperature.',
      );
    });

    test('SH-S-6: mirror wall for Room 2 is marked WallType.interior', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.addRoomFromDetection(
        room: _room2,
        wallIds: ['wall-fe', 'wall-be', 'wall-bc', 'wall-cf'],
      );

      final walls = container.read(editorStateProvider).walls;
      // The mirror is a room-2 wall at the same geometric position as BE.
      final mirror = walls.firstWhere(
        (w) => w.roomId == 'room-2' && w.wallType == WallType.interior,
      );
      expect(mirror.wallType, equals(WallType.interior));
    });

    test('SH-S-7: mirror wall has adjacentRoomId = room-1 '
        "on Room 2's side", () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.addRoomFromDetection(
        room: _room2,
        wallIds: ['wall-fe', 'wall-be', 'wall-bc', 'wall-cf'],
      );

      final walls = container.read(editorStateProvider).walls;
      final mirror = walls.firstWhere(
        (w) => w.roomId == 'room-2' && w.wallType == WallType.interior,
      );
      expect(
        mirror.adjacentRoomId,
        equals('room-1'),
        reason:
            'interiorCorrectionFactor for Room 2 must resolve '
            'adjacentRoomId to look up Room 1 targetTempC.',
      );
    });

    test('SH-S-8: mirror wall geometry is the reverse of BE '
        '(start=E, end=B)', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.addRoomFromDetection(
        room: _room2,
        wallIds: ['wall-fe', 'wall-be', 'wall-bc', 'wall-cf'],
      );

      final walls = container.read(editorStateProvider).walls;
      final mirror = walls.firstWhere(
        (w) => w.roomId == 'room-2' && w.wallType == WallType.interior,
      );
      // Mirror of BE (start=B=(5000,0), end=E=(5000,4000))
      // should have startPoint=E, endPoint=B.
      expect(mirror.startPoint, equals(_ptE));
      expect(mirror.endPoint, equals(_ptB));
    });

    test('SH-S-9: total wall count in state is 8 '
        '(4 room-1 + 3 new room-2 + 1 mirror)', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.addRoomFromDetection(
        room: _room2,
        wallIds: ['wall-fe', 'wall-be', 'wall-bc', 'wall-cf'],
      );

      final walls = container.read(editorStateProvider).walls;
      expect(walls, hasLength(8));
    });
  });

  // ── Group 2b: two rooms created from a single wall (sequential) ───────────
  //
  // The dialog queue creates the two detected rooms one after another via
  // addRoomFromDetection. This verifies the second creation correctly
  // promotes the shared divider BE to an interior wall with a mirror — the
  // same shared-wall outcome as drawing the rooms separately.

  group('Two rooms from one wall — sequential addRoomFromDetection', () {
    const dividerBe = WallSegment(
      id: 'wall-be',
      roomId: '',
      startPoint: _ptB,
      endPoint: _ptE,
    );

    (ProviderContainer, EditorStateNotifier) makeContainer() {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);
      final notifier = container.read(editorStateProvider.notifier);

      // All seven walls of the two squares exist, none assigned to a room.
      for (final w in [
        _wallAb,
        dividerBe,
        _wallEd,
        _wallDa,
        _wallBc,
        _wallCf,
        _wallFe,
      ]) {
        notifier.addWall(w.copyWith(roomId: ''));
      }
      return (container, notifier);
    }

    void createBoth(EditorStateNotifier notifier) {
      notifier.addRoomFromDetection(
        room: const Room(id: 'left', floorId: 'floor-1', name: 'Left'),
        wallIds: ['wall-be', 'wall-ab', 'wall-ed', 'wall-da'],
      );
      notifier.addRoomFromDetection(
        room: const Room(id: 'right', floorId: 'floor-1', name: 'Right'),
        wallIds: ['wall-be', 'wall-bc', 'wall-cf', 'wall-fe'],
      );
    }

    test('TR-1: both rooms exist after sequential creation', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      createBoth(notifier);

      final rooms = container.read(editorStateProvider).rooms;
      expect(rooms, hasLength(2));
      expect(rooms.map((r) => r.id), containsAll(['left', 'right']));
    });

    test('TR-2: divider BE becomes interior with a mirror (8 walls)', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      createBoth(notifier);

      final walls = container.read(editorStateProvider).walls;
      // 7 original + 1 mirror of the shared divider.
      expect(walls, hasLength(8));

      final be = walls.firstWhere((w) => w.id == 'wall-be');
      expect(be.wallType, equals(WallType.interior));
      expect(be.adjacentRoomId, equals('right'));

      final mirror = walls.firstWhere(
        (w) => w.roomId == 'right' && w.wallType == WallType.interior,
      );
      expect(mirror.adjacentRoomId, equals('left'));
    });
  });

  // ── Group 3: Heat demand with interior wall ──────────────────────────────
  //
  // Shared wall dimensions: 4 000 mm wide × 2 600 mm high = 10.4 m²
  // U = 0.5 W/(m²·K),  outdoor = -12 °C
  //
  // Room 2 (24 °C) → Room 1 (20 °C):
  //   f = (24 − 20) / (24 − (−12)) = 4/36 = 1/9 ≈ 0.1111
  //   Q = 0.5 × 10.4 × (1/9) × 36 = 20.8 W  (heat LOSS from bathroom)
  //
  // Room 1 (20 °C) → Room 2 (24 °C):
  //   f = (20 − 24) / (20 − (−12)) = −4/32 = −0.125
  //   Q = 0.5 × 10.4 × (−0.125) × 32 = −20.8 W  (heat GAIN into living room)
  //
  // Exterior equivalent for Room 2's shared wall:
  //   Q_ext = 0.5 × 10.4 × 1.0 × 36 = 187.2 W
  //   Reduction factor: 20.8 / 187.2 = 1/9 = f  ✓

  group('Shared-wall heat demand — ThermalEngine integration', () {
    const room1TempC = 20.0;
    const room2TempC = 24.0;

    test('SH-T-1: interiorCorrectionFactor for Room 2 facing Room 1 '
        'is (24−20)/(24−(−12)) = 4/36', () {
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: room2TempC,
        tAdjacentRoomC: room1TempC,
        tOutdoorC: _outdoorTempC,
      );
      // 4 / 36 = 0.1111…
      expect(f, closeTo(4.0 / 36.0, 0.001));
    });

    test('SH-T-2: interiorCorrectionFactor for Room 1 facing Room 2 '
        'is (20−24)/(20−(−12)) = −4/32 (negative = heat gain)', () {
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: room1TempC,
        tAdjacentRoomC: room2TempC,
        tOutdoorC: _outdoorTempC,
      );
      // −4 / 32 = −0.125
      expect(f, closeTo(-4.0 / 32.0, 0.001));
    });

    test('SH-T-3: transmission loss through the shared wall for Room 2 '
        'is 20.8 W (reduced compared to exterior)', () {
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: room2TempC,
        tAdjacentRoomC: room1TempC,
        tOutdoorC: _outdoorTempC,
      );
      final q = ThermalEngine.transmissionLoss(
        uValue: _sharedWallUValue,
        areaM2: _sharedWallAreaM2,
        correctionF: f,
        tIndoorC: room2TempC,
        tOutdoorC: _outdoorTempC,
      );
      // 0.5 × 10.4 × (4/36) × 36 = 20.8 W
      expect(q, closeTo(20.8, 20.8 * 0.02));
    });

    test('SH-T-4: Room 1 has negative transmission loss (heat gain) '
        'through shared wall because bathroom is warmer', () {
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: room1TempC,
        tAdjacentRoomC: room2TempC,
        tOutdoorC: _outdoorTempC,
      );
      final q = ThermalEngine.transmissionLoss(
        uValue: _sharedWallUValue,
        areaM2: _sharedWallAreaM2,
        correctionF: f,
        tIndoorC: room1TempC,
        tOutdoorC: _outdoorTempC,
      );
      // 0.5 × 10.4 × (−0.125) × 32 = −20.8 W
      expect(
        q,
        lessThan(0),
        reason:
            'A negative transmission loss means the adjacent room is '
            'supplying heat — Room 1 heating demand is reduced.',
      );
      expect(q, closeTo(-20.8, 20.8 * 0.02));
    });

    test(
      'SH-T-5: heat flow is symmetric — magnitude equal from both sides',
      () {
        final fRoom2 = ThermalEngine.interiorCorrectionFactor(
          tThisRoomC: room2TempC,
          tAdjacentRoomC: room1TempC,
          tOutdoorC: _outdoorTempC,
        );
        final qRoom2 = ThermalEngine.transmissionLoss(
          uValue: _sharedWallUValue,
          areaM2: _sharedWallAreaM2,
          correctionF: fRoom2,
          tIndoorC: room2TempC,
          tOutdoorC: _outdoorTempC,
        );

        final fRoom1 = ThermalEngine.interiorCorrectionFactor(
          tThisRoomC: room1TempC,
          tAdjacentRoomC: room2TempC,
          tOutdoorC: _outdoorTempC,
        );
        final qRoom1 = ThermalEngine.transmissionLoss(
          uValue: _sharedWallUValue,
          areaM2: _sharedWallAreaM2,
          correctionF: fRoom1,
          tIndoorC: room1TempC,
          tOutdoorC: _outdoorTempC,
        );

        // Both sides must resolve to U × A × (T_this − T_adjacent):
        //   Room 2: 0.5 × 10.4 × (24−20) = +20.8 W
        //   Room 1: 0.5 × 10.4 × (20−24) = −20.8 W
        expect(
          qRoom2,
          closeTo(-qRoom1, 0.1),
          reason:
              'Heat flowing out of Room 2 must equal heat flowing '
              'into Room 1 — energy is conserved.',
        );
      },
    );

    test('SH-T-6: Room 2 shared-wall demand is ≈ 11 % of the '
        'equivalent exterior wall demand', () {
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: room2TempC,
        tAdjacentRoomC: room1TempC,
        tOutdoorC: _outdoorTempC,
      );
      final qInterior = ThermalEngine.transmissionLoss(
        uValue: _sharedWallUValue,
        areaM2: _sharedWallAreaM2,
        correctionF: f,
        tIndoorC: room2TempC,
        tOutdoorC: _outdoorTempC,
      );
      final qExterior = ThermalEngine.transmissionLoss(
        uValue: _sharedWallUValue,
        areaM2: _sharedWallAreaM2,
        correctionF: 1.0,
        tIndoorC: room2TempC,
        tOutdoorC: _outdoorTempC,
      );

      // Interior / exterior = f = 4/36 ≈ 11.1 %
      expect(qInterior / qExterior, closeTo(f, 0.001));
      expect(
        qInterior,
        lessThan(qExterior),
        reason:
            'Shared interior wall always produces less heat demand '
            'than the same wall exposed to outdoor conditions.',
      );
    });

    test('SH-T-7: zero correction factor when both rooms at same '
        'temperature — shared wall contributes nothing to demand', () {
      const sameTempC = 20.0;
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: sameTempC,
        tAdjacentRoomC: sameTempC,
        tOutdoorC: _outdoorTempC,
      );
      final q = ThermalEngine.transmissionLoss(
        uValue: _sharedWallUValue,
        areaM2: _sharedWallAreaM2,
        correctionF: f,
        tIndoorC: sameTempC,
        tOutdoorC: _outdoorTempC,
      );
      expect(f, equals(0.0));
      expect(q, equals(0.0));
    });
  });

  // ── Group 4: commitWallWithSplit — wall splitting at draw time (ADR-003) ──
  //
  // The user draws room 1 (rectangle with walls a,b,c,d).  Room 2 is then
  // drawn starting at the junction of walls c and d.  The third new wall of
  // room 2 ends at an interior point of wall d.  commitWallWithSplit must
  // split wall d at that junction point BEFORE room detection runs.
  //
  // Layout (all coordinates in mm):
  //
  //   jcd=(0,2000)  ← junction of wall_c & wall_d (existing endpoint)
  //        |
  //      d1 wall_d_before  (0,2000)→(0,1000)  — room-1, exterior after split
  //        |
  //   J=(0,1000)  ← new junction where wall_3 ends on wall_d's interior
  //        |
  //      d2 wall_d_after   (0,1000)→(0,0)    — room-1, exterior after split
  //        |
  //   A=(0,0)─────────────────B=(3000,0)
  //
  // Room 1 walls (assigned to 'big-room'):
  //   wall_a: A(0,0)→B(3000,0)
  //   wall_b: B(3000,0)→C(3000,2000)
  //   wall_c: C(3000,2000)→jcd(0,2000)
  //   wall_d: jcd(0,2000)→A(0,0)
  //
  // New walls drawn for room 2 (unassigned), committed via commitWallWithSplit:
  //   wall_1: jcd(0,2000) → E(-1000,2000)
  //   wall_2: E(-1000,2000) → J(-1000,1000)
  //   wall_3: J(-1000,1000) → J_on_d(0,1000)  ← endpoint on wall_d interior
  //
  // After commitWallWithSplit(wall_3):
  //   wall_d is split at (0,1000):
  //     d1: (0,2000)→(0,1000)  roomId=big-room, exterior
  //     d2: (0,1000)→(0,0)     roomId=big-room, exterior
  //   wall_3 is added.
  //
  // Room detection then finds the cycle [wall_3, d1, wall_1, wall_2].
  // addRoomFromDetection marks d1 as interior and creates a mirror for room-2.

  group('EditorStateNotifier.commitWallWithSplit — '
      'wall split at draw time (ADR-003)', () {
    // Room 1 corners.
    const ptA = Point2D(x: 0, y: 0);
    const ptB = Point2D(x: 3000, y: 0);
    const ptC = Point2D(x: 3000, y: 2000);
    const ptJcd = Point2D(x: 0, y: 2000); // junction of c and d

    // Junction point where wall_3 ends on wall_d's interior.
    const ptJ = Point2D(x: 0, y: 1000);

    // External corners of room 2.
    const ptE = Point2D(x: -1000, y: 2000);
    const ptF = Point2D(x: -1000, y: 1000);

    // Room 1 walls (assigned).
    const wallA = WallSegment(
      id: 'wall-a',
      roomId: 'big-room',
      startPoint: ptA,
      endPoint: ptB,
    );
    const wallB = WallSegment(
      id: 'wall-b',
      roomId: 'big-room',
      startPoint: ptB,
      endPoint: ptC,
    );
    const wallC = WallSegment(
      id: 'wall-c',
      roomId: 'big-room',
      startPoint: ptC,
      endPoint: ptJcd,
    );
    const wallD = WallSegment(
      id: 'wall-d',
      roomId: 'big-room',
      startPoint: ptJcd,
      endPoint: ptA,
    );

    // New walls for room 2 (unassigned).
    const wall1 = WallSegment(
      id: 'wall-1',
      roomId: '',
      startPoint: ptJcd,
      endPoint: ptE,
    );
    const wall2 = WallSegment(
      id: 'wall-2',
      roomId: '',
      startPoint: ptE,
      endPoint: ptF,
    );
    // wall_3 ends at ptJ = (0,1000), which is on wall_d's interior.
    const wall3 = WallSegment(
      id: 'wall-3',
      roomId: '',
      startPoint: ptF,
      endPoint: ptJ,
    );

    (ProviderContainer, EditorStateNotifier) makeContainer() {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);
      final notifier = container.read(editorStateProvider.notifier);

      notifier.addRoom(
        const Room(
          id: 'big-room',
          floorId: 'floor-1',
          name: 'Big Room',
          targetTempC: 20.0,
        ),
      );
      notifier.addWall(wallA);
      notifier.addWall(wallB);
      notifier.addWall(wallC);
      notifier.addWall(wallD);

      // Commit the first two walls of room 2 normally.
      notifier.commitWallWithSplit(wall1);
      notifier.commitWallWithSplit(wall2);

      return (container, notifier);
    }

    test('WS-1: committing wall_3 splits wall_d at (0,1000) — '
        'original wall_d is removed', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.commitWallWithSplit(wall3);

      final walls = container.read(editorStateProvider).walls;
      expect(
        walls.any((w) => w.id == 'wall-d'),
        isFalse,
        reason: 'Original wall_d must be replaced by two split segments.',
      );
    });

    test('WS-2: two split segments of wall_d are created for big-room', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.commitWallWithSplit(wall3);

      final walls = container.read(editorStateProvider).walls;
      final dPieces = walls
          .where(
            (w) =>
                w.roomId == 'big-room' &&
                (w.startPoint == ptJcd ||
                    w.startPoint == ptJ ||
                    w.endPoint == ptJ ||
                    w.endPoint == ptA) &&
                w.id != 'wall-c',
          )
          .toList();

      expect(
        dPieces,
        hasLength(2),
        reason: 'wall_d must be split into two segments at (0,1000).',
      );
    });

    test('WS-3: first split piece spans jcd(0,2000)→J(0,1000) and is '
        'exterior (not yet shared)', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.commitWallWithSplit(wall3);

      final walls = container.read(editorStateProvider).walls;
      final d1 = walls.firstWhere(
        (w) =>
            w.roomId == 'big-room' &&
            w.startPoint == ptJcd &&
            w.endPoint == ptJ,
      );

      expect(d1.wallType, equals(WallType.exterior));
    });

    test('WS-4: second split piece spans J(0,1000)→A(0,0) and is exterior', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.commitWallWithSplit(wall3);

      final walls = container.read(editorStateProvider).walls;
      final d2 = walls.firstWhere(
        (w) =>
            w.roomId == 'big-room' && w.startPoint == ptJ && w.endPoint == ptA,
      );

      expect(d2.wallType, equals(WallType.exterior));
    });

    test('WS-5: wall_3 is added to state after the split', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.commitWallWithSplit(wall3);

      final walls = container.read(editorStateProvider).walls;
      expect(walls.any((w) => w.id == 'wall-3'), isTrue);
    });

    test('WS-6: committing wall_1 (endpoint at jcd = existing corner) '
        'does not split wall_d', () {
      // The endpoint of wall_1 is at jcd = startPoint of wall_d,
      // which is NOT an interior point, so no split should occur.
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      // wall_1 and wall_2 were already committed in makeContainer.
      // Verify wall_d is still intact.
      final walls = container.read(editorStateProvider).walls;
      expect(
        walls.any((w) => w.id == 'wall-d'),
        isTrue,
        reason:
            'wall_d must not be split by wall_1 whose endpoint '
            'is at wall_d\'s own startPoint (a corner, not interior).',
      );
    });

    test('WS-7: unassigned walls are not split by new wall endpoints', () {
      // If an unassigned wall happens to lie on the path of a new wall,
      // it should not be split (only assigned walls are split).
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);

      // Add an unassigned "dangling" wall at x=0, y=[0,2000].
      const unassignedWall = WallSegment(
        id: 'unassigned',
        roomId: '',
        startPoint: Point2D(x: 0, y: 0),
        endPoint: Point2D(x: 0, y: 2000),
      );
      notifier.addWall(unassignedWall);

      // Commit a wall whose endpoint (0,1000) is on the unassigned wall.
      const newWall = WallSegment(
        id: 'new-wall',
        roomId: '',
        startPoint: Point2D(x: -500, y: 1000),
        endPoint: Point2D(x: 0, y: 1000),
      );
      notifier.commitWallWithSplit(newWall);

      final walls = container.read(editorStateProvider).walls;
      expect(
        walls.any((w) => w.id == 'unassigned'),
        isTrue,
        reason: 'Unassigned walls must not be split.',
      );
      expect(walls, hasLength(2)); // unassigned + new-wall
    });
  });

  // ── Group 5: reverse split — new wall longer than the existing wall ────────
  //
  // Symmetric counterpart to Group 4. The user draws the SMALL room first,
  // then an adjacent WIDER room whose shared wall is longer than the small
  // room's. The wide room's shared edge must be split at the small room's
  // corners so the overlapping sub-segment becomes its own graph edge and
  // is recognised as a shared (mirrored) wall — exactly as it would be if
  // the rooms were drawn in the opposite order (screenshot bug).
  //
  // Layout (mm):
  //
  //          D(0,2000)──────C(2000,2000)
  //            │  small room   │            (drawn first, y ∈ [0, 2000])
  //   tl(-1000,0)──A(0,0)──────B(2000,0)──tr(3000,0)
  //            │                              │
  //            │       wide room (drawn 2nd)  │   (y ∈ [-2000, 0])
  //   bl(-1000,-2000)──────────────────br(3000,-2000)
  //
  // Small room's bottom wall AB = (0,0)→(2000,0). The wide room's top edge
  // tl→tr = (-1000,0)→(3000,0) is 4000 mm long; AB's endpoints A and B lie
  // on its interior.
  group('EditorStateNotifier.commitWallWithSplit — '
      'reverse split when the new wall is longer (screenshot bug)', () {
    const tl = Point2D(x: -1000, y: 0);
    const tr = Point2D(x: 3000, y: 0);
    const br = Point2D(x: 3000, y: -2000);
    const bl = Point2D(x: -1000, y: -2000);

    const smallA = Point2D(x: 0, y: 0);
    const smallB = Point2D(x: 2000, y: 0);
    const smallC = Point2D(x: 2000, y: 2000);
    const smallD = Point2D(x: 0, y: 2000);

    // Small room walls (assigned). Bottom wall is the shared candidate.
    const smallBottom = WallSegment(
      id: 'small-bottom',
      roomId: 'small-room',
      startPoint: smallA,
      endPoint: smallB,
    );
    const smallRight = WallSegment(
      id: 'small-right',
      roomId: 'small-room',
      startPoint: smallB,
      endPoint: smallC,
    );
    const smallTop = WallSegment(
      id: 'small-top',
      roomId: 'small-room',
      startPoint: smallC,
      endPoint: smallD,
    );
    const smallLeft = WallSegment(
      id: 'small-left',
      roomId: 'small-room',
      startPoint: smallD,
      endPoint: smallA,
    );

    (ProviderContainer, EditorStateNotifier) makeContainer() {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);
      final notifier = container.read(editorStateProvider.notifier);

      notifier.addRoom(
        const Room(
          id: 'small-room',
          floorId: 'floor-1',
          name: 'Small Room',
          targetTempC: 20.0,
        ),
      );
      notifier.addWall(smallBottom);
      notifier.addWall(smallRight);
      notifier.addWall(smallTop);
      notifier.addWall(smallLeft);
      return (container, notifier);
    }

    // The wide room's long top edge, drawn over the small room's bottom wall.
    const wideTop = WallSegment(
      id: 'wide-top',
      roomId: '',
      startPoint: tl,
      endPoint: tr,
    );

    bool sameSpan(WallSegment w, Point2D a, Point2D b) {
      bool eq(Point2D p, Point2D q) =>
          (p.x - q.x).abs() < 1.0 && (p.y - q.y).abs() < 1.0;
      return (eq(w.startPoint, a) && eq(w.endPoint, b)) ||
          (eq(w.startPoint, b) && eq(w.endPoint, a));
    }

    test('RS-1: the longer new wall is split at the small room\'s corners', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.commitWallWithSplit(wideTop);

      final walls = container.read(editorStateProvider).walls;
      // No single wall may span the full 4000 mm top edge any more.
      expect(
        walls.any((w) => sameSpan(w, tl, tr)),
        isFalse,
        reason: 'The full-length top edge must be split into fragments.',
      );
      // The two non-overlapping outer fragments must exist.
      expect(
        walls.any((w) => sameSpan(w, tl, smallA)),
        isTrue,
        reason: 'Left outer fragment (-1000,0)->(0,0) must be added.',
      );
      expect(
        walls.any((w) => sameSpan(w, smallB, tr)),
        isTrue,
        reason: 'Right outer fragment (2000,0)->(3000,0) must be added.',
      );
    });

    test('RS-2: the shared sub-segment is not duplicated', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      notifier.commitWallWithSplit(wideTop);

      final walls = container.read(editorStateProvider).walls;
      final sharedSpan = walls
          .where((w) => sameSpan(w, smallA, smallB))
          .toList();
      expect(
        sharedSpan,
        hasLength(1),
        reason:
            'Only the existing small-room wall covers the shared span; '
            'the new wall must not duplicate it.',
      );
      expect(sharedSpan.single.id, 'small-bottom');
    });

    test('RS-3: detection from the wide room finds it through the existing '
        'shared wall', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);

      // Draw the wide room as four edges (rect order), capturing the seed
      // fragment returned for the reverse-split top edge.
      final seed = notifier.commitWallWithSplit(wideTop);
      notifier.commitWallWithSplit(
        const WallSegment(
          id: 'wide-right',
          roomId: '',
          startPoint: tr,
          endPoint: br,
        ),
      );
      notifier.commitWallWithSplit(
        const WallSegment(
          id: 'wide-bottom',
          roomId: '',
          startPoint: br,
          endPoint: bl,
        ),
      );
      notifier.commitWallWithSplit(
        const WallSegment(
          id: 'wide-left',
          roomId: '',
          startPoint: bl,
          endPoint: tl,
        ),
      );

      final result = RoomDetection.detectRoom(
        container.read(editorStateProvider).walls,
        seed,
        existingRooms: container.read(editorStateProvider).rooms,
      );

      expect(result.outcome, RoomDetectionOutcome.detected);
      final room = result.room!;
      // The detected boundary must traverse the existing small-room wall,
      // so addRoomFromDetection will promote it to a shared (mirrored) wall.
      expect(
        room.wallIds,
        contains('small-bottom'),
        reason:
            'The wide room must close through the existing shared wall, '
            'not a duplicate fragment.',
      );
    });
  });

  // ── Group 6: forward host split — attach a smaller room to a larger one ────
  //
  // The complement of Group 5. The LARGE room is drawn first; a SMALLER room
  // is then attached, sharing only part of the large room's wall. The large
  // wall is host-split at the small room's corners (Group 4 / ADR-003), and
  // the small room's drawn shared edge — which now lies exactly on the
  // host-split middle piece — must NOT be added as an orphan duplicate.
  //
  // Layout (mm): large room below the x-axis, top wall (0,0)→(4000,0). Small
  // room above, bottom edge (1000,0)→(3000,0) on the large wall's interior.
  group('EditorStateNotifier.commitWallWithSplit — '
      'attaching a smaller room leaves no orphan duplicate wall', () {
    const l0 = Point2D(x: 0, y: 0);
    const l1 = Point2D(x: 4000, y: 0);
    const l2 = Point2D(x: 4000, y: -2000);
    const l3 = Point2D(x: 0, y: -2000);

    const sTlBottomL = Point2D(x: 1000, y: 0); // shared span left
    const sTrBottomR = Point2D(x: 3000, y: 0); // shared span right
    const sTr = Point2D(x: 3000, y: 2000);
    const sTl = Point2D(x: 1000, y: 2000);

    (ProviderContainer, EditorStateNotifier) makeContainer() {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);
      final notifier = container.read(editorStateProvider.notifier);
      notifier.addRoom(
        const Room(
          id: 'large',
          floorId: 'floor-1',
          name: 'Large',
          targetTempC: 20.0,
        ),
      );
      const corners = [l0, l1, l2, l3];
      for (var i = 0; i < 4; i++) {
        notifier.addWall(
          WallSegment(
            id: 'large-$i',
            roomId: 'large',
            startPoint: corners[i],
            endPoint: corners[(i + 1) % 4],
          ),
        );
      }
      return (container, notifier);
    }

    // Draw the small room's four edges; bottom drawn right→left so it is the
    // reverse of the host-split middle piece.
    void drawSmall(EditorStateNotifier n) {
      final seed = n.commitWallWithSplit(
        const WallSegment(
          id: 's-top',
          roomId: '',
          startPoint: sTl,
          endPoint: sTr,
        ),
      );
      n.commitWallWithSplit(
        const WallSegment(
          id: 's-right',
          roomId: '',
          startPoint: sTr,
          endPoint: sTrBottomR,
        ),
      );
      n.commitWallWithSplit(
        const WallSegment(
          id: 's-bottom',
          roomId: '',
          startPoint: sTrBottomR,
          endPoint: sTlBottomL,
        ),
      );
      n.commitWallWithSplit(
        const WallSegment(
          id: 's-left',
          roomId: '',
          startPoint: sTlBottomL,
          endPoint: sTl,
        ),
      );
      final r = RoomDetection.detectRoom(
        n.state.walls,
        seed,
        existingRooms: n.state.rooms,
      );
      n.addRoomFromDetection(
        room: const Room(
          id: 'small',
          floorId: 'floor-1',
          name: 'Small',
          targetTempC: 20.0,
        ),
        wallIds: r.room!.wallIds,
      );
    }

    bool onSharedSpan(WallSegment w) {
      bool eq(Point2D p, Point2D q) =>
          (p.x - q.x).abs() < 1.0 && (p.y - q.y).abs() < 1.0;
      return (eq(w.startPoint, sTlBottomL) && eq(w.endPoint, sTrBottomR)) ||
          (eq(w.startPoint, sTrBottomR) && eq(w.endPoint, sTlBottomL));
    }

    test('FS-1: no orphan (room-less) wall is left on the shared span', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);
      drawSmall(notifier);

      final orphans = container
          .read(editorStateProvider)
          .walls
          .where((w) => w.roomId.isEmpty && onSharedSpan(w))
          .toList();
      expect(
        orphans,
        isEmpty,
        reason:
            'The drawn shared edge must be absorbed into the shared wall, '
            'not left as a duplicate orphan over it.',
      );
    });

    test('FS-2: the shared span is exactly one mirrored interior pair', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);
      drawSmall(notifier);

      final spanWalls = container
          .read(editorStateProvider)
          .walls
          .where(onSharedSpan)
          .toList();
      expect(
        spanWalls,
        hasLength(2),
        reason: 'Exactly the shared wall and its mirror.',
      );
      for (final w in spanWalls) {
        expect(w.wallType, WallType.interior);
        expect(w.mirrorId, isNotNull);
        expect(w.roomId, isNotEmpty);
      }
      expect(
        spanWalls.map((w) => w.roomId).toSet(),
        {'large', 'small'},
        reason: 'One side belongs to each room.',
      );
    });

    test('FS-3: the large wall is host-split into three pieces', () {
      final (container, notifier) = makeContainer();
      addTearDown(container.dispose);
      drawSmall(notifier);

      final largeTopPieces = container
          .read(editorStateProvider)
          .walls
          .where(
            (w) =>
                w.roomId == 'large' &&
                w.startPoint.y.abs() < 1.0 &&
                w.endPoint.y.abs() < 1.0,
          )
          .toList();
      // (0,0)-(1000,0) exterior, (1000,0)-(3000,0) shared interior,
      // (3000,0)-(4000,0) exterior.
      expect(largeTopPieces, hasLength(3));
      expect(
        largeTopPieces.where((w) => w.wallType == WallType.interior),
        hasLength(1),
      );
    });
  });
}
