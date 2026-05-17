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
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/l10n/app_localizations_en.dart';
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
      final r =
          SelectTool.identifyRectCornersAroundDrag(corners, tl);
      expect(r, isNotNull);
      expect(r!.anchor, br);
      // xAdj shares dragCorner's x (= tl.x = 0) → bl (0, 2000).
      expect(r.xAdj, bl);
      // yAdj shares dragCorner's y (= tl.y = 0) → tr (3000, 0).
      expect(r.yAdj, tr);
    });

    test('ST-RR-4b: dragging top-right → diagonal anchor is bottom-left', () {
      final r =
          SelectTool.identifyRectCornersAroundDrag(corners, tr);
      expect(r, isNotNull);
      expect(r!.anchor, bl);
      expect(r.xAdj, br); // shares x=3000
      expect(r.yAdj, tl); // shares y=0
    });

    test(
        'ST-RR-4c: dragging bottom-right → diagonal anchor is top-left', () {
      final r =
          SelectTool.identifyRectCornersAroundDrag(corners, br);
      expect(r, isNotNull);
      expect(r!.anchor, tl);
      expect(r.xAdj, tr); // shares x=3000
      expect(r.yAdj, bl); // shares y=2000
    });

    test(
        'ST-RR-4d: dragging bottom-left → diagonal anchor is top-right', () {
      final r =
          SelectTool.identifyRectCornersAroundDrag(corners, bl);
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
          WallSegment(
            id: 'w-top',
            roomId: roomId,
            startPoint: tl,
            endPoint: tr,
          ),
          WallSegment(
            id: 'w-right',
            roomId: roomId,
            startPoint: tr,
            endPoint: br,
          ),
          WallSegment(
            id: 'w-bottom',
            roomId: roomId,
            startPoint: br,
            endPoint: bl,
          ),
          WallSegment(
            id: 'w-left',
            roomId: roomId,
            startPoint: bl,
            endPoint: tl,
          ),
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
      tool.updateModifiers(ctrl: true);
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
    });

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
      tool.updateModifiers(ctrl: true);
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
      tool.updateModifiers(ctrl: true);
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
    });

    test('ST-RR-8: mid-drag Ctrl-release still commits as rect-reshape', () {
      const roomId = 'room-4';
      final cb = _ReshapeStubCallbacks(
        walls: buildRectWalls(roomId),
        rooms: [buildRoom(roomId)],
      );
      final tool = _makeTool(cb);

      tool.onTap(const Point2D(x: 1500, y: 0), PointerDeviceKind.mouse);
      tool.updateModifiers(ctrl: true);
      tool.onPointerDown(tl, 1);

      // Release Ctrl mid-drag — mode must remain rect-reshape.
      tool.updateModifiers(ctrl: false);

      tool.onDragEnd(const Point2D(x: -1000, y: -500));

      // Still 4 walls; rectangle reshaped despite Ctrl release.
      expect(cb._walls, hasLength(4));
      final xs = <double>{};
      final ys = <double>{};
      for (final w in cb._walls) {
        xs..add(w.startPoint.x)..add(w.endPoint.x);
        ys..add(w.startPoint.y)..add(w.endPoint.y);
      }
      expect(xs, {-1000.0, 3000.0});
      expect(ys, {-500.0, 2000.0});
    });

    test(
        'ST-RR-9: Shift is a no-op — no new code path activated for it',
        () {
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
      tool.updateModifiers(ctrl: true);
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
    });
  });
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
  })  : _walls = List<WallSegment>.of(walls),
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
  void replaceAllWalls(List<WallSegment> walls) {
    _walls
      ..clear()
      ..addAll(walls);
  }

  @override
  void replaceAllWallsAndRooms(
    List<WallSegment> walls,
    List<Room> rooms,
  ) {
    _walls
      ..clear()
      ..addAll(walls);
    _rooms
      ..clear()
      ..addAll(rooms);
  }

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
  void commitWallWithSplit(WallSegment wall) {}
  @override
  void removeWall(String wallId) {}
  @override
  void destroyRoom(String roomId) {}
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
  void requestDistributorDeleteDialog({
    required void Function() onConfirmed,
  }) {}
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
  List<Room> get currentRooms =>
      _container.read(editorStateProvider).rooms;

  @override
  void updateWall(WallSegment wall) => _notifier.updateWall(wall);

  @override
  void updateRoom(Room room) => _notifier.updateRoom(room);

  @override
  void replaceAllWalls(List<WallSegment> walls) =>
      _notifier.replaceAllWalls(walls);

  @override
  void replaceAllWallsAndRooms(
    List<WallSegment> walls,
    List<Room> rooms,
  ) =>
      _notifier.replaceAllWallsAndRooms(walls, rooms);

  @override
  void showToast(String message) {}

  @override
  void selectElement(String? type, String? id) {}

  // ── Unused stubs ──────────────────────────────────────────────────────────
  @override
  void commitWall(WallSegment wall) {}
  @override
  void commitWallWithSplit(WallSegment wall) {}
  @override
  void removeWall(String wallId) {}
  @override
  void destroyRoom(String roomId) {}
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
  void requestDistributorDeleteDialog({
    required void Function() onConfirmed,
  }) {}
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
  List<HeatingZone> get currentZones => const [];
  @override
  double get currentZoom => 1.0;
  @override
  double get currentGridSpacingMm => 100.0;
}
