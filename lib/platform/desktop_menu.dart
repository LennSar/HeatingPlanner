import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/enums.dart';
import '../l10n/app_localizations.dart';
import '../ui/dialogs/project_settings_dialog.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return PlatformMenuBar(
      menus: [
        _fileMenu(context, l10n),
        _editMenu(context, l10n),
        _viewMenu(context, l10n),
        _toolsMenu(context, l10n),
        _helpMenu(l10n),
      ],
      child: child,
    );
  }

  // ── File ────────────────────────────────────────────────────

  PlatformMenu _fileMenu(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return PlatformMenu(
      label: l10n.menuFile,
      menus: [
        // New — not yet implemented; greyed out.
        PlatformMenuItem(
          label: l10n.menuNew,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyN,
            control: true,
          ),
          onSelected: null,
        ),
        PlatformMenuItemGroup(
          members: [
            // Open (Ctrl/Cmd+O)
            PlatformMenuItem(
              label: l10n.menuOpen,
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
              label: l10n.menuSave,
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
              label: l10n.menuSaveAs,
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
        PlatformMenuItemGroup(
          members: [
            // Export PDF — not yet implemented.
            PlatformMenuItem(
              label: l10n.menuExportPdf,
              onSelected: null,
            ),
            // Export CSV — not yet implemented.
            PlatformMenuItem(
              label: l10n.menuExportCsv,
              onSelected: null,
            ),
          ],
        ),
      ],
    );
  }

  // ── Edit ────────────────────────────────────────────────────

  PlatformMenu _editMenu(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return PlatformMenu(
      label: l10n.menuEdit,
      menus: [
        PlatformMenuItem(
          label: l10n.menuUndo,
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
          label: l10n.menuRedo,
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
              label: l10n.menuDelete,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.delete,
              ),
              onSelected: () => Actions.invoke(
                context,
                const DeleteIntent(),
              ),
            ),
            // Select All — not yet implemented.
            PlatformMenuItem(
              label: l10n.menuSelectAll,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyA,
                control: true,
              ),
              onSelected: null,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: l10n.projectSettings,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.comma,
                control: true,
              ),
              onSelected: () =>
                  showProjectSettingsDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  // ── View ────────────────────────────────────────────────────

  PlatformMenu _viewMenu(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return PlatformMenu(
      label: l10n.menuView,
      menus: [
        PlatformMenuItem(
          label: l10n.menuZoomIn,
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
          label: l10n.menuZoomOut,
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
          label: l10n.menuZoomToFit,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.digit0,
            control: true,
          ),
          onSelected: () => Actions.invoke(
            context,
            const ZoomToFitIntent(),
          ),
        ),
        PlatformMenuItemGroup(
          members: [
            // Grid submenu and panel toggles — not yet
            // implemented.
            PlatformMenuItem(
              label: l10n.menuTogglePropertiesPanel,
              onSelected: null,
            ),
            PlatformMenuItem(
              label: l10n.menuToggleDashboard,
              onSelected: null,
            ),
          ],
        ),
      ],
    );
  }

  // ── Tools ───────────────────────────────────────────────────

  PlatformMenu _toolsMenu(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return PlatformMenu(
      label: l10n.menuTools,
      menus: [
        PlatformMenuItem(
          label: l10n.toolSelect,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyV,
          ),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.select),
          ),
        ),
        PlatformMenuItem(
          label: l10n.menuDrawWall,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyW,
          ),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.drawWall),
          ),
        ),
        PlatformMenuItem(
          label: l10n.menuPlaceWindow,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyN,
          ),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(
              DrawingTool.placeWindow,
            ),
          ),
        ),
        PlatformMenuItem(
          label: l10n.menuPlaceDoor,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyD,
          ),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(
              DrawingTool.placeDoor,
            ),
          ),
        ),
        PlatformMenuItem(
          label: l10n.menuDrawFloorZone,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyH,
          ),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.drawZone),
          ),
        ),
        PlatformMenuItem(
          label: l10n.menuPlaceDistributor,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyG,
          ),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(
              DrawingTool.placeDistributor,
            ),
          ),
        ),
        PlatformMenuItem(
          label: l10n.menuRoutePipe,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyR,
          ),
          onSelected: () => Actions.invoke(
            context,
            const RotateOrRoutePipeIntent(),
          ),
        ),
        PlatformMenuItem(
          label: l10n.toolMeasure,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyM,
          ),
          onSelected: () => Actions.invoke(
            context,
            const SwitchToolIntent(DrawingTool.measure),
          ),
        ),
      ],
    );
  }

  // ── Help ────────────────────────────────────────────────────

  PlatformMenu _helpMenu(AppLocalizations l10n) {
    return PlatformMenu(
      label: l10n.menuHelp,
      menus: [
        PlatformMenuItem(
          label: l10n.menuAbout,
          onSelected: null,
        ),
        PlatformMenuItem(
          label: l10n.menuDocumentation,
          onSelected: null,
        ),
      ],
    );
  }
}
