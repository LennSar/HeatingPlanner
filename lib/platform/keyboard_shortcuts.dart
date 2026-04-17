import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart' as $db;
import '../data/models/enums.dart';
import '../repositories/app_preferences.dart';
import '../repositories/hsp_importer.dart';
import '../repositories/save_state_notifier.dart';
import '../ui/canvas/canvas_controller.dart';
import '../ui/canvas/floor_plan_canvas.dart';
import '../ui/canvas/tools/undo_redo_service.dart';
import '../ui/panels/properties_panel.dart'
    show selectedElementProvider;
import '../ui/providers/editor_state_provider.dart'
    show currentProjectNameProvider;
import '../ui/screens/editor_screen.dart';
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

// ----------------------------------------------------------
// Shortcut map
// ----------------------------------------------------------

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
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (_) {
              unawaited(_performSave(ref));
              return null;
            },
          ),
          SaveAsIntent: CallbackAction<SaveAsIntent>(
            onInvoke: (_) {
              unawaited(_performSaveAs(ref));
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
            final isCtrl =
                key == LogicalKeyboardKey.controlLeft ||
                key == LogicalKeyboardKey.controlRight ||
                key == LogicalKeyboardKey.control;
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
Future<void> _performSave(WidgetRef ref) async {
  final state = ref.read(saveStateProvider);
  if (state.lastExportPath != null) {
    await ref.read(saveStateProvider.notifier).exportNow();
    ref.read(saveFlashProvider.notifier).trigger();
  } else {
    await _performSaveAs(ref);
  }
}

/// Opens a save-file dialog and exports to the selected path.
///
/// Default filename is `{ProjectName}.hsp`. Updates [SaveState.lastExportPath]
/// and clears `isDirty`. Triggers [saveFlashProvider] on success.
Future<void> _performSaveAs(WidgetRef ref) async {
  final projectName = ref.read(currentProjectNameProvider);
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Project As',
    fileName: '$projectName.hsp',
    allowedExtensions: ['hsp'],
    type: FileType.custom,
  );
  if (path == null) return;
  await ref.read(saveStateProvider.notifier).saveAs(path);
  ref.read(saveFlashProvider.notifier).trigger();
}

/// Opens a file picker, imports the chosen `.hsp` file with fresh UUIDs,
/// persists `lastOpenedProjectId`, and navigates to the new project.
///
/// On cancel (null path) does nothing.
Future<void> _performOpen(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['hsp'],
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return;
  final path = result.files.first.path;
  if (path == null) return;

  final bytes = await File(path).readAsBytes();
  final jsonStr =
      utf8.decode(const GZipDecoder().decodeBytes(bytes));
  final snapshot =
      jsonDecode(jsonStr) as Map<String, dynamic>;

  final newId = await HspImporter(
    ref.read($db.appDatabaseProvider),
  ).importSnapshot(snapshot);

  await ref
      .read(lastOpenedProjectIdProvider.notifier)
      .set(newId);

  if (!context.mounted) return;
  await Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => EditorScreen(projectId: newId),
    ),
  );
}
