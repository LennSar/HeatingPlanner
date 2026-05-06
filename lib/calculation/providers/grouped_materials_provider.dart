import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/localized_catalog_row.dart';
import '../../data/models/material_entry.dart';
import '../../repositories/material_repository.dart';

/// Canonical category order per agent-hvac.md §7.1.
///
/// Categories not present in this list are appended alphabetically after the
/// known categories so that user-created custom categories are still reachable.
const _categoryOrder = [
  'Masonry',
  'Concrete & Screed',
  'Insulation boards',
  'Loose fill / Blow-in',
  'Wood',
  'Plaster & Mortar',
  'Board materials',
  'Floor covering',
  'Glass',
];

/// Transforms [materialEntriesProvider] into a three-level nested structure
/// for the material picker: **category → subcategory → materials**.
///
/// - Categories appear in the fixed order defined by agent-hvac.md §7.1.
///   Unknown/custom categories are appended alphabetically after the known set.
/// - Subcategories within each category are sorted alphabetically.
/// - Materials within each subcategory are sorted alphabetically by name.
/// - Materials without a subcategory are grouped under the empty-string key
///   `''`, which the picker should render as "General" or similar.
///
/// Returns an empty map while the underlying stream is loading or has errored.
final groupedMaterialsProvider =
    Provider<Map<String, Map<String, List<MaterialEntry>>>>((ref) {
  return ref.watch(materialEntriesProvider).when(
        data: _buildGrouped,
        loading: () => const {},
        error: (_, __) => const {},
      );
});

Map<String, Map<String, List<MaterialEntry>>> _buildGrouped(
  List<MaterialEntry> materials,
) {
  // Collect all unique categories, preserving the canonical order for known
  // ones and sorting any extras alphabetically at the end.
  final allCategories = materials.map((m) => m.category).toSet();
  final knownInOrder =
      _categoryOrder.where(allCategories.contains).toList();
  final extra = (allCategories.difference(knownInOrder.toSet()).toList()
    ..sort());
  final orderedCategories = [...knownInOrder, ...extra];

  final result = <String, Map<String, List<MaterialEntry>>>{};

  for (final category in orderedCategories) {
    final inCategory =
        materials.where((m) => m.category == category).toList();

    // Group by subcategory.
    final bySubcategory = <String, List<MaterialEntry>>{};
    for (final m in inCategory) {
      bySubcategory.putIfAbsent(m.subcategory, () => []).add(m);
    }

    // Sort subcategory keys alphabetically; sort materials within each group.
    final sortedSubcategories = bySubcategory.keys.toList()..sort();
    result[category] = {
      for (final sub in sortedSubcategories)
        sub: bySubcategory[sub]!..sort((a, b) => a.name.compareTo(b.name)),
    };
  }

  return result;
}

/// Locale-aware variant of [groupedMaterialsProvider].
///
/// Same three-level shape, but each leaf is a
/// [LocalizedCatalogRow] of [MaterialEntry] so the picker can render
/// the locale-appropriate name without a second lookup, and
/// material-level sort uses the localized display name (case-insensitive).
/// Category and subcategory keys remain the canonical English values
/// (matching `material_entries.category` / `subcategory` columns) — the
/// picker maps those to localized headers via its own AppLocalizations.
///
/// Returns an empty map while the underlying entries provider is loading
/// or has errored.
final localizedGroupedMaterialsProvider = Provider<
    Map<String, Map<String, List<LocalizedCatalogRow<MaterialEntry>>>>>(
  (ref) {
    final entries = ref.watch(localizedMaterialEntriesProvider);
    if (entries.isEmpty) return const {};
    return _buildGroupedLocalized(entries);
  },
);

Map<String, Map<String, List<LocalizedCatalogRow<MaterialEntry>>>>
    _buildGroupedLocalized(
  List<LocalizedCatalogRow<MaterialEntry>> entries,
) {
  final allCategories = entries.map((e) => e.row.category).toSet();
  final knownInOrder =
      _categoryOrder.where(allCategories.contains).toList();
  final extra = (allCategories.difference(knownInOrder.toSet()).toList()
    ..sort());
  final orderedCategories = [...knownInOrder, ...extra];

  final result =
      <String, Map<String, List<LocalizedCatalogRow<MaterialEntry>>>>{};

  for (final category in orderedCategories) {
    final inCategory =
        entries.where((e) => e.row.category == category).toList();

    final bySubcategory =
        <String, List<LocalizedCatalogRow<MaterialEntry>>>{};
    for (final e in inCategory) {
      bySubcategory.putIfAbsent(e.row.subcategory, () => []).add(e);
    }

    final sortedSubcategories = bySubcategory.keys.toList()..sort();
    result[category] = {
      for (final sub in sortedSubcategories)
        sub: bySubcategory[sub]!
          ..sort((a, b) => a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase())),
    };
  }

  return result;
}
