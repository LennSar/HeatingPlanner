// Unit-style tests for RouteDrawTool — the connection-pipe tool
// (ADR-040). The tool is exercised directly via a stub EditorCallbacks,
// following the pattern of zone_draw_tool_test.dart.
//
// Covered:
//   RDT-1 … RDT-3    starting on the distributor
//   RDT-4 … RDT-10   single clicks are route points; a double-click inside
//                    a zone connects it; refusals; Escape
//   RDT-11, RDT-12   supply and return are laid out together; distances
//                    carry over
//   RDT-13 … RDT-15  live preview on pointer move
//   RDT-16, RDT-17   wall distance applied while drawing

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/pipe_layout_engine.dart';
import 'package:heating_planner/calculation/engines/geometry_engine.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/door.dart';
import 'package:heating_planner/calculation/providers/pipe_layout_providers.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/data/models/window_element.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/l10n/app_localizations_en.dart';
import 'package:heating_planner/ui/canvas/painters/interaction_data.dart';
import 'package:heating_planner/ui/canvas/tools/editor_callbacks.dart';
import 'package:heating_planner/ui/canvas/tools/route_draw_tool.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';

// ── Stub EditorCallbacks ─────────────────────────────────────────────────────

class _StubCallbacks implements EditorCallbacks {
  // Real English localizations — ADR-014 zone-creation commands read
  // `l10n.undo_createZone` at construction time (same pattern as
  // select_tool_test.dart).
  @override
  final AppLocalizations l10n = AppLocalizationsEn();

  final List<Room> _rooms;
  final List<HeatingZone> _zones;
  final List<HeatingCircuit> _circuits;
  final List<String> _toasts = [];

  final List<WallSegment> _walls;

  /// The floor's distributor; null to test the no-distributor case.
  ///
  /// One outlet, so its stub tip — where every route starts (ADR-044) —
  /// is at (500, 500): 240 mm in front of the body centre.
  Distributor? distributor = const Distributor(
    id: 'dist-1',
    floorId: 'floor-1',
    position: Point2D(x: 500, y: 740),
    outletCount: 1,
  );

  _StubCallbacks({
    List<Room>? rooms,
    List<HeatingZone>? zones,
    List<HeatingCircuit>? circuits,
    List<WallSegment>? walls,
  }) : _walls = List<WallSegment>.of(walls ?? const []),
       _rooms = List<Room>.of(rooms ?? const []),
       _zones = List<HeatingZone>.of(zones ?? const []),
       _circuits = List<HeatingCircuit>.of(circuits ?? const []);

  @override
  List<Room> get currentRooms => List.unmodifiable(_rooms);
  @override
  List<HeatingZone> get currentZones => List.unmodifiable(_zones);
  @override
  void commitZone(HeatingZone zone) => _zones.add(zone);
  @override
  void showToast(String message) => _toasts.add(message);

  List<String> get toasts => List.unmodifiable(_toasts);

  // ---- Unused stubs ----
  @override
  List<WallSegment> get currentWalls => List.unmodifiable(_walls);
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
  void replaceAllWalls(List<WallSegment> walls) {}
  @override
  void replaceAllWallsAndRooms(List<WallSegment> walls, List<Room> rooms) {}
  @override
  void replaceAllWallsRoomsZones(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
  ) {}
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
  Distributor? get currentDistributor => distributor;
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
  void removeCircuit(String circuitId) {
    _circuits.removeWhere((c) => c.id == circuitId);
  }

  @override
  void clearAllCircuits() => _circuits.clear();
  @override
  List<HeatingCircuit> get currentCircuits => List.unmodifiable(_circuits);
  @override
  void updateZone(HeatingZone zone) {
    final i = _zones.indexWhere((z) => z.id == zone.id);
    if (i >= 0) _zones[i] = zone;
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
  void selectElement(String? type, String? id) {}
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
  double get currentZoom => 1.0;
  @override
  double get currentGridSpacingMm => 100.0;
}

// ── Fixtures ─────────────────────────────────────────────────────────────────
//
// Two rooms side by side. The distributor stands in the left room, on top
// of zone A, with its outlet at (500, 500). Zone B is the zone in the
// other room.

const _zoneA = HeatingZone(
  id: 'zone-a',
  roomId: 'room-a',
  polygon: [
    Point2D(x: 200, y: 200),
    Point2D(x: 3800, y: 200),
    Point2D(x: 3800, y: 3800),
    Point2D(x: 200, y: 3800),
  ],
  tubeTypeId: 'tube-1',
  flooringMaterialId: 'mat-1',
);

const _zoneB = HeatingZone(
  id: 'zone-b',
  roomId: 'room-b',
  polygon: [
    Point2D(x: 4200, y: 200),
    Point2D(x: 7800, y: 200),
    Point2D(x: 7800, y: 3800),
    Point2D(x: 4200, y: 3800),
  ],
  tubeTypeId: 'tube-1',
  flooringMaterialId: 'mat-1',
);

const _mouse = PointerDeviceKind.mouse;

RouteDrawTool _makeTool(_StubCallbacks cb, [UndoRedoService? undo]) =>
    RouteDrawTool(
      callbacks: cb,
      onStateChanged: () {},
      undoRedo: undo ?? UndoRedoService(),
    );

void _click(RouteDrawTool tool, double x, double y) =>
    tool.onTap(Point2D(x: x, y: y), _mouse);

/// Two taps on the same spot — the tool sees a double-click (both are
/// within 200 mm and 300 ms, which always holds in a unit test).
void _doubleClick(RouteDrawTool tool, double x, double y) {
  _click(tool, x, y);
  _click(tool, x, y);
}

HeatingZone _zone(_StubCallbacks cb, String id) =>
    cb.currentZones.firstWhere((z) => z.id == id);

void main() {
  group('RDT: starting the route', () {
    test('RDT-1: a click away from the distributor does not start a route', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final tool = _makeTool(cb);
      _click(tool, 3000, 3000);
      expect(tool.isDrawing, isFalse);
      expect(tool.getInteractionData(), isNull);
    });

    test(
      'RDT-2: a click on the distributor starts the route at its outlet',
      () {
        final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
        final tool = _makeTool(cb);
        _click(tool, 600, 450); // within the distributor hit radius
        expect(tool.isDrawing, isTrue);
        final data = tool.getInteractionData()! as RouteDrawData;
        expect(data.waypoints, const [Point2D(x: 500, y: 500)]);
      },
    );

    test('RDT-3: without a distributor nothing starts', () {
      final cb = _StubCallbacks(zones: const [_zoneA])..distributor = null;
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      expect(tool.isDrawing, isFalse);
    });
  });

  group('RDT: connecting by double-click', () {
    test('RDT-4: single clicks inside the zone the distributor stands in '
        'are route points — they never connect that zone', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _click(tool, 2000, 500); // inside zone A
      _click(tool, 2000, 2000); // inside zone A

      expect(cb.currentCircuits, isEmpty);
      expect(_zone(cb, 'zone-a').circuitId, isNull);
      expect(tool.isDrawing, isTrue);
      final data = tool.getInteractionData()! as RouteDrawData;
      expect(data.waypoints, hasLength(3));
    });

    test('RDT-5: a double-click inside another zone connects that zone and '
        'leaves the zone on the way unconnected', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _click(tool, 2000, 500);
      _click(tool, 2000, 2000);
      _doubleClick(tool, 6000, 2000);

      final circuit = cb.currentCircuits.single;
      expect(circuit.heatingZoneId, 'zone-b');
      expect(circuit.distributorId, 'dist-1');
      expect(_zone(cb, 'zone-b').circuitId, circuit.id);
      expect(_zone(cb, 'zone-a').circuitId, isNull);
      expect(circuit.centerlinePath, const [
        Point2D(x: 500, y: 500),
        Point2D(x: 2000, y: 500),
        Point2D(x: 2000, y: 2000),
        Point2D(x: 6000, y: 2000),
      ]);
      expect(tool.isDrawing, isFalse, reason: 'the tool is ready again');
    });

    test('RDT-6: the zone the distributor stands in can still be connected '
        '— by a double-click inside it', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _doubleClick(tool, 1500, 1500);

      expect(cb.currentCircuits.single.heatingZoneId, 'zone-a');
      expect(_zone(cb, 'zone-a').circuitId, isNotNull);
    });

    test('RDT-7: a double-click outside every zone shows a hint and keeps '
        'the route', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _doubleClick(tool, 4000, 5000); // in no zone

      expect(cb.currentCircuits, isEmpty);
      expect(cb.toasts, contains(cb.l10n.route_doubleClickInZoneToast));
      expect(tool.isDrawing, isTrue);
    });

    test('RDT-8: a double-click in an already connected zone is refused', () {
      final cb = _StubCallbacks(
        zones: [
          _zoneA,
          _zoneB.copyWith(circuitId: 'existing'),
        ],
      );
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _doubleClick(tool, 6000, 2000);

      expect(cb.currentCircuits, isEmpty);
      expect(cb.toasts, contains(cb.l10n.route_zoneAlreadyConnectedToast));
      expect(_zone(cb, 'zone-b').circuitId, 'existing');
    });

    test('RDT-9: the click that starts the route is not half of a '
        'double-click', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _click(tool, 520, 520); // right next to the start, right after it

      expect(cb.currentCircuits, isEmpty);
      expect(cb.toasts, isEmpty);
      expect(tool.isDrawing, isTrue);
    });

    test('RDT-10: Escape discards the route', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _click(tool, 2000, 500);
      tool.cancel();

      expect(tool.isDrawing, isFalse);
      expect(tool.getInteractionData(), isNull);
      expect(cb.currentCircuits, isEmpty);
    });
  });

  group('RDT: supply and return are drawn together', () {
    test('RDT-11: the committed circuit holds a supply and a return pipe, '
        'parallel and one pipe spacing apart', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _click(tool, 500, 2000);
      _doubleClick(tool, 6000, 2000);

      final c = cb.currentCircuits.single;
      expect(c.pipeSpacingMm, 100);
      final pair = PipeLayoutEngine.connectionPipePair(
        centerline: c.centerlinePath,
        pipeSpacingMm: 100,
      );
      expect(c.supplyRoutePath, pair.supply);
      expect(c.returnRoutePath, pair.back);

      // Both are tied to the distributor.
      expect(c.supplyRoutePath.first, const Point2D(x: 500, y: 500));
      expect(c.returnRoutePath.last, const Point2D(x: 500, y: 500));
      // Along the last section (y = 2000) they run 50 mm either side.
      expect(c.supplyRoutePath.last.y, 2050.0);
      expect(c.returnRoutePath.first.y, 1950.0);
      // Each pipe enters zone B on its own.
      final entry = PipeLayoutEngine.zoneEntryPoint(
        polygon: _zoneB.polygon,
        supplyRoutePath: c.supplyRoutePath,
      );
      final exit = PipeLayoutEngine.zoneExitPoint(
        polygon: _zoneB.polygon,
        returnRoutePath: c.returnRoutePath,
      );
      expect(entry, const Point2D(x: 4200, y: 2050));
      expect(exit, const Point2D(x: 4200, y: 1950));
    });

    test('RDT-12: a new circuit takes its distances and insulation from '
        'the pipes drawn last', () {
      final previous = relaidConnectionPipes(
        const HeatingCircuit(
          id: 'previous',
          distributorId: 'dist-1',
          heatingZoneId: 'zone-a',
          pipeSpacingMm: 160,
          zoneClearanceMm: 220,
          wallClearanceMm: 80,
          supplyPipeInsulationType: SupplyPipeInsulationType.insulationLayer,
        ),
        const [],
        centerline: const [Point2D(x: 500, y: 500), Point2D(x: 1500, y: 1500)],
      );
      final cb = _StubCallbacks(
        zones: [
          _zoneA.copyWith(circuitId: 'previous'),
          _zoneB,
        ],
        circuits: [previous],
      );
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _doubleClick(tool, 6000, 2000);

      final c = cb.currentCircuits.last;
      expect(c.pipeSpacingMm, 160);
      expect(c.zoneClearanceMm, 220);
      expect(c.wallClearanceMm, 80);
      expect(
        c.supplyPipeInsulationType,
        SupplyPipeInsulationType.insulationLayer,
      );
    });
  });

  group('RDT: no crossing inside the connected zone (ADR-041)', () {
    for (final (name, viaY) in [
      ('return above supply', 2000.0),
      ('supply above return', 1000.0),
    ]) {
      test('RDT-18: double-click connects; the zone tube starts at the '
          'supply, ends at the return and its leads cross nothing '
          '($name)', () {
        final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
        final tool = _makeTool(cb);
        _click(tool, 500, 500);
        _click(tool, 500, viaY);
        _doubleClick(tool, 6000, viaY);

        final c = cb.currentCircuits.single;
        final entry = PipeLayoutEngine.zoneEntryPoint(
          polygon: _zoneB.polygon,
          supplyRoutePath: c.supplyRoutePath,
        )!;
        final exit = PipeLayoutEngine.zoneExitPoint(
          polygon: _zoneB.polygon,
          returnRoutePath: c.returnRoutePath,
        )!;
        final tube = PipeLayoutEngine.meanderPath(
          polygon: _zoneB.polygon,
          tubeSpacingMm: _zoneB.tubeSpacingMm,
          borderDistanceMm: _zoneB.borderDistanceMm,
          entryPoint: entry,
          exitPoint: exit,
        );
        expect(tube.first, entry);
        expect(tube.last, exit);
        expect(PipeLayoutEngine.leadCrossings(tube), 0);
      });
    }
  });

  group('RDT: undo and redo (ADR-042)', () {
    test('RDT-19: undo removes the drawn pipes and disconnects the zone; '
        'redo brings back the identical circuit', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final undo = UndoRedoService();
      final tool = _makeTool(cb, undo);
      _click(tool, 500, 500);
      _click(tool, 500, 2000);
      _doubleClick(tool, 6000, 2000);
      final drawn = cb.currentCircuits.single;
      expect(undo.canUndo, isTrue);

      undo.undo();
      expect(cb.currentCircuits, isEmpty);
      expect(_zone(cb, 'zone-b').circuitId, isNull);
      expect(undo.canRedo, isTrue);

      undo.redo();
      expect(cb.currentCircuits.single, drawn);
      expect(_zone(cb, 'zone-b').circuitId, drawn.id);

      undo.undo();
      expect(cb.currentCircuits, isEmpty);
      expect(
        undo.canUndo,
        isFalse,
        reason: 'drawing one pair is exactly one undo entry',
      );
    });

    test('RDT-20: a refused double-click leaves nothing to undo', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final undo = UndoRedoService();
      final tool = _makeTool(cb, undo);
      _click(tool, 500, 500);
      _doubleClick(tool, 4000, 5000);
      expect(undo.canUndo, isFalse);
    });
  });

  group('RDT: live preview', () {
    test('RDT-13: while the cursor moves, both pipes are laid out up to '
        'the cursor', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _click(tool, 500, 2000);
      tool.onPointerMove(const Point2D(x: 3020, y: 1990));

      final data = tool.getInteractionData()! as RouteDrawData;
      // Cursor is grid-snapped to (3000, 2000).
      final pair = PipeLayoutEngine.connectionPipePair(
        centerline: const [
          Point2D(x: 500, y: 500),
          Point2D(x: 500, y: 2000),
          Point2D(x: 3000, y: 2000),
        ],
        pipeSpacingMm: 100,
      );
      expect(data.supplyPoints, pair.supply);
      expect(data.returnPoints, pair.back);
      // Only placed points are marked — not the cursor.
      expect(data.waypoints, const [
        Point2D(x: 500, y: 500),
        Point2D(x: 500, y: 2000),
      ]);
      expect(
        data.cumulativeLengthMm,
        closeTo(
          GeometryEngine.polylineLengthMm(pair.supply) +
              GeometryEngine.polylineLengthMm(pair.back),
          1e-6,
        ),
      );
    });

    test('RDT-14: the preview follows every pointer move', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB]);
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      tool.onPointerMove(const Point2D(x: 1500, y: 500));
      final first = (tool.getInteractionData()! as RouteDrawData).supplyPoints;
      tool.onPointerMove(const Point2D(x: 1500, y: 1500));
      final second = (tool.getInteractionData()! as RouteDrawData).supplyPoints;
      expect(first.last, const Point2D(x: 1500, y: 550));
      expect(second.last, isNot(first.last));
    });

    test('RDT-15: the preview says whether a double-click would connect', () {
      final cb = _StubCallbacks(
        zones: [
          _zoneA,
          _zoneB.copyWith(circuitId: 'existing'),
        ],
      );
      final tool = _makeTool(cb);
      _click(tool, 500, 500);

      tool.onPointerMove(const Point2D(x: 2000, y: 2000)); // zone A, free
      var data = tool.getInteractionData()! as RouteDrawData;
      expect(data.hoveredZoneConnectable, isTrue);
      expect(data.hoveredZoneAlreadyConnected, isFalse);

      tool.onPointerMove(const Point2D(x: 6000, y: 2000)); // zone B, taken
      data = tool.getInteractionData()! as RouteDrawData;
      expect(data.hoveredZoneConnectable, isFalse);
      expect(data.hoveredZoneAlreadyConnected, isTrue);

      tool.onPointerMove(const Point2D(x: 4000, y: 5000)); // no zone
      data = tool.getInteractionData()! as RouteDrawData;
      expect(data.hoveredZoneConnectable, isFalse);
      expect(data.hoveredZoneAlreadyConnected, isFalse);
    });
  });

  group('RDT: wall distance while drawing', () {
    // Wall along y = 0, 200 mm thick: its face is at y = 100.
    const wall = WallSegment(
      id: 'w-top',
      roomId: 'room-a',
      startPoint: Point2D(x: 0, y: 0),
      endPoint: Point2D(x: 8000, y: 0),
      thicknessMm: 200,
    );

    test('RDT-16: a section drawn along a wall is shown — and committed — '
        'at the wall distance', () {
      final cb = _StubCallbacks(
        zones: const [_zoneA, _zoneB],
        walls: const [wall],
      );
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _click(tool, 1000, 300); // 200 mm off the face
      tool.onPointerMove(const Point2D(x: 3000, y: 300));

      // Live: face 100 + distance 100 + half spacing 50 = 250.
      final data = tool.getInteractionData()! as RouteDrawData;
      final ys = [data.supplyPoints.last.y, data.returnPoints.first.y]..sort();
      expect(ys, [200.0, 300.0]);

      _doubleClick(tool, 6000, 300);
      final c = cb.currentCircuits.single;
      expect(c.centerlinePath.last, const Point2D(x: 6000, y: 250));
      expect(c.centerlinePath[1], const Point2D(x: 1000, y: 250));
      expect(
        c.centerlinePath.first,
        const Point2D(x: 500, y: 500),
        reason: 'the end on the distributor does not move',
      );
    });

    test('RDT-17: a route through the middle of the room is not pulled to '
        'a wall', () {
      final cb = _StubCallbacks(
        zones: const [_zoneA, _zoneB],
        walls: const [wall],
      );
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      _click(tool, 500, 2000);
      _doubleClick(tool, 6000, 2000);

      expect(cb.currentCircuits.single.centerlinePath, const [
        Point2D(x: 500, y: 500),
        Point2D(x: 500, y: 2000),
        Point2D(x: 6000, y: 2000),
      ]);
    });
  });

  group('RDT: distributor outlets (ADR-044)', () {
    // 500 mm wide, 4 outlets: stub tips at x = 312.5, 437.5, 562.5,
    // 687.5 on y = 500.
    const four = Distributor(
      id: 'dist-1',
      floorId: 'floor-1',
      position: Point2D(x: 500, y: 740),
      outletCount: 4,
    );

    test('RDT-21: the route starts at the outlet nearest the click; supply '
        'and return both attach to that one stub', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB])
        ..distributor = four;
      final tool = _makeTool(cb);
      _click(tool, 690, 520);
      _click(tool, 700, 2000);
      _doubleClick(tool, 6000, 2000);

      final c = cb.currentCircuits.single;
      const tip = Point2D(x: 687.5, y: 500);
      expect(c.outletIndex, 3);
      expect(c.centerlinePath.first, tip);
      expect(c.supplyRoutePath.first, tip);
      expect(c.returnRoutePath.last, tip);
    });

    test('RDT-22: an outlet already in use is skipped for the nearest free '
        'one', () {
      final cb = _StubCallbacks(
        zones: const [_zoneA, _zoneB],
        circuits: const [
          HeatingCircuit(
            id: 'c-0',
            distributorId: 'dist-1',
            heatingZoneId: 'zone-x',
            outletIndex: 3,
          ),
        ],
      )..distributor = four;
      final tool = _makeTool(cb);
      _click(tool, 690, 520);
      final data = tool.getInteractionData()! as RouteDrawData;
      expect(data.waypoints.first, const Point2D(x: 562.5, y: 500));
    });

    test('RDT-23: with every outlet in use nothing starts and a toast says '
        'so', () {
      final cb = _StubCallbacks(
        zones: const [_zoneA, _zoneB],
        circuits: const [
          HeatingCircuit(
            id: 'c-0',
            distributorId: 'dist-1',
            heatingZoneId: 'zone-x',
            outletIndex: 0,
          ),
        ],
      ); // the default fixture has one outlet
      final tool = _makeTool(cb);
      _click(tool, 500, 500);
      expect(tool.isDrawing, isFalse);
      expect(cb.toasts, [cb.l10n.route_allOutletsInUseToast(1)]);
    });

    test('RDT-24: the whole body counts as the distributor, also when it '
        'is wide and turned', () {
      final cb = _StubCallbacks(zones: const [_zoneA, _zoneB])
        ..distributor = const Distributor(
          id: 'dist-1',
          floorId: 'floor-1',
          position: Point2D(x: 2000, y: 2000),
          widthMm: 2000,
          rotationDeg: 90,
          outletCount: 8,
        );
      final tool = _makeTool(cb);
      // Turned 90° clockwise: the body runs along y, outlets face +x.
      // Near its lower end — 900 mm from the centre.
      _click(tool, 2000, 2900);
      expect(tool.isDrawing, isTrue);
      final start = (tool.getInteractionData()! as RouteDrawData)
          .waypoints
          .first;
      // Last outlet: 875 mm along the body, 240 mm in front of it.
      expect(start.x, closeTo(2240, 1e-6));
      expect(start.y, closeTo(2875, 1e-6));
    });
  });
}
