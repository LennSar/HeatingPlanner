// Integration test: full workflow from empty canvas to VR-04 warning.
//
// Per agent-test.md §7.1.
//
// Steps covered:
//   FW-1  EditorScreen renders without errors.
//   FW-2  Wall tool activated; 5 canvas taps draw a 2 000 mm × 2 000 mm
//         rectangle; room auto-detected and confirmed via dialog; room
//         exists in editorStateProvider.rooms.
//   FW-3  Room is auto-selected after creation; selectedElementProvider
//         holds type='room' and the new room's ID.
//   FW-4  Zone tool activated; 4 taps draw a triangle inside the room;
//         zone exists in editorStateProvider.zones.
//   FW-5  Distributor tool activated; tap places a distributor;
//         editorStateProvider.distributor is not null.
//   FW-6  Warnings tab in the performance dashboard shows at least one
//         VR-04 entry ('Heating zone has no circuit connected.').
//
// The canvas controller is overridden with a fixed state (zoom = 0.1,
// panOffset = Offset(100, 100)) so world-coordinate → screen-coordinate
// conversions are deterministic across viewport sizes:
//
//   screenLocal = Offset(world.x * 0.1 + 100, world.y * 0.1 + 100)
//   global      = canvasTopLeft + screenLocal
//
// pumpAndSettle is intentionally avoided throughout; Drift's StreamProviders
// (e.g. projectProvider) keep the event loop busy and cause it to loop
// indefinitely.  Explicit pump() calls are used instead.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/ui/canvas/canvas_controller.dart';
import 'package:heating_planner/ui/canvas/floor_plan_canvas.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';
import 'package:heating_planner/ui/providers/selection_provider.dart';
import 'package:heating_planner/ui/screens/editor_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// ── Fixed canvas controller ───────────────────────────────────────────────────

/// A [CanvasController] whose state is frozen at zoom = 0.1,
/// panOffset = Offset(100, 100).
///
/// Overrides [setInitialView] as a no-op so the canvas layout callback
/// cannot change the transform during the test.
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

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Pumps [count] frames, mirroring the settle() helper in
/// file_roundtrip_test.dart to let async provider work complete without
/// triggering infinite loops from Drift stream providers.
Future<void> _pump(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump();
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Full workflow integration (FW-1 … FW-6)', () {
    testWidgets(
      'wall draw → room → zone → distributor → VR-04 warning',
      (tester) async {
        // ── Viewport ───────────────────────────────────────────────────────
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // ── SharedPreferences mock ─────────────────────────────────────────
        // EditorScreen.initState reads appPreferencesProvider (backed by
        // SharedPreferencesAsync). Set an in-memory platform so the provider
        // does not throw in the test environment.
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();

        // ── Database ───────────────────────────────────────────────────────
        final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        // Seed a bare project + floor; no rooms, walls, or zones so the
        // test exercises the full drawing workflow from scratch.
        const projectId = 'fw-proj-1';
        const floorId = 'fw-floor-1';
        final now = DateTime(2025, 1, 1);

        await db.into(db.projects).insert(
          $db.ProjectsCompanion.insert(
            id: projectId,
            name: 'Workflow Test',
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

        // ── Provider container ─────────────────────────────────────────────
        final container = ProviderContainer(
          overrides: [
            $db.appDatabaseProvider.overrideWithValue(db),
            // Fixed canvas transform: zoom=0.1, pan=(100,100).
            // world (x, y) → local (x*0.1+100, y*0.1+100)
            canvasControllerProvider
                .overrideWith(_FixedCanvasController.new),
          ],
        );
        addTearDown(container.dispose);

        // ── Pump widget ────────────────────────────────────────────────────
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const EditorScreen(projectId: projectId),
            ),
          ),
        );

        // Allow EditorScreen.initState post-frame callback to run, the
        // building repository to query the floor, and initFromFloor to
        // complete its async DB reads.
        await _pump(tester, 10);

        // ── FW-1: EditorScreen renders ─────────────────────────────────────
        expect(
          find.byType(EditorScreen),
          findsOneWidget,
          reason: 'FW-1: EditorScreen must render without errors',
        );

        // ── Canvas coordinate helper ───────────────────────────────────────
        // Converts world-mm coordinates to a global tap position using the
        // fixed canvas transform and the canvas widget's screen position.
        final canvasTopLeft =
            tester.getTopLeft(find.byType(FloorPlanCanvas));

        Offset w2g(double wx, double wy) =>
            canvasTopLeft +
            Offset(
              wx * _FixedCanvasController._zoom +
                  _FixedCanvasController._panX,
              wy * _FixedCanvasController._zoom +
                  _FixedCanvasController._panY,
            );

        // ── FW-2: Draw walls (2 000 mm × 2 000 mm rectangle) ──────────────
        // Tap the Wall tool button in the toolbar.
        await tester.tap(find.byTooltip('Wall'));
        await tester.pump();

        // Five sequential taps draw four walls that close a rectangle and
        // trigger room auto-detection on the fifth tap:
        //   tap 1: (0,0)         – sets anchor
        //   tap 2: (2000,0)      – commits wall 1, chains to (2000,0)
        //   tap 3: (2000,2000)   – commits wall 2, chains to (2000,2000)
        //   tap 4: (0,2000)      – commits wall 3, chains to (0,2000)
        //   tap 5: (0,0)         – commits wall 4 (close) → room detected
        for (final pt in [
          [0.0, 0.0],
          [2000.0, 0.0],
          [2000.0, 2000.0],
          [0.0, 2000.0],
          [0.0, 0.0], // closing tap — triggers RoomDetection
        ]) {
          await tester.tapAt(w2g(pt[0], pt[1]));
          await tester.pump();
        }

        // The room-name dialog must appear after the rectangle is closed.
        expect(
          find.text('New Room Detected'),
          findsOneWidget,
          reason: 'FW-2: room-detection dialog must appear after closing the '
              'rectangular wall loop',
        );

        // Confirm with the default name ('Room 1').
        await tester.tap(find.text('Create'));
        await _pump(tester, 5);

        final roomsAfterDraw =
            container.read(editorStateProvider).rooms;
        expect(
          roomsAfterDraw,
          isNotEmpty,
          reason: 'FW-2: a room must be added to editorStateProvider after '
              'the detection dialog is confirmed',
        );

        // ── FW-3: Room is auto-selected ────────────────────────────────────
        final selAfterCreate =
            container.read(selectedElementProvider);
        expect(
          selAfterCreate,
          isNotNull,
          reason:
              'FW-3: selectedElementProvider must be set after room creation',
        );
        expect(
          selAfterCreate!.type,
          equals('room'),
          reason: 'FW-3: selected element type must be "room"',
        );
        expect(
          selAfterCreate.id,
          equals(roomsAfterDraw.first.id),
          reason:
              'FW-3: selected element ID must match the newly created room',
        );

        // Clear selection so RoomProperties (which overflows at 247 px) is
        // not rendered during FW-4 zone drawing.
        container.read(selectedElementProvider.notifier).select(null);
        await tester.pump();

        // ── FW-4: Draw a zone inside the room ─────────────────────────────
        await tester.tap(find.byTooltip('Floor Zone'));
        await tester.pump();

        // Four taps: three vertices forming a triangle inside the 2 000 mm
        // room, then a closing tap back at the first vertex.
        // Zone close threshold = 15 px / zoom = 15 / 0.1 = 150 mm,
        // so re-tapping exactly at (500, 500) closes the polygon.
        for (final pt in [
          [500.0, 500.0], // first vertex (locks primary room)
          [1500.0, 500.0],
          [1500.0, 1500.0],
          [500.0, 500.0], // re-tap first vertex → polygon closed
        ]) {
          await tester.tapAt(w2g(pt[0], pt[1]));
          await tester.pump();
        }

        final zonesAfterDraw =
            container.read(editorStateProvider).zones;
        expect(
          zonesAfterDraw,
          isNotEmpty,
          reason: 'FW-4: a zone must be created inside the room',
        );

        // ── FW-5: Place a distributor ──────────────────────────────────────
        await tester.tap(find.byTooltip('Distributor'));
        await tester.pump();

        // Place the distributor to the right of the room at world (3000, 1000).
        // local = (3000*0.1+100, 1000*0.1+100) = (400, 200) — within canvas.
        await tester.tapAt(w2g(3000.0, 1000.0));
        await _pump(tester, 3);

        expect(
          container.read(editorStateProvider).distributor,
          isNotNull,
          reason:
              'FW-5: distributor must be placed after tapping the canvas',
        );

        // Clear the auto-selection made by DistributorPlaceTool so the
        // DistributorProperties panel (which has a known overflow in a
        // constrained viewport) does not render during subsequent steps.
        container.read(selectedElementProvider.notifier).select(null);
        await tester.pump();

        // ── FW-6: Warnings tab shows VR-04 entry ───────────────────────────
        // Tap the warning count in the status bar; this calls onOpenWarnings
        // which sets _dashboardVisible=true and _dashboardInitialTab=2,
        // opening the dashboard directly on the Warnings tab (no animation).
        await tester.tap(find.textContaining('warning'));
        await _pump(tester, 5);

        // The zone was placed without a circuit, so VR-04 must appear:
        // "Heating zone has no circuit connected."
        expect(
          find.textContaining('Heating zone has no circuit connected'),
          findsAtLeastNWidgets(1),
          reason: 'FW-6: VR-04 must fire for a zone not connected to a '
              'circuit; message must appear in the Warnings tab',
        );

        // ── Teardown ───────────────────────────────────────────────────────
        // Replace widget tree and advance fake time to drain Riverpod's
        // autoDispose timers (mirrors the cleanup in file_roundtrip_test.dart).
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });
}
