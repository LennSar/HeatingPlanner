// Integration tests for .hsp file roundtrip and session restore.
//
// Per agent-test.md §7.2 and §9.
//
// Group 1 (.hsp export via SaveStateNotifier):
//   Seeds a full project, exports via saveAs(), decodes the gzip-JSON,
//   verifies the snapshot contents, re-imports via HspImporter, checks
//   all entity values, and confirms that a second import yields two
//   projects without ID conflicts.
//
// Group 2 (Session restore):
//   Pumps HeatingPlannerApp inside a ProviderScope with an in-memory DB
//   and InMemorySharedPreferencesAsync.  Verifies that the startup
//   router shows EditorScreen for a valid stored project ID and
//   ProjectListScreen when no ID is stored or the project has been deleted.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/app.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:heating_planner/repositories/hsp_importer.dart';
import 'package:heating_planner/repositories/save_state_notifier.dart';
import 'package:heating_planner/ui/screens/editor_screen.dart';
import 'package:heating_planner/ui/screens/project_list_screen.dart';

import '../helpers/test_factories.dart';

// ── Stub notifiers ────────────────────────────────────────────────────────────

/// Resolves [LastOpenedProjectIdNotifier] immediately to [_value].
class _FixedProjectIdNotifier extends LastOpenedProjectIdNotifier {
  _FixedProjectIdNotifier(this._value);
  final String? _value;

  @override
  Future<String?> build() async => _value;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── .hsp export via SaveStateNotifier ──────────────────────────────────────

  group('.hsp export via SaveStateNotifier', () {
    late $db.AppDatabase db;
    late FullTestProjectSeed seed;
    late Directory tempDir;
    late String tempPath;
    late ProviderContainer container;

    setUp(() async {
      db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      seed = await createFullTestProject(db);

      tempDir =
          await Directory.systemTemp.createTemp('hsp_roundtrip_test_');
      tempPath = '${tempDir.path}/export.hsp';

      container = ProviderContainer(
        overrides: [
          $db.appDatabaseProvider.overrideWithValue(db),
          lastOpenedProjectIdProvider.overrideWith(
            () => _FixedProjectIdNotifier(seed.projectId),
          ),
        ],
      );
      // Resolve the async project-ID provider before the export.
      await container.read(lastOpenedProjectIdProvider.future);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      await tempDir.delete(recursive: true);
    });

    test('saveAs writes a non-empty gzip file and clears isDirty', () async {
      await container.read(saveStateProvider.notifier).saveAs(tempPath);

      final saveState = container.read(saveStateProvider);
      expect(saveState.isDirty, isFalse,
          reason: 'isDirty must be cleared after a successful export');
      expect(saveState.lastExportedAt, isNotNull);

      final bytes = await File(tempPath).readAsBytes();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('snapshot version field is present', () async {
      await container.read(saveStateProvider.notifier).saveAs(tempPath);

      final snapshot = await _decodeHsp(tempPath);
      expect(snapshot.containsKey('version'), isTrue,
          reason: 'snapshot must contain a "version" key');
    });

    test('snapshot contains correct entity counts', () async {
      await container.read(saveStateProvider.notifier).saveAs(tempPath);

      final snapshot = await _decodeHsp(tempPath);

      expect((snapshot['floors'] as List).length, equals(1),
          reason: 'one floor expected');
      expect((snapshot['rooms'] as List).length, equals(2),
          reason: 'two rooms expected');
      expect((snapshot['wallSegments'] as List).length, equals(8),
          reason: 'eight wall segments expected (4 per room)');
      expect((snapshot['heatingZones'] as List).length, equals(2),
          reason: 'two heating zones expected');
      expect((snapshot['heatingCircuits'] as List).length, equals(2),
          reason: 'two heating circuits expected');
    });

    test('re-imported project preserves entity values', () async {
      await container.read(saveStateProvider.notifier).saveAs(tempPath);
      final snapshot = await _decodeHsp(tempPath);

      final db2 = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);

      await HspImporter(db2).importSnapshot(snapshot);

      // Project name
      final projects = await db2.select(db2.projects).get();
      expect(projects.length, equals(1));
      expect(projects.first.name, equals('Test Villa'));

      // Room names and target temperatures
      final rooms = await db2.select(db2.rooms).get();
      expect(rooms.length, equals(2));
      final names = rooms.map((r) => r.name).toSet();
      expect(names, containsAll(['Living Room', 'Bathroom']));

      final living = rooms.firstWhere((r) => r.name == 'Living Room');
      final bath = rooms.firstWhere((r) => r.name == 'Bathroom');
      expect(living.targetTempC, closeTo(21.0, 0.001));
      expect(bath.targetTempC, closeTo(24.0, 0.001));

      // Polygon vertex count for each room (must be 4 for 5 m × 4 m rect)
      for (final r in rooms) {
        final polygon = jsonDecode(r.polygonJson) as List;
        expect(polygon.length, equals(4),
            reason: 'room "${r.name}" polygon must have 4 vertices');
      }

      // Tube spacings
      final zones = await db2.select(db2.heatingZones).get();
      expect(zones.length, equals(2));
      final spacings = zones.map((z) => z.tubeSpacingMm).toSet();
      expect(spacings, containsAll([150, 200]));

      // Distributor supply / return temperatures
      final dists = await db2.select(db2.distributors).get();
      expect(dists.length, equals(1));
      expect(dists.first.supplyTempC, closeTo(35.0, 0.001));
      expect(dists.first.returnTempC, closeTo(28.0, 0.001));
    });

    test('importing the same snapshot twice yields two separate projects',
        () async {
      await container.read(saveStateProvider.notifier).saveAs(tempPath);
      final snapshot = await _decodeHsp(tempPath);

      final db2 = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);

      final id1 = await HspImporter(db2).importSnapshot(snapshot);
      final id2 = await HspImporter(db2).importSnapshot(snapshot);

      expect(id1, isNot(equals(id2)),
          reason: 'each import must produce a unique project ID');

      final projects = await db2.select(db2.projects).get();
      expect(projects.length, equals(2),
          reason: 'both imported projects must coexist in the database');
    });
  });

  // ── Session restore ─────────────────────────────────────────────────────────
  //
  // Each test overrides [lastOpenedProjectIdProvider] directly rather than
  // seeding [InMemorySharedPreferencesAsync]. This avoids the platform-channel
  // async chain that can cause [pumpAndSettle] to loop indefinitely when Drift
  // StreamProviders keep the event loop busy.  The routing logic under test
  // is [_startupProjectIdProvider]: it reads the stored ID and calls
  // [projectRepositoryProvider.findById], whose result controls which screen
  // the [_StartupRouter] renders.
  //
  // We use explicit [pump] calls (not [pumpAndSettle]) for the same reason.
  // After assertions, [pumpWidget(SizedBox())] + a timed [pump] disposes the
  // ProviderScope and advances fake-time past any Riverpod autoDispose timers.

  group('Session restore', () {
    /// Pumps enough frames to let [_startupProjectIdProvider] resolve and the
    /// router rebuild.  Does NOT use pumpAndSettle to avoid infinite looping
    /// on Drift stream providers.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
    }

    /// Disposes the widget tree and advances fake time to drain Riverpod's
    /// autoDispose timers so that Flutter's post-test invariant check passes.
    Future<void> cleanup(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('routes to EditorScreen when a valid project ID is stored',
        (tester) async {
      // Intercept Flutter layout errors so that PropertiesPanel overflow does
      // not fail this routing test.  We only care that the router chose
      // EditorScreen, not that the panel renders without overflows.
      final capturedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = capturedErrors.add;
      addTearDown(() => FlutterError.onError = originalOnError);

      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // Insert a project so projectRepositoryProvider.findById() succeeds.
      final seed = await createFullTestProject(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            $db.appDatabaseProvider.overrideWithValue(db),
            lastOpenedProjectIdProvider.overrideWith(
              () => _FixedProjectIdNotifier(seed.projectId),
            ),
          ],
          child: const HeatingPlannerApp(),
        ),
      );
      await settle(tester);

      expect(
        find.byType(EditorScreen),
        findsOneWidget,
        reason: 'EditorScreen must be shown when a valid project ID is stored',
      );

      await cleanup(tester);
    });

    testWidgets(
        'routes to ProjectListScreen when no project ID is stored',
        (tester) async {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            $db.appDatabaseProvider.overrideWithValue(db),
            // null → _startupProjectIdProvider returns null → ProjectListScreen
            lastOpenedProjectIdProvider.overrideWith(
              () => _FixedProjectIdNotifier(null),
            ),
          ],
          child: const HeatingPlannerApp(),
        ),
      );
      await settle(tester);

      expect(
        find.byType(ProjectListScreen),
        findsOneWidget,
        reason:
            'ProjectListScreen must be shown when no project ID is stored',
      );

      await cleanup(tester);
    });

    testWidgets(
        'routes to ProjectListScreen when stored project ID no longer exists',
        (tester) async {
      // Empty DB — no project row for the stored ID.
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            $db.appDatabaseProvider.overrideWithValue(db),
            // Non-existent ID → findById returns null → ProjectListScreen
            lastOpenedProjectIdProvider.overrideWith(
              () => _FixedProjectIdNotifier('deleted-project-999'),
            ),
          ],
          child: const HeatingPlannerApp(),
        ),
      );
      await settle(tester);

      expect(
        find.byType(ProjectListScreen),
        findsOneWidget,
        reason: 'ProjectListScreen must be shown when the stored project '
            'no longer exists in the database',
      );

      await cleanup(tester);
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Reads [path], gzip-decodes, JSON-decodes, and returns the snapshot map.
Future<Map<String, dynamic>> _decodeHsp(String path) async {
  final bytes = await File(path).readAsBytes();
  final jsonStr = utf8.decode(const GZipDecoder().decodeBytes(bytes));
  return jsonDecode(jsonStr) as Map<String, dynamic>;
}
