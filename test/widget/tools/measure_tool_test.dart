// Tests for MeasureTool — ADR-030.
//
// MeasureTool is exercised directly (no widget pump) via a stub
// EditorCallbacks. It is purely visual: it never mutates editor state,
// so the assertions read the MeasureData it emits from getInteractionData().
//
// Snapping is opt-in (ADR-031): off by default, enabled while Shift is
// held. Tests drive the flag through MeasureTool.updateSnapEnabled with
// the hardware re-sync disabled via the test seam.
//
// Covered scenarios:
//   MT-1  First tap sets the start point; getInteractionData reports a
//         zero-length, non-finalized measurement at that point.
//   MT-2  Default (no Shift): pointer move tracks the RAW cursor — no
//         snap pulls the end point off the cursor.
//   MT-2b Shift held: pointer move snaps the end point to the grid.
//   MT-3  Second tap finalizes the measurement at the resolved point.
//   MT-4  After finalizing, pointer move does NOT move the frozen end.
//   MT-5  A tap after finalizing starts a fresh measurement.
//   MT-6  Escape (cancel()) clears the measurement → getInteractionData null.
//   MT-7  With Shift held, the end snaps to an existing wall endpoint and
//         reports the snap indicator.
//   MT-8  Without Shift, the end does NOT snap to a nearby wall endpoint.
//
// SnapService.gridSpacingMm == 100 mm.

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
import 'package:heating_planner/ui/canvas/painters/interaction_data.dart';
import 'package:heating_planner/ui/canvas/tools/editor_callbacks.dart';
import 'package:heating_planner/ui/canvas/tools/measure_tool.dart';

// ── Stub EditorCallbacks ─────────────────────────────────────────────────────

class _StubCallbacks implements EditorCallbacks {
  _StubCallbacks([List<WallSegment> walls = const []])
      : _walls = List.of(walls);

  final List<WallSegment> _walls;

  @override
  List<WallSegment> get currentWalls => List.unmodifiable(_walls);

  @override
  double get currentGridSpacingMm => 100.0;

  // ---- Unused stubs ----
  @override
  Never get l10n => throw UnimplementedError();
  @override
  void commitWall(WallSegment wall) {}
  @override
  WallSegment commitWallWithSplit(WallSegment wall, {bool splitNewWall = true}) =>
      wall;
  @override
  void updateWall(WallSegment wall) {}
  @override
  void updateWallTransient(WallSegment wall) {}
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
  void updateRoomTransient(Room room) {}
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
  void updateWindowTransient(WindowElement window) {}
  @override
  void removeWindow(String windowId) {}
  @override
  void commitDoor(Door door) {}
  @override
  void updateDoor(Door door) {}
  @override
  void updateDoorTransient(Door door) {}
  @override
  void removeDoor(String doorId) {}
  @override
  void commitDistributor(Distributor distributor) {}
  @override
  void updateDistributor(Distributor distributor) {}
  @override
  void updateDistributorTransient(Distributor distributor) {}
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
  void updateZoneTransient(HeatingZone zone) {}
  @override
  void removeZone(String zoneId) {}
  @override
  String get currentFloorId => 'floor-1';
  @override
  String get defaultTubeTypeId => 'tube-1';
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
  void showToast(String message) {}
  @override
  void requestZoneContextMenu(ZoneContextMenuRequest request) {}
  @override
  List<Room> get currentRooms => const [];
  @override
  List<WindowElement> get currentWindows => const [];
  @override
  List<Door> get currentDoors => const [];
  @override
  List<HeatingZone> get currentZones => const [];
  @override
  double get currentZoom => 1.0;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

MeasureTool _makeTool(_StubCallbacks callbacks) =>
    MeasureTool(callbacks: callbacks, onStateChanged: () {});

const _mouse = PointerDeviceKind.mouse;

MeasureData? _data(MeasureTool tool) =>
    tool.getInteractionData() as MeasureData?;

void main() {
  // Disable the live-hardware re-sync so tests fully control the snap flag.
  setUp(() => MeasureTool.debugDisableHardwareSync = true);
  tearDown(() => MeasureTool.debugDisableHardwareSync = false);

  test('MT-1: first tap sets start point, non-finalized zero length', () {
    final tool = _makeTool(_StubCallbacks());
    tool.onTap(const Point2D(x: 1000, y: 2000), _mouse);

    final d = _data(tool)!;
    expect(d.start, const Point2D(x: 1000, y: 2000));
    expect(d.end, const Point2D(x: 1000, y: 2000));
    expect(d.finalized, isFalse);
  });

  test('MT-2: default (no Shift) tracks the raw cursor — no snap', () {
    final tool = _makeTool(_StubCallbacks());
    tool.onTap(const Point2D(x: 0, y: 0), _mouse);
    tool.onPointerMove(const Point2D(x: 1230, y: 40)); // raw, not snapped

    final d = _data(tool)!;
    expect(d.start, const Point2D(x: 0, y: 0));
    expect(d.end, const Point2D(x: 1230, y: 40));
    expect(d.snapEnabled, isFalse);
    expect(d.snapIndicator, isNull);
  });

  test('MT-2b: Shift held snaps the end point to the grid', () {
    final tool = _makeTool(_StubCallbacks())..updateSnapEnabled(true);
    tool.onTap(const Point2D(x: 0, y: 0), _mouse);
    tool.onPointerMove(const Point2D(x: 1230, y: 40)); // → snaps to 1200,0

    final d = _data(tool)!;
    expect(d.end, const Point2D(x: 1200, y: 0));
    expect(d.snapEnabled, isTrue);
  });

  test('MT-3: second tap finalizes the measurement', () {
    final tool = _makeTool(_StubCallbacks());
    tool.onTap(const Point2D(x: 0, y: 0), _mouse);
    tool.onPointerMove(const Point2D(x: 2000, y: 0));
    tool.onTap(const Point2D(x: 2000, y: 0), _mouse);

    final d = _data(tool)!;
    expect(d.start, const Point2D(x: 0, y: 0));
    expect(d.end, const Point2D(x: 2000, y: 0));
    expect(d.finalized, isTrue);
  });

  test('MT-4: pointer move after finalizing does not move the end', () {
    final tool = _makeTool(_StubCallbacks());
    tool.onTap(const Point2D(x: 0, y: 0), _mouse);
    tool.onTap(const Point2D(x: 2000, y: 0), _mouse);
    tool.onPointerMove(const Point2D(x: 5000, y: 5000));

    final d = _data(tool)!;
    expect(d.end, const Point2D(x: 2000, y: 0));
    expect(d.finalized, isTrue);
  });

  test('MT-5: a tap after finalizing starts a fresh measurement', () {
    final tool = _makeTool(_StubCallbacks());
    tool.onTap(const Point2D(x: 0, y: 0), _mouse);
    tool.onTap(const Point2D(x: 2000, y: 0), _mouse);
    tool.onTap(const Point2D(x: 3000, y: 3000), _mouse);

    final d = _data(tool)!;
    expect(d.start, const Point2D(x: 3000, y: 3000));
    expect(d.end, const Point2D(x: 3000, y: 3000));
    expect(d.finalized, isFalse);
  });

  test('MT-6: cancel clears the measurement', () {
    final tool = _makeTool(_StubCallbacks());
    tool.onTap(const Point2D(x: 0, y: 0), _mouse);
    tool.cancel();

    expect(tool.getInteractionData(), isNull);
  });

  test('MT-7: Shift held — end snaps to a wall endpoint, reports indicator', () {
    const wall = WallSegment(
      id: 'w1',
      roomId: '',
      startPoint: Point2D(x: 5000, y: 5000),
      endPoint: Point2D(x: 8000, y: 5000),
    );
    final tool = _makeTool(_StubCallbacks([wall]))..updateSnapEnabled(true);
    tool.onTap(const Point2D(x: 0, y: 0), _mouse);
    // Within endpoint threshold (200 mm) of the wall's start corner.
    tool.onPointerMove(const Point2D(x: 5050, y: 5050));

    final d = _data(tool)!;
    expect(d.end, const Point2D(x: 5000, y: 5000));
    expect(d.snapIndicator, const Point2D(x: 5000, y: 5000));
  });

  test('MT-8: without Shift, the end does not snap to a nearby endpoint', () {
    const wall = WallSegment(
      id: 'w1',
      roomId: '',
      startPoint: Point2D(x: 5000, y: 5000),
      endPoint: Point2D(x: 8000, y: 5000),
    );
    final tool = _makeTool(_StubCallbacks([wall]));
    tool.onTap(const Point2D(x: 0, y: 0), _mouse);
    tool.onPointerMove(const Point2D(x: 5050, y: 5050)); // raw, near corner

    final d = _data(tool)!;
    expect(d.end, const Point2D(x: 5050, y: 5050));
    expect(d.snapIndicator, isNull);
  });
}
