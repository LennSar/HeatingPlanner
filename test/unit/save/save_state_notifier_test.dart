// Tests for SaveStateNotifier, SaveState, SaveStateMixin, and AppPreferences.
//
// Per agent-test.md §3.1 and §12. Document storage model: the `.hsp` file is
// written only on explicit save (no debounced auto-export), and [exportNow]
// targets the project named by [currentProjectIdProvider]. AppPreferences tests
// use InMemorySharedPreferencesAsync so no real platform channel is needed.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:heating_planner/repositories/project_repository.dart'
    show currentProjectIdProvider;
import 'package:heating_planner/repositories/save_state_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

/// A notifier that mixes in [SaveStateMixin] for mixin-group tests.
///
/// [doWrite] simulates a repository mutation; [doReadOnly] simulates a query.
class _MixinTestNotifier extends Notifier<void> with SaveStateMixin {
  @override
  void build() {}

  void doWrite() => markProjectDirty();
  void doReadOnly() {}
}

final _mixinTestProvider = NotifierProvider<_MixinTestNotifier, void>(
  _MixinTestNotifier.new,
);

// ── Database helpers ──────────────────────────────────────────────────────────

/// Creates an in-memory [AppDatabase] backed by a volatile SQLite file.
/// Uses [AppDatabase.forTesting] so no real path-provider call is made.
$db.AppDatabase buildTestDatabase() =>
    $db.AppDatabase.forTesting(NativeDatabase.memory());

/// Inserts the minimum project row required by [HspExporter.buildSnapshot].
Future<void> insertTestProject(
  $db.AppDatabase db, {
  String id = 'proj-1',
}) async {
  final now = DateTime.now();
  await db
      .into(db.projects)
      .insert(
        $db.ProjectsCompanion.insert(
          id: id,
          name: 'Test Project',
          createdAt: now,
          modifiedAt: now,
        ),
      );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── SaveState initial state ─────────────────────────────────────────────────

  group('SaveState initial state', () {
    test('starts with isDirty = false, isAutoExporting = false, '
        'lastExportPath = null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(saveStateProvider);

      expect(state.isDirty, isFalse);
      expect(state.isAutoExporting, isFalse);
      expect(state.lastExportPath, isNull);
    });
  });

  // ── markDirty ───────────────────────────────────────────────────────────────

  group('markDirty', () {
    test('sets isDirty = true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(saveStateProvider.notifier).markDirty();

      expect(container.read(saveStateProvider).isDirty, isTrue);
    });

    test('already dirty: isDirty stays true and no second state emission', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var emitCount = 0;
      container.listen(
        saveStateProvider,
        (_, __) => emitCount++,
        fireImmediately: false,
      );

      container.read(saveStateProvider.notifier).markDirty(); // false → true
      container.read(saveStateProvider.notifier).markDirty(); // no-op

      expect(container.read(saveStateProvider).isDirty, isTrue);
      expect(emitCount, equals(1));
    });

    test('does NOT write the file even when lastExportPath is set '
        '(explicit-save model)', () async {
      final db = buildTestDatabase();
      addTearDown(db.close);
      await insertTestProject(db, id: 'proj-1');

      final dir = await Directory.systemTemp.createTemp('hsp_test_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/test.hsp';

      final container = ProviderContainer(
        overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.read(currentProjectIdProvider.notifier).set('proj-1');

      // Associate a file with the open project, then make an edit.
      container.read(saveStateProvider.notifier).markOpenedFrom(path);
      container.read(saveStateProvider.notifier).markDirty();
      // Give any (now-removed) async auto-export a chance to misfire.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(saveStateProvider);
      expect(state.isDirty, isTrue);
      expect(state.isAutoExporting, isFalse);
      expect(
        File(path).existsSync(),
        isFalse,
        reason: 'editing must not write the .hsp file until an explicit save',
      );
    });
  });

  // ── clearDirty ──────────────────────────────────────────────────────────────

  group('clearDirty', () {
    test('sets isDirty = false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(saveStateProvider.notifier).markDirty();
      container.read(saveStateProvider.notifier).clearDirty();

      expect(container.read(saveStateProvider).isDirty, isFalse);
    });
  });

  // ── exportNow ───────────────────────────────────────────────────────────────

  group('exportNow', () {
    test('does nothing when lastExportPath is null', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final before = container.read(saveStateProvider);
      await container.read(saveStateProvider.notifier).exportNow();

      expect(container.read(saveStateProvider), equals(before));
    });

    test('passes through isAutoExporting = true during the export', () async {
      final db = buildTestDatabase();
      addTearDown(db.close);
      await insertTestProject(db, id: 'proj-1');

      final dir = await Directory.systemTemp.createTemp('hsp_test_');
      addTearDown(() => dir.delete(recursive: true));

      final container = ProviderContainer(
        overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.read(currentProjectIdProvider.notifier).set('proj-1');
      container
          .read(saveStateProvider.notifier)
          .markOpenedFrom('${dir.path}/test.hsp');

      final states = <SaveState>[];
      container.listen(
        saveStateProvider,
        (_, next) => states.add(next),
        fireImmediately: false,
      );

      await container.read(saveStateProvider.notifier).exportNow();

      expect(
        states.any((s) => s.isAutoExporting),
        isTrue,
        reason: 'the transient in-progress state should be observable',
      );
      expect(container.read(saveStateProvider).isAutoExporting, isFalse);
    });

    test(
      'after successful export: isDirty = false, lastExportedAt is set',
      () async {
        final db = buildTestDatabase();
        addTearDown(db.close);
        await insertTestProject(db, id: 'proj-1');

        final dir = await Directory.systemTemp.createTemp('hsp_test_');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}/test.hsp';

        final container = ProviderContainer(
          overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);
        container.read(currentProjectIdProvider.notifier).set('proj-1');

        // Set state: dirty with a known export path.
        // ignore: invalid_use_of_protected_member
        container.read(saveStateProvider.notifier).state = container
            .read(saveStateProvider)
            .copyWith(isDirty: true, lastExportPath: path);

        await container.read(saveStateProvider.notifier).exportNow();

        final state = container.read(saveStateProvider);
        expect(state.isDirty, isFalse);
        expect(state.lastExportedAt, isNotNull);
        expect(state.isAutoExporting, isFalse);
        expect(File(path).existsSync(), isTrue);
      },
    );

    test('does nothing when no project is open', () async {
      final db = buildTestDatabase();
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      // currentProjectId stays '' (no project open).

      // ignore: invalid_use_of_protected_member
      container.read(saveStateProvider.notifier).state = container
          .read(saveStateProvider)
          .copyWith(isDirty: true, lastExportPath: '/tmp/irrelevant.hsp');

      await container.read(saveStateProvider.notifier).exportNow();

      final state = container.read(saveStateProvider);
      expect(state.isDirty, isTrue);
      expect(state.isAutoExporting, isFalse);
    });

    test(
      'on write failure: isDirty stays true, isAutoExporting = false',
      () async {
        // Project id set but no matching row → buildSnapshot throws.
        final db = buildTestDatabase();
        addTearDown(db.close);

        final container = ProviderContainer(
          overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);
        container.read(currentProjectIdProvider.notifier).set('missing');

        // ignore: invalid_use_of_protected_member
        container.read(saveStateProvider.notifier).state = container
            .read(saveStateProvider)
            .copyWith(isDirty: true, lastExportPath: '/tmp/irrelevant.hsp');

        await container.read(saveStateProvider.notifier).exportNow();

        final state = container.read(saveStateProvider);
        expect(state.isDirty, isTrue);
        expect(state.isAutoExporting, isFalse);
      },
    );
  });

  // ── SaveStateMixin ──────────────────────────────────────────────────────────

  group('SaveStateMixin', () {
    test(
      'a repository using SaveStateMixin calls markDirty() after a write',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(_mixinTestProvider.notifier).doWrite();

        expect(container.read(saveStateProvider).isDirty, isTrue);
      },
    );

    test('a read-only method does NOT call markDirty()', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(_mixinTestProvider.notifier).doReadOnly();

      expect(container.read(saveStateProvider).isDirty, isFalse);
    });
  });

  // ── AppPreferences ──────────────────────────────────────────────────────────

  group('AppPreferences', () {
    setUp(() {
      // Replace the real platform with a clean in-memory store so that tests
      // are hermetic and no platform channel is needed.
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test(
      'lastOpenedProjectId round-trip: write → read returns same value',
      () async {
        final prefs = AppPreferences();
        await prefs.setLastOpenedProjectId('abc-123');
        expect(await prefs.getLastOpenedProjectId(), equals('abc-123'));
      },
    );

    test(
      'lastOpenedProjectId returns null when no value has been written',
      () async {
        final prefs = AppPreferences();
        expect(await prefs.getLastOpenedProjectId(), isNull);
      },
    );

    test('canvasZoom round-trips correctly', () async {
      final prefs = AppPreferences();
      await prefs.setCanvasZoom(2.5);
      expect(await prefs.getCanvasZoom(), closeTo(2.5, 0.001));
    });

    test('canvasPanX round-trips correctly', () async {
      final prefs = AppPreferences();
      await prefs.setCanvasPanX(-120.0);
      expect(await prefs.getCanvasPanX(), closeTo(-120.0, 0.001));
    });

    test('canvasPanY round-trips correctly', () async {
      final prefs = AppPreferences();
      await prefs.setCanvasPanY(350.75);
      expect(await prefs.getCanvasPanY(), closeTo(350.75, 0.001));
    });

    test('writing a new value overwrites the previous one', () async {
      final prefs = AppPreferences();
      await prefs.setLastOpenedProjectId('old-id');
      await prefs.setLastOpenedProjectId('new-id');
      expect(await prefs.getLastOpenedProjectId(), equals('new-id'));
    });
  });
}
