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
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/app.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:heating_planner/repositories/hsp_exporter.dart';
import 'package:heating_planner/repositories/hsp_importer.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/repositories/project_repository.dart'
    show currentProjectIdProvider;
import 'package:heating_planner/repositories/save_state_notifier.dart';
import 'package:heating_planner/ui/screens/editor_screen.dart';
import 'package:heating_planner/ui/screens/project_list_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/test_factories.dart';

// ── Stub notifiers ────────────────────────────────────────────────────────────

/// Test fake that resolves every path_provider directory to [dir] so the
/// startup chain (custom-material library file, migration export folder) works
/// without the real plugin.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

/// Inserts one built-in material so `MaterialRepository.ensureMaterialsSeeded`
/// short-circuits (it requires both a matching version **and** a non-empty
/// material table) instead of loading `assets/materials.json` via `rootBundle`,
/// which does not resolve under the fake test clock.
Future<void> _seedMaterialNoOp($db.AppDatabase db) async {
  await db.into(db.materialEntries).insert(
        $db.MaterialEntriesCompanion.insert(
          id: 'builtin-stub',
          name: 'Stub',
          categoryPath: '["x"]',
          lambdaDefault: 1,
          densityDefault: 1,
          specificHeatDefault: 1,
          isBuiltIn: const Value(true),
        ),
      );
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
        overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
      );
      // The exporter targets the project open in the editor.
      container.read(currentProjectIdProvider.notifier).set(seed.projectId);
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
  // Document storage model: the startup router restores by the last-opened
  // `.hsp` file path (`lastOpenedDocumentPath`), loading it into the database
  // working copy. It shows EditorScreen for a valid, existing file and
  // ProjectListScreen when no path is stored or the file is missing.
  //
  // `documentMigrationDone` is pre-set so the one-time legacy migration is a
  // no-op (it would otherwise call path_provider, unavailable in tests).

  group('Session restore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('session_restore_test_');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
        'materialDbVersion': materialDbVersion,
      });
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    /// Boots [HeatingPlannerApp] and lets the startup [FutureProvider] finish.
    ///
    /// The startup chain does real I/O (SharedPreferences, the custom-material
    /// library file, `.hsp` files) that only progresses on the real event loop,
    /// so the widget pump **and** any [beforePump] fixture setup run inside
    /// [WidgetTester.runAsync]; the fake-clock pumps afterwards render the
    /// resolved router. Avoids pumpAndSettle (loops on the editor's Drift
    /// stream providers).
    Future<void> bootApp(
      WidgetTester tester,
      $db.AppDatabase db, {
      Future<void> Function()? beforePump,
    }) async {
      await tester.runAsync(() async {
        if (beforePump != null) await beforePump();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
            child: const HeatingPlannerApp(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    /// Disposes the widget tree and advances fake time to drain Riverpod's
    /// autoDispose timers so that Flutter's post-test invariant check passes.
    Future<void> cleanup(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('routes to EditorScreen when a valid document path is stored',
        (tester) async {
      // Intercept Flutter layout errors so that PropertiesPanel overflow does
      // not fail this routing test.
      final capturedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = capturedErrors.add;

      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await bootApp(
        tester,
        db,
        beforePump: () async {
          await _seedMaterialNoOp(db);
          // Write a real .hsp file and point the session at it.
          final seed = await createFullTestProject(db);
          final path = '${tempDir.path}/restore.hsp';
          final snapshot = await HspExporter(db).buildSnapshot(seed.projectId);
          await File(path).writeAsBytes(
            const GZipEncoder().encode(utf8.encode(jsonEncode(snapshot))),
          );
          await AppPreferences().setLastOpenedDocumentPath(path);
        },
      );

      // Restore FlutterError.onError before any expect() — the framework
      // asserts it is restored before the test body returns.
      FlutterError.onError = originalOnError;

      expect(
        find.byType(EditorScreen),
        findsOneWidget,
        reason:
            'EditorScreen must be shown when a valid document path is stored',
      );

      await cleanup(tester);
    });

    testWidgets('routes to ProjectListScreen when no document path is stored',
        (tester) async {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await bootApp(
        tester,
        db,
        beforePump: () => _seedMaterialNoOp(db),
      );

      expect(
        find.byType(ProjectListScreen),
        findsOneWidget,
        reason:
            'ProjectListScreen must be shown when no document path is stored',
      );

      await cleanup(tester);
    });

    testWidgets(
        'routes to ProjectListScreen when the stored document file is missing',
        (tester) async {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await bootApp(
        tester,
        db,
        beforePump: () async {
          await _seedMaterialNoOp(db);
          // Path points at a file that does not exist.
          await AppPreferences()
              .setLastOpenedDocumentPath('${tempDir.path}/gone.hsp');
        },
      );

      expect(
        find.byType(ProjectListScreen),
        findsOneWidget,
        reason: 'ProjectListScreen must be shown when the stored document '
            'file no longer exists',
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
