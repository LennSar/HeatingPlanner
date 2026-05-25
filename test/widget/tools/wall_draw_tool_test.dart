// Tests for WallDrawTool — agent-test.md §6.2.
//
// WallDrawTool is exercised directly (no widget pump) via a stub
// EditorCallbacks. All modifier-key behaviour is driven through
// WallDrawTool.updateModifiers(), which mirrors what the canvas widget
// calls when it processes key events.
//
// Covered scenarios:
//   WDT-1  Two sequential taps create a wall with correct start/end points.
//   WDT-2  Tap at an off-grid position snaps to nearest grid coordinate.
//   WDT-3  Escape (cancel()) after first tap → no wall created.
//   WDT-4  Shift + ortho horizontal: Δx > Δy → endpoint Y locked to anchor Y.
//   WDT-5  Shift + ortho vertical:  Δy > Δx → endpoint X locked to anchor X.
//   WDT-6  Ctrl + drag rectangle → four WallSegments forming a closed rect.
//   WDT-7  Ctrl + drag too small (< 100 mm both dims) → no walls created.
//   WDT-8  Alt + free placement → committed point equals raw tap coordinate.
//
// SnapService.gridSpacingMm == 100 mm.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Drift generates data classes that collide with our freezed models.
import 'package:heating_planner/data/database/app_database.dart'
    hide Distributor, Door, HeatingCircuit, HeatingZone, Room, WallSegment;
import 'package:heating_planner/calculation/engines/geometry_engine.dart';
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
import 'package:heating_planner/ui/canvas/tools/snap_service.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';
import 'package:heating_planner/ui/canvas/tools/wall_draw_tool.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Stub EditorCallbacks ─────────────────────────────────────────────────────

class _StubCallbacks implements EditorCallbacks {
  // Tool tests don't exercise localized labels; throw to flag any
  // future test that needs them.
  @override
  Never get l10n => throw UnimplementedError();

  final List<WallSegment> _walls = [];
  final List<String> _toasts = [];

  @override
  List<WallSegment> get currentWalls => List.unmodifiable(_walls);

  @override
  void commitWall(WallSegment wall) => _walls.add(wall);

  @override
  void commitWallWithSplit(WallSegment wall) => _walls.add(wall);

  @override
  void replaceAllWalls(List<WallSegment> walls) {
    _walls
      ..clear()
      ..addAll(walls);
  }

  @override
  void showToast(String message) => _toasts.add(message);

  // ---- Unused stubs ----
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
  void selectElement(String? type, String? id) {}
  @override
  void requestRoomDialog(List<Point2D> polygon, List<String> wallIds, {void Function(List<WallSegment>, List<Room>)? onCreated}) {}
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
  @override
  double get currentGridSpacingMm => 100.0;
}

// ── Factory ──────────────────────────────────────────────────────────────────

WallDrawTool _makeTool(_StubCallbacks callbacks) {
  return WallDrawTool(
    callbacks: callbacks,
    onStateChanged: () {},
    undoRedo: UndoRedoService(),
  );
}

// ── Room-aware stub (WDT-9 only) ─────────────────────────────────────────────
//
// Extends _StubCallbacks with two behaviours needed to test shared-wall
// detection across two sequential Ctrl+drag rooms:
//
//   replaceAllWallsAndRooms — actually commits both collections so that
//     subsequent callbacks.currentWalls / currentRooms calls reflect the
//     post-drag state (the base stub is a no-op).
//
//   requestRoomDialog — synchronously simulates addRoomFromDetection:
//     tags every wall listed in wallIds with a fresh roomId so that the
//     second rect-drag's _findMatchingWall skips walls with empty roomId.
//     Then calls onCreated so that _RectDrawCommand.newWalls is updated.

class _RoomAwareStubCallbacks implements EditorCallbacks {
  // Tool tests don't exercise localized labels; throw to flag any
  // future test that needs them.
  @override
  Never get l10n => throw UnimplementedError();

  final List<WallSegment> _walls = [];
  final List<Room> _rooms = [];
  int _roomSeq = 0;

  @override
  List<WallSegment> get currentWalls => List.unmodifiable(_walls);
  @override
  List<Room> get currentRooms => List.unmodifiable(_rooms);

  @override
  void commitWall(WallSegment wall) => _walls.add(wall);
  @override
  void commitWallWithSplit(WallSegment wall) => _walls.add(wall);

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
  void requestRoomDialog(
    List<Point2D> polygon,
    List<String> wallIds, {
    void Function(List<WallSegment>, List<Room>)? onCreated,
  }) {
    if (onCreated == null) return;
    // Tag every detected wall with a non-empty roomId so the next
    // rect-drag's _findMatchingWall can recognise them as room-assigned.
    _roomSeq++;
    final roomId = 'room-$_roomSeq';
    final ids = wallIds.toSet();
    final updated = _walls
        .map((w) => ids.contains(w.id) ? w.copyWith(roomId: roomId) : w)
        .toList();
    _walls
      ..clear()
      ..addAll(updated);
    final newRoom = Room(
      id: roomId,
      floorId: 'floor-1',
      name: 'Room $_roomSeq',
      targetTempC: 20.0,
      polygon: polygon,
    );
    _rooms.add(newRoom);
    onCreated(List.unmodifiable(_walls), List.unmodifiable(_rooms));
  }

  @override
  void requestZoneContextMenu(ZoneContextMenuRequest request) {}

  @override
  void showToast(String message) {}

  // ---- Unused stubs ----
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
  void selectElement(String? type, String? id) {}
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

// ── Geometry helper ───────────────────────────────────────────────────────────

/// Returns the bounding-box span of [pts] along [axis] (width or height).
double _polySpan(List<Point2D> pts, double Function(Point2D) axis) {
  final vals = pts.map(axis).toList();
  final hi = vals.reduce((a, b) => a > b ? a : b);
  final lo = vals.reduce((a, b) => a < b ? a : b);
  return hi - lo;
}

// ── Provider-backed callbacks adapter (WDT-13 / WDT-14) ──────────────────────
//
// Routes every wall-creation call to a real EditorStateNotifier so the
// ADR-017 Rule 1 (thickness defaults) and Rule 2 (anchorMode defaults)
// applied inside `addWall` / `commitWallWithSplit` execute exactly as in
// production. Without this adapter the stub-based callbacks above never
// touch the notifier and Rule 1/2 are bypassed.

class _ProviderWallDrawCallbacks implements EditorCallbacks {
  _ProviderWallDrawCallbacks(this._container);

  final ProviderContainer _container;

  EditorStateNotifier get _n =>
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
  void destroyRoomCascade(String roomId) =>
      _n.destroyRoomCascade(roomId);

  @override
  void replaceAllForRoomCascade(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
    List<WindowElement> windows,
    List<Door> doors,
  ) =>
      _n.replaceAllForRoomCascade(walls, rooms, zones, windows, doors);

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
    Map<String, WallSegment>? movedSideProperties,
  }) =>
      _n.addRoomFromDetection(
        room: room,
        wallIds: wallIds,
        movedSideProperties: movedSideProperties,
      );

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
  void showToast(String message) {}

  @override
  double get currentZoom => 1.0;
  @override
  double get currentGridSpacingMm => 100.0;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  // WDT-1 ────────────────────────────────────────────────────────────────────

  test(
    'WDT-1: two sequential taps create a wall with correct start and end',
    () {
      final cb = _StubCallbacks();
      final tool = _makeTool(cb);

      const start = Point2D(x: 0, y: 0);
      const end = Point2D(x: 5000, y: 0);

      tool.onTap(start, PointerDeviceKind.mouse);
      tool.onTap(end, PointerDeviceKind.mouse);

      expect(cb.currentWalls, hasLength(1));
      final wall = cb.currentWalls.first;
      expect(wall.startPoint.x, closeTo(0, 0.5));
      expect(wall.startPoint.y, closeTo(0, 0.5));
      expect(wall.endPoint.x, closeTo(5000, 0.5));
      expect(wall.endPoint.y, closeTo(0, 0.5));
    },
  );

  // WDT-2 ────────────────────────────────────────────────────────────────────

  test(
    'WDT-2: tap at off-grid position snaps to nearest 100 mm grid coordinate',
    () {
      final cb = _StubCallbacks();
      final tool = _makeTool(cb);

      // 130 mm → snaps to 100; 270 mm → snaps to 300.
      // Length = sqrt((100-0)² + (300-0)²) ≈ 316 mm > 100 mm → commits.
      const rawStart = Point2D(x: 0, y: 0);
      const rawEnd = Point2D(x: 130, y: 270);

      tool.onTap(rawStart, PointerDeviceKind.mouse);
      tool.onTap(rawEnd, PointerDeviceKind.mouse);

      expect(cb.currentWalls, hasLength(1));
      final wall = cb.currentWalls.first;

      // Start: (0, 0) is already on-grid.
      expect(wall.startPoint.x % SnapService.gridSpacingMm, closeTo(0, 0.5));
      expect(wall.startPoint.y % SnapService.gridSpacingMm, closeTo(0, 0.5));
      // End: x → 100, y → 300.
      expect(wall.endPoint.x, closeTo(100, 0.5));
      expect(wall.endPoint.y, closeTo(300, 0.5));
    },
  );

  // WDT-3 ────────────────────────────────────────────────────────────────────

  test(
    'WDT-3: cancel() after first tap clears state and leaves no wall',
    () {
      final cb = _StubCallbacks();
      final tool = _makeTool(cb);

      tool.onTap(const Point2D(x: 0, y: 0), PointerDeviceKind.mouse);
      tool.cancel(); // simulates Escape

      // A second tap now acts as a fresh first click, not a commit.
      tool.onTap(const Point2D(x: 5000, y: 0), PointerDeviceKind.mouse);

      expect(cb.currentWalls, isEmpty);
    },
  );

  // WDT-4 ────────────────────────────────────────────────────────────────────

  test(
    'WDT-4: Shift + ortho horizontal — Δx > Δy → endpoint Y locked to anchor Y',
    () {
      final cb = _StubCallbacks();
      final tool = _makeTool(cb);

      // Anchor at origin.
      tool.onTap(const Point2D(x: 0, y: 0), PointerDeviceKind.mouse);
      // Enable ortho.
      tool.updateModifiers(shift: true, ctrl: false, alt: false);
      // Cursor is further in X than Y (Δx=3000 > Δy=500).
      tool.onTap(const Point2D(x: 3000, y: 500), PointerDeviceKind.mouse);

      expect(cb.currentWalls, hasLength(1));
      final wall = cb.currentWalls.first;
      // Y must be locked to anchor Y = 0.
      expect(wall.endPoint.y, closeTo(0, 0.5));
      expect(wall.endPoint.x, closeTo(3000, 0.5));
    },
  );

  // WDT-5 ────────────────────────────────────────────────────────────────────

  test(
    'WDT-5: Shift + ortho vertical — Δy > Δx → endpoint X locked to anchor X',
    () {
      final cb = _StubCallbacks();
      final tool = _makeTool(cb);

      // Anchor at origin.
      tool.onTap(const Point2D(x: 0, y: 0), PointerDeviceKind.mouse);
      // Enable ortho.
      tool.updateModifiers(shift: true, ctrl: false, alt: false);
      // Cursor is further in Y than X (Δy=3000 > Δx=500).
      tool.onTap(const Point2D(x: 500, y: 3000), PointerDeviceKind.mouse);

      expect(cb.currentWalls, hasLength(1));
      final wall = cb.currentWalls.first;
      // X must be locked to anchor X = 0.
      expect(wall.endPoint.x, closeTo(0, 0.5));
      expect(wall.endPoint.y, closeTo(3000, 0.5));
    },
  );

  // WDT-6 ────────────────────────────────────────────────────────────────────

  test(
    'WDT-6: Ctrl+drag rectangle → four WallSegments forming a closed rect',
    () {
      final cb = _StubCallbacks();
      final tool = _makeTool(cb);

      tool.updateModifiers(shift: false, ctrl: true, alt: false);

      const a = Point2D(x: 0, y: 0);
      const b = Point2D(x: 2000, y: 1000);

      tool.onPointerDown(a, 1);
      tool.onDragEnd(b);

      expect(cb.currentWalls, hasLength(4));

      // Collect all endpoints.
      final pts = <Point2D>{};
      for (final w in cb.currentWalls) {
        pts.add(w.startPoint);
        pts.add(w.endPoint);
      }
      // Must have exactly the four corners.
      expect(pts, hasLength(4));

      // Every wall must connect to the next (closed polygon).
      for (int i = 0; i < cb.currentWalls.length; i++) {
        final current = cb.currentWalls[i];
        final next = cb.currentWalls[(i + 1) % cb.currentWalls.length];
        expect(
          GeometryEngine.distanceMm(current.endPoint, next.startPoint),
          closeTo(0, 0.5),
          reason: 'Wall $i endPoint must equal wall ${(i + 1) % 4} startPoint',
        );
      }
    },
  );

  // WDT-7 ────────────────────────────────────────────────────────────────────

  test(
    'WDT-7: Ctrl+drag both dims < 100 mm → no walls and toast shown',
    () {
      final cb = _StubCallbacks();
      final tool = _makeTool(cb);

      // Alt disables grid snap so the raw 50×50 mm is preserved.
      tool.updateModifiers(shift: false, ctrl: true, alt: true);

      // 50 × 50 mm (raw) — both below 100 mm threshold.
      tool.onPointerDown(const Point2D(x: 0, y: 0), 1);
      tool.onDragEnd(const Point2D(x: 50, y: 50));

      expect(cb.currentWalls, isEmpty);
      expect(cb._toasts, isNotEmpty);
    },
  );

  // WDT-8 ────────────────────────────────────────────────────────────────────

  test(
    'WDT-8: Alt + free placement → committed point equals raw tap coordinate',
    () {
      final cb = _StubCallbacks();
      final tool = _makeTool(cb);

      tool.updateModifiers(shift: false, ctrl: false, alt: true);

      // Off-grid start.
      const rawStart = Point2D(x: 123, y: 456);
      // Off-grid end, far enough away to pass the min-length check.
      const rawEnd = Point2D(x: 1123, y: 456);

      tool.onTap(rawStart, PointerDeviceKind.mouse);
      tool.onTap(rawEnd, PointerDeviceKind.mouse);

      expect(cb.currentWalls, hasLength(1));
      final wall = cb.currentWalls.first;
      // No rounding applied.
      expect(wall.startPoint.x, closeTo(123, 0.5));
      expect(wall.startPoint.y, closeTo(456, 0.5));
      expect(wall.endPoint.x, closeTo(1123, 0.5));
      expect(wall.endPoint.y, closeTo(456, 0.5));
    },
  );

  // WDT-9 ────────────────────────────────────────────────────────────────────
  //
  // Two same-size adjacent rooms drawn with Ctrl+drag must share exactly one
  // wall at the common boundary — no duplicate.
  //
  // Room 1: (0,0) → (3000,3000).  Produces 4 walls tagged with roomId='room-1'
  //   via the _RoomAwareStubCallbacks.requestRoomDialog simulation.
  // Room 2: (3000,0) → (6000,3000).  Its left edge (3000,3000)→(3000,0)
  //   reverse-matches Room 1's right wall (3000,0)→(3000,3000), so
  //   _findMatchingWall reuses it and no new wall is committed for that edge.
  //
  // Pass: exactly 1 wall whose both endpoints lie at x ≈ 3000.
  // Fail: 2 or more such walls (duplicate shared-edge regression).

  test(
    'WDT-9: two same-size Ctrl+drag rooms share exactly one wall at the common edge',
    () {
      final cb = _RoomAwareStubCallbacks();
      final tool = WallDrawTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: UndoRedoService(),
      );

      tool.updateModifiers(shift: false, ctrl: true, alt: false);

      // ── Room 1: (0,0) → (3000,3000) ──────────────────────────────────────
      tool.onPointerDown(const Point2D(x: 0, y: 0), 1);
      tool.onDragEnd(const Point2D(x: 3000, y: 3000));

      // The stub's requestRoomDialog ran synchronously and tagged all four
      // walls with roomId='room-1'.
      expect(cb.currentWalls, hasLength(4),
          reason: 'Room 1 should produce exactly 4 walls');

      // ── Room 2: (3000,0) → (6000,3000) ───────────────────────────────────
      // Same 3000×3000 mm size, starting at Room 1's top-right corner.
      // The left edge of Room 2 coincides with Room 1's right wall
      // (3000,0)→(3000,3000), which now has a non-empty roomId.
      // _findMatchingWall must detect and reuse it → only 3 new walls added.
      tool.onPointerDown(const Point2D(x: 3000, y: 0), 1);
      tool.onDragEnd(const Point2D(x: 6000, y: 3000));

      // 4 (Room 1) + 3 (Room 2 new) = 7 total; NOT 8.
      expect(cb.currentWalls, hasLength(7),
          reason: 'Shared edge must not produce a duplicate wall');

      // ── Shared-edge assertion ─────────────────────────────────────────────
      // Exactly one wall should have both endpoints at x ≈ 3000
      // (the shared vertical boundary between the two rooms).
      final sharedEdgeWalls = cb.currentWalls
          .where(
            (w) =>
                (w.startPoint.x - 3000.0).abs() < 1.0 &&
                (w.endPoint.x - 3000.0).abs() < 1.0,
          )
          .toList();

      expect(
        sharedEdgeWalls,
        hasLength(1),
        reason:
            'Exactly one wall should exist at the shared vertical boundary x=3000',
      );
    },
  );

  // WDT-10 ───────────────────────────────────────────────────────────────────
  //
  // Clicking near an existing wall endpoint snaps the new wall's start to that
  // corner, overriding grid snap.
  //
  // Endpoint snap threshold: 200 mm (SnapService.endpointThresholdMm).
  // Grid spacing: 100 mm.
  //
  // Test point (3060, 80):
  //   • distance to anchor (3000, 0) = √(60²+80²) = 100 mm  → inside threshold
  //   • grid snap alone  → (3100, 100)                       → DIFFERENT corner
  //
  // If endpoint snap works, startPoint = (3000, 0).
  // If endpoint snap is broken, grid snap gives (3100, 100) and the test fails.

  test(
    'WDT-10: tap within endpoint snap threshold pins new wall start to existing corner',
    () {
      final cb = _StubCallbacks();
      // Pre-populate a wall whose right endpoint is the anchor at (3000, 0).
      cb.commitWall(const WallSegment(
        id: 'w-anchor',
        roomId: '',
        startPoint: Point2D(x: 0, y: 0),
        endPoint: Point2D(x: 3000, y: 0),
      ));

      final tool = _makeTool(cb);

      // First tap: 100 mm from (3000, 0), inside the 200 mm endpoint threshold.
      // Without endpoint snap, grid would land this at (3100, 100).
      tool.onTap(const Point2D(x: 3060, y: 80), PointerDeviceKind.mouse);
      // Second tap: 2 m above the anchor, cleanly on-grid.
      tool.onTap(const Point2D(x: 3000, y: 2000), PointerDeviceKind.mouse);

      // Pre-existing wall + newly committed wall.
      expect(cb.currentWalls, hasLength(2));

      // The new wall must begin at the snapped anchor, not the grid fallback.
      final newWall = cb.currentWalls.last;
      expect(
        newWall.startPoint.x,
        closeTo(3000, 0.5),
        reason: 'endpoint snap should pin x to 3000, not grid x=3100',
      );
      expect(
        newWall.startPoint.y,
        closeTo(0, 0.5),
        reason: 'endpoint snap should pin y to 0, not grid y=100',
      );
    },
  );

  // WDT-11 ───────────────────────────────────────────────────────────────────
  //
  // Combination of WDT-9 and WDT-10: drawing a second room adjacent to the
  // first by starting near a corner and dragging diagonally to approximately
  // the same size results in:
  //   (a) the drag-start snapping to the existing corner (WDT-10),
  //   (b) the drag-end snapping via grid to produce the same dimensions, and
  //   (c) exactly one shared wall between the two rooms (WDT-9).
  //
  // Room 1: (0,0) → (3000,3000) — 3 m × 3 m.
  //
  // Drag-start for Room 2: (3060, 80)
  //   • 100 mm from (3000,0) → inside the 200 mm endpoint threshold
  //   • grid alone would land at (3100, 100) — a different corner
  //   → endpoint snap wins → _dragStart = (3000, 0)  ✓
  //
  // Drag-end for Room 2: (5970, 2980)
  //   • no wall endpoint within 200 mm — snapRectCorner does not help
  //   • grid snap: 5970 → 6000, 2980 → 3000 → (6000, 3000)
  //   • Room 2 width  = 6000 − 3000 = 3000 mm = Room 1 width  ✓
  //   • Room 2 height = 3000 − 0    = 3000 mm = Room 1 height ✓
  //
  // Note: "close by" here means within grid-snap tolerance (±50 mm of the
  // grid-aligned matching position). For offsets beyond that a dedicated
  // dimension-matching snap would be required (future work).

  test(
    'WDT-11: Ctrl+drag near existing corner produces same-dimension adjacent '
    'room with a single shared wall',
    () {
      final cb = _RoomAwareStubCallbacks();
      final tool = WallDrawTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: UndoRedoService(),
      );

      tool.updateModifiers(shift: false, ctrl: true, alt: false);

      // ── Room 1: (0,0) → (3000,3000) ────────────────────────────────────
      tool.onPointerDown(const Point2D(x: 0, y: 0), 1);
      tool.onDragEnd(const Point2D(x: 3000, y: 3000));

      expect(cb.currentRooms, hasLength(1), reason: 'Room 1 must be created');
      final room1Width =
          _polySpan(cb.currentRooms.first.polygon, (p) => p.x);
      final room1Height =
          _polySpan(cb.currentRooms.first.polygon, (p) => p.y);

      // ── Room 2: start near (3000,0), drag diagonally ────────────────────
      // (3060, 80) is 100 mm from (3000,0); endpoint snap overrides grid.
      tool.onPointerDown(const Point2D(x: 3060, y: 80), 1);
      // (5970, 2980) is ~30 mm from the grid point (6000, 3000) in each
      // axis, so grid snap aligns it to exactly the matching footprint.
      tool.onDragEnd(const Point2D(x: 5970, y: 2980));

      expect(cb.currentRooms, hasLength(2), reason: 'Room 2 must be created');
      final room2Width =
          _polySpan(cb.currentRooms.last.polygon, (p) => p.x);
      final room2Height =
          _polySpan(cb.currentRooms.last.polygon, (p) => p.y);

      // (a) Room 2 dimensions match Room 1.
      expect(
        room2Width,
        closeTo(room1Width, 0.5),
        reason: 'Room 2 width should equal Room 1 width',
      );
      expect(
        room2Height,
        closeTo(room1Height, 0.5),
        reason: 'Room 2 height should equal Room 1 height',
      );

      // (b) Exactly one wall at the shared vertical boundary x = 3000.
      final sharedEdgeWalls = cb.currentWalls
          .where(
            (w) =>
                (w.startPoint.x - 3000.0).abs() < 1.0 &&
                (w.endPoint.x - 3000.0).abs() < 1.0,
          )
          .toList();
      expect(
        sharedEdgeWalls,
        hasLength(1),
        reason: 'Shared boundary must have exactly one wall segment',
      );

      // (c) Total walls: 4 (Room 1) + 3 (Room 2, shared edge reused) = 7.
      expect(cb.currentWalls, hasLength(7));
    },
  );

  // WDT-12 ───────────────────────────────────────────────────────────────────
  //
  // Dimension-matching snap: when the Ctrl+drag end-point's y-coordinate is
  // within 100 mm of an existing wall endpoint that shares x with the snapped
  // drag-start, the y-axis snaps to that coordinate so Room 2 gets the same
  // height as the adjacent room's shared wall — even though grid snap alone
  // would have placed it on the wrong grid line.
  //
  // Setup:
  //   Room 1 — Ctrl+drag (-2000,0)→(0,2000): a 2000×2000 mm room whose
  //   right wall runs from (0,0) to (0,2000) along x=0.
  //
  // Room 2 drag:
  //   drag-start: (10,20)
  //     → 22 mm from (0,0), inside 200 mm endpoint threshold → snaps to (0,0)
  //   drag-end:   (1000,2050)
  //     → grid snap alone: 2050/100 = 20.5, rounds UP → y=2100 → height 2100 mm ✗
  //     → dimension snap: x=0 column has wall endpoint at y=2000;
  //                       |2100−2000| = 100 mm ≤ 100 mm threshold
  //                       → override y to 2000 → height 2000 mm ✓
  //
  // NOTE: this test currently FAILS — it defines the target behaviour for the
  // dimension-matching snap feature (to be implemented in SnapService /
  // WallDrawTool.onDragEnd). Per agent-test.md §3: tests are written against
  // the specification, not the current implementation.

  // WDT-13 / WDT-14 ────────────────────────────────────────────────────────
  //
  // ADR-017 Rule 1: a newly drawn room's walls all carry the matching
  // project default `thicknessMm` for their `wallType`, and `anchorMode`
  // per Rule 2.
  //
  // These cases drive WallDrawTool through a provider-backed
  // EditorCallbacks so the real EditorStateNotifier's wall-creation path
  // runs (where Rule 1 / Rule 2 defaults are applied). The stub-based
  // tests above intentionally bypass the notifier so they remain unit
  // tests of WallDrawTool's gesture logic.

  test(
    'WDT-13: single wall drawn click-click carries default exterior '
    'thickness (240 mm) and anchorMode = innerFace',
    () {
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ]);
      addTearDown(container.dispose);
      final cb = _ProviderWallDrawCallbacks(container);
      final tool = WallDrawTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: UndoRedoService(),
      );

      tool.onTap(const Point2D(x: 0, y: 0), PointerDeviceKind.mouse);
      tool.onTap(const Point2D(x: 5000, y: 0), PointerDeviceKind.mouse);

      expect(cb.currentWalls, hasLength(1));
      final wall = cb.currentWalls.single;
      // Rule 1: default exterior thickness from ProjectSettings (240 mm).
      expect(wall.thicknessMm, 240.0);
      // Rule 2: exterior + no mirror → innerFace.
      expect(wall.anchorMode, WallAnchorMode.innerFace);
    },
  );

  test(
    'WDT-14: Ctrl+drag rectangle commits 4 walls, all carrying default '
    'exterior thickness and innerFace anchor per ADR-017 Rules 1 & 2',
    () {
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ]);
      addTearDown(container.dispose);
      final cb = _ProviderWallDrawCallbacks(container);
      final tool = WallDrawTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: UndoRedoService(),
      );

      tool.updateModifiers(shift: false, ctrl: true, alt: false);
      tool.onPointerDown(const Point2D(x: 0, y: 0), 1);
      tool.onDragEnd(const Point2D(x: 4000, y: 3000));

      expect(cb.currentWalls, hasLength(4));
      for (final w in cb.currentWalls) {
        expect(
          w.thicknessMm,
          240.0,
          reason: 'every freshly drawn wall must inherit the project '
              "exterior default thickness, not the freezed fallback of 0",
        );
        expect(
          w.anchorMode,
          WallAnchorMode.innerFace,
          reason: 'ADR-017 Rule 2: exterior + no mirror → innerFace',
        );
      }
    },
  );

  // WDT-15 ───────────────────────────────────────────────────────────────────
  //
  // ADR-020 Rule 3: every WallDrawTool-committed wall must carry a non-null
  // `constructionId` pointing at a fresh single-layer auto-default
  // construction (project default material + thickness for its `wallType`).
  // The Ctrl+drag rectangle path exercises commitWallWithSplit four times,
  // so we expect four auto-default constructions, each with exactly one
  // layer using the default exterior material id and thickness.

  test(
    'WDT-15: Ctrl+drag rectangle gives every wall an auto-default '
    'construction (ADR-020 Rule 3)',
    () {
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ]);
      addTearDown(container.dispose);
      final cb = _ProviderWallDrawCallbacks(container);
      final tool = WallDrawTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: UndoRedoService(),
      );

      tool.updateModifiers(shift: false, ctrl: true, alt: false);
      tool.onPointerDown(const Point2D(x: 0, y: 0), 1);
      tool.onDragEnd(const Point2D(x: 4000, y: 3000));

      final state = container.read(editorStateProvider);
      expect(state.walls, hasLength(4));
      for (final w in state.walls) {
        expect(
          w.constructionId,
          isNotNull,
          reason:
              'ADR-020 Rule 3: every freshly drawn wall must carry a '
              'construction id',
        );
        final c = state.constructions
            .where((c) => c.id == w.constructionId)
            .single;
        expect(c.isAutoDefault, isTrue);
        expect(c.isPreset, isFalse);
        final layers = state.materialLayers
            .where((l) => l.constructionId == c.id)
            .toList();
        expect(
          layers,
          hasLength(1),
          reason: 'auto-default construction must have exactly one layer',
        );
        expect(layers.single.materialId, 'mat-016');
        expect(layers.single.thicknessMm, 240.0);
      }
    },
  );

  test(
    'WDT-12: drag-end within 100 mm of shared-wall height snaps y to match '
    'adjacent room dimension',
    () {
      final cb = _RoomAwareStubCallbacks();
      final tool = WallDrawTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: UndoRedoService(),
      );

      tool.updateModifiers(shift: false, ctrl: true, alt: false);

      // ── Room 1: (-2000,0) → (0,2000) — right wall at x=0 ────────────────
      tool.onPointerDown(const Point2D(x: -2000, y: 0), 1);
      tool.onDragEnd(const Point2D(x: 0, y: 2000));

      expect(cb.currentRooms, hasLength(1), reason: 'Room 1 must be created');
      final room1Height = _polySpan(cb.currentRooms.first.polygon, (p) => p.y);
      expect(room1Height, closeTo(2000, 0.5),
          reason: 'Room 1 height sanity check');

      // ── Room 2: start near (0,0), drag to (1000,2050) ────────────────────
      //
      // Without dimension snap: grid gives (1000,2100) → Room 2 is 2100 mm tall.
      // With dimension snap:    y snaps to 2000       → Room 2 is 2000 mm tall.
      tool.onPointerDown(const Point2D(x: 10, y: 20), 1);
      tool.onDragEnd(const Point2D(x: 1000, y: 2050));

      expect(cb.currentRooms, hasLength(2), reason: 'Room 2 must be created');

      final room2Height = _polySpan(cb.currentRooms.last.polygon, (p) => p.y);
      expect(
        room2Height,
        closeTo(room1Height, 0.5),
        reason: 'Room 2 height must match Room 1 shared-wall height (2000 mm); '
            'grid snap alone gives 2100 mm',
      );
    },
  );
}
