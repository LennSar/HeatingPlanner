import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/providers/grouped_materials_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/localized_catalog_row.dart';
import '../../data/models/material_entry.dart';
import '../../l10n/app_localizations.dart';
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
/// - **Search inactive**: grouped three-level tree via [_GroupedList] backed
///   by [localizedGroupedMaterialsProvider].
/// - **Search active**: flat [_FlatFilteredList] — case-insensitive substring
///   match against the row's display name *and* its alternate-locale name
///   (so a query typed in English finds DE rows and vice versa) plus the
///   canonical subcategory.
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

  /// Raw query text; drives search-active / search-inactive path switch.
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns true when [entry] matches [lowerQuery] on any searchable field.
  ///
  /// [lowerQuery] must already be lower-cased by the caller (done once per
  /// build, not per item). Matches on the locale-resolved display name,
  /// the alternate-locale name (so English queries match DE rows and
  /// vice versa), and the canonical subcategory.
  static bool _matches(
    LocalizedCatalogRow<MaterialEntry> entry,
    String lowerQuery,
  ) =>
      catalogRowMatchesQuery(entry, lowerQuery) ||
      entry.row.subcategory.toLowerCase().contains(lowerQuery);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Grouped data from the provider — empty while loading or on error.
    final grouped = ref.watch(localizedGroupedMaterialsProvider);

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
              hintText: l10n.searchMaterials,
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
            onChanged: (value) => setState(() => _query = value),
          ),
        ),

        // ── List area ────────────────────────────────────────────────────
        // Loading and error states are surfaced through the canonical
        // `materialEntriesProvider` (handled by parent consumers); the
        // localized variant is a plain Provider that emits an empty list
        // until canonical data is ready.
        Flexible(
          child: Builder(
            builder: (_) {
              final materials =
                  ref.watch(localizedMaterialEntriesProvider);
              // ── Search-active path ──────────────────────────────────────
              final q = _query.trim().toLowerCase();
              if (q.isNotEmpty) {
                final filtered =
                    materials.where((m) => _matches(m, q)).toList();
                return _FlatFilteredList(
                  materials: filtered,
                  onSelected: widget.onSelected,
                );
              }
              // ── Search-inactive path ────────────────────────────────────
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
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Private: flat filtered list (search-active path) ──────────────────────

/// Flat [ListView] of [MaterialEntryTile] rows with no group headers.
///
/// Shown when the search field is non-empty. [materials] is already filtered
/// by [_MaterialPickerState._matches]; this widget only renders them.
class _FlatFilteredList extends StatelessWidget {
  const _FlatFilteredList({
    required this.materials,
    required this.onSelected,
  });

  final List<LocalizedCatalogRow<MaterialEntry>> materials;
  final void Function(MaterialEntry) onSelected;

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
      // indentLevel 0: no group headers to nest under, so tiles sit flush
      // at the base indent (Spacing.sm = 8 px left padding).
      itemBuilder: (_, i) => MaterialEntryTile(
        entry: materials[i],
        indentLevel: 0,
        onTap: () => onSelected(materials[i].row),
      ),
    );
  }
}

// ── Private: grouped list (search-inactive path) ───────────────────────────

/// Scrollable three-level grouped list backed by
/// [localizedGroupedMaterialsProvider].
///
/// Extracted into its own [StatelessWidget] so the list is not rebuilt when
/// the search field text changes (the search-active path is a separate
/// sibling widget).
class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.grouped,
    required this.onSelected,
  });

  final Map<String, Map<String, List<LocalizedCatalogRow<MaterialEntry>>>>
      grouped;
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
                if (subcatEntry.key.isEmpty)
                  // No subcategory — render materials directly at level 1
                  // to avoid an empty-titled subcategory header.
                  for (final material in subcatEntry.value)
                    MaterialEntryTile(
                      entry: material,
                      indentLevel: 1,
                      onTap: () => onSelected(material.row),
                    )
                else
                  // Level 1 — subcategory header.
                  CollapsibleGroupTile(
                    title: subcatEntry.key,
                    indentLevel: 1,
                    children: [
                      for (final material in subcatEntry.value)
                        // Level 2 — leaf material row.
                        MaterialEntryTile(
                          entry: material,
                          onTap: () => onSelected(material.row),
                        ),
                    ],
                  ),
            ],
          ),
      ],
    );
  }
}
