import 'package:flutter_riverpod/flutter_riverpod.dart';

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
