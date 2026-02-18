import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/enums.dart';
import '../ui/canvas/canvas_controller.dart';
import '../ui/canvas/floor_plan_canvas.dart';
import '../ui/screens/editor_screen.dart';

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
  const SingleActivator(LogicalKeyboardKey.keyG):
      const SwitchToolIntent(DrawingTool.placeDistributor),
  const SingleActivator(LogicalKeyboardKey.keyR):
      const SwitchToolIntent(DrawingTool.routePipe),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: editorShortcuts,
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) {
              // TODO: wire to UndoRedoService.
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) {
              // TODO: wire to UndoRedoService.
              return null;
            },
          ),
          DeleteIntent: CallbackAction<DeleteIntent>(
            onInvoke: (_) {
              // TODO: delete selected element.
              return null;
            },
          ),
          CancelIntent: CallbackAction<CancelIntent>(
            onInvoke: (_) {
              ref
                  .read(toolCancelProvider.notifier)
                  .cancel();
              return null;
            },
          ),
          SwitchToolIntent:
              CallbackAction<SwitchToolIntent>(
            onInvoke: (intent) {
              ref
                  .read(selectedToolProvider.notifier)
                  .select(intent.tool);
              return null;
            },
          ),
          ZoomInIntent: CallbackAction<ZoomInIntent>(
            onInvoke: (_) {
              final ctrl = ref.read(
                canvasControllerProvider.notifier,
              );
              ctrl.zoomBy(0.1, Offset.zero);
              return null;
            },
          ),
          ZoomOutIntent: CallbackAction<ZoomOutIntent>(
            onInvoke: (_) {
              final ctrl = ref.read(
                canvasControllerProvider.notifier,
              );
              ctrl.zoomBy(-0.1, Offset.zero);
              return null;
            },
          ),
          ZoomToFitIntent: CallbackAction<ZoomToFitIntent>(
            onInvoke: (_) {
              ref
                  .read(
                    canvasControllerProvider.notifier,
                  )
                  .zoomToFit();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
