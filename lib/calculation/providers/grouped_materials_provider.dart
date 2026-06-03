import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/localized_catalog_row.dart';
import '../../data/models/material_entry.dart';
import '../../repositories/material_repository.dart';

/// Breadcrumb separator used in path-grouped headers per UI/UX §5.7.1
/// item 4 (`U+203A SINGLE RIGHT-POINTING ANGLE QUOTATION MARK` with
/// surrounding spaces).
const String breadcrumbSeparator = ' › ';

/// Renders [path] as the canonical breadcrumb string used both as a
/// group header in the picker / manage screen and as the sort key.
String breadcrumbFor(List<String> path) => path.join(breadcrumbSeparator);

/// One group in the picker / manage-screen tree: a full
/// [MaterialEntry.categoryPath] and the materials anchored there.
typedef MaterialPathGroup = ({
  List<String> path,
  List<LocalizedCatalogRow<MaterialEntry>> entries,
});

/// Flat, alphabetically-sorted list of materials grouped by full
/// `categoryPath` per `DECISIONS.md` ADR-022 Rule 5 and UI/UX §5.7.1
/// item 4.
///
/// - Groups are sorted alphabetically by their canonical English
///   breadcrumb (`segments.join(' › ')`). Built-in and custom entries
///   interleave naturally — the prior "built-in first" ordering is
///   retired with ADR-022.
/// - Entries inside each group are sorted by their locale-resolved
///   display name (case-insensitive).
///
/// Returns an empty list while the underlying entries provider is
/// loading or has errored.
final localizedMaterialsByPathProvider =
    Provider<List<MaterialPathGroup>>((ref) {
  final entries = ref.watch(localizedMaterialEntriesProvider);
  if (entries.isEmpty) return const [];

  final byKey = <String, List<LocalizedCatalogRow<MaterialEntry>>>{};
  final keyToPath = <String, List<String>>{};
  for (final e in entries) {
    final key = breadcrumbFor(e.row.categoryPath);
    keyToPath[key] = e.row.categoryPath;
    byKey.putIfAbsent(key, () => []).add(e);
  }
  final sortedKeys = byKey.keys.toList()..sort();
  return [
    for (final k in sortedKeys)
      (
        path: keyToPath[k]!,
        entries: byKey[k]!
          ..sort((a, b) => a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase())),
      ),
  ];
});

/// All distinct `categoryPath` values present in the catalog, sorted
/// alphabetically by canonical English breadcrumb. Used by the Custom
/// Material dialog's "Start under" picker per UI/UX §5.7.2.
final distinctCategoryPathsProvider = Provider<List<List<String>>>((ref) {
  final groups = ref.watch(localizedMaterialsByPathProvider);
  return [for (final g in groups) g.path];
});
