// Integration test: measure tool (ADR-030) with opt-in snapping (ADR-031),
// end to end through the real EditorScreen.
//
// Drives real pointer + keyboard events against the live canvas:
//   1. Select the Measure tool from the toolbar.
//   2. Tap the first point at world (0, 0), then hover the mouse to world
//      (1230, 0). With no modifier held, snapping is OFF: the live distance
//      surfaced to the status bar is the RAW 1230 mm (grid snap would have
//      rounded the endpoint to 1200), and the hint advertises "hold Shift
//      to snap".
//   3. Hold Shift and hover to world (1240, 0). Snapping is now ON: the
//      endpoint snaps to the 1200 grid line, so the status bar shows
//      1200 mm and drops the "hold Shift" affordance.
//   4. The measure tool is non-destructive: no walls (or other geometry)
//      are ever committed.
//
// Mirrors the deterministic fixed-transform / explicit-pump conventions of
// alignment_guide_wall_draw_test.dart (pumpAndSettle loops forever against
// Drift's stream providers).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/ui/canvas/canvas_controller.dart';
import 'package:heating_planner/ui/canvas/floor_plan_canvas.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';
import 'package:heating_planner/ui/screens/editor_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// ── Fixed canvas controller (zoom = 0.1, pan = (100, 100)) ────────────────────

class _FixedCanvasController extends CanvasController {
  static const double _zoom = 0.1;
  static const double _panX = 100.0;
  static const double _panY = 100.0;

  @override
  CanvasState build() => const CanvasState(
        zoom: _zoom,
        panOffset: Offset(_panX, _panY),
      );

  @override
  void setInitialView(double zoom, Offset panOffset) {
    // no-op: keep the fixed test transform
  }
}

Future<void> _pump(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump();
  }
}

void main() {
  group('measure tool with opt-in snapping (end to end)', () {
    testWidgets(
      'measures the raw distance by default and snaps only while Shift is held',
      (tester) async {
        // ── Viewport ─────────────────────────────────────────────────────
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();

        // ── Database: bare project + floor ───────────────────────────────
        final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        const projectId = 'me-proj-1';
        const floorId = 'me-floor-1';
        final now = DateTime(2025, 1, 1);

        await db.into(db.projects).insert(
              $db.ProjectsCompanion.insert(
                id: projectId,
                name: 'Measure Tool Test',
                createdAt: now,
                modifiedAt: now,
                designOutdoorTempC: const Value(-10.0),
                defaultIndoorTempC: const Value(20.0),
              ),
            );
        await db.into(db.floors).insert(
              $db.FloorsCompanion.insert(
                id: floorId,
                projectId: projectId,
                name: 'Ground Floor',
              ),
            );

        final container = ProviderContainer(
          overrides: [
            $db.appDatabaseProvider.overrideWithValue(db),
            canvasControllerProvider.overrideWith(_FixedCanvasController.new),
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

        expect(find.byType(EditorScreen), findsOneWidget);

        // world (x, y) → global position under the fixed transform.
        final canvasTopLeft = tester.getTopLeft(find.byType(FloorPlanCanvas));
        Offset w2g(double wx, double wy) =>
            canvasTopLeft +
            Offset(
              wx * _FixedCanvasController._zoom + _FixedCanvasController._panX,
              wy * _FixedCanvasController._zoom + _FixedCanvasController._panY,
            );

        // ── Select the Measure tool ──────────────────────────────────────
        await tester.tap(find.byTooltip('Measure'));
        await tester.pump();

        // ── First point at (0, 0) ────────────────────────────────────────
        await tester.tapAt(w2g(0, 0));
        await tester.pump();

        // ── Default (no Shift): hover to (1230, 0) → raw 1230 mm ──────────
        final mouse =
            await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: w2g(0, 0));
        addTearDown(() => mouse.removePointer());
        await mouse.moveTo(w2g(1230, 0));
        await _pump(tester);

        final rawHint = container.read(toolStatusHintProvider);
        expect(rawHint, isNotNull);
        expect(
          rawHint,
          contains('(1230 mm)'),
          reason: 'default measurement must use the raw cursor (grid snap '
              'would have rounded the endpoint to 1200 mm)',
        );
        expect(
          rawHint,
          contains('hold Shift to snap'),
          reason: 'the snap affordance is advertised while snapping is off',
        );

        // ── Shift held: hover to (1240, 0) → snaps to the 1200 grid line ──
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await mouse.moveTo(w2g(1240, 0));
        await _pump(tester);

        final snapHint = container.read(toolStatusHintProvider);
        expect(
          snapHint,
          contains('(1200 mm)'),
          reason: 'with Shift the endpoint snaps to the grid (1200), not the '
              'raw 1240 mm',
        );
        expect(
          snapHint,
          isNot(contains('hold Shift to snap')),
          reason: 'the affordance disappears once snapping is active',
        );

        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();

        // ── The measure tool commits nothing ─────────────────────────────
        final state = container.read(editorStateProvider);
        expect(state.walls, isEmpty);
        expect(state.rooms, isEmpty);
        expect(state.zones, isEmpty);

        // ── Teardown ─────────────────────────────────────────────────────
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });
}
