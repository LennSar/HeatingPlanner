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
import 'project_repository.dart' show currentProjectIdProvider;

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
/// Document storage model: the `.hsp` file is written **only on explicit
/// save**. Repositories call [markDirty] after every successful database
/// write, which flags the in-memory working copy as ahead of its file; the
/// file itself is not touched until the user invokes [exportNow] (Save) or
/// [saveAs] (Save As). This keeps edits from silently rewriting the on-disk
/// snapshot — e.g. undoing a change must not overwrite the saved file.
class SaveStateNotifier extends Notifier<SaveState> {
  static final _log = Logger('SaveStateNotifier');

  @override
  SaveState build() {
    return const SaveState(
      isDirty: false,
      lastExportedAt: null,
      lastExportPath: null,
      isAutoExporting: false,
    );
  }

  /// Marks the project as dirty — the in-database working copy has changed
  /// since the last `.hsp` save. Does **not** write the file; the dirty flag
  /// surfaces in the title bar and drives the save prompt on close/quit.
  void markDirty() {
    if (!state.isDirty) {
      state = state.copyWith(isDirty: true);
    }
  }

  /// Clears the dirty flag.
  void clearDirty() {
    state = state.copyWith(isDirty: false);
  }

  /// Writes the current project state to [SaveState.lastExportPath].
  ///
  /// - Sets [SaveState.isAutoExporting] to `true` during the write.
  /// - On success: clears [SaveState.isDirty] and updates
  ///   [SaveState.lastExportedAt].
  /// - On failure: logs the error and leaves [SaveState.isDirty] `true`.
  ///
  /// Does nothing if [SaveState.lastExportPath] is `null` or no project is
  /// currently open.
  Future<void> exportNow() async {
    final path = state.lastExportPath;
    if (path == null) return;

    state = state.copyWith(isAutoExporting: true);

    try {
      // Export the project currently open in the editor.
      final projectId = ref.read(currentProjectIdProvider);
      if (projectId.isEmpty) {
        state = state.copyWith(isAutoExporting: false);
        return;
      }

      final exporter = HspExporter(ref.read($db.appDatabaseProvider));
      final snapshot = await exporter.buildSnapshot(projectId);

      final jsonBytes = utf8.encode(jsonEncode(snapshot));
      final compressed = const GZipEncoder().encode(jsonBytes);

      await File(path).writeAsBytes(Uint8List.fromList(compressed));

      final now = DateTime.now();
      state = state.copyWith(
        isDirty: false,
        lastExportedAt: now,
        isAutoExporting: false,
      );

      // Document model: keep the project-list (recent-documents) metadata in
      // sync so the card shows the latest name and save time. Best-effort —
      // a failure here must never fail the save itself.
      final name =
          (snapshot['project'] as Map<String, dynamic>)['name'] as String;
      unawaited(_touchRecentDocument(path, name, now));
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

  /// Refreshes the recent-documents entry for [path], swallowing any error so
  /// a failure to update list metadata never fails the underlying save.
  Future<void> _touchRecentDocument(
    String path,
    String name,
    DateTime when,
  ) async {
    try {
      await ref.read(recentDocumentsProvider.notifier).touch(
            path: path,
            name: name,
            modifiedAt: when,
          );
    } catch (e, st) {
      _log.warning('Failed to refresh recent-documents entry for "$path"', e, st);
    }
  }

  /// Records that the open project was just loaded from [path].
  ///
  /// Sets [SaveState.lastExportPath] and marks the state clean **without**
  /// writing the file — the in-database working copy already matches the file
  /// on disk. Used by the open-document flow of the document storage model.
  void markOpenedFrom(String path) {
    state = state.copyWith(
      lastExportPath: path,
      lastExportedAt: DateTime.now(),
      isDirty: false,
      isAutoExporting: false,
    );
  }

  /// Resets save-state to its initial empty value.
  ///
  /// Called when a project is closed and its working copy is cleared, so the
  /// next opened project starts from a clean slate.
  void reset() {
    state = const SaveState(
      isDirty: false,
      lastExportedAt: null,
      lastExportPath: null,
      isAutoExporting: false,
    );
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
