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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/thermal_engine.dart';
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
    test(
        'SH-D-1: detecting Room 1 (4 new walls) '
        'returns exactly 4 wall IDs', () {
      // Room 1 walls are drawn in order AB, BE, ED, DA.
      // DA is the closing wall.  The DFS must traverse AB, BE, ED
      // and include ED as the closing edge.
      final allWalls = [_wallAb, _wallBe, _wallEd, _wallDa];
      final result = RoomDetection.detectClosedRoom(allWalls, _wallDa);

      expect(result, isNotNull);
      expect(result!.wallIds, hasLength(4));
      expect(result.wallIds, containsAll(['wall-da', 'wall-ab', 'wall-be', 'wall-ed']));
    });

    test(
        'SH-D-2: closing wall (ED) is present in Room 1 wallIds '
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
        reason: 'wall-ed connects the last traversed node (E) back to the '
            "start point (D) — it is the 'closing edge' that was previously "
            'dropped from wallIds.',
      );
    });

    test(
        'SH-D-3: detecting Room 2 returns 4 wall IDs including '
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

    test(
        'SH-D-4: Room 2 detection includes BE (shared wall) specifically '
        '— verifies DFS crosses into existing room territory', () {
      final result = RoomDetection.detectClosedRoom(
        _allWallsForRoom2Detection,
        _wallFe,
      );

      expect(result, isNotNull);
      expect(
        result!.wallIds,
        contains('wall-be'),
        reason: 'wall-be already belongs to Room 1 but lies on the boundary '
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

  // ── Group 2: EditorStateNotifier.addRoomFromDetection ───────────────────

  group('EditorStateNotifier.addRoomFromDetection — shared wall handling', () {
    /// Build a ProviderContainer seeded with Room 1 (4 walls) and
    /// the three unassigned walls for Room 2 (BC, CF, FE).
    ///
    /// In the real app [WallDrawTool] commits each wall to state
    /// before room detection fires, so all seven walls are present
    /// when [addRoomFromDetection] is called.
    (ProviderContainer, EditorStateNotifier) makeContainer() {
      final container = ProviderContainer();
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

    test(
        'SH-S-1: after adding Room 2, state contains exactly 2 rooms', () {
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

    test(
        'SH-S-2: Room 1 still has exactly 4 wall segments after '
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
        reason: 'Room 1 must keep AB, BE (updated), ED, DA — '
            'the shared wall stays in Room 1 (roomId unchanged).',
      );
    });

    test(
        'SH-S-3: Room 2 has exactly 4 wall segments '
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
        reason: 'Room 2 must have FE, BC, CF (new) and a mirror of '
            'BE (created by addRoomFromDetection).',
      );
    });

    test(
        'SH-S-4: shared wall BE is marked WallType.interior on '
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

    test(
        'SH-S-5: shared wall BE has adjacentRoomId = room-2 '
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
        reason: 'ThermalEngine.interiorCorrectionFactor needs adjacentRoomId '
            'to look up the neighbouring room temperature.',
      );
    });

    test(
        'SH-S-6: mirror wall for Room 2 is marked WallType.interior', () {
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

    test(
        'SH-S-7: mirror wall has adjacentRoomId = room-1 '
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
        reason: 'interiorCorrectionFactor for Room 2 must resolve '
            'adjacentRoomId to look up Room 1 targetTempC.',
      );
    });

    test(
        'SH-S-8: mirror wall geometry is the reverse of BE '
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

    test(
        'SH-S-9: total wall count in state is 8 '
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

    test(
        'SH-T-1: interiorCorrectionFactor for Room 2 facing Room 1 '
        'is (24−20)/(24−(−12)) = 4/36', () {
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: room2TempC,
        tAdjacentRoomC: room1TempC,
        tOutdoorC: _outdoorTempC,
      );
      // 4 / 36 = 0.1111…
      expect(f, closeTo(4.0 / 36.0, 0.001));
    });

    test(
        'SH-T-2: interiorCorrectionFactor for Room 1 facing Room 2 '
        'is (20−24)/(20−(−12)) = −4/32 (negative = heat gain)', () {
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: room1TempC,
        tAdjacentRoomC: room2TempC,
        tOutdoorC: _outdoorTempC,
      );
      // −4 / 32 = −0.125
      expect(f, closeTo(-4.0 / 32.0, 0.001));
    });

    test(
        'SH-T-3: transmission loss through the shared wall for Room 2 '
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

    test(
        'SH-T-4: Room 1 has negative transmission loss (heat gain) '
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
        reason: 'A negative transmission loss means the adjacent room is '
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
        reason: 'Heat flowing out of Room 2 must equal heat flowing '
            'into Room 1 — energy is conserved.',
      );
    });

    test(
        'SH-T-6: Room 2 shared-wall demand is ≈ 11 % of the '
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
        reason: 'Shared interior wall always produces less heat demand '
            'than the same wall exposed to outdoor conditions.',
      );
    });

    test(
        'SH-T-7: zero correction factor when both rooms at same '
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
}
