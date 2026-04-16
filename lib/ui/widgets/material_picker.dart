import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/providers/grouped_materials_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/material_entry.dart';
import '../../repositories/material_repository.dart';
import 'collapsible_group_tile.dart';
import 'material_entry_tile.dart';

/// Searchable, grouped material picker for use in the wall construction editor.
///
/// Renders a pinned search field followed by a three-level collapsible list:
/// **Category (level 0) → Subcategory (level 1) → [MaterialEntryTile] (level 2)**.
///
/// All category and subcategory groups start collapsed. Selecting a
/// [MaterialEntryTile] invokes [onSelected]; the caller is responsible for
/// dismissing any surrounding overlay or dialog.
///
/// Place this widget inside a height-constrained parent (e.g. a [SizedBox]
/// with a fixed height, or a [Dialog]) so the [Flexible] list region can
/// scroll correctly.
///
/// ## Paths
/// - **Search inactive** (implemented): grouped three-level tree via
///   [_GroupedList] backed by [groupedMaterialsProvider].
/// - **Search active** (TODO): flat case-insensitive filtered list with
///   group headers hidden — see inline TODO in [_MaterialPickerState.build].
class MaterialPicker extends ConsumerStatefulWidget {
  /// Creates a [MaterialPicker].
  const MaterialPicker({super.key, required this.onSelected});

  /// Called with the chosen [MaterialEntry] when the user taps a row.
  final void Function(MaterialEntry) onSelected;

  @override
  ConsumerState<MaterialPicker> createState() => _MaterialPickerState();
}

class _MaterialPickerState extends ConsumerState<MaterialPicker> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Grouped data from the provider — empty while loading or on error.
    final grouped = ref.watch(groupedMaterialsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search field — always pinned at top (UI/UX §5.7.1) ───────────
        Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search materials…',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: Spacing.md + Spacing.xs, // 20 px
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
            // TODO(frontend §5.7.1 — search-active path): add onChanged that
            // calls setState to track query text. When text is non-empty,
            // replace _GroupedList below with a _FlatFilteredList that performs
            // case-insensitive substring matching on MaterialEntry.name and
            // shows only MaterialEntryTile rows (no CollapsibleGroupTile headers).
          ),
        ),

        // ── List area — handles all three async states (§2.3) ────────────
        Flexible(
          child: ref.watch(materialEntriesProvider).when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Text(
                'Failed to load materials.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
            data: (_) => grouped.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Text(
                      'No materials available.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : _GroupedList(
                    grouped: grouped,
                    onSelected: widget.onSelected,
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Private: grouped list (search-inactive path) ───────────────────────────

/// Scrollable three-level grouped list backed by [groupedMaterialsProvider].
///
/// Extracted into its own [StatelessWidget] so the list is not rebuilt when
/// the search field text changes (the search-active path will be a separate
/// sibling widget at that point).
class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.grouped,
    required this.onSelected,
  });

  final Map<String, Map<String, List<MaterialEntry>>> grouped;
  final void Function(MaterialEntry) onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      // shrinkWrap allows the ListView to fit inside the Flexible region
      // without requiring an explicit height; Flexible bounds the max size.
      shrinkWrap: true,
      children: [
        for (final catEntry in grouped.entries)
          // Level 0 — category header. All groups start collapsed (spec).
          CollapsibleGroupTile(
            title: catEntry.key,
            indentLevel: 0,
            children: [
              for (final subcatEntry in catEntry.value.entries)
                // Level 1 — subcategory header.
                CollapsibleGroupTile(
                  title: subcatEntry.key,
                  indentLevel: 1,
                  children: [
                    for (final material in subcatEntry.value)
                      // Level 2 — leaf material row.
                      MaterialEntryTile(
                        entry: material,
                        onTap: () => onSelected(material),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
