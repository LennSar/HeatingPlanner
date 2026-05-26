import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/material_entry.dart';
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
    await pickAndConfigureCustomMaterialLibrary(ref);
  }

  Future<void> _onClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink custom material library?'),
        content: const Text(
          'The file on disk will not be deleted, but your custom '
          'materials will disappear from the app until you pick the '
          'file again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unlink'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reloaded $count custom materials')),
    );
  }

  // ── Row actions ─────────────────────────────────────────────────────────

  Future<void> _onDelete(MaterialEntry entry) async {
    final service = ref.read(customMaterialLibraryServiceProvider);
    final result = await service.delete(entry.id);
    if (!mounted) return;
    switch (result) {
      case DeleteOk():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${entry.name}"')),
        );
      case DeleteBlocked(:final usages):
        await _showBlockedDialog(entry, usages);
    }
  }

  Future<void> _confirmAndDelete(MaterialEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${entry.name}"?'),
        content: const Text(
          'This will remove it from your custom material library '
          'file and from the in-app database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('custom-material-blocked-dialog'),
        title: Text('"${entry.name}" is in use'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${entry.name}" is used in ${usages.length} '
              'layer${usages.length == 1 ? '' : 's'}:',
            ),
            const SizedBox(height: Spacing.sm),
            for (final u in usages)
              Padding(
                padding: const EdgeInsets.only(left: Spacing.sm),
                child: Text('• ${u.constructionName}'),
              ),
            const SizedBox(height: Spacing.sm),
            const Text(
              'Remove or reassign those layers first, then try again.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final path = ref.watch(customMaterialLibraryPathProvider);
    final customs =
        ref.watch(customMaterialsProvider).asData?.value ?? const [];
    final filtered = _filter(customs, _query);
    final grouped = _group(filtered);
    final isCompact = MediaQuery.of(context).size.shortestSide < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Materials'),
        actions: [
          if (!isCompact)
            TextButton.icon(
              key: const Key('custom-materials-add'),
              onPressed: path == null ? null : _onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          else
            IconButton(
              key: const Key('custom-materials-add'),
              onPressed: path == null ? null : _onAdd,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LibraryHeader(
              path: path,
              compact: isCompact,
              onBrowse: _onBrowse,
              onClear: path == null ? null : _onClear,
              onReload: path == null ? null : _onReload,
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: Spacing.md),
            Expanded(
              child: customs.isEmpty
                  ? _EmptyState(
                      onAdd: path == null ? null : _onAdd,
                    )
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

  static Map<String, Map<String, List<MaterialEntry>>> _group(
    List<MaterialEntry> entries,
  ) {
    final result = <String, Map<String, List<MaterialEntry>>>{};
    for (final e in entries) {
      result
          .putIfAbsent(e.category, () => {})
          .putIfAbsent(e.subcategory, () => [])
          .add(e);
    }
    for (final byCat in result.values) {
      for (final list in byCat.values) {
        list.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
    }
    return result;
  }
}

// ── Library path header ─────────────────────────────────────────────────────

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.path,
    required this.compact,
    required this.onBrowse,
    required this.onClear,
    required this.onReload,
  });

  final String? path;
  final bool compact;
  final VoidCallback onBrowse;
  final VoidCallback? onClear;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            path ?? 'No library configured',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: path == null
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        if (compact)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'browse':
                  onBrowse();
                case 'clear':
                  onClear?.call();
                case 'reload':
                  onReload?.call();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'browse', child: Text('Browse…')),
              PopupMenuItem(
                value: 'clear',
                enabled: onClear != null,
                child: const Text('Clear'),
              ),
              PopupMenuItem(
                value: 'reload',
                enabled: onReload != null,
                child: const Text('Reload from file'),
              ),
            ],
          )
        else ...[
          OutlinedButton(
            onPressed: onBrowse,
            child: const Text('Browse…'),
          ),
          const SizedBox(width: Spacing.sm),
          OutlinedButton(
            onPressed: onClear,
            child: const Text('Clear'),
          ),
          const SizedBox(width: Spacing.sm),
          OutlinedButton(
            key: const Key('custom-materials-reload'),
            onPressed: onReload,
            child: const Text('Reload from file'),
          ),
        ],
      ],
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

  final Map<String, Map<String, List<MaterialEntry>>> grouped;
  final bool compact;
  final void Function(MaterialEntry) onEdit;
  final void Function(MaterialEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    if (grouped.isEmpty) {
      return Center(
        child: Text(
          'No matches.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    return ListView(
      children: [
        for (final catEntry in grouped.entries) ...[
          for (final subEntry in catEntry.value.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Spacing.sm,
              ),
              child: Text(
                '${catEntry.key} › ${subEntry.key}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ),
            for (final mat in subEntry.value)
              _CustomEntryRow(
                entry: mat,
                compact: compact,
                onEdit: () => onEdit(mat),
                onDelete: () => onDelete(mat),
              ),
          ],
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
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('custom-entry-${entry.id}-edit'),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: Key('custom-entry-${entry.id}-delete'),
                  tooltip: 'Delete',
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No custom materials yet.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Press "+ Add" to create your first one.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.md),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
