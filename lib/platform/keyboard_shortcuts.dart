import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/enums.dart';
import '../l10n/app_localizations.dart';
import '../repositories/document_service.dart';
import '../repositories/project_repository.dart' show currentProjectIdProvider;
import '../repositories/save_state_notifier.dart';
import '../ui/canvas/canvas_controller.dart';
import '../ui/canvas/floor_plan_canvas.dart';
import '../ui/canvas/tools/undo_redo_service.dart';
import '../ui/panels/properties_panel.dart'
    show selectedElementProvider;
import '../ui/providers/editor_state_provider.dart'
    show currentProjectNameProvider;
import '../ui/screens/editor_screen.dart';
import '../ui/screens/project_list_screen.dart';
import '../ui/widgets/save_flash_notifier.dart';

// ----------------------------------------------------------
// Intent definitions (UI/UX Section 8)
// ----------------------------------------------------------

/// Undo the last action.
class UndoIntent extends Intent {
  /// Creates an [UndoIntent].
  const UndoIntent();
}

/// Redo the last undone action.
class RedoIntent extends Intent {
  /// Creates a [RedoIntent].
  const RedoIntent();
}

/// Delete the selected element.
class DeleteIntent extends Intent {
  /// Creates a [DeleteIntent].
  const DeleteIntent();
}

/// Cancel the current tool or deselect.
class CancelIntent extends Intent {
  /// Creates a [CancelIntent].
  const CancelIntent();
}

/// Switch to a specific drawing tool.
class SwitchToolIntent extends Intent {
  /// Creates a [SwitchToolIntent] for [tool].
  const SwitchToolIntent(this.tool);

  /// The tool to switch to.
  final DrawingTool tool;
}

/// Zoom in on the canvas.
class ZoomInIntent extends Intent {
  /// Creates a [ZoomInIntent].
  const ZoomInIntent();
}

/// Zoom out on the canvas.
class ZoomOutIntent extends Intent {
  /// Creates a [ZoomOutIntent].
  const ZoomOutIntent();
}

/// Zoom to fit the entire floor plan.
class ZoomToFitIntent extends Intent {
  /// Creates a [ZoomToFitIntent].
  const ZoomToFitIntent();
}

/// Pan the canvas view by a fixed screen-pixel step (arrow keys — ADR-032).
class PanViewIntent extends Intent {
  /// Creates a [PanViewIntent] that shifts the view by [delta] screen pixels.
  const PanViewIntent(this.delta);

  /// Screen-pixel offset added to the canvas pan; the drawing moves this way.
  final Offset delta;
}

/// Rotate the selected distributor 90° clockwise; if no distributor is
/// selected, switch to the route-pipe tool instead.
class RotateOrRoutePipeIntent extends Intent {
  /// Creates a [RotateOrRoutePipeIntent].
  const RotateOrRoutePipeIntent();
}

/// Save the current project to its existing `.hsp` path (Ctrl/Cmd+S).
///
/// If no path has been established yet, behaves as [SaveAsIntent].
class SaveIntent extends Intent {
  /// Creates a [SaveIntent].
  const SaveIntent();
}

/// Save the current project to a user-chosen `.hsp` path (Ctrl/Cmd+Shift+S).
class SaveAsIntent extends Intent {
  /// Creates a [SaveAsIntent].
  const SaveAsIntent();
}

/// Open an `.hsp` project file (Ctrl/Cmd+O).
///
/// Opens a file picker, imports the selected project (with new UUIDs per
/// §7.4 of agent-architect.md), writes `lastOpenedProjectId`, and navigates
/// to the editor for the newly imported project.
class OpenIntent extends Intent {
  /// Creates an [OpenIntent].
  const OpenIntent();
}

/// Close the current project and return to the Project List screen.
///
/// Honours the unsaved-`.hsp`-export prompt (§12.5), clears
/// `lastOpenedProjectId` so the next launch shows the project list, then
/// replaces the navigation stack with [ProjectListScreen].
class CloseProjectIntent extends Intent {
  /// Creates a [CloseProjectIntent].
  const CloseProjectIntent();
}

// ----------------------------------------------------------
// Shortcut map
// ----------------------------------------------------------

/// Screen-pixel step the arrow keys pan the canvas per press (ADR-032).
const double _arrowPanStepPx = 60.0;

/// All keyboard shortcuts for the editor screen.
///
/// Uses [LogicalKeyboardKey.control] which maps to Cmd
/// on macOS automatically.
final Map<ShortcutActivator, Intent> editorShortcuts = {
  // Edit
  const SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
  ): const UndoIntent(),
  const SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
    shift: true,
  ): const RedoIntent(),
  const SingleActivator(
    LogicalKeyboardKey.keyY,
    control: true,
  ): const RedoIntent(),
  const SingleActivator(LogicalKeyboardKey.delete):
      const DeleteIntent(),
  const SingleActivator(LogicalKeyboardKey.backspace):
      const DeleteIntent(),
  const SingleActivator(LogicalKeyboardKey.escape):
      const CancelIntent(),

  // Tools
  const SingleActivator(LogicalKeyboardKey.keyV):
      const SwitchToolIntent(DrawingTool.select),
  const SingleActivator(LogicalKeyboardKey.keyW):
      const SwitchToolIntent(DrawingTool.drawWall),
  const SingleActivator(LogicalKeyboardKey.keyN):
      const SwitchToolIntent(DrawingTool.placeWindow),
  const SingleActivator(LogicalKeyboardKey.keyD):
      const SwitchToolIntent(DrawingTool.placeDoor),
  const SingleActivator(LogicalKeyboardKey.keyH):
      const SwitchToolIntent(DrawingTool.drawZone),
  const SingleActivator(LogicalKeyboardKey.keyK):
      const SwitchToolIntent(DrawingTool.drawWallZone),
  const SingleActivator(LogicalKeyboardKey.keyG):
      const SwitchToolIntent(DrawingTool.placeDistributor),
  const SingleActivator(LogicalKeyboardKey.keyR):
      const RotateOrRoutePipeIntent(),
  const SingleActivator(LogicalKeyboardKey.keyM):
      const SwitchToolIntent(DrawingTool.measure),

  // Zoom
  const SingleActivator(
    LogicalKeyboardKey.equal,
    control: true,
  ): const ZoomInIntent(),
  const SingleActivator(
    LogicalKeyboardKey.minus,
    control: true,
  ): const ZoomOutIntent(),
  const SingleActivator(
    LogicalKeyboardKey.digit0,
    control: true,
  ): const ZoomToFitIntent(),

  // Pan (arrow keys always move the drawing — ADR-032). Each arrow moves the
  // drawing in the direction the key points.
  const SingleActivator(LogicalKeyboardKey.arrowUp):
      const PanViewIntent(Offset(0, _arrowPanStepPx)),
  const SingleActivator(LogicalKeyboardKey.arrowDown):
      const PanViewIntent(Offset(0, -_arrowPanStepPx)),
  const SingleActivator(LogicalKeyboardKey.arrowLeft):
      const PanViewIntent(Offset(_arrowPanStepPx, 0)),
  const SingleActivator(LogicalKeyboardKey.arrowRight):
      const PanViewIntent(Offset(-_arrowPanStepPx, 0)),

  // File
  const SingleActivator(
    LogicalKeyboardKey.keyO,
    control: true,
  ): const OpenIntent(),
  const SingleActivator(
    LogicalKeyboardKey.keyS,
    control: true,
  ): const SaveIntent(),
  const SingleActivator(
    LogicalKeyboardKey.keyS,
    control: true,
    shift: true,
  ): const SaveAsIntent(),
};

/// Wraps [child] with [Shortcuts] and [Actions] for the
/// editor screen.
///
/// Call this at the top of the editor widget tree.
class EditorShortcuts extends ConsumerWidget {
  /// Creates [EditorShortcuts] wrapping [child].
  const EditorShortcuts({required this.child, super.key});

  /// The editor screen subtree.
  final Widget child;

  /// Returns true when a text-editing widget currently has
  /// keyboard focus. Used to prevent canvas shortcuts from
  /// firing while the user is typing in a properties field.
  ///
  /// Checks for an [EditableText] ancestor of the focused
  /// node's context, because Flutter's [TextField] attaches
  /// the [FocusNode] to an internal [Focus] widget *inside*
  /// [EditableText] — so `context.widget` is `Focus`, not
  /// `EditableText`.
  static bool _isTextFieldFocused() {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: editorShortcuts,
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              ref.read(undoRedoProvider).undo();
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              ref.read(undoRedoProvider).redo();
              return null;
            },
          ),
          DeleteIntent: CallbackAction<DeleteIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              ref
                  .read(toolDeleteProvider.notifier)
                  .delete();
              return null;
            },
          ),
          CancelIntent: CallbackAction<CancelIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              ref
                  .read(toolCancelProvider.notifier)
                  .cancel();
              return null;
            },
          ),
          SwitchToolIntent:
              CallbackAction<SwitchToolIntent>(
            onInvoke: (intent) {
              if (_isTextFieldFocused()) return null;
              ref
                  .read(selectedToolProvider.notifier)
                  .select(intent.tool);
              return null;
            },
          ),
          ZoomInIntent: CallbackAction<ZoomInIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              final ctrl = ref.read(
                canvasControllerProvider.notifier,
              );
              ctrl.zoomBy(0.1, Offset.zero);
              return null;
            },
          ),
          ZoomOutIntent: CallbackAction<ZoomOutIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              final ctrl = ref.read(
                canvasControllerProvider.notifier,
              );
              ctrl.zoomBy(-0.1, Offset.zero);
              return null;
            },
          ),
          ZoomToFitIntent: CallbackAction<ZoomToFitIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              ref
                  .read(
                    canvasControllerProvider.notifier,
                  )
                  .zoomToFit();
              return null;
            },
          ),
          PanViewIntent: CallbackAction<PanViewIntent>(
            onInvoke: (intent) {
              if (_isTextFieldFocused()) return null;
              ref
                  .read(canvasControllerProvider.notifier)
                  .panBy(intent.delta);
              return null;
            },
          ),
          RotateOrRoutePipeIntent:
              CallbackAction<RotateOrRoutePipeIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              final selected =
                  ref.read(selectedElementProvider);
              final activeTool =
                  ref.read(selectedToolProvider);
              if (selected?.type == 'distributor' &&
                  activeTool == DrawingTool.select) {
                ref
                    .read(
                      toolRotateDistributorProvider
                          .notifier,
                    )
                    .rotate();
              } else {
                ref
                    .read(selectedToolProvider.notifier)
                    .select(DrawingTool.routePipe);
              }
              return null;
            },
          ),
          OpenIntent: CallbackAction<OpenIntent>(
            onInvoke: (_) {
              unawaited(_performOpen(context, ref));
              return null;
            },
          ),
          CloseProjectIntent:
              CallbackAction<CloseProjectIntent>(
            onInvoke: (_) {
              unawaited(_performCloseProject(context, ref));
              return null;
            },
          ),
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (_) {
              unawaited(_performSave(context, ref));
              return null;
            },
          ),
          SaveAsIntent: CallbackAction<SaveAsIntent>(
            onInvoke: (_) {
              unawaited(_performSaveAs(context, ref));
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (_isTextFieldFocused()) return KeyEventResult.ignored;
            final isDown =
                event is KeyDownEvent || event is KeyRepeatEvent;
            final isUp = event is KeyUpEvent;
            if (!isDown && !isUp) return KeyEventResult.ignored;

            final key = event.logicalKey;
            final isShift =
                key == LogicalKeyboardKey.shiftLeft ||
                key == LogicalKeyboardKey.shiftRight ||
                key == LogicalKeyboardKey.shift;
            // Cmd on macOS maps to logical "meta" — treat the same as
            // Ctrl so rect-mode (wall draw) and rect-reshape
            // (ADR-012) work cross-platform.
            final isCtrl =
                key == LogicalKeyboardKey.controlLeft ||
                key == LogicalKeyboardKey.controlRight ||
                key == LogicalKeyboardKey.control ||
                key == LogicalKeyboardKey.metaLeft ||
                key == LogicalKeyboardKey.metaRight ||
                key == LogicalKeyboardKey.meta;
            final isAlt =
                key == LogicalKeyboardKey.altLeft ||
                key == LogicalKeyboardKey.altRight ||
                key == LogicalKeyboardKey.alt;

            if (isShift) {
              ref
                  .read(wallModifiersProvider.notifier)
                  .update(orthoSnap: isDown);
            } else if (isCtrl) {
              ref
                  .read(wallModifiersProvider.notifier)
                  .update(rectMode: isDown);
            } else if (isAlt) {
              ref
                  .read(wallModifiersProvider.notifier)
                  .update(freePlacement: isDown);
            }

            // Never consume — let Shortcuts handle Ctrl+Z etc.
            return KeyEventResult.ignored;
          },
          child: child,
        ),
      ),
    );
  }
}

// ── File action helpers ────────────────────────────────────────────────────────

/// Saves to the existing `.hsp` path, or opens a Save As picker if
/// no path is established yet.
///
/// Triggers [saveFlashProvider] on success for the 2-second status-bar
/// confirmation (agent-ui-ux.md §12.7).
Future<void> _performSave(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = ref.read(saveStateProvider);
  if (state.lastExportPath != null) {
    await ref.read(saveStateProvider.notifier).exportNow();
    ref.read(saveFlashProvider.notifier).trigger();
  } else {
    await _performSaveAs(context, ref);
  }
}

/// Opens a save-file dialog and exports to the selected path.
///
/// Default filename is `{ProjectName}.hsp`. Updates [SaveState.lastExportPath]
/// and clears `isDirty`. Triggers [saveFlashProvider] on success.
Future<void> _performSaveAs(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final projectName = ref.read(currentProjectNameProvider);
  final path = await FilePicker.platform.saveFile(
    dialogTitle: l10n.dialogSaveProjectAs,
    fileName: '$projectName.hsp',
    allowedExtensions: ['hsp'],
    type: FileType.custom,
  );
  if (path == null) return;
  await ref.read(saveStateProvider.notifier).saveAs(path);
  ref.read(saveFlashProvider.notifier).trigger();
}

/// Opens a file picker and loads the chosen `.hsp` file as the working copy
/// (preserving its project UUID), then navigates to it.
///
/// Prompts to save the currently open project first (document model — the open
/// project's working copy is replaced). On cancel (null path) does nothing.
Future<void> _performOpen(
  BuildContext context,
  WidgetRef ref,
) async {
  // Replacing the working copy — make sure the current project is committed.
  final resolved = await ensureSavedBeforeLeaving(context, ref);
  if (!resolved) return;

  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['hsp'],
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return;
  final path = result.files.first.path;
  if (path == null) return;

  final projectId =
      await ref.read(documentServiceProvider).openDocument(path);

  if (!context.mounted) return;
  await Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => EditorScreen(projectId: projectId),
    ),
  );
}

/// Closes the current project and returns to [ProjectListScreen].
///
/// Reuses the existing dirty-state check ([SaveState.isDirty] +
/// [SaveState.lastExportPath]) and the same [SaveStateNotifier.exportNow]
/// save action as the window-close flow (§12.5) — the prompt is only shown
/// when there are unsaved `.hsp` changes, and "Cancel" aborts the close.
///
/// On confirm: clears `lastOpenedProjectId` (so the next launch shows the
/// project list instead of auto-reopening) and replaces the entire
/// navigation stack with the project list, which works regardless of how
/// the editor was reached (pushed, pushReplacement, or startup home route).
Future<void> _performCloseProject(
  BuildContext context,
  WidgetRef ref,
) async {
  final resolved = await ensureSavedBeforeLeaving(context, ref);
  if (!resolved) return; // User cancelled.

  // Document model: tear down the in-database working copy so the database
  // never accumulates closed projects.
  await ref.read(documentServiceProvider).closeWorkingCopy();

  if (!context.mounted) return;
  await Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => const ProjectListScreen(),
    ),
    (route) => false,
  );
}

/// Ensures the open project is committed to an `.hsp` file before the editor is
/// left (close or quit), prompting the user when there are unsaved changes
/// **or** the project has never been saved.
///
/// Returns `true` when it is safe to proceed (saved, or the user chose to
/// discard), and `false` when the user cancelled — in which case the caller
/// must abort the close/quit.
///
/// Shared by [_performCloseProject] and the app-exit handler in `app.dart`.
Future<bool> ensureSavedBeforeLeaving(
  BuildContext context,
  WidgetRef ref,
) async {
  // No project open (e.g. quitting from the project list) — nothing to save.
  if (ref.read(currentProjectIdProvider).isEmpty) return true;

  final saveState = ref.read(saveStateProvider);
  final neverSaved = saveState.lastExportPath == null;
  if (!saveState.isDirty && !neverSaved) return true; // Already up to date.

  final choice = await showDialog<_CloseChoice>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CloseProjectUnsavedDialog(
      projectName: ref.read(currentProjectNameProvider),
      neverSaved: neverSaved,
    ),
  );

  switch (choice) {
    case _CloseChoice.saveAndClose:
      if (neverSaved) {
        // No path yet — run Save As; abort the close if the user cancels it.
        if (!context.mounted) return false;
        final saved = await _performSaveAsReturning(context, ref);
        return saved;
      }
      await ref.read(saveStateProvider.notifier).exportNow();
      return true;
    case _CloseChoice.closeAnyway:
      return true;
    case null:
    case _CloseChoice.cancel:
      return false;
  }
}

/// Runs the Save As picker and reports whether a file was written.
Future<bool> _performSaveAsReturning(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final projectName = ref.read(currentProjectNameProvider);
  final path = await FilePicker.platform.saveFile(
    dialogTitle: l10n.dialogSaveProjectAs,
    fileName: '$projectName.hsp',
    allowedExtensions: ['hsp'],
    type: FileType.custom,
  );
  if (path == null) return false;
  await ref.read(saveStateProvider.notifier).saveAs(path);
  ref.read(saveFlashProvider.notifier).trigger();
  return true;
}

/// User's choice in [_CloseProjectUnsavedDialog].
enum _CloseChoice { saveAndClose, closeAnyway, cancel }

/// Shown when the user leaves a project that has unsaved `.hsp` changes or has
/// never been saved. In the document storage model the `.hsp` file is the only
/// permanent copy, so closing without saving a never-saved project discards it.
class _CloseProjectUnsavedDialog extends StatelessWidget {
  const _CloseProjectUnsavedDialog({
    required this.projectName,
    required this.neverSaved,
  });

  final String projectName;
  final bool neverSaved;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.unsavedExportFile),
      content: Text(
        neverSaved
            ? l10n.unsavedNeverSavedContent(projectName)
            : l10n.unsavedExportContent(projectName),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_CloseChoice.cancel),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(_CloseChoice.closeAnyway),
          child: Text(l10n.closeWithoutSaving),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .pop(_CloseChoice.saveAndClose),
          child: Text(l10n.saveFileAndClose),
        ),
      ],
    );
  }
}
