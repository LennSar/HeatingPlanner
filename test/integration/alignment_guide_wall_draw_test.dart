// Integration test: ADR-028 alignment guides for wall drawing, end to end.
//
// Drives the real EditorScreen with real pointer + keyboard events:
//   1. Draw a 4 000 mm × 3 000 mm rectangular room (5 wall-tool taps +
//      confirm the auto-detection dialog). Its bottom corners sit at y = 3000.
//   2. Draw a new vertical wall far to the right (x = 6000, well clear of the
//      room so endpoint snap cannot fire): first tap sets the start at
//      (6000, 0); the second tap lands at raw world (6000, 2940).
//   3. Grid snap alone would round y 2940 → 2900. The corner-alignment snap
//      must instead pull the endpoint's y onto the existing room's bottom
//      corner row (y = 3000), because |2900 − 3000| = 100 mm ≤ the 150 mm
//      alignment tolerance and x is gated independently (no x corner near
//      6000). Assert the committed wall ends at (6000, 3000), not (6000, 2900).
//
// Mirrors the deterministic fixed-transform / explicit-pump conventions of
// keep_orientation_wall_drag_test.dart (pumpAndSettle loops forever against
// Drift's stream providers).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/ui/canvas/canvas_controller.dart';
import 'package:heating_planner/ui/canvas/floor_plan_canvas.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';
import 'package:heating_planner/ui/providers/selection_provider.dart';
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
  group('ADR-028 alignment guides for wall drawing (end to end)', () {
    testWidgets(
      'a drawn wall endpoint snaps onto an existing room corner row, '
      'overriding grid snap',
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

        const projectId = 'al-proj-1';
        const floorId = 'al-floor-1';
        final now = DateTime(2025, 1, 1);

        await db.into(db.projects).insert(
              $db.ProjectsCompanion.insert(
                id: projectId,
                name: 'Alignment Guide Test',
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

        // world (x, y) → global tap position under the fixed transform.
        final canvasTopLeft = tester.getTopLeft(find.byType(FloorPlanCanvas));
        Offset w2g(double wx, double wy) =>
            canvasTopLeft +
            Offset(
              wx * _FixedCanvasController._zoom + _FixedCanvasController._panX,
              wy * _FixedCanvasController._zoom + _FixedCanvasController._panY,
            );

        // ── Draw the reference 4 000 × 3 000 room ────────────────────────
        await tester.tap(find.byTooltip('Wall'));
        await tester.pump();

        for (final pt in [
          [0.0, 0.0],
          [4000.0, 0.0],
          [4000.0, 3000.0],
          [0.0, 3000.0],
          [0.0, 0.0], // closing tap → room detection
        ]) {
          await tester.tapAt(w2g(pt[0], pt[1]));
          await tester.pump();
        }

        expect(find.text('New Room Detected'), findsOneWidget);
        await tester.tap(find.text('Create'));
        await _pump(tester, 5);

        expect(container.read(editorStateProvider).rooms, hasLength(1));
        final wallsAfterRoom = container.read(editorStateProvider).walls.length;

        // Clear the auto-selection from room creation.
        container.read(selectedElementProvider.notifier).select(null);
        await tester.pump();

        // Switch tools to break the Wall tool's click-chain left over from the
        // room-closing tap (switching cancels the previous tool — see
        // FloorPlanCanvas), then re-activate the Wall tool for a fresh segment.
        await tester.tap(find.byTooltip('Select'));
        await tester.pump();
        await tester.tap(find.byTooltip('Wall'));
        await tester.pump();

        // ── Draw a new wall far to the right that should align to y = 3000 ──
        // First tap: start at (6000, 0) — on grid, no endpoint nearby.
        await tester.tapAt(w2g(6000, 0));
        await tester.pump();

        // Second tap at raw (6000, 2940):
        //   • nearest existing endpoint is (4000, 3000), ~2000 mm away →
        //     no endpoint snap (threshold 200 mm).
        //   • grid snap alone → (6000, 2900).
        //   • alignment: corner row y = 3000 is 100 mm from 2900 (≤ 150) →
        //     y snaps to 3000; no corner shares x ≈ 6000 → x stays 6000.
        await tester.tapAt(w2g(6000, 2940));
        await _pump(tester, 3);

        // ── Assert: the committed wall ends on the corner row, not the grid ─
        final walls = container.read(editorStateProvider).walls;
        expect(walls, hasLength(wallsAfterRoom + 1),
            reason: 'exactly one new wall should have been committed');

        final newWall = walls.firstWhere(
          (w) =>
              (w.startPoint.x - 6000.0).abs() < 1.0 &&
              (w.endPoint.x - 6000.0).abs() < 1.0,
          orElse: () => throw StateError('new vertical wall at x=6000 not found'),
        );

        expect(newWall.startPoint.y, closeTo(0, 0.5));
        expect(
          newWall.endPoint.y,
          closeTo(3000, 0.5),
          reason: 'corner alignment must pull the endpoint to the existing '
              'room corner row (3000), overriding grid snap (2900)',
        );

        // ── Teardown ─────────────────────────────────────────────────────
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });
}
