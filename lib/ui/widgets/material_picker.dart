import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/localized_catalog_row.dart';
import '../../data/models/material_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/custom_material_library_service.dart';
import '../../repositories/material_repository.dart';
import '../dialogs/custom_material_dialog.dart';
import '../providers/material_tree_expansion_provider.dart';
import 'material_entry_tile.dart';
import 'material_path_breadcrumb.dart';

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
      entry.row.categoryPath
          .any((seg) => seg.toLowerCase().contains(lowerQuery));

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
              if (materials.isEmpty) {
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
              return _TaxonomyTree(
                roots: _buildTaxonomy(materials),
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
        // Search results carry a full breadcrumb subtitle (UI/UX
        // §5.7.1 item 4) instead of the λ secondary text.
        if (entry.row.isBuiltIn) {
          return MaterialEntryTile(
            entry: entry,
            indentLevel: 0,
            breadcrumbPath: entry.row.categoryPath,
            onTap: () => onSelected(entry.row),
          );
        }
        return _CustomMaterialPickerRow(
          entry: entry,
          indentLevel: 0,
          breadcrumbPath: entry.row.categoryPath,
          onTap: () => onSelected(entry.row),
          onEdit: () => onEditCustom(entry.row),
          onDelete: () => onDeleteCustom(entry.row),
        );
      },
    );
  }
}

// ── Private: inline-disclosure taxonomy tree ───────────────────────────────
// (ADR-022 Rule 5 / UI/UX §5.7.1 item 4)

/// Width of the leading chevron slot. Doubles as the per-level indent
/// step (UI/UX §5.7.1 item 4: "each level inset by `md`").
const double _chevronSlot = Spacing.md;

/// One node in the material taxonomy: a unique `categoryPath` prefix with
/// its child sub-nodes and the materials anchored exactly at this path.
class _TaxonomyNode {
  _TaxonomyNode({
    required this.path,
    required this.childNodes,
    required this.directMaterials,
    required this.subtreeMaterialCount,
  });

  /// Full path from the root to this node (its last segment is the label).
  final List<String> path;

  /// Sub-nodes (paths one segment longer), alphabetical by last segment.
  final List<_TaxonomyNode> childNodes;

  /// Materials whose `categoryPath` equals [path] exactly, alphabetical
  /// by display name.
  final List<LocalizedCatalogRow<MaterialEntry>> directMaterials;

  /// Count of materials in this node and every descendant.
  final int subtreeMaterialCount;

  /// Last path segment — the row label.
  String get segment => path.last;

  /// Stable expansion key (segments can't contain `/` per ADR-022 R1).
  String get joinedPath => path.join('/');

  /// Whether the node has anything to disclose (sub-nodes or materials).
  bool get hasChildren => childNodes.isNotEmpty || directMaterials.isNotEmpty;
}

/// Mutable scratch node used while assembling the taxonomy.
class _MutableNode {
  _MutableNode(this.path);
  final List<String> path;
  final Map<String, _MutableNode> children = {};
  final List<LocalizedCatalogRow<MaterialEntry>> materials = [];
}

/// Pure builder: turns the flat material list into a tree of
/// [_TaxonomyNode] roots. Sub-nodes are alphabetical by last segment and
/// materials alphabetical by display name within each node (UI/UX
/// §5.7.1 item 4 — sub-nodes are rendered before materials).
List<_TaxonomyNode> _buildTaxonomy(
  List<LocalizedCatalogRow<MaterialEntry>> entries,
) {
  final roots = <String, _MutableNode>{};
  for (final e in entries) {
    final path = e.row.categoryPath;
    if (path.isEmpty) continue;
    var level = roots;
    _MutableNode? node;
    final acc = <String>[];
    for (final seg in path) {
      acc.add(seg);
      node = level.putIfAbsent(seg, () => _MutableNode(List<String>.of(acc)));
      level = node.children;
    }
    node!.materials.add(e);
  }
  return _freezeTaxonomy(roots);
}

List<_TaxonomyNode> _freezeTaxonomy(Map<String, _MutableNode> level) {
  final nodes = <_TaxonomyNode>[];
  for (final m in level.values) {
    final children = _freezeTaxonomy(m.children);
    final childCount =
        children.fold<int>(0, (sum, c) => sum + c.subtreeMaterialCount);
    final materials = [...m.materials]..sort(
        (a, b) => a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase()),
      );
    nodes.add(
      _TaxonomyNode(
        path: m.path,
        childNodes: children,
        directMaterials: materials,
        subtreeMaterialCount: m.materials.length + childCount,
      ),
    );
  }
  nodes.sort(
    (a, b) => a.segment.toLowerCase().compareTo(b.segment.toLowerCase()),
  );
  return nodes;
}

/// Scrollable list of root [_TaxonomyNode]s rendered as an inline tree.
class _TaxonomyTree extends StatelessWidget {
  const _TaxonomyTree({
    required this.roots,
    required this.onSelected,
    required this.onEditCustom,
    required this.onDeleteCustom,
  });

  final List<_TaxonomyNode> roots;
  final void Function(MaterialEntry) onSelected;
  final Future<void> Function(MaterialEntry) onEditCustom;
  final Future<void> Function(MaterialEntry) onDeleteCustom;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        for (final node in roots)
          _NodeView(
            node: node,
            onSelected: onSelected,
            onEditCustom: onEditCustom,
            onDeleteCustom: onDeleteCustom,
          ),
      ],
    );
  }
}

/// One node row plus — when expanded — its children, recursively. The
/// expanded/collapsed state lives in [materialTreeExpansionProvider]
/// (editor-scoped) so it survives the dropdown reopening.
class _NodeView extends ConsumerWidget {
  const _NodeView({
    required this.node,
    required this.onSelected,
    required this.onEditCustom,
    required this.onDeleteCustom,
  });

  final _TaxonomyNode node;
  final void Function(MaterialEntry) onSelected;
  final Future<void> Function(MaterialEntry) onEditCustom;
  final Future<void> Function(MaterialEntry) onDeleteCustom;

  Widget _materialRow(LocalizedCatalogRow<MaterialEntry> entry) {
    // Indent the material label so it aligns under sibling sub-node
    // labels (which sit after the chevron slot). The tile already adds
    // its own Spacing.sm, so the extra pad is the remainder.
    final tile = entry.row.isBuiltIn
        ? MaterialEntryTile(
            entry: entry,
            indentLevel: 0,
            onTap: () => onSelected(entry.row),
          )
        : _CustomMaterialPickerRow(
            entry: entry,
            indentLevel: 0,
            onTap: () => onSelected(entry.row),
            onEdit: () => onEditCustom(entry.row),
            onDelete: () => onDeleteCustom(entry.row),
          );
    return Padding(
      padding: const EdgeInsets.only(left: _chevronSlot - Spacing.sm),
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final expanded =
        ref.watch(materialTreeExpansionProvider).contains(node.joinedPath);

    final row = InkWell(
      onTap: node.hasChildren
          ? () => ref
              .read(materialTreeExpansionProvider.notifier)
              .toggle(node.joinedPath)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: _chevronSlot,
              child: node.hasChildren
                  ? Icon(
                      expanded ? Icons.expand_more : Icons.chevron_right,
                      size: _chevronSlot,
                      color: secondary,
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                node.segment,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (node.subtreeMaterialCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: Text(
                  '${node.subtreeMaterialCount}',
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ),
          ],
        ),
      ),
    );

    if (!expanded || !node.hasChildren) return row;

    final children = <Widget>[
      // Sub-nodes first, then materials (UI/UX §5.7.1 item 4).
      for (final child in node.childNodes)
        _NodeView(
          node: child,
          onSelected: onSelected,
          onEditCustom: onEditCustom,
          onDeleteCustom: onDeleteCustom,
        ),
      for (final material in node.directMaterials) _materialRow(material),
    ];

    final gridLine = theme.extension<HeatingPlannerColors>()!.gridLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        // Hairline guide from the parent's chevron centre down the open
        // subtree (UI/UX §5.7.1 item 4).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: _chevronSlot / 2),
              Container(width: 1, color: gridLine),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: _chevronSlot / 2 - 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
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
    this.breadcrumbPath,
  });

  final LocalizedCatalogRow<MaterialEntry> entry;
  final int indentLevel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// When non-null the secondary line renders this `categoryPath` as a
  /// breadcrumb instead of the λ value (search-result rows, UI/UX
  /// §5.7.1 item 4).
  final List<String>? breadcrumbPath;

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
                      if (widget.breadcrumbPath != null)
                        MaterialPathBreadcrumb(path: widget.breadcrumbPath!)
                      else
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
