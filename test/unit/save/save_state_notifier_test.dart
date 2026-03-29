// Tests for SaveStateNotifier, SaveState, SaveStateMixin, and AppPreferences.
//
// Per agent-test.md §3.1 and §12. Timer tests use package:fake_async to avoid
// real 3-second waits.  AppPreferences tests use InMemorySharedPreferencesAsync
// so that no real SharedPreferences platform channel is needed.

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:heating_planner/repositories/save_state_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

/// Overrides [LastOpenedProjectIdNotifier] to stay in the loading state
/// forever.  [exportNow]'s `asData?.value` check returns null, so the export
/// exits early without any database or file-system interaction.
class _LoadingProjectIdNotifier extends LastOpenedProjectIdNotifier {
  @override
  Future<String?> build() => Completer<String?>().future; // never resolves
}

/// Overrides [LastOpenedProjectIdNotifier] to resolve immediately to [value].
class _FixedProjectIdNotifier extends LastOpenedProjectIdNotifier {
  _FixedProjectIdNotifier(this._value);
  final String? _value;

  @override
  Future<String?> build() async => _value;
}

/// A notifier that mixes in [SaveStateMixin] for mixin-group tests.
///
/// [doWrite] simulates a repository mutation; [doReadOnly] simulates a query.
class _MixinTestNotifier extends Notifier<void> with SaveStateMixin {
  @override
  void build() {}

  void doWrite() => markProjectDirty();
  void doReadOnly() {}
}

final _mixinTestProvider =
    NotifierProvider<_MixinTestNotifier, void>(_MixinTestNotifier.new);

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
  await db.into(db.projects).insert(
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
    test(
        'starts with isDirty = false, isAutoExporting = false, '
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

    test(
        'already dirty: isDirty stays true and no second state emission', () {
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

    test('starts a debounce timer when lastExportPath is set', () {
      fakeAsync((fake) {
        final container = ProviderContainer(
          overrides: [
            lastOpenedProjectIdProvider
                .overrideWith(_LoadingProjectIdNotifier.new),
          ],
        );

        // saveAs sets lastExportPath and calls exportNow, which exits early
        // because the project-id provider never resolves.
        container.read(saveStateProvider.notifier).saveAs('/tmp/test.hsp');
        fake.flushMicrotasks();

        final states = <SaveState>[];
        container.listen(
          saveStateProvider,
          (_, next) => states.add(next),
          fireImmediately: false,
        );

        container.read(saveStateProvider.notifier).markDirty();

        // Before the 3 s debounce window: no export attempt yet.
        expect(states.every((s) => !s.isAutoExporting), isTrue);

        // Advance past the debounce window — timer fires → exportNow called.
        fake.elapse(const Duration(seconds: 4));
        fake.flushMicrotasks();

        // exportNow set isAutoExporting = true before the early-exit path.
        expect(
          states.any((s) => s.isAutoExporting),
          isTrue,
          reason: 'exportNow should have been triggered by the debounce timer',
        );

        container.dispose();
      });
    });

    test(
        'calling markDirty() twice resets the timer — only one export fires',
        () {
      fakeAsync((fake) {
        final container = ProviderContainer(
          overrides: [
            lastOpenedProjectIdProvider
                .overrideWith(_LoadingProjectIdNotifier.new),
          ],
        );

        container.read(saveStateProvider.notifier).saveAs('/tmp/test.hsp');
        fake.flushMicrotasks();

        final states = <SaveState>[];
        container.listen(
          saveStateProvider,
          (_, next) => states.add(next),
          fireImmediately: false,
        );

        // t = 0: first markDirty → timer T1 (fires at t = 3 s).
        container.read(saveStateProvider.notifier).markDirty();
        fake.elapse(const Duration(seconds: 2));
        // t = 2: second markDirty → T1 cancelled, timer T2 (fires at t = 5 s).
        container.read(saveStateProvider.notifier).markDirty();
        // t = 6: T2 has fired; T1 must NOT have fired.
        fake.elapse(const Duration(seconds: 4));
        fake.flushMicrotasks();

        expect(
          states.where((s) => s.isAutoExporting).length,
          equals(1),
          reason: 'exactly one export should have been triggered',
        );

        container.dispose();
      });
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

    test('cancels any pending debounce timer', () {
      fakeAsync((fake) {
        final container = ProviderContainer(
          overrides: [
            lastOpenedProjectIdProvider
                .overrideWith(_LoadingProjectIdNotifier.new),
          ],
        );

        container.read(saveStateProvider.notifier).saveAs('/tmp/test.hsp');
        fake.flushMicrotasks();

        final states = <SaveState>[];
        container.listen(
          saveStateProvider,
          (_, next) => states.add(next),
          fireImmediately: false,
        );

        container.read(saveStateProvider.notifier).markDirty();
        // Cancel before the 3 s window elapses.
        container.read(saveStateProvider.notifier).clearDirty();
        fake.elapse(const Duration(seconds: 4));
        fake.flushMicrotasks();

        // exportNow must NOT have been called after clearDirty cancelled the
        // timer.
        expect(
          states.every((s) => !s.isAutoExporting),
          isTrue,
          reason: 'clearDirty() should have cancelled the debounce timer',
        );

        container.dispose();
      });
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

    test('sets isAutoExporting = true while the export is in progress', () {
      fakeAsync((fake) {
        final container = ProviderContainer(
          overrides: [
            lastOpenedProjectIdProvider
                .overrideWith(_LoadingProjectIdNotifier.new),
          ],
        );

        container.read(saveStateProvider.notifier).saveAs('/tmp/test.hsp');
        fake.flushMicrotasks();

        final states = <SaveState>[];
        container.listen(
          saveStateProvider,
          (_, next) => states.add(next),
          fireImmediately: false,
        );

        // exportNow synchronously sets isAutoExporting = true then exits early
        // (null projectId).  Both transitions happen before the first await.
        container.read(saveStateProvider.notifier).exportNow();
        fake.flushMicrotasks();

        expect(
          states.any((s) => s.isAutoExporting),
          isTrue,
        );

        container.dispose();
      });
    });

    test('after successful export: isDirty = false, lastExportedAt is set',
        () async {
      final db = buildTestDatabase();
      addTearDown(db.close);
      await insertTestProject(db, id: 'proj-1');

      final dir = await Directory.systemTemp.createTemp('hsp_test_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/test.hsp';

      final container = ProviderContainer(
        overrides: [
          $db.appDatabaseProvider.overrideWithValue(db),
          lastOpenedProjectIdProvider
              .overrideWith(() => _FixedProjectIdNotifier('proj-1')),
        ],
      );
      addTearDown(container.dispose);

      // Warm up the async provider so asData resolves before exportNow reads it.
      container.read(lastOpenedProjectIdProvider);
      await Future<void>.delayed(Duration.zero);

      // Set state: dirty with a known export path.
      // ignore: invalid_use_of_protected_member
      container.read(saveStateProvider.notifier).state =
          container.read(saveStateProvider).copyWith(
        isDirty: true,
        lastExportPath: path,
      );

      await container.read(saveStateProvider.notifier).exportNow();

      final state = container.read(saveStateProvider);
      expect(state.isDirty, isFalse);
      expect(state.lastExportedAt, isNotNull);
      expect(state.isAutoExporting, isFalse);
    });

    test('on write failure: isDirty stays true, isAutoExporting = false',
        () async {
      // Empty DB — no project with id 'missing' → buildSnapshot throws.
      final db = buildTestDatabase();
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [
          $db.appDatabaseProvider.overrideWithValue(db),
          lastOpenedProjectIdProvider
              .overrideWith(() => _FixedProjectIdNotifier('missing')),
        ],
      );
      addTearDown(container.dispose);

      container.read(lastOpenedProjectIdProvider);
      await Future<void>.delayed(Duration.zero);

      // ignore: invalid_use_of_protected_member
      container.read(saveStateProvider.notifier).state =
          container.read(saveStateProvider).copyWith(
        isDirty: true,
        lastExportPath: '/tmp/irrelevant.hsp',
      );

      await container.read(saveStateProvider.notifier).exportNow();

      final state = container.read(saveStateProvider);
      expect(state.isDirty, isTrue);
      expect(state.isAutoExporting, isFalse);
    });
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
    });

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

    test('lastOpenedProjectId round-trip: write → read returns same value',
        () async {
      final prefs = AppPreferences();
      await prefs.setLastOpenedProjectId('abc-123');
      expect(await prefs.getLastOpenedProjectId(), equals('abc-123'));
    });

    test('lastOpenedProjectId returns null when no value has been written',
        () async {
      final prefs = AppPreferences();
      expect(await prefs.getLastOpenedProjectId(), isNull);
    });

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
