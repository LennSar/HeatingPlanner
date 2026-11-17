// Unit-style tests for SelectTool — agent-test.md §6.2.
//
// SelectTool is exercised directly via a stub EditorCallbacks,
// following the same pattern as wall_draw_tool_test.dart.
//
// Covered scenarios:
//   ST-1   Tapping a wall selects it  → selectElement('wall', id) called.
//   ST-2   Tapping empty space clears → selectElement(null, null) called.
//   ST-3   Tapping inside a zone selects it → selectElement('zone', id).
//   ST-4   Delete key with a circuit selected → circuit removed from list.
//   ST-5   Delete key with nothing selected → no exception, no state change.
//
// ADR-012 (Ctrl+endpoint rectangle reshape):
//   ST-RR-1  rectangleCorners returns 4 corners for an axis-aligned rect.
//   ST-RR-2  rectangleCorners rejects rooms with 5 walls.
//   ST-RR-3  rectangleCorners rejects non-axis-aligned walls.
//   ST-RR-4  identifyRectCornersAroundDrag for each of the 4 corner positions.
//   ST-RR-5  Ctrl+drag commits 4 wall updates atomically.
//   ST-RR-6  Snap pipeline at onDragEnd snaps the cursor to the world grid.
//   ST-RR-7  Min-dimension rejection — < 100 mm dim leaves walls unchanged.
//   ST-RR-8  Mid-drag Ctrl-release does NOT switch modes (still reshapes).
//   ST-RR-9  Shift held during endpoint drag is a no-op.
//   ST-RR-10 Shared-wall mirror sync of all 4 walls (via real provider).

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/pipe_layout_engine.dart';
import 'package:heating_planner/calculation/providers/pipe_layout_providers.dart';
// Drift generates data classes that collide with our freezed models.
// Hide every name we use from the freezed/model side.
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
import 'package:heating_planner/data/database/daos/building_dao.dart';
import 'package:heating_planner/data/database/daos/heating_dao.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/l10n/app_localizations_en.dart';
import 'package:heating_planner/repositories/building_repository.dart'
    show buildingDaoProvider;
import 'package:heating_planner/repositories/heating_repository.dart'
    show heatingDaoProvider;
import 'package:heating_planner/ui/canvas/painters/interaction_data.dart';
import 'package:heating_planner/ui/canvas/tools/editor_callbacks.dart';
import 'package:heating_planner/ui/canvas/tools/select_tool.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Stub EditorCallbacks ─────────────────────────────────────────────────────

class _StubCallbacks implements EditorCallbacks {
  // ST-4 deletes a circuit, which now reads a localised label for the
  // undo entry. Return a real EN instance so the command can resolve
  // it without a surrounding widget tree.
  @override
  final AppLocalizations l10n = AppLocalizationsEn();

  final List<WallSegment> _walls;
  final List<Room> _rooms;
  final List<HeatingZone> _zones;
  final List<HeatingCircuit> _circuits;

  // Last selectElement call: null if (null, null), or (type, id).
  String? lastSelectedType;
  String? lastSelectedId;
  bool selectCalledWithNull = false;

  _StubCallbacks({
    List<WallSegment>? walls,
    List<Room>? rooms,
    List<HeatingZone>? zones,
    List<HeatingCircuit>? circuits,
  }) : _walls = List<WallSegment>.of(walls ?? const []),
       _rooms = List<Room>.of(rooms ?? const []),
       _zones = List<HeatingZone>.of(zones ?? const []),
       _circuits = List<HeatingCircuit>.of(circuits ?? const []);

  @override
  List<WallSegment> get currentWalls => List.unmodifiable(_walls);
  @override
  List<Room> get currentRooms => List.unmodifiable(_rooms);
  @override
  List<HeatingZone> get currentZones => List.unmodifiable(_zones);
  @override
  List<HeatingCircuit> get currentCircuits => List.unmodifiable(_circuits);

  @override
  void selectElement(String? type, String? id) {
    if (type == null || id == null) {
      selectCalledWithNull = true;
      lastSelectedType = null;
      lastSelectedId = null;
    } else {
      selectCalledWithNull = false;
      lastSelectedType = type;
      lastSelectedId = id;
    }
  }

  @override
  void removeCircuit(String circuitId) {
    _circuits.removeWhere((c) => c.id == circuitId);
  }

  @override
  void updateZone(HeatingZone zone) {
    final idx = _zones.indexWhere((z) => z.id == zone.id);
    if (idx >= 0) _zones[idx] = zone;
  }

  // Transient variants delegate to the persisting ones so this stub's
  // observable state matches the pre-debounce behaviour.
  @override
  void updateWallTransient(WallSegment wall) => updateWall(wall);
  @override
  void updateRoomTransient(Room room) => updateRoom(room);
  @override
  void updateZoneTransient(HeatingZone zone) => updateZone(zone);
  @override
  void updateCircuitTransient(HeatingCircuit circuit) => updateCircuit(circuit);
  @override
  void updateWindowTransient(WindowElement window) => updateWindow(window);
  @override
  void updateDoorTransient(Door door) => updateDoor(door);
  @override
  void updateDistributorTransient(Distributor distributor) =>
      updateDistributor(distributor);

  @override
  void showToast(String message) => _toasts.add(message);
  @override
  void replaceAllWalls(List<WallSegment> walls) {
    _walls
      ..clear()
      ..addAll(walls);
  }

  /// Last context-menu request received via [requestZoneContextMenu].
  /// ADR-018 ST-S1 / ST-S2 / ST-S3 / ST-S4 / ST-S5 inspect this to verify
  /// menu state and to drive the user-selected callbacks.
  ZoneContextMenuRequest? lastContextMenuRequest;

  @override
  void requestZoneContextMenu(ZoneContextMenuRequest request) {
    lastContextMenuRequest = request;
  }

  // Toast collector (ADR-018 ST-S4 verifies the too-small toast fires).
  final List<String> _toasts = [];
  List<String> get toasts => List.unmodifiable(_toasts);

  // ---- Unused stubs ----
  @override
  void commitWall(WallSegment wall) {}
  @override
  WallSegment commitWallWithSplit(
    WallSegment wall, {
    bool splitNewWall = true,
  }) => wall;
  @override
  void updateWall(WallSegment wall) {}
  @override
  void removeWall(String wallId) {}
  @override
  void destroyRoom(String roomId) {}
  @override
  void destroyRoomCascade(String roomId) {}
  @override
  void replaceAllForRoomCascade(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
    List<WindowElement> windows,
    List<Door> doors,
  ) {}
  @override
  void restoreRoom(Room room, List<String> wallIds) {}
  @override
  void updateRoom(Room room) {}
  @override
  void replaceAllWallsAndRooms(List<WallSegment> walls, List<Room> rooms) {}
  @override
  void replaceAllWallsRoomsZones(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
  ) {
    _walls
      ..clear()
      ..addAll(walls);
    _rooms
      ..clear()
      ..addAll(rooms);
    _zones
      ..clear()
      ..addAll(zones);
  }

  @override
  void addRoomFromDetection({
    required Room room,
    required List<String> wallIds,
    Map<String, WallSegment>? movedSideProperties,
  }) {}
  @override
  void commitWindow(WindowElement window) {}
  @override
  void updateWindow(WindowElement window) {}
  @override
  void removeWindow(String windowId) {}
  @override
  void commitDoor(Door door) {}
  @override
  void updateDoor(Door door) {}
  @override
  void removeDoor(String doorId) {}
  @override
  void commitDistributor(Distributor distributor) {}
  @override
  void updateDistributor(Distributor distributor) {}
  @override
  void removeDistributor() {}
  @override
  Distributor? get currentDistributor => null;
  @override
  void requestDistributorReplaceDialog({
    required void Function() onMove,
    required void Function() onReplace,
  }) {}
  @override
  void requestDistributorDeleteDialog({required void Function() onConfirmed}) {}
  @override
  void commitCircuit(HeatingCircuit circuit) => _circuits.add(circuit);
  @override
  void updateCircuit(HeatingCircuit circuit) {
    final i = _circuits.indexWhere((c) => c.id == circuit.id);
    if (i >= 0) _circuits[i] = circuit;
  }

  @override
  void clearAllCircuits() => _circuits.clear();
  @override
  void commitZone(HeatingZone zone) => _zones.add(zone);
  @override
  void removeZone(String zoneId) => _zones.removeWhere((z) => z.id == zoneId);
  @override
  String get currentFloorId => 'floor-1';
  @override
  String get defaultTubeTypeId => 'tube-1';
  @override
  String get defaultWallTubeTypeId => 'tube-1';
  @override
  String get defaultFlooringMaterialId => 'mat-1';
  @override
  void requestRoomDialog(
    List<Point2D> polygon,
    List<String> wallIds, {
    void Function(List<WallSegment>, List<Room>)? onCreated,
  }) {}
  @override
  List<WindowElement> get currentWindows => const [];
  @override
  List<Door> get currentDoors => const [];
  @override
  double get currentZoom => 1.0;
  @override
  double get currentGridSpacingMm => 100.0;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

SelectTool _makeTool(EditorCallbacks cb) => SelectTool(
  callbacks: cb,
  onStateChanged: () {},
  undoRedo: UndoRedoService(),
);

// A horizontal wall from (0,0) to (5000,0).
const _testWall = WallSegment(
  id: 'wall-1',
  roomId: '',
  startPoint: Point2D(x: 0, y: 0),
  endPoint: Point2D(x: 5000, y: 0),
);

// A zone polygon: 1000×1000 mm square at (1000,1000).
const _zonePolygon = [
  Point2D(x: 1000, y: 1000),
  Point2D(x: 2000, y: 1000),
  Point2D(x: 2000, y: 2000),
  Point2D(x: 1000, y: 2000),
];

const _testZone = HeatingZone(
  id: 'zone-1',
  roomId: 'room-1',
  polygon: _zonePolygon,
  tubeSpacingMm: 150,
  tubeTypeId: 'tube-1',
  flooringMaterialId: 'mat-1',
);

// A circuit whose supply route passes through (3000, 3000)→(4000, 3000).
const _testCircuit = HeatingCircuit(
  id: 'circuit-1',
  distributorId: 'dist-1',
  heatingZoneId: 'zone-1',
  supplyRoutePath: [Point2D(x: 3000, y: 3000), Point2D(x: 4000, y: 3000)],
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // The rect-reshape gate (ADR-012) consults
  // HardwareKeyboard.instance.logicalKeysPressed at drag-start to
  // catch missed key-up events. That class requires the binding to
  // be initialized — ensure it once for the whole file.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ST-1 ────────────────────────────────────────────────────────────────────

  test('ST-1: tapping a wall calls selectElement("wall", wallId)', () {
    final cb = _StubCallbacks(walls: [_testWall]);
    final tool = _makeTool(cb);

    // Tap on the wall's midpoint (2500, 0) — within the 100 mm threshold.
    tool.onTap(const Point2D(x: 2500, y: 0), PointerDeviceKind.mouse);

    expect(cb.lastSelectedType, 'wall');
    expect(cb.lastSelectedId, 'wall-1');
  });

  // ST-2 ────────────────────────────────────────────────────────────────────

  test('ST-2: tapping empty space calls selectElement(null, null)', () {
    final cb = _StubCallbacks(walls: [_testWall]);
    final tool = _makeTool(cb);

    // Far from any wall (10 m away from the wall at y=0).
    tool.onTap(const Point2D(x: 2500, y: 10000), PointerDeviceKind.mouse);

    expect(cb.selectCalledWithNull, isTrue);
  });

  // ST-3 ────────────────────────────────────────────────────────────────────

  test('ST-3: tapping inside a zone calls selectElement("zone", zoneId)', () {
    // Also provide the room so the room polygon does not shadow the zone.
    const roomPolygon = [
      Point2D(x: 0, y: 0),
      Point2D(x: 5000, y: 0),
      Point2D(x: 5000, y: 5000),
      Point2D(x: 0, y: 5000),
    ];
    const room = Room(
      id: 'room-1',
      floorId: 'floor-1',
      name: 'Test Room',
      targetTempC: 20.0,
      polygon: roomPolygon,
    );
    final cb = _StubCallbacks(zones: [_testZone], rooms: [room]);
    final tool = _makeTool(cb);

    // Tap the zone centre (1500, 1500).
    tool.onTap(const Point2D(x: 1500, y: 1500), PointerDeviceKind.mouse);

    expect(cb.lastSelectedType, 'zone');
    expect(cb.lastSelectedId, 'zone-1');
  });

  // ST-4 ────────────────────────────────────────────────────────────────────

  test('ST-4: Delete with a circuit selected removes the circuit', () {
    final cb = _StubCallbacks(circuits: [_testCircuit]);
    final tool = _makeTool(cb);

    // Tap a point on the circuit's supply route (midpoint 3500, 3000).
    tool.onTap(const Point2D(x: 3500, y: 3000), PointerDeviceKind.mouse);
    expect(cb.lastSelectedType, 'circuit');

    // Fire onDelete — simulates the Delete key via toolDeleteProvider.
    tool.onDelete();

    expect(cb.currentCircuits, isEmpty);
  });

  // ST-5 ────────────────────────────────────────────────────────────────────

  test('ST-5: Delete with nothing selected does not throw', () {
    final cb = _StubCallbacks();
    final tool = _makeTool(cb);

    // No selection → onDelete is a no-op.
    expect(() => tool.onDelete(), returnsNormally);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // ADR-012 — Ctrl + endpoint-handle rectangle reshape
  // ────────────────────────────────────────────────────────────────────────────

  group('ADR-012 rectangleCorners eligibility', () {
    // A 3000 × 2000 mm axis-aligned rectangle from (0,0) to (3000,2000).
    final rectWalls = <WallSegment>[
      const WallSegment(
        id: 'top',
        roomId: 'r',
        startPoint: Point2D(x: 0, y: 0),
        endPoint: Point2D(x: 3000, y: 0),
      ),
      const WallSegment(
        id: 'right',
        roomId: 'r',
        startPoint: Point2D(x: 3000, y: 0),
        endPoint: Point2D(x: 3000, y: 2000),
      ),
      const WallSegment(
        id: 'bottom',
        roomId: 'r',
        startPoint: Point2D(x: 3000, y: 2000),
        endPoint: Point2D(x: 0, y: 2000),
      ),
      const WallSegment(
        id: 'left',
        roomId: 'r',
        startPoint: Point2D(x: 0, y: 2000),
        endPoint: Point2D(x: 0, y: 0),
      ),
    ];

    test('ST-RR-1: 4 axis-aligned walls → returns 4 corners', () {
      final corners = SelectTool.rectangleCorners(rectWalls);
      expect(corners, isNotNull);
      expect(corners!, hasLength(4));
      // Distinct x-values {0, 3000} and distinct y-values {0, 2000}.
      final xs = corners.map((c) => c.x).toSet();
      final ys = corners.map((c) => c.y).toSet();
      expect(xs, {0.0, 3000.0});
      expect(ys, {0.0, 2000.0});
    });

    test('ST-RR-2: 5 walls → null (not a rectangle)', () {
      final fiveWalls = <WallSegment>[
        ...rectWalls,
        const WallSegment(
          id: 'extra',
          roomId: 'r',
          startPoint: Point2D(x: 1500, y: 1000),
          endPoint: Point2D(x: 2000, y: 1000),
        ),
      ];
      expect(SelectTool.rectangleCorners(fiveWalls), isNull);
    });

    test('ST-RR-3: diagonal (non-axis-aligned) wall → null', () {
      // Replace the top edge with a diagonal one.
      final diagWalls = <WallSegment>[
        const WallSegment(
          id: 'diag',
          roomId: 'r',
          startPoint: Point2D(x: 0, y: 0),
          endPoint: Point2D(x: 3000, y: 500),
        ),
        rectWalls[1],
        rectWalls[2],
        rectWalls[3],
      ];
      expect(SelectTool.rectangleCorners(diagWalls), isNull);
    });
  });

  group('ADR-012 identifyRectCornersAroundDrag', () {
    const tl = Point2D(x: 0, y: 0);
    const tr = Point2D(x: 3000, y: 0);
    const br = Point2D(x: 3000, y: 2000);
    const bl = Point2D(x: 0, y: 2000);
    final corners = [tl, tr, br, bl];

    test('ST-RR-4a: dragging top-left → diagonal anchor is bottom-right', () {
      final r = SelectTool.identifyRectCornersAroundDrag(corners, tl);
      expect(r, isNotNull);
      expect(r!.anchor, br);
      // xAdj shares dragCorner's x (= tl.x = 0) → bl (0, 2000).
      expect(r.xAdj, bl);
      // yAdj shares dragCorner's y (= tl.y = 0) → tr (3000, 0).
      expect(r.yAdj, tr);
    });

    test('ST-RR-4b: dragging top-right → diagonal anchor is bottom-left', () {
      final r = SelectTool.identifyRectCornersAroundDrag(corners, tr);
      expect(r, isNotNull);
      expect(r!.anchor, bl);
      expect(r.xAdj, br); // shares x=3000
      expect(r.yAdj, tl); // shares y=0
    });

    test('ST-RR-4c: dragging bottom-right → diagonal anchor is top-left', () {
      final r = SelectTool.identifyRectCornersAroundDrag(corners, br);
      expect(r, isNotNull);
      expect(r!.anchor, tl);
      expect(r.xAdj, tr); // shares x=3000
      expect(r.yAdj, bl); // shares y=2000
    });

    test('ST-RR-4d: dragging bottom-left → diagonal anchor is top-right', () {
      final r = SelectTool.identifyRectCornersAroundDrag(corners, bl);
      expect(r, isNotNull);
      expect(r!.anchor, tr);
      expect(r.xAdj, tl); // shares x=0
      expect(r.yAdj, br); // shares y=2000
    });
  });

  // ── Stub-callbacks based reshape tests ─────────────────────────────────────

  group('ADR-012 rect-reshape commit (stub callbacks)', () {
    // Standard 3000 × 2000 rectangle. Walls share endpoints exactly so
    // rectangleCorners returns 4 corners and identifyRectCornersAroundDrag
    // succeeds for each.
    const tl = Point2D(x: 0, y: 0);
    const tr = Point2D(x: 3000, y: 0);
    const br = Point2D(x: 3000, y: 2000);
    const bl = Point2D(x: 0, y: 2000);

    List<WallSegment> buildRectWalls(String roomId) => [
      WallSegment(id: 'w-top', roomId: roomId, startPoint: tl, endPoint: tr),
      WallSegment(id: 'w-right', roomId: roomId, startPoint: tr, endPoint: br),
      WallSegment(id: 'w-bottom', roomId: roomId, startPoint: br, endPoint: bl),
      WallSegment(id: 'w-left', roomId: roomId, startPoint: bl, endPoint: tl),
    ];

    Room buildRoom(String id) => Room(
      id: id,
      floorId: 'floor-1',
      name: 'R',
      polygon: const [tl, tr, br, bl],
    );

    test(
      'ST-RR-5: Ctrl-drag of top-left corner reshapes all 4 walls atomically',
      () {
        const roomId = 'room-1';
        final cb = _ReshapeStubCallbacks(
          walls: buildRectWalls(roomId),
          rooms: [buildRoom(roomId)],
        );
        final tool = _makeTool(cb);

        // Select the top wall by tapping on its midpoint.
        tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);
        expect(cb.lastSelectedType, 'wall');

        // Enter rect-reshape mode: Ctrl held, then pointer down on the
        // top-left endpoint handle of the selected top wall.
        tool.debugCtrlHeldOverride = true;
        tool.onPointerDown(tl, 1);

        // Drag the corner to (-1000, -500) — on-grid, no snap surprise.
        const newCorner = Point2D(x: -1000, y: -500);
        tool.onDragUpdate(newCorner);
        tool.onDragEnd(newCorner);

        // All 4 walls must still be present.
        expect(cb._walls, hasLength(4));

        // Collect distinct corner points across the 4 walls.
        final pts = <Point2D>{};
        for (final w in cb._walls) {
          pts.add(w.startPoint);
          pts.add(w.endPoint);
        }
        // Should now be the new rectangle: (-1000,-500), (3000,-500),
        // (3000,2000), (-1000,2000).
        expect(pts, hasLength(4));
        expect(pts.map((p) => p.x).toSet(), {-1000.0, 3000.0});
        expect(pts.map((p) => p.y).toSet(), {-500.0, 2000.0});

        // Room polygon must reflect the new rectangle.
        final room = cb._rooms.firstWhere((r) => r.id == roomId);
        expect(room.polygon.map((p) => p.x).toSet(), {-1000.0, 3000.0});
        expect(room.polygon.map((p) => p.y).toSet(), {-500.0, 2000.0});
      },
    );

    test('ST-RR-6: snap pipeline snaps the cursor to the world grid', () {
      const roomId = 'room-2';
      final cb = _ReshapeStubCallbacks(
        walls: buildRectWalls(roomId),
        rooms: [buildRoom(roomId)],
      );
      final tool = _makeTool(cb);

      // Select the top wall.
      tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);

      // Ctrl-drag top-left corner to an off-grid point. Grid is 100 mm,
      // so (1230, -1270) snaps to (1200, -1300).
      tool.debugCtrlHeldOverride = true;
      tool.onPointerDown(tl, 1);
      tool.onDragEnd(const Point2D(x: 1230, y: -1270));

      // The new dragged corner should be on-grid.
      final pts = <Point2D>{};
      for (final w in cb._walls) {
        pts.add(w.startPoint);
        pts.add(w.endPoint);
      }
      // The diagonal anchor (br = (3000, 2000)) must remain.
      expect(pts, contains(br));
      // The new dragged corner sits on (1200, -1300) post-grid-snap.
      expect(pts.map((p) => p.x).toSet(), {1200.0, 3000.0});
      expect(pts.map((p) => p.y).toSet(), {-1300.0, 2000.0});
    });

    test(
      'ST-RR-7: collapsing the rectangle below 100 mm rejects the commit',
      () {
        const roomId = 'room-3';
        final initialWalls = buildRectWalls(roomId);
        final cb = _ReshapeStubCallbacks(
          walls: initialWalls,
          rooms: [buildRoom(roomId)],
        );
        final tool = _makeTool(cb);

        tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);
        tool.debugCtrlHeldOverride = true;
        tool.onPointerDown(tl, 1);
        // Drag to nearly coincide with the diagonal anchor — height/width
        // collapse below the 100 mm threshold.
        tool.onDragEnd(const Point2D(x: 2950, y: 1950));

        // Walls must be unchanged (snapshot comparison via id+coords).
        for (final orig in initialWalls) {
          final cur = cb._walls.firstWhere((w) => w.id == orig.id);
          expect(cur.startPoint, orig.startPoint);
          expect(cur.endPoint, orig.endPoint);
        }
        // The rejection toast must have fired.
        expect(cb._toasts.last, contains('100'));
      },
    );

    test('ST-RR-8: mid-drag Ctrl-release still commits as rect-reshape', () {
      const roomId = 'room-4';
      final cb = _ReshapeStubCallbacks(
        walls: buildRectWalls(roomId),
        rooms: [buildRoom(roomId)],
      );
      final tool = _makeTool(cb);

      tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);
      tool.debugCtrlHeldOverride = true;
      tool.onPointerDown(tl, 1);

      // Release Ctrl mid-drag — mode must remain rect-reshape.
      tool.debugCtrlHeldOverride = false;

      tool.onDragEnd(const Point2D(x: -1000, y: -500));

      // Still 4 walls; rectangle reshaped despite Ctrl release.
      expect(cb._walls, hasLength(4));
      final xs = <double>{};
      final ys = <double>{};
      for (final w in cb._walls) {
        xs
          ..add(w.startPoint.x)
          ..add(w.endPoint.x);
        ys
          ..add(w.startPoint.y)
          ..add(w.endPoint.y);
      }
      expect(xs, {-1000.0, 3000.0});
      expect(ys, {-500.0, 2000.0});
    });

    test('ST-RR-9: Shift is a no-op — no new code path activated for it', () {
      // Shift has no API in SelectTool (no updateModifiers param). Verify
      // that absent Ctrl, a corner drag falls back to default endpoint
      // pivot — the diagonally opposite endpoint must NOT move.
      const roomId = 'room-5';
      final cb = _ReshapeStubCallbacks(
        walls: buildRectWalls(roomId),
        rooms: [buildRoom(roomId)],
      );
      final tool = _makeTool(cb);

      tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);
      // Ctrl NOT pressed (simulating Shift-only) — must fall back to
      // default endpoint drag.
      tool.onPointerDown(tl, 1);
      tool.onDragUpdate(const Point2D(x: -1000, y: -500));
      tool.onDragEnd(const Point2D(x: -1000, y: -500));

      // The diagonally opposite corner (br = 3000, 2000) must remain
      // unchanged on every wall — rect-reshape would have moved nothing
      // there either, but here we also verify that NO corner besides
      // the one connected to the dragged endpoint moved.
      final brStillPresent = cb._walls.any(
        (w) => w.startPoint == br || w.endPoint == br,
      );
      expect(brStillPresent, isTrue);
      // And the bottom-left corner (bl = 0, 2000) should be unchanged —
      // default endpoint drag only pivots the single wall, not all 4.
      final blStillPresent = cb._walls.any(
        (w) => w.startPoint == bl || w.endPoint == bl,
      );
      expect(blStillPresent, isTrue);
    });

    test('ST-RR-11: rect-reshape + undo + rect-reshape — second drag still '
        'engages rect-reshape (refreshes stale _selectedWall after undo)', () {
      // Regression for the "wall detaches after undo" bug. Sequence:
      //   1. Select top wall, Ctrl-drag top-left to a new corner — commits
      //      rect-reshape, pushes _RectReshapeCommand.
      //   2. Undo via UndoRedoService — state is restored, but the cached
      //      _selectedWall in SelectTool still carries post-reshape geometry.
      //   3. Ctrl-drag top-left again. If _selectedWall is not refreshed,
      //      the rect-reshape eligibility check fails (the stale endpoint
      //      doesn't match any corner of the restored rectangle), the tool
      //      falls through to default endpoint drag, _dragStartConnected is
      //      empty, and only the top wall moves while the other three stay
      //      put — the rectangle "detaches".
      const roomId = 'room-undo-redo';
      final initialWalls = buildRectWalls(roomId);
      final cb = _ReshapeStubCallbacks(
        walls: initialWalls,
        rooms: [buildRoom(roomId)],
      );
      final undoRedo = UndoRedoService();
      final tool = SelectTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: undoRedo,
      );

      // Select top wall.
      tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);

      // First reshape: drag top-left from (0,0) to (-1000,-500).
      tool.debugCtrlHeldOverride = true;
      tool.onPointerDown(tl, 1);
      tool.onDragEnd(const Point2D(x: -1000, y: -500));

      // Confirm the rectangle moved.
      final xsAfterFirst = <double>{};
      final ysAfterFirst = <double>{};
      for (final w in cb._walls) {
        xsAfterFirst
          ..add(w.startPoint.x)
          ..add(w.endPoint.x);
        ysAfterFirst
          ..add(w.startPoint.y)
          ..add(w.endPoint.y);
      }
      expect(xsAfterFirst, {-1000.0, 3000.0});
      expect(ysAfterFirst, {-500.0, 2000.0});

      // Undo.
      undoRedo.undo();
      // State must be back to the original rectangle.
      final xsAfterUndo = <double>{};
      final ysAfterUndo = <double>{};
      for (final w in cb._walls) {
        xsAfterUndo
          ..add(w.startPoint.x)
          ..add(w.endPoint.x);
        ysAfterUndo
          ..add(w.startPoint.y)
          ..add(w.endPoint.y);
      }
      expect(xsAfterUndo, {0.0, 3000.0});
      expect(ysAfterUndo, {0.0, 2000.0});

      // Second Ctrl-drag — must engage rect-reshape, not default
      // endpoint pivot. Drag the (now-restored) top-left corner to
      // (-500,-300).
      tool.onPointerDown(tl, 1);
      tool.onDragEnd(const Point2D(x: -500, y: -300));

      // All 4 walls must move: distinct x-values {-500, 3000} and
      // y-values {-300, 2000}.  If the bug had occurred, only the top
      // wall would have shifted and the corner set would still contain
      // 0.0 from the unmoved left/right/bottom walls.
      final xsAfterSecond = <double>{};
      final ysAfterSecond = <double>{};
      for (final w in cb._walls) {
        xsAfterSecond
          ..add(w.startPoint.x)
          ..add(w.endPoint.x);
        ysAfterSecond
          ..add(w.startPoint.y)
          ..add(w.endPoint.y);
      }
      expect(xsAfterSecond, {-500.0, 3000.0});
      expect(ysAfterSecond, {-300.0, 2000.0});
    });

    test('ST-RR-12: user scenario — non-Ctrl corner drag deforms the room; '
        'Ctrl+Z restores rectangle; subsequent Ctrl-drag rect-reshapes', () {
      // Reproduces the exact sequence the user described:
      //   1. Have a rectangular room.
      //   2. Drag a corner WITHOUT Ctrl → only that corner moves; the room
      //      becomes non-rectangular but remains a closed room.
      //   3. Ctrl+Z (undo) → rectangle restored to its original geometry.
      //   4. Drag the same corner WITH Ctrl → rect-reshape kicks in; all
      //      four corners reposition and the room remains an axis-aligned
      //      rectangle.
      const roomId = 'room-user-scenario';
      final cb = _ReshapeStubCallbacks(
        walls: buildRectWalls(roomId),
        rooms: [buildRoom(roomId)],
      );
      final undoRedo = UndoRedoService();
      final tool = SelectTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: undoRedo,
      );

      // Step 1: confirm the starting rectangle.
      {
        final xs = <double>{};
        final ys = <double>{};
        for (final w in cb._walls) {
          xs
            ..add(w.startPoint.x)
            ..add(w.endPoint.x);
          ys
            ..add(w.startPoint.y)
            ..add(w.endPoint.y);
        }
        expect(xs, {
          0.0,
          3000.0,
        }, reason: 'starting room must be a 3000×2000 rectangle');
        expect(ys, {
          0.0,
          2000.0,
        }, reason: 'starting room must be a 3000×2000 rectangle');
      }

      // Step 2: select the top wall, then drag the top-left corner WITHOUT
      // Ctrl from (0,0) to (-500, -300). Default endpoint pivot must move
      // ONLY the dragged corner and the single adjacent wall that shares
      // that endpoint; the diagonally opposite corner (3000, 2000) and the
      // far-side corners must stay put.
      tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);
      // Ctrl explicitly NOT held.
      tool.debugCtrlHeldOverride = false;
      tool.onPointerDown(tl, 1);
      tool.onDragUpdate(const Point2D(x: -500, y: -300));
      tool.onDragEnd(const Point2D(x: -500, y: -300));

      // The dragged corner must be at (-500, -300).
      final cornersAfterDeform = <Point2D>{};
      for (final w in cb._walls) {
        cornersAfterDeform.add(w.startPoint);
        cornersAfterDeform.add(w.endPoint);
      }
      expect(
        cornersAfterDeform.length,
        4,
        reason: 'room must still have exactly 4 distinct corners',
      );
      expect(
        cornersAfterDeform,
        contains(const Point2D(x: -500, y: -300)),
        reason: 'the dragged corner must be at the new position',
      );

      // The other three corners must be the original ones — the three
      // walls NOT connected to the moved endpoint stay in place.
      expect(
        cornersAfterDeform,
        contains(tr),
        reason: '(3000,0) must remain — top wall endPoint unchanged',
      );
      expect(
        cornersAfterDeform,
        contains(br),
        reason: '(3000,2000) must remain — diagonally opposite corner',
      );
      expect(
        cornersAfterDeform,
        contains(bl),
        reason: '(0,2000) must remain — left wall startPoint unchanged',
      );

      // The deformed room must NOT be a rectangle — three distinct
      // y-values is the signature of the diagonal corner break.
      final ysAfterDeform = cornersAfterDeform.map((p) => p.y).toSet();
      expect(
        ysAfterDeform.length,
        greaterThan(2),
        reason: 'after non-Ctrl drag the room must NOT be rectangular',
      );

      // The 4 walls must still form a closed chain (room remains a room).
      // We verify this by checking that every corner is touched by exactly
      // two distinct walls' endpoints.
      for (final corner in cornersAfterDeform) {
        final touching = cb._walls
            .where((w) => w.startPoint == corner || w.endPoint == corner)
            .toList();
        expect(
          touching,
          hasLength(2),
          reason: 'each corner $corner must connect exactly 2 walls',
        );
      }

      // Step 3: Ctrl+Z. The original rectangle must be restored.
      undoRedo.undo();
      final cornersAfterUndo = <Point2D>{};
      for (final w in cb._walls) {
        cornersAfterUndo.add(w.startPoint);
        cornersAfterUndo.add(w.endPoint);
      }
      expect(
        cornersAfterUndo,
        equals({tl, tr, br, bl}),
        reason: 'undo must restore the original four corners',
      );
      final xsAfterUndo = cornersAfterUndo.map((p) => p.x).toSet();
      final ysAfterUndo = cornersAfterUndo.map((p) => p.y).toSet();
      expect(xsAfterUndo, {0.0, 3000.0});
      expect(ysAfterUndo, {0.0, 2000.0});

      // Step 4: Ctrl-drag the same corner — rect-reshape this time.
      tool.debugCtrlHeldOverride = true;
      tool.onPointerDown(tl, 1);
      tool.onDragUpdate(const Point2D(x: -500, y: -300));
      tool.onDragEnd(const Point2D(x: -500, y: -300));

      final cornersAfterReshape = <Point2D>{};
      for (final w in cb._walls) {
        cornersAfterReshape.add(w.startPoint);
        cornersAfterReshape.add(w.endPoint);
      }
      // Rect-reshape: the room must still be an axis-aligned rectangle
      // with corners (-500,-300), (3000,-300), (3000,2000), (-500,2000).
      expect(cornersAfterReshape, hasLength(4));
      expect(
        cornersAfterReshape.map((p) => p.x).toSet(),
        {-500.0, 3000.0},
        reason: 'rect-reshape must leave exactly 2 distinct x-values',
      );
      expect(
        cornersAfterReshape.map((p) => p.y).toSet(),
        {-300.0, 2000.0},
        reason: 'rect-reshape must leave exactly 2 distinct y-values',
      );
    });

    test('ST-RR-13: a stranded cached _ctrlHeld (no override, no hardware key) '
        'does NOT engage rect-reshape — drag-start re-syncs from hardware', () {
      // This guards the exact symptom the user reported ("now it always
      // moves as a rectangular"): the cached `_ctrlHeld` flag is stuck
      // "on" because a Cmd-up event was swallowed during Cmd+Z. With
      // the live-hardware re-sync at drag-start, the gate now ignores
      // the stale cache and falls back to default endpoint pivot.
      const roomId = 'room-stuck-ctrl';
      final cb = _ReshapeStubCallbacks(
        walls: buildRectWalls(roomId),
        rooms: [buildRoom(roomId)],
      );
      final tool = _makeTool(cb);

      tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);

      // Strand the cached flag: pretend Cmd-down was processed but
      // Cmd-up was lost. `updateModifiers(ctrl: true)` mirrors the
      // canvas's ref.listen handler exactly.
      tool.updateModifiers(ctrl: true);
      // Debug override stays null → drag-start polls real hardware
      // (no keys pressed in unit-test isolate) and resets _ctrlHeld.
      expect(tool.debugCtrlHeldOverride, isNull);

      tool.onPointerDown(tl, 1);
      tool.onDragUpdate(const Point2D(x: -500, y: -300));
      tool.onDragEnd(const Point2D(x: -500, y: -300));

      // Default endpoint pivot must have run — only the dragged corner
      // moved; the diagonally opposite corner (3000, 2000) and the
      // far-side corners (3000, 0) and (0, 2000) stay put. Rect-reshape
      // would have moved ALL four corners onto two distinct x-/y-values
      // each — assert the room is now NON-rectangular.
      final corners = <Point2D>{};
      for (final w in cb._walls) {
        corners
          ..add(w.startPoint)
          ..add(w.endPoint);
      }
      expect(
        corners,
        contains(const Point2D(x: -500, y: -300)),
        reason: 'dragged corner must have moved',
      );
      expect(
        corners,
        contains(tr),
        reason: 'far top-right corner must stay put',
      );
      expect(
        corners,
        contains(br),
        reason: 'diagonally opposite corner must stay put',
      );
      expect(
        corners,
        contains(bl),
        reason: 'far bottom-left corner must stay put',
      );
      // Non-rectangular signature.
      expect(
        corners.map((p) => p.y).toSet().length,
        greaterThan(2),
        reason:
            'stuck _ctrlHeld must NOT engage rect-reshape — '
            'the room must end up non-rectangular',
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // ADR-027 — Keep-orientation wall-body translate (Shift / Ctrl + mid drag)
  // ────────────────────────────────────────────────────────────────────────────

  group('ADR-027 keep-orientation wall-body drag (stub callbacks)', () {
    // Standard 3000 × 2000 rectangle (same layout as the ADR-012 group).
    const tl = Point2D(x: 0, y: 0);
    const tr = Point2D(x: 3000, y: 0);
    const br = Point2D(x: 3000, y: 2000);
    const bl = Point2D(x: 0, y: 2000);

    List<WallSegment> buildRectWalls(String roomId) => [
      WallSegment(id: 'w-top', roomId: roomId, startPoint: tl, endPoint: tr),
      WallSegment(id: 'w-right', roomId: roomId, startPoint: tr, endPoint: br),
      WallSegment(id: 'w-bottom', roomId: roomId, startPoint: br, endPoint: bl),
      WallSegment(id: 'w-left', roomId: roomId, startPoint: bl, endPoint: tl),
    ];

    Room buildRoom(String id) => const Room(
      id: 'room-1',
      floorId: 'floor-1',
      name: 'R',
      polygon: [tl, tr, br, bl],
    );

    Set<Point2D> cornersOf(List<WallSegment> walls) {
      final pts = <Point2D>{};
      for (final w in walls) {
        pts
          ..add(w.startPoint)
          ..add(w.endPoint);
      }
      return pts;
    }

    test(
      'ADR-027-1: Ctrl + mid drag of the top wall keeps the room rectangular',
      () {
        final cb = _ReshapeStubCallbacks(
          walls: buildRectWalls('room-1'),
          rooms: [buildRoom('room-1')],
        );
        final tool = _makeTool(cb);

        // Select the top wall, then grab its mid handle (its midpoint).
        tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);
        tool.debugCtrlHeldOverride = true;
        tool.onPointerDown(const Point2D(x: 1500, y: 0), 1);

        // Drag diagonally: a 500 mm sideways component that MUST be ignored
        // and a 500 mm upward (perpendicular) component that moves the wall.
        tool.onDragUpdate(const Point2D(x: 2000, y: -500));
        tool.onDragEnd(const Point2D(x: 2000, y: -500));

        // Still an axis-aligned rectangle: only the top edge's y moved.
        final corners = cornersOf(cb._walls);
        expect(corners, hasLength(4));
        expect(
          corners.map((p) => p.x).toSet(),
          {0.0, 3000.0},
          reason: 'the sideways drag component must not slant the sides',
        );
        expect(corners.map((p) => p.y).toSet(), {-500.0, 2000.0});
      },
    );

    test('ADR-027-2: Shift alone also engages keep-orientation', () {
      final cb = _ReshapeStubCallbacks(
        walls: buildRectWalls('room-1'),
        rooms: [buildRoom('room-1')],
      );
      final tool = _makeTool(cb);

      tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);
      tool.debugShiftHeldOverride = true;
      tool.onPointerDown(const Point2D(x: 1500, y: 0), 1);
      tool.onDragUpdate(const Point2D(x: 2000, y: -500));
      tool.onDragEnd(const Point2D(x: 2000, y: -500));

      final corners = cornersOf(cb._walls);
      expect(corners.map((p) => p.x).toSet(), {0.0, 3000.0});
      expect(corners.map((p) => p.y).toSet(), {-500.0, 2000.0});
    });

    test(
      'ADR-027-3: without a modifier the same drag slants the side walls',
      () {
        final cb = _ReshapeStubCallbacks(
          walls: buildRectWalls('room-1'),
          rooms: [buildRoom('room-1')],
        );
        final tool = _makeTool(cb);

        // No Ctrl / Shift override → plain translate (both axes applied).
        tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);
        tool.onPointerDown(const Point2D(x: 1500, y: 0), 1);
        tool.onDragUpdate(const Point2D(x: 2000, y: -500));
        tool.onDragEnd(const Point2D(x: 2000, y: -500));

        // The left wall is no longer vertical — the room is non-rectangular.
        final left = cb._walls.firstWhere((w) => w.id == 'w-left');
        expect(
          (left.startPoint.x - left.endPoint.x).abs(),
          greaterThan(1.0),
          reason: 'default mid drag translates both axes, slanting the side',
        );
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // ADR-018 — Split zone via right-click context menu
  // ────────────────────────────────────────────────────────────────────────────

  group('ADR-018 SelectTool zone context menu', () {
    // 8 m × 6 m parent room so the zones below sit comfortably inside.
    const roomPolygon = [
      Point2D(x: 0, y: 0),
      Point2D(x: 8000, y: 0),
      Point2D(x: 8000, y: 6000),
      Point2D(x: 0, y: 6000),
    ];
    const parentRoom = Room(
      id: 'room-1',
      floorId: 'floor-1',
      name: 'Test Room',
      targetTempC: 20.0,
      polygon: roomPolygon,
    );

    // ST-S1 ────────────────────────────────────────────────────────────────

    test(
      'ST-S1: right-click on a rectangular zone shows enabled split items',
      () {
        // Rectangular zone 4000 × 2000.
        const rectZone = HeatingZone(
          id: 'zone-rect',
          roomId: 'room-1',
          polygon: [
            Point2D(x: 1000, y: 1000),
            Point2D(x: 5000, y: 1000),
            Point2D(x: 5000, y: 3000),
            Point2D(x: 1000, y: 3000),
          ],
          tubeTypeId: 'tube-1',
          flooringMaterialId: 'mat-1',
        );
        final cb = _StubCallbacks(rooms: const [parentRoom], zones: [rectZone]);
        final tool = _makeTool(cb);

        tool.onSecondaryTap(const Point2D(x: 3000, y: 2000));

        final req = cb.lastContextMenuRequest;
        expect(
          req,
          isNotNull,
          reason: 'right-click on a zone must request the menu',
        );
        expect(
          req!.showSplitItems,
          isTrue,
          reason: 'floor zones expose the split items',
        );
        expect(
          req.splitEnabled,
          isTrue,
          reason: 'rectangular zones enable the split items',
        );
      },
    );

    // ST-S2 ────────────────────────────────────────────────────────────────

    test(
      'ST-S2: right-click on a zone that cannot be cut in two shows disabled '
      'split items',
      () {
        // Open ring: no single vertical or horizontal cut yields two
        // pieces (ADR-037 Rule 1).
        const ringZone = HeatingZone(
          id: 'zone-ring',
          roomId: 'room-1',
          polygon: [
            Point2D(x: 1000, y: 1000),
            Point2D(x: 4000, y: 1000),
            Point2D(x: 4000, y: 2200),
            Point2D(x: 3000, y: 2200),
            Point2D(x: 3000, y: 2000),
            Point2D(x: 2000, y: 2000),
            Point2D(x: 2000, y: 3000),
            Point2D(x: 3000, y: 3000),
            Point2D(x: 3000, y: 2400),
            Point2D(x: 4000, y: 2400),
            Point2D(x: 4000, y: 4000),
            Point2D(x: 1000, y: 4000),
          ],
          tubeTypeId: 'tube-1',
          flooringMaterialId: 'mat-1',
        );
        final cb = _StubCallbacks(rooms: const [parentRoom], zones: [ringZone]);
        final tool = _makeTool(cb);

        tool.onSecondaryTap(const Point2D(x: 1500, y: 1500));

        final req = cb.lastContextMenuRequest;
        expect(req, isNotNull);
        expect(
          req!.showSplitItems,
          isTrue,
          reason: 'floor zones still expose the items, just disabled',
        );
        expect(
          req.splitEnabled,
          isFalse,
          reason: 'unsplittable shapes disable the split items',
        );
      },
    );

    // ST-S3 ────────────────────────────────────────────────────────────────

    test(
      'ST-S3: split vertically on a zone with a connected circuit assigns the '
      'circuitId to whichever child contains the pipe terminus',
      () {
        // 4000 × 2000 rectangle with a connected circuit whose supply
        // ends at (4500, 2000) — inside the RIGHT half (child B).
        const rectZone = HeatingZone(
          id: 'zone-rect',
          roomId: 'room-1',
          polygon: [
            Point2D(x: 1000, y: 1000),
            Point2D(x: 5000, y: 1000),
            Point2D(x: 5000, y: 3000),
            Point2D(x: 1000, y: 3000),
          ],
          tubeTypeId: 'tube-1',
          flooringMaterialId: 'mat-1',
          circuitId: 'circuit-1',
        );
        const circuit = HeatingCircuit(
          id: 'circuit-1',
          distributorId: 'dist-1',
          heatingZoneId: 'zone-rect',
          supplyRoutePath: [Point2D(x: 0, y: 2000), Point2D(x: 4500, y: 2000)],
        );
        final cb = _StubCallbacks(
          rooms: const [parentRoom],
          zones: [rectZone],
          circuits: const [circuit],
        );
        final tool = _makeTool(cb);

        tool.onSecondaryTap(const Point2D(x: 3000, y: 2000));
        final req = cb.lastContextMenuRequest!;

        // Invoke the menu item directly.
        req.onSplitVertically();

        // Parent removed, two children present.
        expect(cb.currentZones, hasLength(2));
        // Right half (x ∈ [3000, 5000]) should carry the circuit.
        final right = cb.currentZones.firstWhere(
          (z) => z.polygon.any((p) => p.x == 5000),
        );
        final left = cb.currentZones.firstWhere((z) => z.id != right.id);
        expect(
          right.circuitId,
          'circuit-1',
          reason: 'child containing the pipe terminus inherits the circuit',
        );
        expect(
          left.circuitId,
          isNull,
          reason: 'the other child renders as unconnected',
        );

        // Circuit's zone-FK now points at the inheriting child.
        expect(cb.currentCircuits.single.heatingZoneId, right.id);
      },
    );

    // ST-S4 ────────────────────────────────────────────────────────────────

    test(
      'ST-S4: split rejected with toast when either half would be < 100 mm',
      () {
        // 150 mm × 1000 mm rectangle — vertical split would give 75 mm
        // halves, below the 100 mm minimum.
        const tinyZone = HeatingZone(
          id: 'zone-tiny',
          roomId: 'room-1',
          polygon: [
            Point2D(x: 1000, y: 1000),
            Point2D(x: 1150, y: 1000),
            Point2D(x: 1150, y: 2000),
            Point2D(x: 1000, y: 2000),
          ],
          tubeTypeId: 'tube-1',
          flooringMaterialId: 'mat-1',
        );
        final cb = _StubCallbacks(rooms: const [parentRoom], zones: [tinyZone]);
        final tool = _makeTool(cb);

        tool.onSecondaryTap(const Point2D(x: 1050, y: 1500));
        cb.lastContextMenuRequest!.onSplitVertically();

        // Zone list unchanged.
        expect(cb.currentZones, hasLength(1));
        expect(cb.currentZones.single.id, tinyZone.id);
        // Toast fired.
        expect(cb.toasts, contains(cb.l10n.zone_splitTooSmallToast));
      },
    );

    // ST-S5 ────────────────────────────────────────────────────────────────

    test('ST-S5: Ctrl+Z after split restores the parent zone with its original '
        'circuitId and the circuit zone-FK', () {
      const rectZone = HeatingZone(
        id: 'zone-rect',
        roomId: 'room-1',
        polygon: [
          Point2D(x: 1000, y: 1000),
          Point2D(x: 5000, y: 1000),
          Point2D(x: 5000, y: 3000),
          Point2D(x: 1000, y: 3000),
        ],
        tubeTypeId: 'tube-1',
        flooringMaterialId: 'mat-1',
        circuitId: 'circuit-1',
      );
      const circuit = HeatingCircuit(
        id: 'circuit-1',
        distributorId: 'dist-1',
        heatingZoneId: 'zone-rect',
        supplyRoutePath: [Point2D(x: 0, y: 2000), Point2D(x: 4500, y: 2000)],
      );
      final cb = _StubCallbacks(
        rooms: const [parentRoom],
        zones: [rectZone],
        circuits: const [circuit],
      );
      final undoRedo = UndoRedoService();
      final tool = SelectTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: undoRedo,
      );

      tool.onSecondaryTap(const Point2D(x: 3000, y: 2000));
      cb.lastContextMenuRequest!.onSplitVertically();

      // Sanity: split happened.
      expect(cb.currentZones, hasLength(2));
      expect(cb.currentCircuits.single.heatingZoneId, isNot('zone-rect'));

      // Undo.
      expect(undoRedo.canUndo, isTrue);
      undoRedo.undo();

      expect(cb.currentZones, hasLength(1));
      expect(cb.currentZones.single.id, 'zone-rect');
      expect(
        cb.currentZones.single.circuitId,
        'circuit-1',
        reason: 'parent restored with its original circuitId',
      );
      expect(
        cb.currentCircuits.single.heatingZoneId,
        'zone-rect',
        reason: 'circuit zone-FK restored to the parent',
      );
    });
  });

  // ── ADR-037 Rule 5: linked zone-boundary drag ─────────────────────────────

  group('ADR-037 linked zone-boundary drag', () {
    const room = Room(
      id: 'room-1',
      floorId: 'floor-1',
      name: 'Test Room',
      targetTempC: 20.0,
      polygon: [
        Point2D(x: 0, y: 0),
        Point2D(x: 8000, y: 0),
        Point2D(x: 8000, y: 6000),
        Point2D(x: 0, y: 6000),
      ],
    );

    HeatingZone rect(String id, double x0, double y0, double x1, double y1) =>
        HeatingZone(
          id: id,
          roomId: 'room-1',
          polygon: [
            Point2D(x: x0, y: y0),
            Point2D(x: x1, y: y0),
            Point2D(x: x1, y: y1),
            Point2D(x: x0, y: y1),
          ],
          tubeTypeId: 'tube-1',
          flooringMaterialId: 'mat-1',
        );

    double minX(HeatingZone z) =>
        z.polygon.map((p) => p.x).reduce((a, b) => a < b ? a : b);
    double maxX(HeatingZone z) =>
        z.polygon.map((p) => p.x).reduce((a, b) => a > b ? a : b);
    HeatingZone zone(_StubCallbacks cb, String id) =>
        cb.currentZones.firstWhere((z) => z.id == id);

    test('ST-B1: dragging the shared edge of two unselected zones grows one '
        'and shrinks the other; one undo restores both', () {
      final cb = _StubCallbacks(
        rooms: const [room],
        zones: [
          rect('left', 1000, 1000, 3000, 3000),
          rect('right', 3000, 1000, 5000, 3000),
        ],
      );
      final undoRedo = UndoRedoService();
      final tool = SelectTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: undoRedo,
      );

      // No selection, no modifier: press on the divider and drag right.
      tool.onPointerDown(const Point2D(x: 3000, y: 2000), kPrimaryButton);
      tool.onDragUpdate(const Point2D(x: 3520, y: 2100));
      tool.onDragEnd(const Point2D(x: 3520, y: 2100));

      // Grid-snapped to 3500; both zones follow the same line.
      expect(maxX(zone(cb, 'left')), 3500.0);
      expect(minX(zone(cb, 'right')), 3500.0);
      expect(minX(zone(cb, 'left')), 1000.0);
      expect(maxX(zone(cb, 'right')), 5000.0);

      expect(undoRedo.canUndo, isTrue);
      undoRedo.undo();
      expect(maxX(zone(cb, 'left')), 3000.0);
      expect(minX(zone(cb, 'right')), 3000.0);
      expect(
        undoRedo.canUndo,
        isFalse,
        reason: 'the whole boundary move is one undo entry',
      );
    });

    test('ST-B2: the boundary stops before a zone would get thinner than '
        '100 mm', () {
      final cb = _StubCallbacks(
        rooms: const [room],
        zones: [
          rect('left', 1000, 1000, 3000, 3000),
          rect('right', 3000, 1000, 5000, 3000),
        ],
      );
      final tool = _makeTool(cb);

      tool.onPointerDown(const Point2D(x: 3000, y: 2000), kPrimaryButton);
      tool.onDragUpdate(const Point2D(x: 4800, y: 2000));
      // 4950 would leave the right zone 50 mm wide — ignored.
      tool.onDragUpdate(const Point2D(x: 4960, y: 2000));
      tool.onDragEnd(const Point2D(x: 4960, y: 2000));

      expect(maxX(zone(cb, 'left')), 4800.0);
      expect(minX(zone(cb, 'right')), 4800.0);
    });

    test('ST-B3: a divider shared with two stacked neighbours moves all three '
        'zones, whichever edge is grabbed', () {
      final cb = _StubCallbacks(
        rooms: const [room],
        zones: [
          rect('left', 1000, 1000, 3000, 5000),
          rect('top-right', 3000, 1000, 5000, 3000),
          rect('bottom-right', 3000, 3000, 5000, 5000),
        ],
      );
      final tool = _makeTool(cb);

      // Grab the short edge of the top-right zone.
      tool.onPointerDown(const Point2D(x: 3000, y: 1500), kPrimaryButton);
      tool.onDragUpdate(const Point2D(x: 2500, y: 1500));
      tool.onDragEnd(const Point2D(x: 2500, y: 1500));

      expect(maxX(zone(cb, 'left')), 2500.0);
      expect(minX(zone(cb, 'top-right')), 2500.0);
      expect(minX(zone(cb, 'bottom-right')), 2500.0);
    });

    test('ST-B4: an edge of a lone unselected zone is not a drag target, but '
        'becomes one once the zone is selected', () {
      final cb = _StubCallbacks(
        rooms: const [room],
        zones: [rect('only', 1000, 1000, 3000, 3000)],
      );
      final tool = _makeTool(cb);

      tool.onPointerMove(const Point2D(x: 3000, y: 2000));
      expect(tool.zoneEdgeResizeNormal, isNull);

      // Select the zone with a click in its interior.
      tool.onPointerDown(const Point2D(x: 2000, y: 2000), kPrimaryButton);
      tool.onTap(const Point2D(x: 2000, y: 2000), PointerDeviceKind.mouse);
      tool.onPointerUp(const Point2D(x: 2000, y: 2000));
      expect(cb.lastSelectedId, 'only');

      tool.onPointerMove(const Point2D(x: 3000, y: 2000));
      expect(tool.zoneEdgeResizeNormal, isNotNull);

      tool.onPointerDown(const Point2D(x: 3000, y: 2000), kPrimaryButton);
      tool.onDragUpdate(const Point2D(x: 3400, y: 2000));
      tool.onDragEnd(const Point2D(x: 3400, y: 2000));
      expect(maxX(zone(cb, 'only')), 3400.0);
      expect(minX(zone(cb, 'only')), 1000.0);
    });

    test('ST-B5: Escape during a boundary drag restores every zone', () {
      final cb = _StubCallbacks(
        rooms: const [room],
        zones: [
          rect('left', 1000, 1000, 3000, 3000),
          rect('right', 3000, 1000, 5000, 3000),
        ],
      );
      final tool = _makeTool(cb);

      tool.onPointerDown(const Point2D(x: 3000, y: 2000), kPrimaryButton);
      tool.onDragUpdate(const Point2D(x: 3500, y: 2000));
      expect(maxX(zone(cb, 'left')), 3500.0);
      tool.cancel();

      expect(maxX(zone(cb, 'left')), 3000.0);
      expect(minX(zone(cb, 'right')), 3000.0);
    });
  });

  // ── ADR-039 Rule 1: editing connection pipes ──────────────────────────────

  group('ADR-039 connection pipe editing', () {
    const room = Room(
      id: 'room-1',
      floorId: 'floor-1',
      name: 'Test Room',
      targetTempC: 20.0,
      polygon: [
        Point2D(x: 0, y: 0),
        Point2D(x: 8000, y: 0),
        Point2D(x: 8000, y: 6000),
        Point2D(x: 0, y: 6000),
      ],
    );
    const zone = HeatingZone(
      id: 'zone-1',
      roomId: 'room-1',
      polygon: [
        Point2D(x: 4000, y: 2000),
        Point2D(x: 7000, y: 2000),
        Point2D(x: 7000, y: 5000),
        Point2D(x: 4000, y: 5000),
      ],
      tubeTypeId: 'tube-1',
      flooringMaterialId: 'mat-1',
      circuitId: 'circuit-1',
    );
    // Distributor at (500, 500). Supply: right, then down into the zone.
    // Return: back up a parallel lane to the distributor.
    const circuit = HeatingCircuit(
      id: 'circuit-1',
      distributorId: 'dist-1',
      heatingZoneId: 'zone-1',
      supplyRoutePath: [
        Point2D(x: 500, y: 500),
        Point2D(x: 5000, y: 500),
        Point2D(x: 5000, y: 3000),
      ],
      returnRoutePath: [
        Point2D(x: 5000, y: 3000),
        Point2D(x: 5000, y: 1000),
        Point2D(x: 500, y: 1000),
        Point2D(x: 500, y: 500),
      ],
    );

    ({_StubCallbacks cb, SelectTool tool, UndoRedoService undo}) setUpTool() {
      final cb = _StubCallbacks(
        rooms: const [room],
        zones: const [zone],
        circuits: const [circuit],
      );
      final undo = UndoRedoService();
      final tool = SelectTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: undo,
      );
      // Select the circuit with a click on its supply pipe.
      const on = Point2D(x: 2500, y: 500);
      tool.onPointerDown(on, kPrimaryButton);
      tool.onTap(on, PointerDeviceKind.mouse);
      tool.onPointerUp(on);
      expect(cb.lastSelectedType, 'circuit');
      return (cb: cb, tool: tool, undo: undo);
    }

    test('ST-P1: a selected circuit shows a handle on every corner except '
        'the two ends on the distributor', () {
      final t = setUpTool();
      final data = t.tool.getInteractionData();
      expect(data, isA<CircuitSelectionData>());
      final handles = (data! as CircuitSelectionData).handles;
      expect(handles, const [
        Point2D(x: 5000, y: 500), // supply corner
        Point2D(x: 5000, y: 3000), // shared end inside the zone (once)
        Point2D(x: 5000, y: 1000), // return corners
        Point2D(x: 500, y: 1000),
      ]);
    });

    test('ST-P2: dragging a corner moves that point only; one undo '
        'restores it', () {
      final t = setUpTool();
      t.tool.onPointerDown(const Point2D(x: 5000, y: 500), kPrimaryButton);
      t.tool.onDragUpdate(const Point2D(x: 5230, y: 310));
      t.tool.onDragEnd(const Point2D(x: 5230, y: 310));

      final c = t.cb.currentCircuits.single;
      expect(c.supplyRoutePath, const [
        Point2D(x: 500, y: 500),
        Point2D(x: 5200, y: 300), // grid-snapped
        Point2D(x: 5000, y: 3000),
      ]);
      expect(c.returnRoutePath, circuit.returnRoutePath);

      t.undo.undo();
      expect(t.cb.currentCircuits.single, circuit);
    });

    test('ST-P3: dragging the end inside the zone moves supply and return '
        'together', () {
      final t = setUpTool();
      t.tool.onPointerDown(const Point2D(x: 5000, y: 3000), kPrimaryButton);
      t.tool.onDragUpdate(const Point2D(x: 5500, y: 3500));
      t.tool.onDragEnd(const Point2D(x: 5500, y: 3500));

      final c = t.cb.currentCircuits.single;
      expect(c.supplyRoutePath.last, const Point2D(x: 5500, y: 3500));
      expect(c.returnRoutePath.first, const Point2D(x: 5500, y: 3500));
    });

    test('ST-P4: dragging a section moves both of its corners and keeps '
        'its direction', () {
      final t = setUpTool();
      // Middle section of the return pipe: (5000,1000) → (500,1000).
      t.tool.onPointerDown(const Point2D(x: 2500, y: 1000), kPrimaryButton);
      t.tool.onDragUpdate(const Point2D(x: 2500, y: 1400));
      t.tool.onDragEnd(const Point2D(x: 2500, y: 1400));

      final c = t.cb.currentCircuits.single;
      expect(c.returnRoutePath, const [
        Point2D(x: 5000, y: 3000),
        Point2D(x: 5000, y: 1400),
        Point2D(x: 500, y: 1400),
        Point2D(x: 500, y: 500),
      ]);
      expect(c.supplyRoutePath, circuit.supplyRoutePath);
    });

    test('ST-P5: moving the section next to the distributor keeps the '
        'distributor end fixed by inserting a corner', () {
      final t = setUpTool();
      // First supply section: (500,500) → (5000,500).
      t.tool.onPointerDown(const Point2D(x: 2500, y: 500), kPrimaryButton);
      t.tool.onDragUpdate(const Point2D(x: 2500, y: 200));
      t.tool.onDragEnd(const Point2D(x: 2500, y: 200));

      final c = t.cb.currentCircuits.single;
      expect(c.supplyRoutePath, const [
        Point2D(x: 500, y: 500), // still on the distributor
        Point2D(x: 500, y: 200),
        Point2D(x: 5000, y: 200),
        Point2D(x: 5000, y: 3000),
      ]);
    });

    test('ST-P6: a drag that takes the pipe end out of its zone is '
        'reverted with a toast', () {
      final t = setUpTool();
      t.tool.onPointerDown(const Point2D(x: 5000, y: 3000), kPrimaryButton);
      t.tool.onDragUpdate(const Point2D(x: 2000, y: 3000));
      t.tool.onDragEnd(const Point2D(x: 2000, y: 3000));

      expect(t.cb.currentCircuits.single, circuit);
      expect(t.cb.toasts, contains(t.cb.l10n.circuit_routeMustEndInZoneToast));
      expect(t.undo.canUndo, isFalse);
    });

    test('ST-P7: dropping a corner onto its neighbour removes it', () {
      final t = setUpTool();
      // Return corner (500,1000) onto the distributor end (500,500).
      t.tool.onPointerDown(const Point2D(x: 500, y: 1000), kPrimaryButton);
      t.tool.onDragUpdate(const Point2D(x: 500, y: 500));
      t.tool.onDragEnd(const Point2D(x: 500, y: 500));

      expect(t.cb.currentCircuits.single.returnRoutePath, const [
        Point2D(x: 5000, y: 3000),
        Point2D(x: 5000, y: 1000),
        Point2D(x: 500, y: 500),
      ]);
    });

    test('ST-P8: Escape during a drag restores the pipe', () {
      final t = setUpTool();
      t.tool.onPointerDown(const Point2D(x: 5000, y: 500), kPrimaryButton);
      t.tool.onDragUpdate(const Point2D(x: 5400, y: 300));
      expect(t.cb.currentCircuits.single, isNot(circuit));
      t.tool.cancel();
      expect(t.cb.currentCircuits.single, circuit);
    });
  });

  // ── ADR-040: editing a pair of connection pipes drawn as one route ───────

  group('ADR-040 editing a drawn pipe pair', () {
    const room = Room(
      id: 'room-1',
      floorId: 'floor-1',
      name: 'Test Room',
      targetTempC: 20.0,
      polygon: [
        Point2D(x: 0, y: 0),
        Point2D(x: 8000, y: 0),
        Point2D(x: 8000, y: 6000),
        Point2D(x: 0, y: 6000),
      ],
    );
    const zone = HeatingZone(
      id: 'zone-1',
      roomId: 'room-1',
      polygon: [
        Point2D(x: 4000, y: 2000),
        Point2D(x: 7000, y: 2000),
        Point2D(x: 7000, y: 5000),
        Point2D(x: 4000, y: 5000),
      ],
      tubeTypeId: 'tube-1',
      flooringMaterialId: 'mat-1',
      circuitId: 'circuit-1',
    );
    const route = [
      Point2D(x: 500, y: 500),
      Point2D(x: 5000, y: 500),
      Point2D(x: 5000, y: 3000),
    ];
    final circuit = relaidConnectionPipes(
      const HeatingCircuit(
        id: 'circuit-1',
        distributorId: 'dist-1',
        heatingZoneId: 'zone-1',
      ),
      const [],
      centerline: route,
    );

    ({_StubCallbacks cb, SelectTool tool, UndoRedoService undo}) setUpTool() {
      final cb = _StubCallbacks(
        rooms: const [room],
        zones: const [zone],
        circuits: [circuit],
      );
      final undo = UndoRedoService();
      final tool = SelectTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: undo,
      );
      // Select by clicking on the supply pipe (50 mm off the route).
      const on = Point2D(x: 2500, y: 550);
      tool.onPointerDown(on, kPrimaryButton);
      tool.onTap(on, PointerDeviceKind.mouse);
      tool.onPointerUp(on);
      expect(cb.lastSelectedType, 'circuit');
      return (cb: cb, tool: tool, undo: undo);
    }

    void expectPairOf(HeatingCircuit c) {
      final pair = PipeLayoutEngine.connectionPipePair(
        centerline: c.centerlinePath,
        pipeSpacingMm: c.pipeSpacingMm.toDouble(),
      );
      expect(c.supplyRoutePath, pair.supply);
      expect(c.returnRoutePath, pair.back);
    }

    test('ST-R1: the handles sit on the route — one per corner, none on '
        'the distributor end', () {
      final t = setUpTool();
      final data = t.tool.getInteractionData()! as CircuitSelectionData;
      expect(data.supplyPoints, route);
      expect(data.returnPoints, isEmpty);
      expect(data.handles, const [
        Point2D(x: 5000, y: 500),
        Point2D(x: 5000, y: 3000),
      ]);
    });

    test('ST-R2: dragging a route corner moves both pipes together; one '
        'undo restores them', () {
      final t = setUpTool();
      t.tool.onPointerDown(const Point2D(x: 5000, y: 500), kPrimaryButton);
      t.tool.onDragUpdate(const Point2D(x: 5200, y: 300));
      // Live: already laid out during the drag.
      expectPairOf(t.cb.currentCircuits.single);
      t.tool.onDragEnd(const Point2D(x: 5200, y: 300));

      final c = t.cb.currentCircuits.single;
      expect(c.centerlinePath, const [
        Point2D(x: 500, y: 500),
        Point2D(x: 5200, y: 300),
        Point2D(x: 5000, y: 3000),
      ]);
      expectPairOf(c);

      t.undo.undo();
      expect(t.cb.currentCircuits.single, circuit);
    });

    test('ST-R3: a section grabbed on either pipe moves the route section '
        'and keeps the pair parallel', () {
      final t = setUpTool();
      // Press on the return pipe of the second section (x = 5050).
      t.tool.onPointerDown(const Point2D(x: 5050, y: 1500), kPrimaryButton);
      t.tool.onDragUpdate(const Point2D(x: 5450, y: 1500));
      t.tool.onDragEnd(const Point2D(x: 5450, y: 1500));

      final c = t.cb.currentCircuits.single;
      expect(c.centerlinePath, const [
        Point2D(x: 500, y: 500),
        Point2D(x: 5400, y: 500),
        Point2D(x: 5400, y: 3000),
      ]);
      expectPairOf(c);
    });

    test('ST-R4: the route must still end inside its zone', () {
      final t = setUpTool();
      t.tool.onPointerDown(const Point2D(x: 5000, y: 3000), kPrimaryButton);
      t.tool.onDragUpdate(const Point2D(x: 2000, y: 3000));
      t.tool.onDragEnd(const Point2D(x: 2000, y: 3000));

      expect(t.cb.currentCircuits.single, circuit);
      expect(t.cb.toasts, contains(t.cb.l10n.circuit_routeMustEndInZoneToast));
    });
  });

  // ── Mirror-sync test (real EditorStateNotifier) ───────────────────────────

  group('ADR-012 shared-wall mirror sync (real provider)', () {
    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    // Layout: two adjacent rectangular rooms sharing the wall x = 3000
    // from y=0 to y=2000.
    //
    //   Room A: (0,0)→(3000,2000)  Room B: (3000,0)→(6000,2000)
    //
    // Shared edge: a single mirrored pair of WallSegments.
    //
    //   w-A-right: A's right wall  (3000,0)→(3000,2000)  mirror=w-B-left
    //   w-B-left:  B's left wall   (3000,2000)→(3000,0)  mirror=w-A-right
    //
    // Reshape Room A by Ctrl-dragging top-left from (0,0) to (-1000,-500).
    // Expectation: all 4 of room A's walls move, INCLUDING the shared
    // right wall whose y-range adjusts. The mirror partner in Room B
    // must follow in reversed orientation (ADR-011).

    final override = appDatabaseProvider.overrideWith((ref) {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      ref.onDispose(db.close);
      return db;
    });

    test(
      'ST-RR-10: shared wall in 4-wall reshape syncs to the mirror partner',
      () {
        final container = ProviderContainer(overrides: [override]);
        addTearDown(container.dispose);
        final notifier = container.read(editorStateProvider.notifier);

        // Room A walls.
        const aTL = Point2D(x: 0, y: 0);
        const aTR = Point2D(x: 3000, y: 0);
        const aBR = Point2D(x: 3000, y: 2000);
        const aBL = Point2D(x: 0, y: 2000);

        // Room B walls (mirrors A's right edge).
        const bTL = aTR; // (3000, 0)
        const bTR = Point2D(x: 6000, y: 0);
        const bBR = Point2D(x: 6000, y: 2000);
        const bBL = aBR; // (3000, 2000)

        final walls = <WallSegment>[
          // Room A: top, right (shared), bottom, left.
          const WallSegment(
            id: 'w-A-top',
            roomId: 'room-A',
            startPoint: aTL,
            endPoint: aTR,
          ),
          const WallSegment(
            id: 'w-A-right',
            roomId: 'room-A',
            startPoint: aTR,
            endPoint: aBR,
            wallType: WallType.interior,
            adjacentRoomId: 'room-B',
            mirrorId: 'w-B-left',
          ),
          const WallSegment(
            id: 'w-A-bottom',
            roomId: 'room-A',
            startPoint: aBR,
            endPoint: aBL,
          ),
          const WallSegment(
            id: 'w-A-left',
            roomId: 'room-A',
            startPoint: aBL,
            endPoint: aTL,
          ),
          // Room B's left wall (the mirror partner — reversed geometry).
          const WallSegment(
            id: 'w-B-left',
            roomId: 'room-B',
            startPoint: aBR,
            endPoint: aTR,
            wallType: WallType.interior,
            adjacentRoomId: 'room-A',
            mirrorId: 'w-A-right',
          ),
          // The rest of Room B (not strictly needed but completes the picture).
          const WallSegment(
            id: 'w-B-top',
            roomId: 'room-B',
            startPoint: bTL,
            endPoint: bTR,
          ),
          const WallSegment(
            id: 'w-B-right',
            roomId: 'room-B',
            startPoint: bTR,
            endPoint: bBR,
          ),
          const WallSegment(
            id: 'w-B-bottom',
            roomId: 'room-B',
            startPoint: bBR,
            endPoint: bBL,
          ),
        ];
        notifier.replaceAllWalls(walls);

        // Build a minimal callbacks shim that delegates to the real
        // notifier so updateWall triggers ADR-011 mirror sync.
        final cb = _ProviderBridgeCallbacks(container);

        // Select Room A's top wall.
        final tool = _makeTool(cb);
        tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);

        // Ctrl-drag from top-left to (-1000, -500).
        tool.debugCtrlHeldOverride = true;
        tool.onPointerDown(aTL, 1);
        tool.onDragEnd(const Point2D(x: -1000, y: -500));

        final updated = container.read(editorStateProvider).walls;

        // Room A's right wall (shared) must now span y = -500 → 2000 at x = 3000.
        final aRight = updated.firstWhere((w) => w.id == 'w-A-right');
        expect(aRight.startPoint, const Point2D(x: 3000, y: -500));
        expect(aRight.endPoint, const Point2D(x: 3000, y: 2000));

        // The mirror partner must have the reversed geometry.
        final bLeft = updated.firstWhere((w) => w.id == 'w-B-left');
        expect(bLeft.startPoint, aRight.endPoint);
        expect(bLeft.endPoint, aRight.startPoint);

        // All 4 of Room A's walls must reflect the reshape.
        final aTop = updated.firstWhere((w) => w.id == 'w-A-top');
        final aBottom = updated.firstWhere((w) => w.id == 'w-A-bottom');
        final aLeft = updated.firstWhere((w) => w.id == 'w-A-left');
        // Top wall: y = -500 from x = -1000 to x = 3000.
        expect(aTop.startPoint.y, -500);
        expect(aTop.endPoint.y, -500);
        // Bottom wall y unchanged (= 2000).
        expect(aBottom.startPoint.y, 2000);
        expect(aBottom.endPoint.y, 2000);
        // Left wall x = -1000.
        expect(aLeft.startPoint.x, -1000);
        expect(aLeft.endPoint.x, -1000);
      },
    );
  });

  // ── Debounced persistence: a mid-handle wall drag must not write to
  // SQLite every frame; the commit at onDragEnd persists each element once.
  group('Debounced persistence (transient drag)', () {
    test('no DB upsert during a multi-frame wall drag; one upsert per element '
        'on drop', () {
      final bDao = _CountingDragBuildingDao();
      final hDao = _CountingDragHeatingDao();
      final container = ProviderContainer(
        overrides: [
          buildingDaoProvider.overrideWithValue(bDao),
          heatingDaoProvider.overrideWithValue(hDao),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);

      // A 3000×2000 rectangular room.
      const tl = Point2D(x: 0, y: 0);
      const tr = Point2D(x: 3000, y: 0);
      const br = Point2D(x: 3000, y: 2000);
      const bl = Point2D(x: 0, y: 2000);
      final walls = <WallSegment>[
        const WallSegment(
          id: 'wall-top',
          roomId: 'room-1',
          startPoint: tl,
          endPoint: tr,
        ),
        const WallSegment(
          id: 'wall-right',
          roomId: 'room-1',
          startPoint: tr,
          endPoint: br,
        ),
        const WallSegment(
          id: 'wall-bottom',
          roomId: 'room-1',
          startPoint: br,
          endPoint: bl,
        ),
        const WallSegment(
          id: 'wall-left',
          roomId: 'room-1',
          startPoint: bl,
          endPoint: tl,
        ),
      ];
      const room = Room(
        id: 'room-1',
        floorId: 'floor-1',
        name: 'Room 1',
        polygon: [tl, tr, br, bl],
      );
      notifier.replaceAllWallsAndRooms(walls, const [room]);

      final cb = _ProviderBridgeCallbacks(container);
      final tool = _makeTool(cb);

      // Select the top wall, then grab its mid handle (its midpoint).
      const mid = Point2D(x: 1500, y: 0);
      tool.onTap(mid, PointerDeviceKind.mouse);
      tool.onPointerDown(mid, 1);

      // Five-frame drag downward — pure in-memory, no DB writes.
      for (var dy = -100; dy >= -500; dy -= 100) {
        tool.onDragUpdate(Point2D(x: 1500, y: dy.toDouble()));
      }
      expect(
        bDao.wallUpserts,
        0,
        reason: 'no wall upsert during a multi-frame drag',
      );
      expect(
        bDao.roomUpserts,
        0,
        reason: 'no room upsert during a multi-frame drag',
      );

      // Drop: commits the final geometry exactly once per element.
      tool.onDragEnd(const Point2D(x: 1500, y: -500));

      expect(bDao.roomUpserts, 1, reason: 'room persisted once on commit');
      expect(bDao.upsertedRoomIds, ['room-1']);
      expect(
        bDao.wallUpserts,
        greaterThan(0),
        reason: 'the moved walls are persisted on commit',
      );
      expect(bDao.upsertedWallIds, contains('wall-top'));
      expect(
        bDao.upsertedWallIds.toSet().length,
        bDao.upsertedWallIds.length,
        reason: 'each wall is persisted at most once per interaction',
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // ST-STALE — a no-drag press on a selected wall must not leave wall-drag
  // state armed, or a later click teleports the wall to the cursor.
  // ────────────────────────────────────────────────────────────────────────────

  test('ST-STALE-1: selecting a wall, clicking it again (no drag), then '
      'clicking elsewhere does NOT move the wall', () {
    // Horizontal wall (0,0)→(5000,0); standalone (no room).
    const wall = WallSegment(
      id: 'w',
      roomId: '',
      startPoint: Point2D(x: 0, y: 0),
      endPoint: Point2D(x: 5000, y: 0),
    );
    final cb = _ReshapeStubCallbacks(walls: [wall], rooms: const []);
    final tool = SelectTool(
      callbacks: cb,
      onStateChanged: () {},
      undoRedo: UndoRedoService(),
    );

    // Click 1 — select the wall (down → tap → up on the wall body).
    tool.onPointerDown(const Point2D(x: 2500, y: 0), kPrimaryButton);
    tool.onTap(const Point2D(x: 2500, y: 0), PointerDeviceKind.mouse);
    tool.onPointerUp(const Point2D(x: 2500, y: 0));
    expect(cb.lastSelectedType, 'wall');

    // Click 2 — a second, separate click that also lands on the wall
    // body, with NO drag. This arms a wall-body (mid) drag in
    // onPointerDown that onPointerUp must clear.
    tool.onPointerDown(const Point2D(x: 1000, y: 0), kPrimaryButton);
    tool.onTap(const Point2D(x: 1000, y: 0), PointerDeviceKind.mouse);
    tool.onPointerUp(const Point2D(x: 1000, y: 0));

    // Click 3 — click far from the wall. A real pointer always reports a
    // little movement, so the canvas treats it as a drag (onDragUpdate /
    // onDragEnd). With stale wall-drag state this ran _applyMidDrag and
    // teleported the wall to the cursor; it must now stay put.
    tool.onPointerDown(const Point2D(x: 1000, y: 3000), kPrimaryButton);
    tool.onTap(const Point2D(x: 1000, y: 3000), PointerDeviceKind.mouse);
    tool.onDragUpdate(const Point2D(x: 1000, y: 3000));
    tool.onDragEnd(const Point2D(x: 1000, y: 3000));

    final moved = cb.currentWalls.firstWhere((w) => w.id == 'w');
    expect(
      moved.startPoint,
      const Point2D(x: 0, y: 0),
      reason: 'wall start must not move on a separate click',
    );
    expect(
      moved.endPoint,
      const Point2D(x: 5000, y: 0),
      reason: 'wall end must not move on a separate click',
    );
  });

  // ADR-034 — multi-wall select + rigid group translate ──────────────────────
  group('ADR-034 multi-wall select + group drag', () {
    // Two collinear top exterior walls meeting at x=5000, plus a vertical
    // divider sharing that corner. Selecting both top walls and dragging
    // them up must translate both rigidly and drag the divider's top
    // corner along (keeping it vertical) — without re-angling anything.
    List<WallSegment> freshWalls() => const [
      WallSegment(
        id: 'top-l',
        roomId: '',
        startPoint: Point2D(x: 0, y: 0),
        endPoint: Point2D(x: 5000, y: 0),
      ),
      WallSegment(
        id: 'top-r',
        roomId: '',
        startPoint: Point2D(x: 5000, y: 0),
        endPoint: Point2D(x: 10000, y: 0),
      ),
      WallSegment(
        id: 'divider',
        roomId: '',
        startPoint: Point2D(x: 5000, y: 0),
        endPoint: Point2D(x: 5000, y: 3000),
      ),
    ];

    /// Ctrl/Cmd-tap both top walls into the multi-selection.
    void selectBothTop(SelectTool tool) {
      tool.debugCtrlHeldOverride = true;
      tool.onTap(const Point2D(x: 2500, y: 0), PointerDeviceKind.mouse);
      tool.onTap(const Point2D(x: 7500, y: 0), PointerDeviceKind.mouse);
      tool.debugCtrlHeldOverride = false;
    }

    test('Ctrl-tap builds a 2-wall selection; re-tap removes one', () {
      final cb = _MutatingStub(walls: freshWalls());
      final tool = _makeTool(cb);

      selectBothTop(tool);
      final data = tool.getInteractionData()! as SelectionHighlightData;
      expect(data.selectedWalls.map((w) => w.id), ['top-l', 'top-r']);
      expect(
        data.handles,
        isEmpty,
        reason: 'group selection shows no endpoint handles',
      );

      // Ctrl-tap top-r again → removed → collapses to single selection.
      tool.debugCtrlHeldOverride = true;
      tool.onTap(const Point2D(x: 7500, y: 0), PointerDeviceKind.mouse);
      tool.debugCtrlHeldOverride = false;
      final after = tool.getInteractionData()! as SelectionHighlightData;
      expect(after.selectedWalls.map((w) => w.id), ['top-l']);
      expect(cb.lastSelectedId, 'top-l');
    });

    test('Group drag translates both walls and drags the shared corner', () {
      final cb = _MutatingStub(walls: freshWalls());
      final tool = _makeTool(cb);
      selectBothTop(tool);

      // Grab top-l and drag straight up 1000 mm.
      tool.onPointerDown(const Point2D(x: 2500, y: 0), kPrimaryButton);
      tool.onDragUpdate(const Point2D(x: 2500, y: -1000));
      tool.onDragEnd(const Point2D(x: 2500, y: -1000));

      final l = cb.currentWalls.firstWhere((w) => w.id == 'top-l');
      final r = cb.currentWalls.firstWhere((w) => w.id == 'top-r');
      final d = cb.currentWalls.firstWhere((w) => w.id == 'divider');

      expect(l.startPoint, const Point2D(x: 0, y: -1000));
      expect(l.endPoint, const Point2D(x: 5000, y: -1000));
      expect(r.startPoint, const Point2D(x: 5000, y: -1000));
      expect(r.endPoint, const Point2D(x: 10000, y: -1000));

      // Divider's top corner follows; bottom stays — still vertical.
      expect(d.startPoint, const Point2D(x: 5000, y: -1000));
      expect(d.endPoint, const Point2D(x: 5000, y: 3000));
      expect(
        d.startPoint.x,
        d.endPoint.x,
        reason: 'divider must stay axis-aligned (vertical)',
      );
    });

    test('Ctrl held → keep-orientation: parallel slide dropped, '
        'divider stays vertical', () {
      final cb = _MutatingStub(walls: freshWalls());
      final tool = _makeTool(cb);
      selectBothTop(tool);

      // Keep Ctrl held through the drag and drag diagonally: +1000 x,
      // -1000 y. Keep-orientation must apply only the perpendicular
      // (vertical) component and drop the horizontal slide.
      tool.debugCtrlHeldOverride = true;
      tool.onPointerDown(const Point2D(x: 2500, y: 0), kPrimaryButton);
      tool.onDragUpdate(const Point2D(x: 3500, y: -1000));
      tool.onDragEnd(const Point2D(x: 3500, y: -1000));
      tool.debugCtrlHeldOverride = false;

      final l = cb.currentWalls.firstWhere((w) => w.id == 'top-l');
      final r = cb.currentWalls.firstWhere((w) => w.id == 'top-r');
      final d = cb.currentWalls.firstWhere((w) => w.id == 'divider');

      // x unchanged (no parallel slide); y shifted by the perpendicular −1000.
      expect(l.startPoint, const Point2D(x: 0, y: -1000));
      expect(l.endPoint, const Point2D(x: 5000, y: -1000));
      expect(r.startPoint, const Point2D(x: 5000, y: -1000));
      expect(r.endPoint, const Point2D(x: 10000, y: -1000));

      // Divider keeps its orientation (vertical) and only changes length.
      expect(d.startPoint, const Point2D(x: 5000, y: -1000));
      expect(d.endPoint, const Point2D(x: 5000, y: 3000));
      expect(d.startPoint.x, d.endPoint.x);
    });

    test('Undo restores the pre-move geometry in one step', () {
      final cb = _MutatingStub(walls: freshWalls());
      final undo = UndoRedoService();
      final tool = SelectTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: undo,
      );
      selectBothTop(tool);

      tool.onPointerDown(const Point2D(x: 2500, y: 0), kPrimaryButton);
      tool.onDragUpdate(const Point2D(x: 2500, y: -1000));
      tool.onDragEnd(const Point2D(x: 2500, y: -1000));
      expect(
        cb.currentWalls.firstWhere((w) => w.id == 'top-l').startPoint,
        const Point2D(x: 0, y: -1000),
      );

      undo.undo();
      expect(
        cb.currentWalls.firstWhere((w) => w.id == 'top-l').startPoint,
        const Point2D(x: 0, y: 0),
      );
      expect(
        cb.currentWalls.firstWhere((w) => w.id == 'top-r').endPoint,
        const Point2D(x: 10000, y: 0),
      );
      expect(
        cb.currentWalls.firstWhere((w) => w.id == 'divider').startPoint,
        const Point2D(x: 5000, y: 0),
      );
    });

    test('Plain (non-Ctrl) click collapses a multi-selection to one', () {
      final cb = _MutatingStub(walls: freshWalls());
      final tool = _makeTool(cb);
      selectBothTop(tool);
      expect(
        (tool.getInteractionData()! as SelectionHighlightData)
            .selectedWalls
            .length,
        2,
      );

      tool.onTap(const Point2D(x: 2500, y: 0), PointerDeviceKind.mouse);
      final data = tool.getInteractionData()! as SelectionHighlightData;
      expect(data.selectedWalls.map((w) => w.id), ['top-l']);
    });
  });
}

/// [_StubCallbacks] whose wall/room mutators actually edit the backing
/// lists, so transient drags and `replaceAllWallsAndRooms` (used by the
/// ADR-034 group-move command) are observable. Same-file privacy lets the
/// subclass reach the base's private lists.
class _MutatingStub extends _StubCallbacks {
  _MutatingStub({super.walls});

  @override
  void updateWall(WallSegment wall) {
    final i = _walls.indexWhere((w) => w.id == wall.id);
    if (i >= 0) _walls[i] = wall;
  }

  @override
  void updateRoom(Room room) {
    final i = _rooms.indexWhere((r) => r.id == room.id);
    if (i >= 0) _rooms[i] = room;
  }

  @override
  void replaceAllWallsAndRooms(List<WallSegment> walls, List<Room> rooms) {
    _walls
      ..clear()
      ..addAll(walls);
    _rooms
      ..clear()
      ..addAll(rooms);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Stub callbacks used by the ADR-012 reshape tests
// ════════════════════════════════════════════════════════════════════════════

/// Stub with a working [updateWall] / [updateRoom] /
/// [replaceAllWallsAndRooms] so the rect-reshape commit path can be
/// verified end-to-end without spinning up a real provider.
class _ReshapeStubCallbacks implements EditorCallbacks {
  _ReshapeStubCallbacks({
    required List<WallSegment> walls,
    required List<Room> rooms,
  }) : _walls = List<WallSegment>.of(walls),
       _rooms = List<Room>.of(rooms);

  final List<WallSegment> _walls;
  final List<Room> _rooms;
  final List<String> _toasts = [];

  String? lastSelectedType;
  String? lastSelectedId;
  bool selectCalledWithNull = false;

  @override
  final AppLocalizations l10n = AppLocalizationsEn();

  @override
  List<WallSegment> get currentWalls => List.unmodifiable(_walls);

  @override
  List<Room> get currentRooms => List.unmodifiable(_rooms);

  @override
  void updateWall(WallSegment wall) {
    final idx = _walls.indexWhere((w) => w.id == wall.id);
    if (idx >= 0) _walls[idx] = wall;
  }

  @override
  void updateRoom(Room room) {
    final idx = _rooms.indexWhere((r) => r.id == room.id);
    if (idx >= 0) _rooms[idx] = room;
  }

  @override
  void updateWallTransient(WallSegment wall) => updateWall(wall);
  @override
  void updateRoomTransient(Room room) => updateRoom(room);
  @override
  void updateZoneTransient(HeatingZone zone) => updateZone(zone);
  @override
  void updateCircuitTransient(HeatingCircuit circuit) => updateCircuit(circuit);
  @override
  void updateWindowTransient(WindowElement window) => updateWindow(window);
  @override
  void updateDoorTransient(Door door) => updateDoor(door);
  @override
  void updateDistributorTransient(Distributor distributor) =>
      updateDistributor(distributor);

  @override
  void replaceAllWalls(List<WallSegment> walls) {
    _walls
      ..clear()
      ..addAll(walls);
  }

  @override
  void replaceAllWallsAndRooms(List<WallSegment> walls, List<Room> rooms) {
    _walls
      ..clear()
      ..addAll(walls);
    _rooms
      ..clear()
      ..addAll(rooms);
  }

  @override
  void replaceAllWallsRoomsZones(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
  ) {
    _walls
      ..clear()
      ..addAll(walls);
    _rooms
      ..clear()
      ..addAll(rooms);
  }

  @override
  void addRoomFromDetection({
    required Room room,
    required List<String> wallIds,
    Map<String, WallSegment>? movedSideProperties,
  }) {}

  @override
  void showToast(String message) => _toasts.add(message);

  @override
  void selectElement(String? type, String? id) {
    if (type == null || id == null) {
      selectCalledWithNull = true;
      lastSelectedType = null;
      lastSelectedId = null;
    } else {
      selectCalledWithNull = false;
      lastSelectedType = type;
      lastSelectedId = id;
    }
  }

  // ── Unused stubs ──────────────────────────────────────────────────────────
  @override
  void commitWall(WallSegment wall) {}
  @override
  WallSegment commitWallWithSplit(
    WallSegment wall, {
    bool splitNewWall = true,
  }) => wall;
  @override
  void removeWall(String wallId) {}
  @override
  void destroyRoom(String roomId) {}
  @override
  void destroyRoomCascade(String roomId) {}
  @override
  void replaceAllForRoomCascade(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
    List<WindowElement> windows,
    List<Door> doors,
  ) {}
  @override
  void restoreRoom(Room room, List<String> wallIds) {}
  @override
  void commitWindow(WindowElement window) {}
  @override
  void updateWindow(WindowElement window) {}
  @override
  void removeWindow(String windowId) {}
  @override
  void commitDoor(Door door) {}
  @override
  void updateDoor(Door door) {}
  @override
  void removeDoor(String doorId) {}
  @override
  void commitDistributor(Distributor distributor) {}
  @override
  void updateDistributor(Distributor distributor) {}
  @override
  void removeDistributor() {}
  @override
  Distributor? get currentDistributor => null;
  @override
  void requestDistributorReplaceDialog({
    required void Function() onMove,
    required void Function() onReplace,
  }) {}
  @override
  void requestDistributorDeleteDialog({required void Function() onConfirmed}) {}
  @override
  void commitCircuit(HeatingCircuit circuit) {}
  @override
  void updateCircuit(HeatingCircuit circuit) {}
  @override
  void removeCircuit(String circuitId) {}
  @override
  void clearAllCircuits() {}
  @override
  List<HeatingCircuit> get currentCircuits => const [];
  @override
  void commitZone(HeatingZone zone) {}
  @override
  void updateZone(HeatingZone zone) {}
  @override
  void removeZone(String zoneId) {}
  @override
  String get currentFloorId => 'floor-1';
  @override
  String get defaultTubeTypeId => 'tube-1';
  @override
  String get defaultWallTubeTypeId => 'tube-1';
  @override
  String get defaultFlooringMaterialId => 'mat-1';
  @override
  void requestRoomDialog(
    List<Point2D> polygon,
    List<String> wallIds, {
    void Function(List<WallSegment>, List<Room>)? onCreated,
  }) {}
  @override
  void requestZoneContextMenu(ZoneContextMenuRequest request) {}
  @override
  List<WindowElement> get currentWindows => const [];
  @override
  List<Door> get currentDoors => const [];
  @override
  List<HeatingZone> get currentZones => const [];
  @override
  double get currentZoom => 1.0;
  @override
  double get currentGridSpacingMm => 100.0;
}

/// Bridge that routes write operations through a real
/// [EditorStateNotifier] so [updateWall] exercises the production
/// ADR-011 mirror-sync path.
class _ProviderBridgeCallbacks implements EditorCallbacks {
  _ProviderBridgeCallbacks(this._container);

  final ProviderContainer _container;

  EditorStateNotifier get _notifier =>
      _container.read(editorStateProvider.notifier);

  @override
  final AppLocalizations l10n = AppLocalizationsEn();

  @override
  List<WallSegment> get currentWalls =>
      _container.read(editorStateProvider).walls;

  @override
  List<Room> get currentRooms => _container.read(editorStateProvider).rooms;

  @override
  void updateWall(WallSegment wall) => _notifier.updateWall(wall);

  @override
  void updateRoom(Room room) => _notifier.updateRoom(room);

  @override
  void updateWallTransient(WallSegment wall) =>
      _notifier.updateWallTransient(wall);
  @override
  void updateRoomTransient(Room room) => _notifier.updateRoomTransient(room);
  @override
  void updateZoneTransient(HeatingZone zone) =>
      _notifier.updateZoneTransient(zone);
  @override
  void updateCircuitTransient(HeatingCircuit circuit) => updateCircuit(circuit);
  @override
  void updateWindowTransient(WindowElement window) =>
      _notifier.updateWindowTransient(window);
  @override
  void updateDoorTransient(Door door) => _notifier.updateDoorTransient(door);
  @override
  void updateDistributorTransient(Distributor distributor) =>
      _notifier.updateDistributorTransient(distributor);

  @override
  void replaceAllWalls(List<WallSegment> walls) =>
      _notifier.replaceAllWalls(walls);

  @override
  void replaceAllWallsAndRooms(List<WallSegment> walls, List<Room> rooms) =>
      _notifier.replaceAllWallsAndRooms(walls, rooms);

  @override
  void replaceAllWallsRoomsZones(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
  ) => _notifier.replaceAllWallsRoomsZones(walls, rooms, zones);

  @override
  void addRoomFromDetection({
    required Room room,
    required List<String> wallIds,
    Map<String, WallSegment>? movedSideProperties,
  }) => _notifier.addRoomFromDetection(
    room: room,
    wallIds: wallIds,
    movedSideProperties: movedSideProperties,
  );

  @override
  void showToast(String message) {}

  @override
  void selectElement(String? type, String? id) {}

  // ── Unused stubs ──────────────────────────────────────────────────────────
  @override
  void commitWall(WallSegment wall) {}
  @override
  WallSegment commitWallWithSplit(
    WallSegment wall, {
    bool splitNewWall = true,
  }) => wall;
  @override
  void removeWall(String wallId) {}
  @override
  void destroyRoom(String roomId) {}
  @override
  void destroyRoomCascade(String roomId) {}
  @override
  void replaceAllForRoomCascade(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
    List<WindowElement> windows,
    List<Door> doors,
  ) {}
  @override
  void restoreRoom(Room room, List<String> wallIds) {}
  @override
  void commitWindow(WindowElement window) {}
  @override
  void updateWindow(WindowElement window) {}
  @override
  void removeWindow(String windowId) {}
  @override
  void commitDoor(Door door) {}
  @override
  void updateDoor(Door door) {}
  @override
  void removeDoor(String doorId) {}
  @override
  void commitDistributor(Distributor distributor) {}
  @override
  void updateDistributor(Distributor distributor) {}
  @override
  void removeDistributor() {}
  @override
  Distributor? get currentDistributor => null;
  @override
  void requestDistributorReplaceDialog({
    required void Function() onMove,
    required void Function() onReplace,
  }) {}
  @override
  void requestDistributorDeleteDialog({required void Function() onConfirmed}) {}
  @override
  void commitCircuit(HeatingCircuit circuit) {}
  @override
  void updateCircuit(HeatingCircuit circuit) {}
  @override
  void removeCircuit(String circuitId) {}
  @override
  void clearAllCircuits() {}
  @override
  List<HeatingCircuit> get currentCircuits => const [];
  @override
  void commitZone(HeatingZone zone) {}
  @override
  void updateZone(HeatingZone zone) {}
  @override
  void removeZone(String zoneId) {}
  @override
  String get currentFloorId => 'floor-1';
  @override
  String get defaultTubeTypeId => 'tube-1';
  @override
  String get defaultWallTubeTypeId => 'tube-1';
  @override
  String get defaultFlooringMaterialId => 'mat-1';
  @override
  void requestRoomDialog(
    List<Point2D> polygon,
    List<String> wallIds, {
    void Function(List<WallSegment>, List<Room>)? onCreated,
  }) {}
  @override
  void requestZoneContextMenu(ZoneContextMenuRequest request) {}
  @override
  List<WindowElement> get currentWindows => const [];
  @override
  List<Door> get currentDoors => const [];
  @override
  List<HeatingZone> get currentZones => const [];
  @override
  double get currentZoom => 1.0;
  @override
  double get currentGridSpacingMm => 100.0;
}

// ════════════════════════════════════════════════════════════════════════════
// Counting DAOs for the debounced-persistence drag test
// ════════════════════════════════════════════════════════════════════════════

/// Records wall/room upserts (with ids) without a real database.
/// `noSuchMethod` forwards every DAO call to the counters and returns a
/// completed future so the `unawaited(upsert…)` calls resolve cleanly.
class _CountingDragBuildingDao implements BuildingDao {
  int wallUpserts = 0;
  int roomUpserts = 0;
  final List<String> upsertedWallIds = [];
  final List<String> upsertedRoomIds = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final member = invocation.memberName;
    if (member == #upsertWallSegment) {
      wallUpserts++;
      upsertedWallIds.add(
        (invocation.positionalArguments.first as dynamic).id.value as String,
      );
    } else if (member == #upsertRoom) {
      roomUpserts++;
      upsertedRoomIds.add(
        (invocation.positionalArguments.first as dynamic).id.value as String,
      );
    }
    return Future<void>.value();
  }
}

class _CountingDragHeatingDao implements HeatingDao {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
