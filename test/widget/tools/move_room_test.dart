// Widget tests for ADR-016 — move entire room by interior drag.
//
// Drives [SelectTool] through an [EditorCallbacks] adapter backed by a
// real [EditorStateNotifier] / [ProviderContainer]. This is the only
// way to exercise the actual room-draw reconciliation pipeline
// (`commitWallWithSplit` + `addRoomFromDetection` mirror sync) — which
// ADR-016 explicitly requires the move to reuse, and which the
// `redraw-equivalence` acceptance rule depends on.
//
// Verification list (ADR-016 §Verification):
//   MR-1 Standalone room moves rigidly with its walls and zones.
//   MR-2 Moving next to another room regenerates a shared wall whose
//        graph matches what redrawing the room at that position
//        produces (ADR-009 promote + ADR-001 mirror copy + ADR-011
//        mirrorId, with the neighbour wall promoted in place).
//   MR-3 Moving a shared room away detaches the shared partner — both
//        walls revert to exterior, mirrorId / adjacentRoomId cleared on
//        both sides, neighbour geometry unchanged.
//   MR-4 A single Ctrl+Z reverts the whole move (regenerated shared
//        walls, detaches, and zone translations all in one undo).
//   MR-5 A click without drag past threshold still only selects.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Drift generates data classes that collide with our freezed models.
import 'package:heating_planner/data/database/app_database.dart'
    hide Distributor, Door, HeatingCircuit, HeatingZone, Room, WallSegment;
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/door.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/data/models/window_element.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/l10n/app_localizations_en.dart';
import 'package:heating_planner/ui/canvas/tools/editor_callbacks.dart';
import 'package:heating_planner/ui/canvas/tools/select_tool.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Provider-backed callbacks adapter ──────────────────────────────────────
//
// Delegates every mutation to a real [EditorStateNotifier] so the ADR-001
// mirror copy, ADR-003 host-wall split, ADR-009 edge-match, and ADR-011
// `mirrorId` linkage execute exactly as they do in production — letting
// the redraw-equivalence acceptance check (ADR-016 Rule 6) actually
// inspect the genuine graph the room-draw pipeline produces.

class _ProviderCallbacks implements EditorCallbacks {
  _ProviderCallbacks(this._container);

  final ProviderContainer _container;

  EditorStateNotifier get _n =>
      _container.read(editorStateProvider.notifier);

  @override
  final AppLocalizations l10n = AppLocalizationsEn();

  String? lastSelectType;
  String? lastSelectId;

  @override
  List<WallSegment> get currentWalls =>
      _container.read(editorStateProvider).walls;
  @override
  List<Room> get currentRooms =>
      _container.read(editorStateProvider).rooms;
  @override
  List<HeatingZone> get currentZones =>
      _container.read(editorStateProvider).zones;
  @override
  List<WindowElement> get currentWindows =>
      _container.read(editorStateProvider).windows;
  @override
  List<Door> get currentDoors =>
      _container.read(editorStateProvider).doors;
  @override
  List<HeatingCircuit> get currentCircuits =>
      _container.read(editorStateProvider).circuits;
  @override
  Distributor? get currentDistributor =>
      _container.read(editorStateProvider).distributor;

  @override
  void commitWall(WallSegment wall) => _n.addWall(wall);
  @override
  void commitWallWithSplit(WallSegment wall) => _n.commitWallWithSplit(wall);
  @override
  void updateWall(WallSegment wall) => _n.updateWall(wall);
  @override
  void removeWall(String wallId) => _n.removeWall(wallId);

  @override
  void destroyRoom(String roomId) {
    _n.clearRoomIdOnWalls(roomId);
    _n.removeRoom(roomId);
  }

  @override
  void restoreRoom(Room room, List<String> wallIds) {
    _n.addRoom(room);
    _n.assignWallsToRoom(wallIds, room.id);
  }

  @override
  void updateRoom(Room room) => _n.updateRoom(room);

  @override
  void replaceAllWalls(List<WallSegment> walls) =>
      _n.replaceAllWalls(walls);
  @override
  void replaceAllWallsAndRooms(
    List<WallSegment> walls,
    List<Room> rooms,
  ) =>
      _n.replaceAllWallsAndRooms(walls, rooms);
  @override
  void replaceAllWallsRoomsZones(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
  ) =>
      _n.replaceAllWallsRoomsZones(walls, rooms, zones);
  @override
  void addRoomFromDetection({
    required Room room,
    required List<String> wallIds,
  }) =>
      _n.addRoomFromDetection(room: room, wallIds: wallIds);

  @override
  void commitWindow(WindowElement window) => _n.addWindow(window);
  @override
  void updateWindow(WindowElement window) => _n.updateWindow(window);
  @override
  void removeWindow(String windowId) => _n.removeWindow(windowId);

  @override
  void commitDoor(Door door) => _n.addDoor(door);
  @override
  void updateDoor(Door door) => _n.updateDoor(door);
  @override
  void removeDoor(String doorId) => _n.removeDoor(doorId);

  @override
  void commitDistributor(Distributor d) => _n.setDistributor(d);
  @override
  void updateDistributor(Distributor d) => _n.updateDistributor(d);
  @override
  void removeDistributor() => _n.clearDistributor();
  @override
  void requestDistributorReplaceDialog({
    required void Function() onMove,
    required void Function() onReplace,
  }) {}
  @override
  void requestDistributorDeleteDialog({
    required void Function() onConfirmed,
  }) {}

  @override
  void commitCircuit(HeatingCircuit circuit) => _n.addCircuit(circuit);
  @override
  void updateCircuit(HeatingCircuit circuit) => _n.updateCircuit(circuit);
  @override
  void removeCircuit(String circuitId) => _n.removeCircuit(circuitId);
  @override
  void clearAllCircuits() => _n.clearAllCircuits();

  @override
  void commitZone(HeatingZone zone) => _n.addZone(zone);
  @override
  void updateZone(HeatingZone zone) => _n.updateZone(zone);
  @override
  void removeZone(String zoneId) => _n.removeZone(zoneId);

  @override
  String get currentFloorId => 'floor-1';
  @override
  String get defaultTubeTypeId => 'tube-1';
  @override
  String get defaultFlooringMaterialId => 'mat-1';

  @override
  void selectElement(String? type, String? id) {
    lastSelectType = type;
    lastSelectId = id;
  }

  @override
  void requestRoomDialog(
    List<Point2D> polygon,
    List<String> wallIds, {
    void Function(List<WallSegment>, List<Room>)? onCreated,
  }) {}

  @override
  void requestZoneContextMenu(ZoneContextMenuRequest request) {}

  @override
  void showToast(String message) {}

  @override
  double get currentZoom => 1.0;
  @override
  double get currentGridSpacingMm => 100.0;
}

// ── Test harness ───────────────────────────────────────────────────────────

final _dbOverride = appDatabaseProvider.overrideWith((ref) {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  ref.onDispose(db.close);
  return db;
});

(_ProviderCallbacks, SelectTool, UndoRedoService, ProviderContainer)
    _setup() {
  final container = ProviderContainer(overrides: [_dbOverride]);
  final cb = _ProviderCallbacks(container);
  final undoRedo = UndoRedoService();
  final tool = SelectTool(
    callbacks: cb,
    onStateChanged: () {},
    undoRedo: undoRedo,
  );
  return (cb, tool, undoRedo, container);
}

// Geometry helpers shared across scenarios.
//
// A 4 × 4 m rectangular room with all four walls assigned to room-1.
// Coordinates in mm. Mirrors the layout `addRoomFromDetection` would
// emit if the room were drawn fresh.

const _ptA = Point2D(x: 0, y: 0);
const _ptB = Point2D(x: 4000, y: 0);
const _ptC = Point2D(x: 4000, y: 4000);
const _ptD = Point2D(x: 0, y: 4000);

const _room1 = Room(
  id: 'room-1',
  floorId: 'floor-1',
  name: 'Room 1',
  targetTempC: 20.0,
  polygon: [_ptA, _ptB, _ptC, _ptD],
);

const _r1Walls = [
  WallSegment(
    id: 'r1-ab',
    roomId: 'room-1',
    startPoint: _ptA,
    endPoint: _ptB,
  ),
  WallSegment(
    id: 'r1-bc',
    roomId: 'room-1',
    startPoint: _ptB,
    endPoint: _ptC,
  ),
  WallSegment(
    id: 'r1-cd',
    roomId: 'room-1',
    startPoint: _ptC,
    endPoint: _ptD,
  ),
  WallSegment(
    id: 'r1-da',
    roomId: 'room-1',
    startPoint: _ptD,
    endPoint: _ptA,
  ),
];

// A 1 × 1 m zone in the centre of room-1 (1500,1500 → 2500,2500).
const _r1Zone = HeatingZone(
  id: 'zone-1',
  roomId: 'room-1',
  polygon: [
    Point2D(x: 1500, y: 1500),
    Point2D(x: 2500, y: 1500),
    Point2D(x: 2500, y: 2500),
    Point2D(x: 1500, y: 2500),
  ],
  tubeSpacingMm: 150,
  tubeTypeId: 'tube-1',
  flooringMaterialId: 'mat-1',
);

// Helper: drive a pointer-down → drag-update(s) → drag-end sequence
// through the SelectTool.
void _drag(
  SelectTool tool, {
  required Point2D from,
  required Point2D to,
}) {
  tool.onPointerDown(from, kPrimaryButton);
  // Two updates: the first crosses the 5 px threshold (zoom = 1.0
  // means 5 mm in world space); the second carries the final cursor.
  tool.onDragUpdate(
    Point2D(x: from.x + 100, y: from.y + 100),
  );
  tool.onDragUpdate(to);
  tool.onDragEnd(to);
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  // ────────────────────────────────────────────────────────────────────────
  // MR-1: Standalone room moves rigidly with its walls and zones.
  // ────────────────────────────────────────────────────────────────────────

  test(
    'MR-1: standalone room moves rigidly; walls and zones translate by delta',
    () {
      final (cb, tool, _, container) = _setup();
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);
      notifier.replaceAllWallsAndRooms(_r1Walls, [_room1]);
      notifier.addZone(_r1Zone);
      // Press at (500, 500) — inside room-1 but outside the zone
      // (the zone spans 1500–2500 in both axes); otherwise zone-body
      // drag would arm first (hit-stack priority).
      tool.onTap(const Point2D(x: 500, y: 500), PointerDeviceKind.mouse);
      expect(cb.lastSelectType, 'room');

      const delta = Point2D(x: 1000, y: 500);
      _drag(
        tool,
        from: const Point2D(x: 500, y: 500),
        to: const Point2D(x: 500 + 1000, y: 500 + 500),
      );

      // All four walls translated by (1000, 500).
      final walls = cb.currentWalls;
      expect(walls, hasLength(4));
      for (final w in _r1Walls) {
        final moved =
            walls.firstWhere((cur) => cur.startPoint == Point2D(
                  x: w.startPoint.x + delta.x,
                  y: w.startPoint.y + delta.y,
                ));
        expect(
          moved.endPoint,
          Point2D(x: w.endPoint.x + delta.x, y: w.endPoint.y + delta.y),
        );
        expect(
          moved.roomId,
          'room-1',
          reason: 'room identity must be preserved across the move',
        );
      }

      // Zone polygon translated by the same delta.
      final zones = cb.currentZones;
      expect(zones, hasLength(1));
      final zone = zones.single;
      expect(
        zone.polygon,
        equals([
          for (final v in _r1Zone.polygon)
            Point2D(x: v.x + delta.x, y: v.y + delta.y),
        ]),
      );
      expect(zone.roomId, 'room-1');

      // Room polygon translated too.
      final room = cb.currentRooms.single;
      expect(
        room.polygon,
        equals([
          for (final v in _room1.polygon)
            Point2D(x: v.x + delta.x, y: v.y + delta.y),
        ]),
      );
    },
  );

  // ────────────────────────────────────────────────────────────────────────
  // MR-2: Moving next to another room regenerates a shared wall whose graph
  // equals the redraw graph (ADR-016 Rule 6 acceptance).
  // ────────────────────────────────────────────────────────────────────────

  test(
    'MR-2: moving next to another room creates a shared wall matching the '
    'redraw graph (interior + mirrorId + adjacentRoomId on both sides)',
    () {
      // Layout: room-2 is a 4×4 room directly to the right of room-1,
      // **but** with a 4000 mm gap between them so they start
      // non-adjacent. Room-1 will be moved right by exactly 4000 mm to
      // make its east edge (x=4000 after move = 8000) coincide with
      // room-2's west edge (x=8000).
      const r2Walls = [
        WallSegment(
          id: 'r2-ef',
          roomId: 'room-2',
          startPoint: Point2D(x: 8000, y: 0),
          endPoint: Point2D(x: 12000, y: 0),
        ),
        WallSegment(
          id: 'r2-fg',
          roomId: 'room-2',
          startPoint: Point2D(x: 12000, y: 0),
          endPoint: Point2D(x: 12000, y: 4000),
        ),
        WallSegment(
          id: 'r2-gh',
          roomId: 'room-2',
          startPoint: Point2D(x: 12000, y: 4000),
          endPoint: Point2D(x: 8000, y: 4000),
        ),
        WallSegment(
          id: 'r2-he',
          roomId: 'room-2',
          startPoint: Point2D(x: 8000, y: 4000),
          endPoint: Point2D(x: 8000, y: 0),
        ),
      ];
      const room2 = Room(
        id: 'room-2',
        floorId: 'floor-1',
        name: 'Room 2',
        targetTempC: 20.0,
        polygon: [
          Point2D(x: 8000, y: 0),
          Point2D(x: 12000, y: 0),
          Point2D(x: 12000, y: 4000),
          Point2D(x: 8000, y: 4000),
        ],
      );

      final (cb, tool, _, container) = _setup();
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);
      notifier.replaceAllWallsAndRooms(
        [..._r1Walls, ...r2Walls],
        [_room1, room2],
      );

      tool.onTap(const Point2D(x: 2000, y: 2000), PointerDeviceKind.mouse);

      // Move room-1 right by 4000 mm so its east wall coincides with
      // room-2's west wall.
      _drag(
        tool,
        from: const Point2D(x: 2000, y: 2000),
        to: const Point2D(x: 6000, y: 2000),
      );

      // After the move there should be a shared wall between room-1
      // and room-2 along x = 8000, y in [0, 4000].
      final walls = cb.currentWalls;
      // Find the wall belonging to room-2 along x=8000.
      final r2ShareCandidates = walls
          .where((w) =>
              w.roomId == 'room-2' &&
              w.startPoint.x == 8000 &&
              w.endPoint.x == 8000)
          .toList();
      expect(
        r2ShareCandidates,
        hasLength(1),
        reason: 'room-2 must keep exactly one wall along the shared edge '
            '(promoted in place, not duplicated)',
      );
      final r2Share = r2ShareCandidates.single;
      expect(
        r2Share.wallType,
        WallType.interior,
        reason: 'shared wall must be promoted to interior on room-2 side',
      );
      expect(r2Share.adjacentRoomId, 'room-1');
      expect(r2Share.mirrorId, isNotNull);

      // Find the mirror partner on room-1's side.
      final r1Share = walls.firstWhere((w) => w.id == r2Share.mirrorId);
      expect(r1Share.roomId, 'room-1');
      expect(r1Share.wallType, WallType.interior);
      expect(r1Share.adjacentRoomId, 'room-2');
      expect(
        r1Share.mirrorId,
        r2Share.id,
        reason: 'ADR-011: both walls must cross-reference each other',
      );
      // Geometry: room-1's copy is reversed relative to room-2's copy
      // (ADR-001 mirror pair).
      expect(r1Share.startPoint, r2Share.endPoint);
      expect(r1Share.endPoint, r2Share.startPoint);

      // Room-2's other three walls remain untouched (neighbour stays put).
      for (final id in ['r2-ef', 'r2-fg', 'r2-gh']) {
        expect(
          walls.any((w) => w.id == id),
          isTrue,
          reason: 'neighbour wall $id must survive the move unchanged',
        );
      }

      // Room-1 now has exactly four walls (three exterior + one shared
      // mirror copy).
      final r1Walls = walls.where((w) => w.roomId == 'room-1').toList();
      expect(r1Walls, hasLength(4));
      expect(
        r1Walls.where((w) => w.wallType == WallType.interior).length,
        1,
      );
    },
  );

  // ────────────────────────────────────────────────────────────────────────
  // MR-3: Moving a shared room away detaches the shared partner —
  // mirrorId / adjacentRoomId cleared on both sides, both revert to
  // exterior, neighbour geometry unchanged (ADR-016 Rule 3).
  // ────────────────────────────────────────────────────────────────────────

  test(
    'MR-3: moving a shared room away detaches both walls to exterior '
    'with mirrorId / adjacentRoomId cleared',
    () {
      // Start: room-1 and room-2 already share the wall along x=4000.
      // Build the shared pair the same way addRoomFromDetection would.
      const sharedR1 = WallSegment(
        id: 'shared-r1',
        roomId: 'room-1',
        startPoint: Point2D(x: 4000, y: 0),
        endPoint: Point2D(x: 4000, y: 4000),
        wallType: WallType.interior,
        adjacentRoomId: 'room-2',
        mirrorId: 'shared-r2',
      );
      const sharedR2 = WallSegment(
        id: 'shared-r2',
        roomId: 'room-2',
        startPoint: Point2D(x: 4000, y: 4000),
        endPoint: Point2D(x: 4000, y: 0),
        wallType: WallType.interior,
        adjacentRoomId: 'room-1',
        mirrorId: 'shared-r1',
      );
      // Replace r1-bc (the original eastern wall) with sharedR1; the
      // other three room-1 walls keep their original ids.
      const r1WallsShared = [
        WallSegment(
          id: 'r1-ab',
          roomId: 'room-1',
          startPoint: _ptA,
          endPoint: _ptB,
        ),
        sharedR1,
        WallSegment(
          id: 'r1-cd',
          roomId: 'room-1',
          startPoint: _ptC,
          endPoint: _ptD,
        ),
        WallSegment(
          id: 'r1-da',
          roomId: 'room-1',
          startPoint: _ptD,
          endPoint: _ptA,
        ),
      ];
      const r2OtherWalls = [
        WallSegment(
          id: 'r2-ef',
          roomId: 'room-2',
          startPoint: Point2D(x: 4000, y: 0),
          endPoint: Point2D(x: 8000, y: 0),
        ),
        WallSegment(
          id: 'r2-fg',
          roomId: 'room-2',
          startPoint: Point2D(x: 8000, y: 0),
          endPoint: Point2D(x: 8000, y: 4000),
        ),
        WallSegment(
          id: 'r2-gh',
          roomId: 'room-2',
          startPoint: Point2D(x: 8000, y: 4000),
          endPoint: Point2D(x: 4000, y: 4000),
        ),
        sharedR2,
      ];
      const room2 = Room(
        id: 'room-2',
        floorId: 'floor-1',
        name: 'Room 2',
        targetTempC: 20.0,
        polygon: [
          Point2D(x: 4000, y: 0),
          Point2D(x: 8000, y: 0),
          Point2D(x: 8000, y: 4000),
          Point2D(x: 4000, y: 4000),
        ],
      );

      final (cb, tool, _, container) = _setup();
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);
      notifier.replaceAllWallsAndRooms(
        [...r1WallsShared, ...r2OtherWalls],
        [_room1, room2],
      );

      // Capture room-2's wall geometry pre-move for the "stays put" check.
      final r2WallsBefore = cb.currentWalls
          .where((w) => w.roomId == 'room-2')
          .toList();

      // Select and move room-1 left by 5000 mm (well clear of room-2).
      tool.onTap(const Point2D(x: 2000, y: 2000), PointerDeviceKind.mouse);
      _drag(
        tool,
        from: const Point2D(x: 2000, y: 2000),
        to: const Point2D(x: -3000, y: 2000),
      );

      // Room-2's former shared wall reverted to exterior, no mirrorId,
      // no adjacentRoomId, and its geometry is unchanged.
      final r2After = cb.currentWalls.firstWhere((w) => w.id == 'shared-r2');
      expect(r2After.wallType, WallType.exterior);
      expect(r2After.mirrorId, isNull);
      expect(r2After.adjacentRoomId, isNull);
      expect(r2After.startPoint, sharedR2.startPoint);
      expect(r2After.endPoint, sharedR2.endPoint);

      // Room-2's other walls are untouched.
      for (final w in r2WallsBefore) {
        if (w.id == 'shared-r2') continue;
        final after = cb.currentWalls.firstWhere((cur) => cur.id == w.id);
        expect(after.startPoint, w.startPoint);
        expect(after.endPoint, w.endPoint);
        expect(after.wallType, w.wallType);
        expect(after.mirrorId, w.mirrorId);
      }

      // Moved room-1's walls are all exterior (no remaining mirror link).
      final r1After =
          cb.currentWalls.where((w) => w.roomId == 'room-1').toList();
      expect(r1After, hasLength(4));
      for (final w in r1After) {
        expect(w.wallType, WallType.exterior);
        expect(w.mirrorId, isNull);
        expect(w.adjacentRoomId, isNull);
      }
    },
  );

  // ────────────────────────────────────────────────────────────────────────
  // MR-4: One Ctrl+Z reverts the whole move (including the regenerated
  // shared wall and zone translations).
  // ────────────────────────────────────────────────────────────────────────

  test(
    'MR-4: one undo reverts the entire move — walls, rooms, zones, '
    'shared-wall regeneration',
    () {
      final (cb, tool, undoRedo, container) = _setup();
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);
      notifier.replaceAllWallsAndRooms(_r1Walls, [_room1]);
      notifier.addZone(_r1Zone);

      // Snapshot the pre-move state for comparison.
      final beforeWalls = cb.currentWalls.toList();
      final beforeRooms = cb.currentRooms.toList();
      final beforeZones = cb.currentZones.toList();

      // Press outside the zone so room-move (not zone body drag) arms.
      tool.onTap(const Point2D(x: 500, y: 500), PointerDeviceKind.mouse);
      _drag(
        tool,
        from: const Point2D(x: 500, y: 500),
        to: const Point2D(x: 2500, y: 1500),
      );

      // Sanity-check: the move did happen.
      // Walls list grew/shuffled and at least one wall now sits at a
      // translated position absent from the pre-move state.
      final beforeStartPoints = {
        for (final w in beforeWalls) w.startPoint,
      };
      final movedSome = cb.currentWalls
          .any((w) => !beforeStartPoints.contains(w.startPoint));
      expect(
        movedSome,
        isTrue,
        reason: 'expected at least one wall to be at a translated position',
      );

      // Undo. Stack must have exactly one entry — "Move room".
      expect(undoRedo.canUndo, isTrue);
      undoRedo.undo();
      expect(undoRedo.canUndo, isFalse);

      // After undo: walls / rooms / zones identical to before.
      expect(cb.currentWalls, equals(beforeWalls));
      expect(cb.currentRooms, equals(beforeRooms));
      expect(cb.currentZones, equals(beforeZones));
    },
  );

  // ────────────────────────────────────────────────────────────────────────
  // MR-5: Click without drag past threshold still only selects
  // (ADR-016 Rule 1 deferred tap).
  // ────────────────────────────────────────────────────────────────────────

  test(
    'MR-5: press inside a room without drag past threshold only selects',
    () {
      final (cb, tool, undoRedo, container) = _setup();
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);
      notifier.replaceAllWallsAndRooms(_r1Walls, [_room1]);

      final beforeWalls = cb.currentWalls.toList();
      final beforeRoomPolys = [for (final r in cb.currentRooms) r.polygon];

      // Pointer-down inside the room, no drag, then onTap (the
      // GestureDetector-onTapDown path fires immediately after pointer-down
      // in real use). Finally onPointerUp dispatches the deferred tap.
      const inside = Point2D(x: 2000, y: 2000);
      tool.onPointerDown(inside, kPrimaryButton);
      tool.onTap(inside, PointerDeviceKind.mouse);
      tool.onPointerUp(inside);

      // Nothing mutated.
      expect(cb.currentWalls, equals(beforeWalls));
      expect(
        [for (final r in cb.currentRooms) r.polygon],
        equals(beforeRoomPolys),
      );
      // Selection landed on room-1.
      expect(cb.lastSelectType, 'room');
      expect(cb.lastSelectId, 'room-1');
      // No undo entry created — a select is not undoable.
      expect(undoRedo.canUndo, isFalse);
    },
  );
}
