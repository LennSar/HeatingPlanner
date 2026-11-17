// ADR-046: Ctrl+Z / Ctrl+Y in the tube tools, end to end — real editor
// screen, real keyboard shortcuts, real canvas wiring.
//
// While a tube is being drawn, Ctrl+Z takes back the last corner and
// Ctrl+Y puts it back (nothing goes onto the undo stack). Once the tube
// is finished, Ctrl+Z removes the whole tube and Ctrl+Y restores it.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:heating_planner/ui/canvas/canvas_controller.dart';
import 'package:heating_planner/ui/canvas/floor_plan_canvas.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';
import 'package:heating_planner/ui/screens/editor_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FixedCanvasController extends CanvasController {
  static const double zoom = 0.1;
  static const double panX = 100.0;
  static const double panY = 100.0;

  @override
  CanvasState build() =>
      const CanvasState(zoom: zoom, panOffset: Offset(panX, panY));

  @override
  void setInitialView(double zoom, Offset panOffset) {}
}

class _NoSnap extends TubeSnapEnabledNotifier {
  @override
  Future<bool> build() async => false;
}

Future<void> _pump(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump();
  }
}

// An unconnected 4 m × 3 m floor zone: a drawn tube starts at the first
// click and ends at the last corner.
const _zone = HeatingZone(
  id: 'tu-zone-1',
  roomId: 'tu-room-1',
  polygon: [
    Point2D(x: 0, y: 0),
    Point2D(x: 4000, y: 0),
    Point2D(x: 4000, y: 3000),
    Point2D(x: 0, y: 3000),
  ],
  tubeTypeId: '10000000-0000-4000-8000-000000000001',
  flooringMaterialId: '20000000-0000-4000-8000-000000000001',
);

void main() {
  testWidgets('Ctrl+Z / Ctrl+Y step through corners while drawing a tube, '
      'then undo and redo the finished tube', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    const projectId = 'tu-proj-1';
    final now = DateTime(2025, 1, 1);
    await db
        .into(db.projects)
        .insert(
          $db.ProjectsCompanion.insert(
            id: projectId,
            name: 'Tube Undo Test',
            createdAt: now,
            modifiedAt: now,
            designOutdoorTempC: const Value(-10.0),
            defaultIndoorTempC: const Value(20.0),
          ),
        );
    await db
        .into(db.floors)
        .insert(
          $db.FloorsCompanion.insert(
            id: 'tu-floor-1',
            projectId: projectId,
            name: 'Ground Floor',
          ),
        );

    final container = ProviderContainer(
      overrides: [
        $db.appDatabaseProvider.overrideWithValue(db),
        canvasControllerProvider.overrideWith(_FixedCanvasController.new),
        // Raw clicks keep the expected corners simple.
        tubeSnapEnabledProvider.overrideWith(_NoSnap.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: const EditorScreen(projectId: projectId),
        ),
      ),
    );
    await _pump(tester, 10);
    container.read(editorStateProvider.notifier).addZone(_zone);
    await _pump(tester);

    final topLeft = tester.getTopLeft(find.byType(FloorPlanCanvas));
    Offset w2g(double x, double y) =>
        topLeft +
        Offset(
          x * _FixedCanvasController.zoom + _FixedCanvasController.panX,
          y * _FixedCanvasController.zoom + _FixedCanvasController.panY,
        );
    // The tools tell a double-click by the wall clock.
    Future<void> pause() => tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    Future<void> click(double x, double y) async {
      await tester.tapAt(w2g(x, y));
      await _pump(tester);
      await pause();
    }

    Future<void> key(LogicalKeyboardKey k) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(k);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pump(tester);
    }

    // Rounded: screen → world leaves floating-point noise.
    List<Point2D>? tube() => container
        .read(editorStateProvider)
        .zones
        .single
        .manualTubePath
        ?.map((p) => Point2D(x: p.x.roundToDouble(), y: p.y.roundToDouble()))
        .toList();

    await tester.tap(find.byTooltip('Draw tube'));
    await _pump(tester);

    await click(500, 500); // start
    await click(3000, 500);
    await click(3000, 2000);
    await key(LogicalKeyboardKey.keyZ); // takes back (3000, 2000)
    await key(LogicalKeyboardKey.keyY); // puts it back
    await key(LogicalKeyboardKey.keyZ); // takes it back again
    await click(3000, 1000);
    // Finish with a double-click on the last corner.
    await tester.tapAt(w2g(1000, 1000));
    await tester.pump();
    await tester.tapAt(w2g(1000, 1000));
    await _pump(tester);

    expect(tube(), const [
      Point2D(x: 500, y: 500),
      Point2D(x: 3000, y: 500),
      Point2D(x: 3000, y: 1000),
      Point2D(x: 1000, y: 1000),
    ]);

    await key(LogicalKeyboardKey.keyZ); // the whole tube
    expect(tube(), isNull);
    await key(LogicalKeyboardKey.keyY);
    expect(tube(), hasLength(4));

    // Let debounce timers (zone colour state, autosave) run out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });
}
