// Widget tests for the ADR-015 / UI-UX §7.2.2 rectangular-room
// Width/Height group in RoomProperties.
//
// Covered scenarios:
//   RD-1  A rectangle-eligible room shows the Width/Height fields
//         pre-filled with the bounding-box extents in cm.
//   RD-2  Editing Width resizes the room top-left-anchored (min-x /
//         min-y fixed; Height unchanged), reusing the four-wall path.
//   RD-3  A value < 10 cm is rejected: the field reverts and the
//         "Room too small (min 10×10 cm)" toast is shown; nothing
//         mutates.
//   RD-4  A non-rectangular room hides the group entirely.
//   RD-5  One undo (Ctrl+Z) reverts a resize as a single command.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/heat_demand_providers.dart';
import 'package:heating_planner/calculation/providers/u_value_providers.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';
import 'package:heating_planner/ui/panels/room_properties.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Stub notifier ─────────────────────────────────────────────────────────────

/// In-memory [EditorStateNotifier] that skips all database I/O.
/// `replaceAllWallsAndRooms` is inherited from the base class
/// (already a pure `state = state.copyWith(...)`).
class _StubEditorNotifier extends EditorStateNotifier {
  _StubEditorNotifier(this._initial);
  final EditorState _initial;

  @override
  EditorState build() => _initial;

  @override
  void updateRoom(Room room) {
    state = state.copyWith(
      rooms: state.rooms.map((r) => r.id == room.id ? room : r).toList(),
    );
  }

  @override
  void updateWall(WallSegment wall) {
    state = state.copyWith(
      walls: state.walls.map((w) => w.id == wall.id ? wall : w).toList(),
    );
  }

  @override
  void markProjectDirty() {}
}

// ── Test data ─────────────────────────────────────────────────────────────────

const _roomId = 'room-1';

const _rectRoom = Room(
  id: _roomId,
  floorId: 'floor-1',
  name: 'Living Room',
  targetTempC: 21.0,
  airChangeRate: 0.5,
  polygon: [
    Point2D(x: 0, y: 0),
    Point2D(x: 5000, y: 0),
    Point2D(x: 5000, y: 4000),
    Point2D(x: 0, y: 4000),
  ],
);

/// Four axis-aligned walls forming the 5000×4000 mm rectangle.
List<WallSegment> _rectWalls() => const [
      WallSegment(
        id: 'w1',
        roomId: _roomId,
        startPoint: Point2D(x: 0, y: 0),
        endPoint: Point2D(x: 5000, y: 0),
      ),
      WallSegment(
        id: 'w2',
        roomId: _roomId,
        startPoint: Point2D(x: 5000, y: 0),
        endPoint: Point2D(x: 5000, y: 4000),
      ),
      WallSegment(
        id: 'w3',
        roomId: _roomId,
        startPoint: Point2D(x: 5000, y: 4000),
        endPoint: Point2D(x: 0, y: 4000),
      ),
      WallSegment(
        id: 'w4',
        roomId: _roomId,
        startPoint: Point2D(x: 0, y: 4000),
        endPoint: Point2D(x: 0, y: 0),
      ),
    ];

/// Five segments (the bottom edge is split) → not rectangle-eligible.
List<WallSegment> _nonRectWalls() => const [
      WallSegment(
        id: 'w1a',
        roomId: _roomId,
        startPoint: Point2D(x: 0, y: 0),
        endPoint: Point2D(x: 2500, y: 0),
      ),
      WallSegment(
        id: 'w1b',
        roomId: _roomId,
        startPoint: Point2D(x: 2500, y: 0),
        endPoint: Point2D(x: 5000, y: 0),
      ),
      WallSegment(
        id: 'w2',
        roomId: _roomId,
        startPoint: Point2D(x: 5000, y: 0),
        endPoint: Point2D(x: 5000, y: 4000),
      ),
      WallSegment(
        id: 'w3',
        roomId: _roomId,
        startPoint: Point2D(x: 5000, y: 4000),
        endPoint: Point2D(x: 0, y: 4000),
      ),
      WallSegment(
        id: 'w4',
        roomId: _roomId,
        startPoint: Point2D(x: 0, y: 4000),
        endPoint: Point2D(x: 0, y: 0),
      ),
    ];

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _build(EditorState initial) {
  return ProviderScope(
    overrides: [
      editorStateProvider.overrideWith(
        () => _StubEditorNotifier(initial),
      ),
      // Real service so RD-5 can exercise a genuine undo.
      undoRedoProvider.overrideWith((_) => UndoRedoService()),
      roomHeatDemandProvider.overrideWith((ref, _) => double.nan),
      uValueProvider.overrideWith((ref, _) => double.nan),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: const Scaffold(
        body: RoomProperties(roomId: _roomId),
      ),
    ),
  );
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(RoomProperties)),
    );

({double minX, double minY, double maxX, double maxY}) _bbox(
  List<Point2D> pts,
) {
  return (
    minX: pts.map((p) => p.x).reduce((a, b) => a < b ? a : b),
    minY: pts.map((p) => p.y).reduce((a, b) => a < b ? a : b),
    maxX: pts.map((p) => p.x).reduce((a, b) => a > b ? a : b),
    maxY: pts.map((p) => p.y).reduce((a, b) => a > b ? a : b),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  Future<void> sized(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  // RD-1 ──────────────────────────────────────────────────────────────────────

  testWidgets(
    'RD-1: rectangular room shows Width/Height fields with cm extents',
    (tester) async {
      await sized(tester);
      await tester.pumpWidget(
        _build(EditorState(rooms: const [_rectRoom], walls: _rectWalls())),
      );
      await tester.pump();

      expect(find.text('Dimensions'), findsOneWidget);
      expect(find.byKey(const Key('roomWidthField')), findsOneWidget);
      expect(find.byKey(const Key('roomHeightField')), findsOneWidget);
      // 5000 mm → 500 cm, 4000 mm → 400 cm.
      expect(find.text('500'), findsOneWidget);
      expect(find.text('400'), findsOneWidget);
    },
  );

  // RD-2 ──────────────────────────────────────────────────────────────────────

  testWidgets(
    'RD-2: editing Width resizes top-left-anchored, Height unchanged',
    (tester) async {
      await sized(tester);
      await tester.pumpWidget(
        _build(EditorState(rooms: const [_rectRoom], walls: _rectWalls())),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('roomWidthField')),
        '600',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final state = _containerOf(tester).read(editorStateProvider);
      final room = state.rooms.firstWhere((r) => r.id == _roomId);
      final rb = _bbox(room.polygon);

      // Top-left fixed, width → 6000 mm, height untouched.
      expect(rb.minX, 0);
      expect(rb.minY, 0);
      expect(rb.maxX, 6000);
      expect(rb.maxY, 4000);

      final wallPts = state.walls
          .where((w) => w.roomId == _roomId)
          .expand((w) => [w.startPoint, w.endPoint])
          .toList();
      final wb = _bbox(wallPts);
      expect(wb.minX, 0);
      expect(wb.maxX, 6000);
      expect(wb.minY, 0);
      expect(wb.maxY, 4000);
      // The right edge moved; the left edge stayed anchored.
      expect(wallPts.where((p) => p.x == 6000), isNotEmpty);
      expect(wallPts.where((p) => p.x == 0), isNotEmpty);
      expect(wallPts.where((p) => p.x == 5000), isEmpty);
    },
  );

  // RD-3 ──────────────────────────────────────────────────────────────────────

  testWidgets(
    'RD-3: a < 10 cm value is rejected — field reverts, toast, no mutation',
    (tester) async {
      await sized(tester);
      await tester.pumpWidget(
        _build(EditorState(rooms: const [_rectRoom], walls: _rectWalls())),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('roomWidthField')),
        '5',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Toast shown.
      expect(
        find.text('Room too small (min 10×10 cm)'),
        findsOneWidget,
      );

      // Field reverted to the current value.
      final widthField = tester.widget<TextField>(
        find.byKey(const Key('roomWidthField')),
      );
      expect(widthField.controller!.text, '500');

      // Nothing mutated.
      final state = _containerOf(tester).read(editorStateProvider);
      final room = state.rooms.firstWhere((r) => r.id == _roomId);
      expect(_bbox(room.polygon).maxX, 5000);
      final undoRedo =
          _containerOf(tester).read(undoRedoProvider);
      expect(undoRedo.canUndo, isFalse);
    },
  );

  // RD-4 ──────────────────────────────────────────────────────────────────────

  testWidgets(
    'RD-4: a non-rectangular room hides the Dimensions group',
    (tester) async {
      await sized(tester);
      await tester.pumpWidget(
        _build(
          EditorState(rooms: const [_rectRoom], walls: _nonRectWalls()),
        ),
      );
      await tester.pump();

      expect(find.text('Dimensions'), findsNothing);
      expect(find.byKey(const Key('roomWidthField')), findsNothing);
      expect(find.byKey(const Key('roomHeightField')), findsNothing);
    },
  );

  // RD-5 ──────────────────────────────────────────────────────────────────────

  testWidgets(
    'RD-5: one undo reverts a resize as a single command',
    (tester) async {
      await sized(tester);
      await tester.pumpWidget(
        _build(EditorState(rooms: const [_rectRoom], walls: _rectWalls())),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('roomWidthField')),
        '600',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final container = _containerOf(tester);
      expect(
        _bbox(
          container
              .read(editorStateProvider)
              .rooms
              .firstWhere((r) => r.id == _roomId)
              .polygon,
        ).maxX,
        6000,
      );

      // Single Ctrl+Z.
      final undoRedo = container.read(undoRedoProvider);
      expect(undoRedo.canUndo, isTrue);
      undoRedo.undo();
      await tester.pump();

      final reverted = container.read(editorStateProvider);
      final room = reverted.rooms.firstWhere((r) => r.id == _roomId);
      expect(_bbox(room.polygon).maxX, 5000);
      final wallPts = reverted.walls
          .where((w) => w.roomId == _roomId)
          .expand((w) => [w.startPoint, w.endPoint])
          .toList();
      expect(_bbox(wallPts).maxX, 5000);
      expect(undoRedo.canUndo, isFalse);
    },
  );
}
