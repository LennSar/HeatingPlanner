import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/providers/grouped_materials_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/material_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/custom_material_library_service.dart';
import '../dialogs/custom_material_dialog.dart';
import 'custom_material_library_picker.dart';

/// Pushes the [ManageCustomMaterialsScreen] onto the given navigator.
Future<void> openManageCustomMaterialsScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => const ManageCustomMaterialsScreen(),
    ),
  );
}

/// Manage Custom Materials screen (UI/UX §5.7.3).
///
/// Reached from the picker dropdown's "Manage custom materials…" pinned
/// row and from the Settings → Custom material library section.
class ManageCustomMaterialsScreen extends ConsumerStatefulWidget {
  /// Creates a [ManageCustomMaterialsScreen].
  const ManageCustomMaterialsScreen({super.key});

  @override
  ConsumerState<ManageCustomMaterialsScreen> createState() =>
      _ManageCustomMaterialsScreenState();
}

class _ManageCustomMaterialsScreenState
    extends ConsumerState<ManageCustomMaterialsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Header actions ──────────────────────────────────────────────────────

  Future<void> _onAdd() async {
    await showAddCustomMaterialDialog(context);
  }

  Future<void> _onEdit(MaterialEntry entry) async {
    await showEditCustomMaterialDialog(context, entry);
  }

  Future<void> _onBrowse() async {
    await pickAndConfigureCustomMaterialLibrary(ref, context: context);
  }

  Future<void> _onResetToDefault() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(l10n.settingsCustomMaterialLibraryResetTitle),
        content:
            Text(l10n.settingsCustomMaterialLibraryResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.customMaterialButtonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.manageCustomMaterialsResetToDefault),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(customMaterialLibraryServiceProvider)
        .setLibraryPath(null);
  }

  Future<void> _onReload() async {
    await ref
        .read(customMaterialLibraryServiceProvider)
        .reloadFromFile();
    if (!mounted) return;
    final count =
        ref.read(customMaterialsProvider).asData?.value.length ?? 0;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(l10n.manageCustomMaterialsReloadedToast(count)),
      ),
    );
  }

  // ── Row actions ─────────────────────────────────────────────────────────

  Future<void> _onDelete(MaterialEntry entry) async {
    final service = ref.read(customMaterialLibraryServiceProvider);
    final result = await service.delete(entry.id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (result) {
      case DeleteOk():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.manageCustomMaterialsDeletedToast(entry.name),
            ),
          ),
        );
      case DeleteBlocked(:final usages):
        await _showBlockedDialog(entry, usages);
    }
  }

  Future<void> _confirmAndDelete(MaterialEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.manageCustomMaterialsDeleteTitle(entry.name),
        ),
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
    if (confirmed != true) return;
    await _onDelete(entry);
  }

  Future<void> _showBlockedDialog(
    MaterialEntry entry,
    List<({String constructionId, String constructionName})> usages,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('custom-material-blocked-dialog'),
        title: Text(
          l10n.manageCustomMaterialsBlockedTitle(entry.name),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.manageCustomMaterialsBlockedBody(
                entry.name,
                usages.length,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            for (final u in usages)
              Padding(
                padding: const EdgeInsets.only(left: Spacing.sm),
                child: Text('• ${u.constructionName}'),
              ),
            const SizedBox(height: Spacing.sm),
            Text(l10n.manageCustomMaterialsBlockedFooter),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.manageCustomMaterialsBlockedOk),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final storedPath = ref.watch(customMaterialLibraryPathProvider);
    final customs =
        ref.watch(customMaterialsProvider).asData?.value ?? const [];
    final filtered = _filter(customs, _query);
    final grouped = _group(filtered);
    final isCompact = MediaQuery.of(context).size.shortestSide < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageCustomMaterialsTitle),
        actions: [
          // ADR-021 Rule 14: a default library always exists, so Add is
          // always enabled.
          if (!isCompact)
            TextButton.icon(
              key: const Key('custom-materials-add'),
              onPressed: _onAdd,
              icon: const Icon(Icons.add),
              label: Text(l10n.manageCustomMaterialsAdd),
            )
          else
            IconButton(
              key: const Key('custom-materials-add'),
              onPressed: _onAdd,
              icon: const Icon(Icons.add),
              tooltip: l10n.manageCustomMaterialsAdd,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LibraryHeader(
              storedPath: storedPath,
              compact: isCompact,
              onBrowse: _onBrowse,
              onResetToDefault:
                  storedPath == null ? null : _onResetToDefault,
              onReload: _onReload,
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l10n.manageCustomMaterialsSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: Spacing.md),
            Expanded(
              child: customs.isEmpty
                  ? _EmptyState(onAdd: _onAdd)
                  : _GroupedList(
                      grouped: grouped,
                      compact: isCompact,
                      onEdit: _onEdit,
                      onDelete: _confirmAndDelete,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static List<MaterialEntry> _filter(
    List<MaterialEntry> all,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            (m.nameDe ?? '').toLowerCase().contains(q))
        .toList();
  }

  /// Groups custom entries by the full `categoryPath` rendered as a
  /// breadcrumb (UI/UX §5.7.3 / ADR-022 Rule 9). Groups are sorted
  /// alphabetically by canonical English breadcrumb; entries inside
  /// each group are sorted by name (case-insensitive).
  static List<({List<String> path, List<MaterialEntry> entries})> _group(
    List<MaterialEntry> entries,
  ) {
    final byKey = <String, List<MaterialEntry>>{};
    final keyToPath = <String, List<String>>{};
    for (final e in entries) {
      final key = breadcrumbFor(e.categoryPath);
      keyToPath[key] = e.categoryPath;
      byKey.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = byKey.keys.toList()..sort();
    return [
      for (final k in sortedKeys)
        (
          path: keyToPath[k]!,
          entries: byKey[k]!
            ..sort((a, b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        ),
    ];
  }
}

// ── Library path header ─────────────────────────────────────────────────────

class _LibraryHeader extends ConsumerWidget {
  const _LibraryHeader({
    required this.storedPath,
    required this.compact,
    required this.onBrowse,
    required this.onResetToDefault,
    required this.onReload,
  });

  /// `null` ⇒ Rule 14 default is in effect; the "Reset to default"
  /// affordance is hidden.
  final String? storedPath;
  final bool compact;
  final VoidCallback onBrowse;
  final VoidCallback? onResetToDefault;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resolved =
        ref.watch(resolvedLibraryPathProvider).asData?.value ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Tooltip(
            message: resolved,
            child: Text(
              resolved,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        if (storedPath == null) ...[
          const SizedBox(width: Spacing.sm),
          const _DefaultChip(),
        ],
        const SizedBox(width: Spacing.sm),
        if (compact)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'browse':
                  onBrowse();
                case 'reset':
                  onResetToDefault?.call();
                case 'reload':
                  onReload();
              }
            },
            itemBuilder: (_) {
              final l10n = AppLocalizations.of(context)!;
              return [
                PopupMenuItem(
                  value: 'browse',
                  child: Text(l10n.manageCustomMaterialsBrowse),
                ),
                if (onResetToDefault != null)
                  PopupMenuItem(
                    value: 'reset',
                    child:
                        Text(l10n.manageCustomMaterialsResetToDefault),
                  ),
                PopupMenuItem(
                  value: 'reload',
                  child: Text(l10n.manageCustomMaterialsReload),
                ),
              ];
            },
          )
        else ...[
          OutlinedButton(
            onPressed: onBrowse,
            child:
                Text(AppLocalizations.of(context)!.manageCustomMaterialsBrowse),
          ),
          if (onResetToDefault != null) ...[
            const SizedBox(width: Spacing.sm),
            OutlinedButton(
              key: const Key('custom-materials-reset'),
              onPressed: onResetToDefault,
              child: Text(
                AppLocalizations.of(context)!
                    .manageCustomMaterialsResetToDefault,
              ),
            ),
          ],
          const SizedBox(width: Spacing.sm),
          OutlinedButton(
            key: const Key('custom-materials-reload'),
            onPressed: onReload,
            child: Text(
              AppLocalizations.of(context)!.manageCustomMaterialsReload,
            ),
          ),
        ],
      ],
    );
  }
}

class _DefaultChip extends StatelessWidget {
  const _DefaultChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs + 2,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Spacing.xs),
      ),
      child: Text(
        AppLocalizations.of(context)!
            .settingsCustomMaterialLibraryDefaultChip,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Grouped list ────────────────────────────────────────────────────────────

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.grouped,
    required this.compact,
    required this.onEdit,
    required this.onDelete,
  });

  /// One row per distinct `categoryPath`, already sorted alphabetically
  /// by canonical English breadcrumb per UI/UX §5.7.3 / ADR-022 Rule 9.
  final List<({List<String> path, List<MaterialEntry> entries})> grouped;
  final bool compact;
  final void Function(MaterialEntry) onEdit;
  final void Function(MaterialEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    if (grouped.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.manageCustomMaterialsNoMatches,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    return ListView(
      children: [
        for (final group in grouped) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Text(
              breadcrumbFor(group.path),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          for (final mat in group.entries)
            _CustomEntryRow(
              entry: mat,
              compact: compact,
              onEdit: () => onEdit(mat),
              onDelete: () => onDelete(mat),
            ),
        ],
      ],
    );
  }
}

class _CustomEntryRow extends StatelessWidget {
  const _CustomEntryRow({
    required this.entry,
    required this.compact,
    required this.onEdit,
    required this.onDelete,
  });

  final MaterialEntry entry;
  final bool compact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final secondary =
        'λ ${entry.lambdaDefault.toStringAsFixed(3)} W/(m·K)';
    return ListTile(
      title: Text(entry.name),
      subtitle: Text(secondary),
      trailing: compact
          ? PopupMenuButton<String>(
              key: Key('custom-entry-${entry.id}-overflow'),
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    onEdit();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) {
                final l10n = AppLocalizations.of(context)!;
                return [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(l10n.manageCustomMaterialsRowEdit),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child:
                        Text(l10n.manageCustomMaterialsRowDelete),
                  ),
                ];
              },
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('custom-entry-${entry.id}-edit'),
                  tooltip: AppLocalizations.of(context)!
                      .manageCustomMaterialsRowEdit,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: Key('custom-entry-${entry.id}-delete'),
                  tooltip: AppLocalizations.of(context)!
                      .manageCustomMaterialsRowDelete,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.manageCustomMaterialsEmptyTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.manageCustomMaterialsEmptyHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.md),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.manageCustomMaterialsAdd),
          ),
        ],
      ),
    );
  }
}
