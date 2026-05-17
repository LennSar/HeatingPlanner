import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/desktop_menu.dart';
import '../../platform/keyboard_shortcuts.dart';
import '../../repositories/app_preferences.dart';
import '../../repositories/building_repository.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/save_state_notifier.dart';
import '../canvas/canvas_controller.dart';
import '../canvas/floor_plan_canvas.dart';
import '../dialogs/project_settings_dialog.dart';
import '../panels/performance_dashboard.dart';
import '../panels/properties_panel.dart';
import '../providers/editor_state_provider.dart';
import '../widgets/save_state_indicator.dart';
import '../../validation/validation_service.dart';

/// Notifier for the active drawing tool.
class SelectedToolNotifier extends Notifier<DrawingTool> {
  @override
  DrawingTool build() => DrawingTool.select;

  /// Switch to [tool].
  void select(DrawingTool tool) {
    state = tool;
  }
}

/// Provider for the currently active drawing tool.
final selectedToolProvider =
    NotifierProvider<SelectedToolNotifier, DrawingTool>(
  SelectedToolNotifier.new,
);

/// Main workspace screen: toolbar + canvas + properties
/// panel + status bar.
///
/// Layout follows UI/UX Section 4.2.
class EditorScreen extends ConsumerStatefulWidget {
  /// Creates an [EditorScreen] for [projectId].
  const EditorScreen({required this.projectId, super.key});

  /// The project being edited.
  final String projectId;

  @override
  ConsumerState<EditorScreen> createState() =>
      _EditorScreenState();
}

class _EditorScreenState
    extends ConsumerState<EditorScreen> {
  bool _propertiesPanelVisible = true;
  bool _dashboardVisible = false;
  int _dashboardInitialTab = 0;

  @override
  void initState() {
    super.initState();
    // Defer provider mutations to after the first frame so that they
    // do not fire while the widget tree is still building (Riverpod
    // disallows mid-build writes). The floor load is awaited inside
    // the callback so state is ready before the canvas first paints.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(currentProjectIdProvider.notifier).set(widget.projectId);

      final prefs = ref.read(appPreferencesProvider);
      final bRepo = ref.read(buildingRepositoryProvider);

      final floors =
          await bRepo.getFloorsForProject(widget.projectId);
      if (floors.isEmpty || !mounted) return;

      final savedFloorId = await prefs.getLastOpenedFloorId();
      if (!mounted) return;

      // Use the saved floor if it belongs to this project; otherwise
      // fall back to the first floor (lowest level).
      final floorId =
          floors.any((f) => f.id == savedFloorId)
              ? savedFloorId!
              : floors.first.id;

      await ref
          .read(editorStateProvider.notifier)
          .initFromFloor(floorId);
      if (!mounted) return;

      ref.read(currentFloorIdProvider.notifier).set(floorId);
      await prefs.setLastOpenedFloorId(floorId);
    });
  }

  /// Computes the desktop window title from the project name and save state.
  ///
  /// Format matches agent-ui-ux.md §12.3:
  /// - Clean / no path: `{name} — HeatingPlanner`
  /// - Dirty:           `{name} ● — HeatingPlanner`
  /// - Saving:          `{name} — HeatingPlanner (Saving…)`
  static String _windowTitle(
    String projectName,
    SaveState s,
    AppLocalizations l10n,
  ) {
    final app = l10n.appTitle;
    if (s.isAutoExporting) {
      return '$projectName — $app (${l10n.saving})';
    }
    if (s.isDirty && s.lastExportPath != null) {
      return '$projectName ● — $app';
    }
    return '$projectName — $app';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Keep the desktop window title in sync with save state.
    final saveState = ref.watch(saveStateProvider);
    final projectName =
        ref.watch(currentProjectNameProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(
          label: _windowTitle(
            projectName,
            saveState,
            l10n,
          ),
          primaryColor: 0,
        ),
      );
    });

    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width < 600;

    return EditorShortcuts(
      child: DesktopMenuBar(
        child: Scaffold(
        body: Column(
        children: [
          // Main content area: toolbar + canvas + panel
          Expanded(
            child: Row(
              children: [
                // Left toolbar
                _Toolbar(
                  isCompact: isTablet,
                  selectedTool:
                      ref.watch(selectedToolProvider),
                  onToolSelected: (tool) {
                    ref
                        .read(selectedToolProvider.notifier)
                        .select(tool);
                  },
                  onToggleDashboard: () {
                    setState(() {
                      _dashboardVisible =
                          !_dashboardVisible;
                      _dashboardInitialTab = 0;
                    });
                  },
                  dashboardVisible: _dashboardVisible,
                ),

                // Canvas fills remaining space.
                // On tablet, show the wall-tool options bar
                // (ortho-snap + rectangle mode toggles) above
                // the canvas when the wall tool is active.
                Expanded(
                  child: Column(
                    children: [
                      if (isTablet &&
                          ref.watch(selectedToolProvider) ==
                              DrawingTool.drawWall)
                        const _WallTabletOptionsBar(),
                      const Expanded(child: FloorPlanCanvas()),
                    ],
                  ),
                ),

                // Properties panel (desktop only)
                if (!isTablet && _propertiesPanelVisible)
                  SizedBox(
                    width: width >= 1200
                        ? PropertiesPanel.widthLarge
                        : PropertiesPanel.widthMedium,
                    child: const PropertiesPanel(),
                  ),

                // Performance dashboard panel (desktop only)
                if (!isTablet && _dashboardVisible)
                  SizedBox(
                    width: width >= 1200
                        ? PerformanceDashboard.widthLarge
                        : PerformanceDashboard.widthMedium,
                    child: PerformanceDashboardPanel(
                      key: ValueKey(_dashboardInitialTab),
                      initialIndex: _dashboardInitialTab,
                    ),
                  ),
              ],
            ),
          ),

          // Status bar
          _StatusBar(
            onTogglePanel: () {
              setState(() {
                _propertiesPanelVisible =
                    !_propertiesPanelVisible;
              });
            },
            onOpenWarnings: () {
              setState(() {
                _dashboardVisible = true;
                _dashboardInitialTab = 2;
              });
            },
          ),
        ],
      ),

      // Tablet: bottom sheet for properties
      bottomSheet: isTablet
          ? DraggableScrollableSheet(
              initialChildSize: 0.08,
              minChildSize: 0.08,
              maxChildSize: 0.7,
              snapSizes: const [0.08, 0.4, 0.7],
              snap: true,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: const [
                      _DragHandle(),
                      PropertiesPanel(),
                    ],
                  ),
                );
              },
            )
          : null,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------
// Toolbar
// ----------------------------------------------------------

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.isCompact,
    required this.selectedTool,
    required this.onToolSelected,
    required this.onToggleDashboard,
    required this.dashboardVisible,
  });

  final bool isCompact;
  final DrawingTool selectedTool;
  final ValueChanged<DrawingTool> onToolSelected;
  final VoidCallback onToggleDashboard;
  final bool dashboardVisible;

  static List<_ToolEntry> _toolEntries(
    AppLocalizations l10n,
  ) =>
      [
        _ToolEntry(
          DrawingTool.select,
          Icons.near_me,
          l10n.toolSelect,
        ),
        _ToolEntry(
          DrawingTool.drawWall,
          Icons.border_style,
          l10n.toolWall,
        ),
        _ToolEntry(
          DrawingTool.placeWindow,
          Icons.window,
          l10n.toolWindow,
        ),
        _ToolEntry(
          DrawingTool.placeDoor,
          Icons.door_front_door_outlined,
          l10n.toolDoor,
        ),
        _ToolEntry(
          DrawingTool.drawZone,
          Icons.grid_on,
          l10n.toolFloorZone,
        ),
        _ToolEntry(
          DrawingTool.drawWallZone,
          Icons.view_column_outlined,
          l10n.toolWallZone,
        ),
        _ToolEntry(
          DrawingTool.placeDistributor,
          Icons.hub_outlined,
          l10n.toolDistributor,
        ),
        _ToolEntry(
          DrawingTool.routePipe,
          Icons.route,
          l10n.toolPipe,
        ),
        _ToolEntry(
          DrawingTool.measure,
          Icons.straighten,
          l10n.toolMeasure,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context)
        .extension<HeatingPlannerColors>()!;
    final primary = Theme.of(context).colorScheme.primary;
    final toolbarWidth = isCompact ? 48.0 : 56.0;

    return Container(
      width: toolbarWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: colors.gridLine),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(1, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Scrollable drawing tools — never overflows when
          // the window is shorter than the full tool list.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: Spacing.sm),
                  for (final entry in _toolEntries(l10n))
                    Tooltip(
                      message: entry.label,
                      preferBelow: false,
                      waitDuration: const Duration(
                        milliseconds: 500,
                      ),
                      child: Material(
                        color: selectedTool == entry.tool
                            ? primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              onToolSelected(entry.tool),
                          child: SizedBox(
                            width: toolbarWidth,
                            height: toolbarWidth,
                            child: Icon(
                              entry.icon,
                              size: isCompact ? 20 : 22,
                              color: selectedTool == entry.tool
                                  ? primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom group — always visible regardless of height.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
            ),
            child: Divider(color: colors.gridLine),
          ),

          // ── File action buttons (Open / Save / Save As) ──────────
          _ToolbarFileButton(
            icon: Icons.folder_open,
            tooltip: l10n.tooltipOpen,
            width: toolbarWidth,
            iconSize: isCompact ? 20.0 : 22.0,
            onTap: () => Actions.invoke(
              context,
              const OpenIntent(),
            ),
          ),
          _ToolbarFileButton(
            icon: Icons.save,
            tooltip: l10n.tooltipSave,
            width: toolbarWidth,
            iconSize: isCompact ? 20.0 : 22.0,
            onTap: () => Actions.invoke(
              context,
              const SaveIntent(),
            ),
          ),
          _ToolbarFileButton(
            icon: Icons.save_as,
            tooltip: l10n.tooltipSaveAs,
            width: toolbarWidth,
            iconSize: isCompact ? 20.0 : 22.0,
            onTap: () => Actions.invoke(
              context,
              const SaveAsIntent(),
            ),
          ),

          // Dashboard toggle
          Tooltip(
            message: l10n.tooltipDashboard,
            child: Material(
              color: dashboardVisible
                  ? primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              child: InkWell(
                onTap: onToggleDashboard,
                child: SizedBox(
                  width: toolbarWidth,
                  height: toolbarWidth,
                  child: Icon(
                    Icons.bar_chart,
                    size: isCompact ? 20 : 22,
                    color: dashboardVisible
                        ? primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

          // Project settings
          Tooltip(
            message: l10n.tooltipProjectSettings,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => showProjectSettingsDialog(
                  context,
                ),
                child: SizedBox(
                  width: toolbarWidth,
                  height: toolbarWidth,
                  child: Icon(
                    Icons.tune,
                    size: isCompact ? 20 : 22,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: Spacing.sm),
        ],
      ),
    );
  }
}

class _ToolEntry {
  const _ToolEntry(this.tool, this.icon, this.label);

  final DrawingTool tool;
  final IconData icon;
  final String label;
}

// ----------------------------------------------------------
// Toolbar file-action button
// ----------------------------------------------------------

/// A single icon button used in the toolbar for Open / Save / Save As.
///
/// Uses [HeatingPlannerColors] tokens; no hard-coded colours.
class _ToolbarFileButton extends StatelessWidget {
  const _ToolbarFileButton({
    required this.icon,
    required this.tooltip,
    required this.width,
    required this.iconSize,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final double width;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: width,
            child: Icon(
              icon,
              size: iconSize,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------
// Status bar
// ----------------------------------------------------------

class _StatusBar extends ConsumerWidget {
  const _StatusBar({
    required this.onTogglePanel,
    required this.onOpenWarnings,
  });

  final VoidCallback onTogglePanel;
  final VoidCallback onOpenWarnings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final canvasState = ref.watch(canvasControllerProvider);
    final zoomPercent =
        (canvasState.zoom * 100).round();
    final cursorPos = ref.watch(cursorPositionProvider);
    final editorState = ref.watch(editorStateProvider);
    final roomCount = editorState.rooms.length;
    final toolHint = ref.watch(toolStatusHintProvider);
    final warningCount = ref
        .watch(validationResultsProvider(''))
        .length;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context)
        .extension<HeatingPlannerColors>()!;

    final coordText = cursorPos != null
        ? 'x: ${cursorPos.x.round()}, '
            'y: ${cursorPos.y.round()}'
        : 'x: -, y: -';

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: colors.gridLine),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
        ),
        child: Row(
          children: [
            // Zoom percentage
            Text(
              l10n.statusBarZoom(zoomPercent),
              style: textTheme.bodySmall,
            ),
            const SizedBox(width: Spacing.lg),

            // Live coordinates
            Text(
              coordText,
              style: textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),

            // Tool hint (e.g. zone draw outside room)
            if (toolHint != null) ...[
              const SizedBox(width: Spacing.lg),
              Icon(
                Icons.info_outline,
                size: 14,
                color: colors.zoneRed,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                toolHint,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.zoneRed,
                ),
              ),
            ],

            const Spacer(),

            // Warnings — tappable to open dashboard
            InkWell(
              onTap: onOpenWarnings,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: warningCount > 0
                        ? colors.zoneYellow
                        : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    l10n.statusBarWarnings(warningCount),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),

            // Save state indicator
            const SaveStateIndicator(),
            const SizedBox(width: Spacing.md),

            // Room count
            Text(
              l10n.statusBarRooms(roomCount),
              style: textTheme.bodySmall,
            ),
            const SizedBox(width: Spacing.sm),

            // Panel toggle
            InkWell(
              onTap: onTogglePanel,
              child: Icon(
                Icons.view_sidebar,
                size: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------
// Drag handle for tablet bottom sheet
// ----------------------------------------------------------

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: Spacing.sm,
        ),
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------
// Tablet wall-tool options bar (§5.1 tablet flow)
// ----------------------------------------------------------

/// Horizontal bar shown above the canvas on tablet when the wall
/// tool is active. Provides toggle buttons for ortho-snap and
/// rectangle mode, replacing the Shift/Ctrl modifier keys that
/// are unavailable on touch screens.
class _WallTabletOptionsBar extends ConsumerWidget {
  const _WallTabletOptionsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mods = ref.watch(wallModifiersProvider);
    final colors = Theme.of(context)
        .extension<HeatingPlannerColors>()!;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colors.gridLine),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
      ),
      child: Row(
        children: [
          Text(
            l10n.wallToolLabel,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(width: Spacing.sm),

          // Ortho-snap toggle (mirrors Shift on desktop).
          Tooltip(
            message: l10n.tooltipOrthoSnap,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => ref
                  .read(wallModifiersProvider.notifier)
                  .update(orthoSnap: !mods.orthoSnap),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: mods.orthoSnap
                      ? primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: mods.orthoSnap
                        ? primary
                        : colors.gridLine,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.straighten,
                      size: 16,
                      color: mods.orthoSnap
                          ? primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.orthoLabel,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: mods.orthoSnap
                                ? primary
                                : null,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: Spacing.sm),

          // Rectangle mode toggle (mirrors Ctrl on desktop).
          Tooltip(
            message: l10n.tooltipRectangleMode,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => ref
                  .read(wallModifiersProvider.notifier)
                  .update(rectMode: !mods.rectMode),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: mods.rectMode
                      ? primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: mods.rectMode
                        ? primary
                        : colors.gridLine,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.crop_square,
                      size: 16,
                      color: mods.rectMode
                          ? primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.rectangleLabel,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: mods.rectMode
                                ? primary
                                : null,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
