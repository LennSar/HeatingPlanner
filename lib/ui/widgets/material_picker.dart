import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/providers/grouped_materials_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/material_category_localizer.dart';
import '../../data/models/localized_catalog_row.dart';
import '../../data/models/material_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/custom_material_library_service.dart';
import '../../repositories/material_repository.dart';
import '../dialogs/custom_material_dialog.dart';
import 'collapsible_group_tile.dart';
import 'material_entry_tile.dart';

/// Searchable, grouped material picker for use in the wall construction editor.
///
/// Renders a pinned search field, a pinned "+ New custom material…" row,
/// a three-level collapsible list, and a pinned "Manage custom materials…"
/// row at the bottom — see UI/UX §5.7.1.
class MaterialPicker extends ConsumerStatefulWidget {
  /// Creates a [MaterialPicker].
  const MaterialPicker({
    super.key,
    required this.onSelected,
    this.onManageRequested,
  });

  /// Called with the chosen [MaterialEntry] when the user taps a row.
  final void Function(MaterialEntry) onSelected;

  /// Called when the user taps the pinned "Manage custom materials…"
  /// row. The caller is responsible for dismissing any surrounding
  /// dialog and pushing the manage screen.
  ///
  /// When null the pinned row is hidden entirely.
  final VoidCallback? onManageRequested;

  @override
  ConsumerState<MaterialPicker> createState() => _MaterialPickerState();
}

class _MaterialPickerState extends ConsumerState<MaterialPicker> {
  final _searchController = TextEditingController();

  /// Raw query text; drives search-active / search-inactive path switch.
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns true when [entry] matches [lowerQuery] on any searchable field.
  static bool _matches(
    LocalizedCatalogRow<MaterialEntry> entry,
    String lowerQuery,
  ) =>
      catalogRowMatchesQuery(entry, lowerQuery) ||
      entry.row.subcategory.toLowerCase().contains(lowerQuery);

  Future<void> _createCustom() async {
    final newEntry = await showAddCustomMaterialDialog(context);
    if (newEntry == null || !mounted) return;
    widget.onSelected(newEntry);
  }

  Future<void> _editCustom(MaterialEntry entry) async {
    await showEditCustomMaterialDialog(context, entry);
  }

  Future<void> _deleteCustom(MaterialEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(l10n.manageCustomMaterialsDeleteTitle(entry.name)),
        content: Text(l10n.manageCustomMaterialsDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.customMaterialButtonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.manageCustomMaterialsRowDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref
        .read(customMaterialLibraryServiceProvider)
        .delete(entry.id);
    if (!mounted) return;
    if (result is DeleteBlocked) {
      final blockedL10n = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            blockedL10n.manageCustomMaterialsBlockedTitle(entry.name),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                blockedL10n.manageCustomMaterialsBlockedBody(
                  entry.name,
                  result.usages.length,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              for (final u in result.usages)
                Padding(
                  padding: const EdgeInsets.only(left: Spacing.sm),
                  child: Text('• ${u.constructionName}'),
                ),
              const SizedBox(height: Spacing.sm),
              Text(blockedL10n.manageCustomMaterialsBlockedFooter),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(blockedL10n.manageCustomMaterialsBlockedOk),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final grouped = ref.watch(localizedGroupedMaterialsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search field ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: l10n.searchMaterials,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: Spacing.md + Spacing.xs,
                color: colorScheme.onSurfaceVariant,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Spacing.xs),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: Spacing.sm,
                horizontal: Spacing.sm,
              ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),

        // ── "+ New custom material…" pinned row ──────────────────────────
        // ADR-021 Rule 14: a default library file is always available,
        // so this row is always enabled.
        _PinnedActionRow(
          key: const Key('material-picker-new-custom'),
          icon: Icons.add,
          label: l10n.customMaterialPickerNewRow,
          onTap: _createCustom,
        ),
        const Divider(height: 1),

        // ── List area ────────────────────────────────────────────────────
        Flexible(
          child: Builder(
            builder: (_) {
              final materials =
                  ref.watch(localizedMaterialEntriesProvider);
              final q = _query.trim().toLowerCase();
              if (q.isNotEmpty) {
                final filtered =
                    materials.where((m) => _matches(m, q)).toList();
                return _FlatFilteredList(
                  materials: filtered,
                  onSelected: widget.onSelected,
                  onEditCustom: _editCustom,
                  onDeleteCustom: _deleteCustom,
                );
              }
              if (grouped.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Text(
                    l10n.noMaterialsInPicker,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return _GroupedList(
                grouped: grouped,
                onSelected: widget.onSelected,
                onEditCustom: _editCustom,
                onDeleteCustom: _deleteCustom,
              );
            },
          ),
        ),

        // ── "Manage custom materials…" pinned row ────────────────────────
        // ADR-021 Rule 14: always enabled.
        if (widget.onManageRequested != null) ...[
          const Divider(height: 1),
          _PinnedActionRow(
            key: const Key('material-picker-manage'),
            icon: Icons.settings,
            label: l10n.customMaterialPickerManageRow,
            onTap: widget.onManageRequested!,
          ),
        ],
      ],
    );
  }
}

// ── Pinned action row ───────────────────────────────────────────────────────

class _PinnedActionRow extends StatelessWidget {
  const _PinnedActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, size: Spacing.md, color: color),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private: flat filtered list ─────────────────────────────────────────────

class _FlatFilteredList extends StatelessWidget {
  const _FlatFilteredList({
    required this.materials,
    required this.onSelected,
    required this.onEditCustom,
    required this.onDeleteCustom,
  });

  final List<LocalizedCatalogRow<MaterialEntry>> materials;
  final void Function(MaterialEntry) onSelected;
  final Future<void> Function(MaterialEntry) onEditCustom;
  final Future<void> Function(MaterialEntry) onDeleteCustom;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          AppLocalizations.of(context)!.noMatchingMaterials,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: materials.length,
      itemBuilder: (_, i) {
        final entry = materials[i];
        if (entry.row.isBuiltIn) {
          return MaterialEntryTile(
            entry: entry,
            indentLevel: 0,
            onTap: () => onSelected(entry.row),
          );
        }
        return _CustomMaterialPickerRow(
          entry: entry,
          indentLevel: 0,
          onTap: () => onSelected(entry.row),
          onEdit: () => onEditCustom(entry.row),
          onDelete: () => onDeleteCustom(entry.row),
        );
      },
    );
  }
}

// ── Private: grouped list ───────────────────────────────────────────────────

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.grouped,
    required this.onSelected,
    required this.onEditCustom,
    required this.onDeleteCustom,
  });

  final Map<String, Map<String, List<LocalizedCatalogRow<MaterialEntry>>>>
      grouped;
  final void Function(MaterialEntry) onSelected;
  final Future<void> Function(MaterialEntry) onEditCustom;
  final Future<void> Function(MaterialEntry) onDeleteCustom;

  Widget _buildMaterialTile(
    BuildContext context,
    LocalizedCatalogRow<MaterialEntry> entry, {
    required int indentLevel,
  }) {
    if (entry.row.isBuiltIn) {
      return MaterialEntryTile(
        entry: entry,
        indentLevel: indentLevel,
        onTap: () => onSelected(entry.row),
      );
    }
    return _CustomMaterialPickerRow(
      entry: entry,
      indentLevel: indentLevel,
      onTap: () => onSelected(entry.row),
      onEdit: () => onEditCustom(entry.row),
      onDelete: () => onDeleteCustom(entry.row),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        for (final catEntry in grouped.entries)
          CollapsibleGroupTile(
            title: localizeMaterialCategory(context, catEntry.key),
            indentLevel: 0,
            children: [
              for (final subcatEntry in catEntry.value.entries)
                if (subcatEntry.key.isEmpty)
                  for (final material in subcatEntry.value)
                    _buildMaterialTile(
                      context,
                      material,
                      indentLevel: 1,
                    )
                else
                  CollapsibleGroupTile(
                    title: localizeMaterialSubcategory(
                      context,
                      subcatEntry.key,
                    ),
                    indentLevel: 1,
                    children: [
                      for (final material in subcatEntry.value)
                        _buildMaterialTile(
                          context,
                          material,
                          indentLevel: 2,
                        ),
                    ],
                  ),
            ],
          ),
      ],
    );
  }
}

// ── Private: custom material row with chip + edit affordance ─────────────────

/// Picker row for an `isBuiltIn = false` entry.
///
/// - Adds a small "*Custom*" chip next to the name (UI/UX §5.7.1 item 5).
/// - Right-click on desktop or long-press on tablet opens an Edit /
///   Delete context menu (UI/UX §5.7.1 item 6).
/// - On hover (desktop) reveals a pencil button at the row's right
///   edge (also opens edit).
class _CustomMaterialPickerRow extends StatefulWidget {
  const _CustomMaterialPickerRow({
    required this.entry,
    required this.indentLevel,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final LocalizedCatalogRow<MaterialEntry> entry;
  final int indentLevel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_CustomMaterialPickerRow> createState() =>
      _CustomMaterialPickerRowState();
}

class _CustomMaterialPickerRowState
    extends State<_CustomMaterialPickerRow> {
  bool _hover = false;
  Offset? _menuPosition;

  Future<void> _openContextMenu(Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final l10n = AppLocalizations.of(context)!;
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Text(l10n.manageCustomMaterialsRowEdit),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(l10n.manageCustomMaterialsRowDelete),
        ),
      ],
    );
    if (!mounted) return;
    switch (selection) {
      case 'edit':
        widget.onEdit();
      case 'delete':
        widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extColors = theme.extension<HeatingPlannerColors>()!;
    final secondary =
        'λ ${widget.entry.row.lambdaDefault.toStringAsFixed(3)} W/(m·K)';
    final leftPad = Spacing.sm + widget.indentLevel * Spacing.md;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (d) {
          _menuPosition = d.globalPosition;
          _openContextMenu(d.globalPosition);
        },
        onSecondaryTapDown: (d) => _menuPosition = d.globalPosition,
        onSecondaryTap: () {
          final pos = _menuPosition;
          if (pos != null) _openContextMenu(pos);
        },
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: EdgeInsets.only(
              left: leftPad,
              right: Spacing.sm,
              top: Spacing.sm,
              bottom: Spacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.entry.displayName,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          _CustomChip(color: extColors.infoBlue),
                        ],
                      ),
                      Text(
                        secondary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hover)
                  IconButton(
                    key: Key(
                      'custom-entry-${widget.entry.row.id}-edit',
                    ),
                    tooltip:
                        AppLocalizations.of(context)!
                            .manageCustomMaterialsRowEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: widget.onEdit,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomChip extends StatelessWidget {
  const _CustomChip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('custom-material-chip'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs + 2,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Spacing.xs),
      ),
      child: Text(
        AppLocalizations.of(context)!.customMaterialChip,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
