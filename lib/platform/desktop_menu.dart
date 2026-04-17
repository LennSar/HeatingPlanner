import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/enums.dart';
import 'keyboard_shortcuts.dart';

/// Wraps [child] with a native desktop menu bar on macOS, Windows,
/// and Linux (agent-frontend.md §6.1).
///
/// Must be placed **inside** [EditorShortcuts] so that
/// `Actions.invoke(context, intent)` can reach the registered
/// action handlers. On iOS and Android [PlatformMenuBar] renders
/// nothing extra — only [child] is returned.
///
/// Menu structure follows UI/UX §4.2 / agent-frontend.md §6.1.
/// Items with no current implementation are greyed out (null
/// [onSelected]).
class DesktopMenuBar extends ConsumerWidget {
  /// Creates a [DesktopMenuBar] wrapping [child].
  const DesktopMenuBar({required this.child, super.key});

  /// The editor widget subtree shown inside the menu bar.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlatformMenuBar(
      menus: [
        _fileMenu(context),
        _editMenu(context),
        _viewMenu(context),
        _toolsMenu(context),
        _helpMenu(),
      ],
      child: child,
    );
  }

  // ── File ──────────────────────────────────────────────────────────────────

  PlatformMenu _fileMenu(BuildContext context) {
    return PlatformMenu(
      label: 'File',
      menus: [
        // New — not yet implemented; greyed out.
        const PlatformMenuItem(
          label: 'New',
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyN,
            control: true,
          ),
          onSelected: null,
        ),
        PlatformMenuItemGroup(
          members: [
            // Open (Ctrl/Cmd+O)
            PlatformMenuItem(
              label: 'Open…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                control: true,
              ),
              onSelected: () => Actions.invoke(
                context,
                const OpenIntent(),
              ),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            // Save (Ctrl/Cmd+S)
            PlatformMenuItem(
              label: 'Save',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                control: true,
              ),
              onSelected: () => Actions.invoke(
                context,
                const SaveIntent(),
              ),
            ),
            // Save As (Ctrl/Cmd+Shift+S)
            PlatformMenuItem(
              label: 'Save As…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                control: true,
                shift: true,
              ),
              onSelected: () => Actions.invoke(
                context,
                const SaveAsIntent(),
              ),
            ),
          ],
        ),
        const PlatformMenuItemGroup(
          members: [
            // Export PDF — not yet implemented.
            PlatformMenuItem(
              label: 'Export PDF…',
              onSelected: null,
            ),
            // Export CSV — not yet implemented.
            PlatformMenuItem(
              label: 'Export CSV…',
              onSelected: null,
            ),
          ],
        ),
      ],
    );
  }

  // ── Edit ──────────────────────────────────────────────────────────────────

  PlatformMenu _editMenu(BuildContext context) {
    return PlatformMenu(
      label: 'Edit',
      menus: [
        PlatformMenuItem(
          label: 'Undo',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
          ),
          onSelected: () => Actions.invoke(
            context,
            const UndoIntent(),
          ),
        ),
        PlatformMenuItem(
          label: 'Redo',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ),
          onSelected: () => Actions.invoke(
            context,
            const RedoIntent(),
          ),
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Delete',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.delete,
              ),
              onSelected: () => Actions.invoke(
                context,
                const DeleteIntent(),
              ),
            ),
            // Select All — not yet implemented.
            const PlatformMenuItem(
              label: 'Select All',
              shortcut: SingleActivator(
                LogicalKeyboardKey.keyA,
                control: true,
              ),
              onSelected: null,
            ),
          ],
        ),
      ],
    );
  }

  // ── View ──────────────────────────────────────────────────────────────────

  PlatformMenu _viewMenu(BuildContext context) {
    return PlatformMenu(
      label: 'View',
      menus: [
        PlatformMenuItem(
          label: 'Zoom In',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.equal,
            control: true,
          ),
          onSelected: () => Actions.invoke(
            context,
            const ZoomInIntent(),
          ),
        ),
        PlatformMenuItem(
          label: 'Zoom Out',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.minus,
            control: true,
          ),
          onSelected: () => Actions.invoke(
            context,
            const ZoomOutIntent(),
          ),
        ),
        PlatformMenuItem(
          label: 'Zoom to Fit',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.digit0,
            control: true,
          ),
          onSelected: () => Actions.invoke(
            context,
            const ZoomToFitIntent(),
          ),
        ),
        const PlatformMenuItemGroup(
          members: [
            // Grid submenu and panel toggles — not yet implemented.
            PlatformMenuItem(
              label: 'Toggle Properties Panel',
              onSelected: null,
            ),
            PlatformMenuItem(
              label: 'Toggle Dashboard',
              onSelected: null,
            ),
          ],
        ),
      ],
    );
  }

  // ── Tools ─────────────────────────────────────────────────────────────────

  PlatformMenu _toolsMenu(BuildContext context) {
    return PlatformMenu(
      label: 'Tools',
      menus: [
        PlatformMenuItem(
          label: 'Select',
          shortcut:
              const SingleActivator(LogicalKeyboardKey.keyV),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.select),
          ),
        ),
        PlatformMenuItem(
          label: 'Draw Wall',
          shortcut:
              const SingleActivator(LogicalKeyboardKey.keyW),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.drawWall),
          ),
        ),
        PlatformMenuItem(
          label: 'Place Window',
          shortcut:
              const SingleActivator(LogicalKeyboardKey.keyN),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.placeWindow),
          ),
        ),
        PlatformMenuItem(
          label: 'Place Door',
          shortcut:
              const SingleActivator(LogicalKeyboardKey.keyD),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.placeDoor),
          ),
        ),
        PlatformMenuItem(
          label: 'Draw Floor Zone',
          shortcut:
              const SingleActivator(LogicalKeyboardKey.keyH),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.drawZone),
          ),
        ),
        PlatformMenuItem(
          label: 'Place Distributor',
          shortcut:
              const SingleActivator(LogicalKeyboardKey.keyG),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.placeDistributor),
          ),
        ),
        PlatformMenuItem(
          label: 'Route Pipe',
          shortcut:
              const SingleActivator(LogicalKeyboardKey.keyR),
          onSelected: () => Actions.invoke(
            context,
            const RotateOrRoutePipeIntent(),
          ),
        ),
        PlatformMenuItem(
          label: 'Measure',
          shortcut:
              const SingleActivator(LogicalKeyboardKey.keyM),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.measure),
          ),
        ),
      ],
    );
  }

  // ── Help ──────────────────────────────────────────────────────────────────

  PlatformMenu _helpMenu() {
    return const PlatformMenu(
      label: 'Help',
      menus: [
        PlatformMenuItem(
          label: 'About HeatingPlanner',
          onSelected: null,
        ),
        PlatformMenuItem(
          label: 'Documentation',
          onSelected: null,
        ),
      ],
    );
  }
}
