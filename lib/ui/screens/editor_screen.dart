import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../platform/keyboard_shortcuts.dart';
import '../canvas/canvas_controller.dart';
import '../canvas/floor_plan_canvas.dart';
import '../dialogs/project_settings_dialog.dart';
import '../panels/properties_panel.dart';
import '../providers/editor_state_provider.dart';

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

  @override
  void initState() {
    super.initState();
    // Defer the provider mutation to after the first frame so
    // that it does not fire while the widget tree is still
    // building (which Riverpod disallows).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(currentProjectIdProvider.notifier)
          .set(widget.projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width < 600;

    return EditorShortcuts(
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
                ),

                // Canvas fills remaining space
                const Expanded(child: FloorPlanCanvas()),

                // Properties panel (desktop only)
                if (!isTablet && _propertiesPanelVisible)
                  SizedBox(
                    width: width >= 1200
                        ? PropertiesPanel.widthLarge
                        : PropertiesPanel.widthMedium,
                    child: const PropertiesPanel(),
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
  });

  final bool isCompact;
  final DrawingTool selectedTool;
  final ValueChanged<DrawingTool> onToolSelected;

  static const _toolEntries = [
    _ToolEntry(DrawingTool.select, Icons.near_me, 'Select'),
    _ToolEntry(
      DrawingTool.drawWall,
      Icons.border_style,
      'Wall',
    ),
    _ToolEntry(
      DrawingTool.placeWindow,
      Icons.window,
      'Window',
    ),
    _ToolEntry(
      DrawingTool.placeDoor,
      Icons.door_front_door_outlined,
      'Door',
    ),
    _ToolEntry(
      DrawingTool.drawZone,
      Icons.grid_on,
      'Floor Zone',
    ),
    _ToolEntry(
      DrawingTool.drawWallZone,
      Icons.view_column_outlined,
      'Wall Zone',
    ),
    _ToolEntry(
      DrawingTool.placeDistributor,
      Icons.hub_outlined,
      'Distributor',
    ),
    _ToolEntry(
      DrawingTool.routePipe,
      Icons.route,
      'Pipe',
    ),
    _ToolEntry(
      DrawingTool.measure,
      Icons.straighten,
      'Measure',
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: Spacing.sm),
          // Drawing tools
          for (final entry in _toolEntries)
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
                  onTap: () => onToolSelected(entry.tool),
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

          const Spacer(),

          // Separator
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
            ),
            child: Divider(color: colors.gridLine),
          ),

          // Dashboard toggle
          Tooltip(
            message: 'Dashboard',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // TODO(frontend): toggle performance dashboard.
                },
                child: SizedBox(
                  width: toolbarWidth,
                  height: toolbarWidth,
                  child: Icon(
                    Icons.bar_chart,
                    size: isCompact ? 20 : 22,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

          // Project settings
          Tooltip(
            message: 'Project Settings',
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
// Status bar
// ----------------------------------------------------------

class _StatusBar extends ConsumerWidget {
  const _StatusBar({required this.onTogglePanel});

  final VoidCallback onTogglePanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasControllerProvider);
    final zoomPercent =
        (canvasState.zoom * 100).round();
    final cursorPos = ref.watch(cursorPositionProvider);
    final editorState = ref.watch(editorStateProvider);
    final roomCount = editorState.rooms.length;
    final toolHint = ref.watch(toolStatusHintProvider);
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
              'Zoom: $zoomPercent%',
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

            // Warnings
            Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: colors.zoneYellow,
            ),
            const SizedBox(width: Spacing.xs),
            Text('0 warnings', style: textTheme.bodySmall),
            const SizedBox(width: Spacing.md),

            // Room count
            Text('$roomCount rooms',
                style: textTheme.bodySmall),
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
