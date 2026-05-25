// Unit-style tests for ZoneDrawTool — agent-test.md §6.2.
//
// ZoneDrawTool is exercised directly via a stub EditorCallbacks,
// following the same pattern as wall_draw_tool_test.dart.
//
// Covered scenarios:
//   ZDT-1  Closing a polygon inside the room creates a HeatingZone with
//           the correct vertex count.
//   ZDT-2  The committed zone vertex count matches the number of tap points.
//   ZDT-3  Tapping outside the active room does not add a vertex; the zone
//           is not committed after a closure attempt.
//   ZDT-4  Escape before closing discards all vertices (no zone added).
//   ZDT-5  Creating a zone (polygon / rectangle / fill-room) is undoable —
//           one Ctrl+Z removes the committed zone (ADR-014).
//   ZDT-6  Redo after undo re-adds the identical zone (ADR-014).
//
// The close-threshold for the tool is 15 px / zoom. Since currentZoom = 1.0
// the threshold is 15 mm.  All coordinates use the 100 mm grid.

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:heating_planner/ui/canvas/painters/interaction_data.dart';
import 'package:heating_planner/ui/canvas/tools/editor_callbacks.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';
import 'package:heating_planner/ui/canvas/tools/zone_draw_tool.dart';

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

  _StubCallbacks({
    List<Room>? rooms,
    List<HeatingZone>? zones,
    List<HeatingCircuit>? circuits,
  })  : _rooms = List<Room>.of(rooms ?? const []),
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
  List<WallSegment> get currentWalls => const [];
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
  void updateZone(HeatingZone zone) {}
  @override
  void removeZone(String zoneId) => _zones.removeWhere((z) => z.id == zoneId);
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
  List<WindowElement> get currentWindows => const [];
  @override
  List<Door> get currentDoors => const [];
  @override
  double get currentZoom => 1.0;
  @override
  double get currentGridSpacingMm => 100.0;
}

// ── Test room ─────────────────────────────────────────────────────────────────

// 8 m × 6 m room polygon, origin at (0,0).
const _roomPolygon = [
  Point2D(x: 0, y: 0),
  Point2D(x: 8000, y: 0),
  Point2D(x: 8000, y: 6000),
  Point2D(x: 0, y: 6000),
];

const _testRoom = Room(
  id: 'room-1',
  floorId: 'floor-1',
  name: 'Test Room',
  targetTempC: 20.0,
  polygon: _roomPolygon,
);

// ── Helper ────────────────────────────────────────────────────────────────────

ZoneDrawTool _makeTool(_StubCallbacks cb, [UndoRedoService? undo]) =>
    ZoneDrawTool(
      callbacks: cb,
      onStateChanged: () {},
      undoRedo: undo ?? UndoRedoService(),
    );

/// Taps a sequence of world points and then taps the first point again to
/// close the polygon. The close tap is placed exactly on the first vertex —
/// which is within the 15 mm close-threshold at zoom=1.
void _tapAndClose(ZoneDrawTool tool, List<Point2D> pts) {
  for (final p in pts) {
    tool.onTap(p, PointerDeviceKind.mouse);
  }
  // Close by tapping exactly on the first point.
  tool.onTap(pts.first, PointerDeviceKind.mouse);
}

/// The three zone-creation gestures, each committing exactly one zone
/// inside [_testRoom] (ADR-013 / ADR-014). Used by ZDT-5 and ZDT-6 so
/// undo/redo is verified identically for every path.
Map<String, void Function(ZoneDrawTool)> _zoneCreators() => {
      'polygon': (tool) => _tapAndClose(tool, const [
            Point2D(x: 1000, y: 1000),
            Point2D(x: 4000, y: 1000),
            Point2D(x: 4000, y: 4000),
          ]),
      'rectangle': (tool) {
        // Ctrl held → rect mode; drag corner to corner.
        tool.updateModifiers(shift: false, ctrl: true, alt: false);
        tool.onPointerDown(const Point2D(x: 1000, y: 1000), kPrimaryButton);
        tool.onDragEnd(const Point2D(x: 5000, y: 4000));
      },
      'fill-room': (tool) {
        // Ctrl+Shift held → fill-room on a no-drag pointer-up (ADR-013).
        tool.updateModifiers(shift: true, ctrl: true, alt: false);
        tool.onPointerUp(const Point2D(x: 2000, y: 2000));
      },
    };

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ZDT-1 ───────────────────────────────────────────────────────────────────

  test(
    'ZDT-1: closing a polygon inside the room commits a HeatingZone',
    () {
      final cb = _StubCallbacks(rooms: [_testRoom]);
      final tool = _makeTool(cb);

      // Triangle inside the room.
      _tapAndClose(tool, const [
        Point2D(x: 1000, y: 1000),
        Point2D(x: 4000, y: 1000),
        Point2D(x: 4000, y: 4000),
      ]);

      expect(cb.currentZones, hasLength(1));
    },
  );

  // ZDT-2 ───────────────────────────────────────────────────────────────────
  //
  // Note: consecutive unit-test taps all occur within the 300 ms double-tap
  // window, so the tool closes on the 4th tap when ≥3 vertices exist.  We
  // therefore use exactly 3 taps (a triangle) and verify that the committed
  // polygon length equals the tap count — demonstrating the invariant without
  // fighting the double-tap timer.

  test(
    'ZDT-2: committed zone vertex count matches the number of tap points',
    () {
      final cb = _StubCallbacks(rooms: [_testRoom]);
      final tool = _makeTool(cb);

      // Triangle (3 vertices). The close tap is placed on the first vertex.
      const taps = [
        Point2D(x: 1000, y: 1000),
        Point2D(x: 5000, y: 1000),
        Point2D(x: 5000, y: 4000),
      ];
      _tapAndClose(tool, taps);

      expect(cb.currentZones, hasLength(1));
      expect(cb.currentZones.first.polygon, hasLength(taps.length));
    },
  );

  // ZDT-3 ───────────────────────────────────────────────────────────────────

  test(
    'ZDT-3: tapping outside the active room does not add a vertex '
    'and produces no zone after closure attempt',
    () {
      final cb = _StubCallbacks(rooms: [_testRoom]);
      final tool = _makeTool(cb);

      // First tap outside the room → rejected; no primary room established.
      tool.onTap(const Point2D(x: 20000, y: 20000), PointerDeviceKind.mouse);

      // Follow-up taps that would form a valid triangle if accepted.
      tool.onTap(const Point2D(x: 21000, y: 20000), PointerDeviceKind.mouse);
      tool.onTap(const Point2D(x: 21000, y: 21000), PointerDeviceKind.mouse);
      // Attempt to close at the (rejected) first point.
      tool.onTap(const Point2D(x: 20000, y: 20000), PointerDeviceKind.mouse);

      expect(cb.currentZones, isEmpty);
    },
  );

  // ZDT-4 ───────────────────────────────────────────────────────────────────

  test(
    'ZDT-4: Escape before closing discards all vertices and adds no zone',
    () {
      final cb = _StubCallbacks(rooms: [_testRoom]);
      final tool = _makeTool(cb);

      // Place two vertices.
      tool.onTap(const Point2D(x: 1000, y: 1000), PointerDeviceKind.mouse);
      tool.onTap(const Point2D(x: 4000, y: 1000), PointerDeviceKind.mouse);

      // Cancel (Escape).
      tool.cancel();

      // No third tap + close — confirm zone count stays zero.
      expect(cb.currentZones, isEmpty);

      // Confirm the tool is fully reset: a subsequent first tap acts as fresh.
      tool.onTap(const Point2D(x: 1000, y: 1000), PointerDeviceKind.mouse);
      tool.onTap(const Point2D(x: 4000, y: 1000), PointerDeviceKind.mouse);
      tool.onTap(const Point2D(x: 4000, y: 4000), PointerDeviceKind.mouse);
      // Close.
      tool.onTap(const Point2D(x: 1000, y: 1000), PointerDeviceKind.mouse);

      // Now one zone should have been committed.
      expect(cb.currentZones, hasLength(1));
    },
  );

  // ZDT-5 ───────────────────────────────────────────────────────────────────
  //
  // ADR-014: every zone-creation gesture is wrapped in a CreateZoneCommand,
  // so a single undo() removes the committed zone — for the polygon,
  // rectangle, and fill-room paths alike.

  group('ZDT-5: zone creation is undoable (ADR-014)', () {
    _zoneCreators().forEach((name, create) {
      test('$name — create then undo removes the zone', () {
        final cb = _StubCallbacks(rooms: [_testRoom]);
        final undo = UndoRedoService();
        final tool = _makeTool(cb, undo);

        create(tool);
        expect(cb.currentZones, hasLength(1),
            reason: '$name path should commit exactly one zone');
        expect(undo.canUndo, isTrue,
            reason: '$name commit should push one undo entry');

        undo.undo();
        expect(cb.currentZones, isEmpty,
            reason: 'undo should remove the $name zone');
      });
    });
  });

  // ZDT-6 ───────────────────────────────────────────────────────────────────
  //
  // ADR-014: redo re-adds the identical zone record (same id + polygon).

  group('ZDT-6: redo re-adds the identical zone (ADR-014)', () {
    _zoneCreators().forEach((name, create) {
      test('$name — undo then redo restores the same zone', () {
        final cb = _StubCallbacks(rooms: [_testRoom]);
        final undo = UndoRedoService();
        final tool = _makeTool(cb, undo);

        create(tool);
        final created = cb.currentZones.single;

        undo.undo();
        expect(cb.currentZones, isEmpty);

        undo.redo();
        expect(cb.currentZones, hasLength(1));
        expect(cb.currentZones.single.id, created.id,
            reason: 'redo should restore the identical $name zone');
        expect(cb.currentZones.single.polygon, created.polygon);
      });
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // ADR-018 — Zone tool double-click split + fill-room + hover preview
  // ────────────────────────────────────────────────────────────────────────────

  // Helper: simulate a double-click at [point] by issuing two onTap calls
  // at the same position. The position-based double-tap detector in
  // ZoneDrawTool recognises the second one as a double-tap (both taps
  // are within 200 mm and < 300 ms, which always holds in unit tests).
  void doubleClick(ZoneDrawTool tool, Point2D point) {
    tool.onTap(point, PointerDeviceKind.mouse);
    tool.onTap(point, PointerDeviceKind.mouse);
  }

  // ZDT-7 ───────────────────────────────────────────────────────────────────

  test(
    'ZDT-7: double-click on a rectangular zone (W > H) splits vertically; '
    'children share an exact midpoint edge and inherit parent settings',
    () {
      // W=4000, H=2000 → longer side is X → vertical bisector at x=3000.
      const parentZone = HeatingZone(
        id: 'zone-parent',
        roomId: 'room-1',
        polygon: [
          Point2D(x: 1000, y: 1000),
          Point2D(x: 5000, y: 1000),
          Point2D(x: 5000, y: 3000),
          Point2D(x: 1000, y: 3000),
        ],
        tubeSpacingMm: 175,
        tubeTypeId: 'tube-X',
        flooringMaterialId: 'mat-X',
        borderDistanceMm: 120,
        layoutPattern: LayoutPattern.spiral,
      );
      final cb =
          _StubCallbacks(rooms: [_testRoom], zones: [parentZone]);
      final undo = UndoRedoService();
      final tool = _makeTool(cb, undo);

      // Double-click inside the parent zone.
      doubleClick(tool, const Point2D(x: 3000, y: 2000));

      // Parent removed, two children inserted.
      expect(cb.currentZones, hasLength(2),
          reason: 'split must replace parent with two children');
      expect(cb.currentZones.any((z) => z.id == parentZone.id), isFalse,
          reason: 'parent must be removed by the split');

      // Children must form left and right halves of the parent rect with
      // a shared edge at x = 3000.
      final xsA = cb.currentZones[0].polygon.map((p) => p.x).toSet();
      final xsB = cb.currentZones[1].polygon.map((p) => p.x).toSet();
      expect(xsA, equals({1000.0, 3000.0}));
      expect(xsB, equals({3000.0, 5000.0}));

      // Both children inherit every setting from the parent verbatim
      // (ADR-018 Rule 5).
      for (final c in cb.currentZones) {
        expect(c.tubeSpacingMm, parentZone.tubeSpacingMm);
        expect(c.tubeTypeId, parentZone.tubeTypeId);
        expect(c.flooringMaterialId, parentZone.flooringMaterialId);
        expect(c.borderDistanceMm, parentZone.borderDistanceMm);
        expect(c.layoutPattern, parentZone.layoutPattern);
        expect(c.zoneType, parentZone.zoneType);
        expect(c.roomId, parentZone.roomId);
        expect(c.id, isNot(parentZone.id),
            reason: 'each child gets a fresh UUID');
      }

      // Single undo entry (ADR-018 Rule 7).
      expect(undo.canUndo, isTrue);
      undo.undo();
      expect(cb.currentZones, hasLength(1));
      expect(cb.currentZones.single.id, parentZone.id,
          reason: 'undo restores the parent verbatim');
    },
  );

  // ZDT-8 ───────────────────────────────────────────────────────────────────

  test(
    'ZDT-8: double-click on a non-rectangular zone emits the splittability '
    'toast and mutates nothing',
    () {
      // 5-vertex pentagon — clearly not rectangle-eligible.
      const pentagonZone = HeatingZone(
        id: 'zone-penta',
        roomId: 'room-1',
        polygon: [
          Point2D(x: 1000, y: 1000),
          Point2D(x: 4000, y: 1000),
          Point2D(x: 5000, y: 2000),
          Point2D(x: 4000, y: 3000),
          Point2D(x: 1000, y: 3000),
        ],
        tubeTypeId: 'tube-1',
        flooringMaterialId: 'mat-1',
      );
      final cb =
          _StubCallbacks(rooms: [_testRoom], zones: [pentagonZone]);
      final undo = UndoRedoService();
      final tool = _makeTool(cb, undo);

      doubleClick(tool, const Point2D(x: 2500, y: 2000));

      // Zone list is unchanged.
      expect(cb.currentZones, hasLength(1));
      expect(cb.currentZones.single.id, pentagonZone.id);
      expect(undo.canUndo, isFalse,
          reason: 'rejected split must not push an undo entry');

      // Toast was emitted.
      expect(
        cb.toasts,
        contains(cb.l10n.zone_splitNonRectangularToast),
      );
    },
  );

  // ZDT-9 ───────────────────────────────────────────────────────────────────

  test(
    'ZDT-9: double-click on empty room interior creates a zone equivalent '
    'to the Ctrl+Shift+click fill-room path (same polygon, one undo entry)',
    () {
      // Establish a baseline by running the existing fill-room gesture.
      final cbA = _StubCallbacks(rooms: [_testRoom]);
      final toolA = _makeTool(cbA);
      toolA.updateModifiers(shift: true, ctrl: true, alt: false);
      toolA.onPointerUp(const Point2D(x: 2000, y: 2000));
      expect(cbA.currentZones, hasLength(1),
          reason: 'baseline: fill-room creates one zone');
      final baselinePolygon = cbA.currentZones.single.polygon;

      // Now exercise the new double-click fill-room path.
      final cbB = _StubCallbacks(rooms: [_testRoom]);
      final undoB = UndoRedoService();
      final toolB = _makeTool(cbB, undoB);
      doubleClick(toolB, const Point2D(x: 2000, y: 2000));

      expect(cbB.currentZones, hasLength(1),
          reason: 'double-click on empty room interior creates one zone');
      expect(cbB.currentZones.single.polygon, baselinePolygon,
          reason: 'polygon equals the fill-room polygon');

      // Exactly one undo entry — single Ctrl+Z reverts the creation.
      expect(undoB.canUndo, isTrue);
      undoB.undo();
      expect(cbB.currentZones, isEmpty);
    },
  );

  // ZDT-10 ──────────────────────────────────────────────────────────────────

  test(
    'ZDT-10: hover preview renders dashed bisector on rectangular zones, '
    'no preview on non-rectangular zones',
    () {
      // Rectangular zone (W=4000, H=2000) → vertical bisector at x=3000.
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
      final cbRect =
          _StubCallbacks(rooms: [_testRoom], zones: [rectZone]);
      final toolRect = _makeTool(cbRect);

      toolRect.onPointerMove(const Point2D(x: 3000, y: 2000));
      final data = toolRect.getInteractionData();
      expect(data, isA<ZoneSplitPreviewData>());
      final preview = data! as ZoneSplitPreviewData;
      expect(preview.start.x, 3000.0);
      expect(preview.end.x, 3000.0);
      // Y range covers the parent's vertical span.
      final ys = {preview.start.y, preview.end.y};
      expect(ys, {1000.0, 3000.0});

      // Non-rectangular zone — no preview.
      const pentagonZone = HeatingZone(
        id: 'zone-penta',
        roomId: 'room-1',
        polygon: [
          Point2D(x: 1000, y: 1000),
          Point2D(x: 4000, y: 1000),
          Point2D(x: 5000, y: 2000),
          Point2D(x: 4000, y: 3000),
          Point2D(x: 1000, y: 3000),
        ],
        tubeTypeId: 'tube-1',
        flooringMaterialId: 'mat-1',
      );
      final cbPenta =
          _StubCallbacks(rooms: [_testRoom], zones: [pentagonZone]);
      final toolPenta = _makeTool(cbPenta);

      toolPenta.onPointerMove(const Point2D(x: 2500, y: 2000));
      expect(toolPenta.getInteractionData(), isNot(isA<ZoneSplitPreviewData>()),
          reason: 'non-rectangular zone must not show the bisector preview');

      // Once a polygon vertex is committed, the preview must disappear even
      // over a rectangular zone (Rule 8: only when buffer is empty).
      toolRect.onTap(const Point2D(x: 1500, y: 1500), PointerDeviceKind.mouse);
      toolRect.onPointerMove(const Point2D(x: 3000, y: 2000));
      expect(toolRect.getInteractionData(), isNot(isA<ZoneSplitPreviewData>()),
          reason: 'preview must hide once a polygon is in progress');
    },
  );
}
