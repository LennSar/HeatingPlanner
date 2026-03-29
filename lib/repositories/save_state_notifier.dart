import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';

import '../data/database/app_database.dart' as $db;
import 'app_preferences.dart';
import 'hsp_exporter.dart';

part 'save_state_notifier.freezed.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// Tracks whether the in-database project state has diverged from the last
/// `.hsp` export (or has never been exported).
///
/// Dirty state is distinct from "unsaved data" — all project data is always
/// persisted in SQLite immediately. The `.hsp` file is a portable point-in-time
/// snapshot; [isDirty] indicates whether a new snapshot is due.
@freezed
abstract class SaveState with _$SaveState {
  const factory SaveState({
    /// `true` when in-database changes have not yet been written to the
    /// `.hsp` export file.
    required bool isDirty,

    /// Timestamp of the most recent successful `.hsp` export.
    /// `null` if the project has never been exported.
    required DateTime? lastExportedAt,

    /// Absolute file-system path of the most recent `.hsp` export.
    /// `null` if the project has never been exported, or the path is
    /// unknown.
    required String? lastExportPath,

    /// `true` while a background `.hsp` write is in progress.
    required bool isAutoExporting,
  }) = _SaveState;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Manages [SaveState] for the currently open project.
///
/// Repositories call [markDirty] after every successful write, which
/// sets [SaveState.isDirty] and schedules a debounced [exportNow] (3 s)
/// whenever [SaveState.lastExportPath] is non-null.
///
/// [exportNow] and [saveAs] drive the `.hsp` write directly and can also be
/// invoked from keyboard shortcuts or the File menu without waiting for the
/// debounce to fire.
class SaveStateNotifier extends Notifier<SaveState> {
  static final _log = Logger('SaveStateNotifier');

  Timer? _debounce;

  @override
  SaveState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SaveState(
      isDirty: false,
      lastExportedAt: null,
      lastExportPath: null,
      isAutoExporting: false,
    );
  }

  /// Marks the project as dirty — in-database state has changed since the
  /// last `.hsp` export.
  ///
  /// If [SaveState.lastExportPath] is set, schedules a debounced [exportNow]
  /// 3 seconds after the last [markDirty] call (cancels any pending timer).
  void markDirty() {
    if (!state.isDirty) {
      state = state.copyWith(isDirty: true);
    }
    if (state.lastExportPath != null) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(seconds: 3),
        () => unawaited(exportNow()),
      );
    }
  }

  /// Clears the dirty flag and cancels any pending debounce timer.
  void clearDirty() {
    _debounce?.cancel();
    _debounce = null;
    state = state.copyWith(isDirty: false);
  }

  /// Writes the current project state to [SaveState.lastExportPath].
  ///
  /// - Cancels any pending debounce timer.
  /// - Sets [SaveState.isAutoExporting] to `true` during the write.
  /// - On success: clears [SaveState.isDirty] and updates
  ///   [SaveState.lastExportedAt].
  /// - On failure: logs the error and leaves [SaveState.isDirty] `true`.
  ///
  /// Does nothing if [SaveState.lastExportPath] is `null`.
  Future<void> exportNow() async {
    final path = state.lastExportPath;
    if (path == null) return;

    _debounce?.cancel();
    _debounce = null;

    state = state.copyWith(isAutoExporting: true);

    try {
      final projectId =
          ref.read(lastOpenedProjectIdProvider).asData?.value;
      if (projectId == null) {
        state = state.copyWith(isAutoExporting: false);
        return;
      }

      final exporter = HspExporter(ref.read($db.appDatabaseProvider));
      final snapshot = await exporter.buildSnapshot(projectId);

      final jsonBytes = utf8.encode(jsonEncode(snapshot));
      final compressed = const GZipEncoder().encode(jsonBytes);

      await File(path).writeAsBytes(Uint8List.fromList(compressed));

      state = state.copyWith(
        isDirty: false,
        lastExportedAt: DateTime.now(),
        isAutoExporting: false,
      );
    } catch (e, st) {
      _log.severe('HSP export to "$path" failed', e, st);
      state = state.copyWith(isAutoExporting: false);
      // isDirty intentionally left true — UI can react to the persisted flag.
    }
  }

  /// Sets [SaveState.lastExportPath] to [path] and immediately calls
  /// [exportNow].
  ///
  /// Use this for the "Save As" action where the user has chosen a new path.
  Future<void> saveAs(String path) async {
    state = state.copyWith(lastExportPath: path);
    await exportNow();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Singleton [SaveState] provider. Consume this to react to dirty-state
/// changes (e.g. to show an unsaved-changes indicator in the title bar).
///
/// Write operations reach the notifier via:
/// ```dart
/// ref.read(saveStateProvider.notifier).markDirty();
/// ```
final saveStateProvider =
    NotifierProvider<SaveStateNotifier, SaveState>(
  SaveStateNotifier.new,
);

// ── Mixin ─────────────────────────────────────────────────────────────────────

/// Convenience mixin for classes that hold a [Ref] and need to mark the
/// project dirty after a mutation.
///
/// Mix this into any [Notifier] subclass (or other [Ref]-owning class) that
/// performs repository writes:
///
/// ```dart
/// class MyNotifier extends Notifier<MyState> with SaveStateMixin {
///   void doWrite() {
///     repository.insert(entity);
///     markProjectDirty();
///   }
/// }
/// ```
mixin SaveStateMixin {
  /// The [Ref] provided by the Riverpod framework. Override this in the
  /// class that uses the mixin.
  Ref get ref;

  /// Marks the currently open project as dirty.
  void markProjectDirty() {
    ref.read(saveStateProvider.notifier).markDirty();
  }
}
