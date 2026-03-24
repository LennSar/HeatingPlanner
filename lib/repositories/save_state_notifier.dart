import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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
/// Repositories call [markDirty] after every successful write. The `.hsp`
/// export mechanism (debounced auto-export and manual Save/Save-As) calls
/// [clearDirty] on completion.
class SaveStateNotifier extends Notifier<SaveState> {
  @override
  SaveState build() => const SaveState(
        isDirty: false,
        lastExportedAt: null,
        lastExportPath: null,
        isAutoExporting: false,
      );

  /// Marks the project as dirty — in-database state has changed since the
  /// last `.hsp` export.
  void markDirty() {
    if (!state.isDirty) {
      state = state.copyWith(isDirty: true);
    }
  }

  /// Clears the dirty flag after a successful `.hsp` export.
  void clearDirty() {
    state = state.copyWith(isDirty: false);
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
