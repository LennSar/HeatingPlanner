// Widget tests for RoomProperties — agent-test.md §6.1.
//
// Covered scenarios:
//   RP-1  Room name is displayed in the name text field.
//   RP-2  Target temperature (21 °C) is displayed in the temperature row.
//   RP-3  "Air Change Rate" label is present (confirming the ACR field renders).
//   RP-4  Editing the name field and submitting updates the room in
//         editorStateProvider (verifying the onChanged→notifier path).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/heat_demand_providers.dart';
import 'package:heating_planner/calculation/providers/u_value_providers.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';
import 'package:heating_planner/ui/panels/room_properties.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Stub notifiers ────────────────────────────────────────────────────────────

/// In-memory [EditorStateNotifier] that skips all database I/O.
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
  void updateZone(HeatingZone zone) {
    state = state.copyWith(
      zones: state.zones.map((z) => z.id == zone.id ? zone : z).toList(),
    );
  }

  @override
  void markProjectDirty() {}
}

// ── Stub undo/redo ────────────────────────────────────────────────────────────

/// [UndoRedoService] stub that executes commands immediately without stacking.
class _StubUndoRedo extends UndoRedoService {
  @override
  void execute(Command command) => command.execute();
}

// ── Test data ─────────────────────────────────────────────────────────────────

const _roomId = 'room-1';

const _testRoom = Room(
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

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _buildWidget({Room room = _testRoom}) {
  return ProviderScope(
    overrides: [
      editorStateProvider.overrideWith(
        () => _StubEditorNotifier(EditorState(rooms: [room])),
      ),
      undoRedoProvider.overrideWith((_) => _StubUndoRedo()),
      // Heat demand returns NaN → display rows show "—" (no DB needed)
      roomHeatDemandProvider.overrideWith((ref, _) => double.nan),
      // U-value returns NaN → envelope section shows "—"
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

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // RP-1 ─────────────────────────────────────────────────────────────────────

  testWidgets('RP-1: room name is displayed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildWidget());
    await tester.pump();

    // The name text field is pre-filled with the room name.
    expect(find.text('Living Room'), findsOneWidget);
  });

  // RP-2 ─────────────────────────────────────────────────────────────────────

  testWidgets('RP-2: target temperature 21 °C is displayed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildWidget());
    await tester.pump();

    // The temperature row shows "Target Temperature: 21 °C"
    expect(
      find.textContaining('21'),
      findsWidgets,
    );
    // More specifically the label line contains "21 °C"
    expect(
      find.textContaining('21 \u00B0C'),
      findsOneWidget,
    );
  });

  // RP-3 ─────────────────────────────────────────────────────────────────────

  testWidgets('RP-3: air change rate field label is present', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildWidget());
    await tester.pump();

    expect(find.text('Air Change Rate'), findsOneWidget);
  });

  // RP-4 ─────────────────────────────────────────────────────────────────────

  testWidgets(
    'RP-4: submitting a new name via the text field updates editorStateProvider',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildWidget());
      await tester.pump();

      // Tap the name text field and replace its content.
      final nameField = find.widgetWithText(TextField, 'Living Room');
      await tester.tap(nameField);
      await tester.pump();

      await tester.enterText(nameField, 'Dining Room');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Read the updated state from the container.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RoomProperties)),
      );
      final updatedRoom = container
          .read(editorStateProvider)
          .rooms
          .firstWhere((r) => r.id == _roomId);

      expect(updatedRoom.name, 'Dining Room');
    },
  );
}
