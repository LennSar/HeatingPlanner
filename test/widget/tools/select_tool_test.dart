// Unit-style tests for SelectTool — agent-test.md §6.2.
//
// SelectTool is exercised directly via a stub EditorCallbacks,
// following the same pattern as wall_draw_tool_test.dart.
//
// Covered scenarios:
//   ST-1  Tapping a wall selects it  → selectElement('wall', id) called.
//   ST-2  Tapping empty space clears → selectElement(null, null) called.
//   ST-3  Tapping inside a zone selects it → selectElement('zone', id).
//   ST-4  Delete key with a circuit selected → circuit removed from list.
//   ST-5  Delete key with nothing selected → no exception, no state change.

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/door.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/data/models/window_element.dart';
import 'package:heating_planner/ui/canvas/tools/editor_callbacks.dart';
import 'package:heating_planner/ui/canvas/tools/select_tool.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';

// ── Stub EditorCallbacks ─────────────────────────────────────────────────────

class _StubCallbacks implements EditorCallbacks {
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
  })  : _walls = List<WallSegment>.of(walls ?? const []),
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

  @override
  void showToast(String message) {}
  @override
  void replaceAllWalls(List<WallSegment> walls) {
    _walls
      ..clear()
      ..addAll(walls);
  }

  // ---- Unused stubs ----
  @override
  void commitWall(WallSegment wall) {}
  @override
  void commitWallWithSplit(WallSegment wall) {}
  @override
  void updateWall(WallSegment wall) {}
  @override
  void removeWall(String wallId) {}
  @override
  void destroyRoom(String roomId) {}
  @override
  void restoreRoom(Room room, List<String> wallIds) {}
  @override
  void updateRoom(Room room) {}
  @override
  void replaceAllWallsAndRooms(List<WallSegment> walls, List<Room> rooms) {}
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
  void requestDistributorDeleteDialog({
    required void Function() onConfirmed,
  }) {}
  @override
  void commitCircuit(HeatingCircuit circuit) => _circuits.add(circuit);
  @override
  void updateCircuit(HeatingCircuit circuit) {}
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
  String get defaultFlooringMaterialId => 'mat-1';
  @override
  void requestRoomDialog(List<Point2D> polygon, List<String> wallIds, {void Function(List<WallSegment>, List<Room>)? onCreated}) {}
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

SelectTool _makeTool(_StubCallbacks cb) => SelectTool(
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
  supplyRoutePath: [
    Point2D(x: 3000, y: 3000),
    Point2D(x: 4000, y: 3000),
  ],
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ST-1 ────────────────────────────────────────────────────────────────────

  test(
    'ST-1: tapping a wall calls selectElement("wall", wallId)',
    () {
      final cb = _StubCallbacks(walls: [_testWall]);
      final tool = _makeTool(cb);

      // Tap on the wall's midpoint (2500, 0) — within the 100 mm threshold.
      tool.onTap(
        const Point2D(x: 2500, y: 0),
        PointerDeviceKind.mouse,
      );

      expect(cb.lastSelectedType, 'wall');
      expect(cb.lastSelectedId, 'wall-1');
    },
  );

  // ST-2 ────────────────────────────────────────────────────────────────────

  test(
    'ST-2: tapping empty space calls selectElement(null, null)',
    () {
      final cb = _StubCallbacks(walls: [_testWall]);
      final tool = _makeTool(cb);

      // Far from any wall (10 m away from the wall at y=0).
      tool.onTap(
        const Point2D(x: 2500, y: 10000),
        PointerDeviceKind.mouse,
      );

      expect(cb.selectCalledWithNull, isTrue);
    },
  );

  // ST-3 ────────────────────────────────────────────────────────────────────

  test(
    'ST-3: tapping inside a zone calls selectElement("zone", zoneId)',
    () {
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
      final cb = _StubCallbacks(
        zones: [_testZone],
        rooms: [room],
      );
      final tool = _makeTool(cb);

      // Tap the zone centre (1500, 1500).
      tool.onTap(
        const Point2D(x: 1500, y: 1500),
        PointerDeviceKind.mouse,
      );

      expect(cb.lastSelectedType, 'zone');
      expect(cb.lastSelectedId, 'zone-1');
    },
  );

  // ST-4 ────────────────────────────────────────────────────────────────────

  test(
    'ST-4: Delete with a circuit selected removes the circuit',
    () {
      final cb = _StubCallbacks(circuits: [_testCircuit]);
      final tool = _makeTool(cb);

      // Tap a point on the circuit's supply route (midpoint 3500, 3000).
      tool.onTap(
        const Point2D(x: 3500, y: 3000),
        PointerDeviceKind.mouse,
      );
      expect(cb.lastSelectedType, 'circuit');

      // Fire onDelete — simulates the Delete key via toolDeleteProvider.
      tool.onDelete();

      expect(cb.currentCircuits, isEmpty);
    },
  );

  // ST-5 ────────────────────────────────────────────────────────────────────

  test(
    'ST-5: Delete with nothing selected does not throw',
    () {
      final cb = _StubCallbacks();
      final tool = _makeTool(cb);

      // No selection → onDelete is a no-op.
      expect(() => tool.onDelete(), returnsNormally);
    },
  );
}
