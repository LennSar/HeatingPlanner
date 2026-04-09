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

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/geometry_engine.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/door.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/data/models/window_element.dart';
import 'package:heating_planner/ui/canvas/tools/editor_callbacks.dart';
import 'package:heating_planner/ui/canvas/tools/snap_service.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';
import 'package:heating_planner/ui/canvas/tools/wall_draw_tool.dart';

// ── Stub EditorCallbacks ─────────────────────────────────────────────────────

class _StubCallbacks implements EditorCallbacks {
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
  void requestRoomDialog(List<Point2D> polygon, List<String> wallIds) {}
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

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
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
}
