import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart' as $db;
import '../data/database/daos/material_dao.dart';
import '../data/models/localized_catalog_row.dart';
import '../data/models/material_entry.dart';
import 'app_preferences.dart';
import 'save_state_notifier.dart';

/// Version of the built-in material catalogue shipped with this build.
///
/// Increment this whenever [assets/materials.json] is updated. On next
/// launch [MaterialRepository.ensureMaterialsSeeded] will detect the
/// mismatch and re-upsert all entries.
const materialDbVersion = 4;

// ── DAO provider ──────────────────────────────────────────────────────────────

/// Provides the [MaterialDao] from the singleton [AppDatabase].
final materialDaoProvider = Provider<MaterialDao>((ref) {
  return ref.watch($db.appDatabaseProvider).materialDao;
});

// ── Stream providers ──────────────────────────────────────────────────────────

/// Reactive stream of all [MaterialEntry] records, ordered by category then
/// name.
final materialEntriesProvider = StreamProvider<List<MaterialEntry>>((ref) {
  return ref
      .watch(materialDaoProvider)
      .watchAll()
      .map((rows) => rows.map(_entryFromRow).toList());
});

/// Reactive stream of a single [MaterialEntry] by [id].
final materialEntryProvider =
    StreamProvider.family<MaterialEntry, String>((ref, id) {
  return ref
      .watch(materialDaoProvider)
      .watchById(id)
      .map(_entryFromRow);
});

/// All [MaterialEntry] records paired with their locale-resolved display
/// name, sorted by display name (case-insensitive).
///
/// Derives from [materialEntriesProvider] (canonical data) and
/// [currentLocaleProvider] (current language), so any test that
/// overrides [materialEntriesProvider] also drives this provider —
/// no separate Drift stream subscription is opened. Returns an empty
/// list while the canonical stream is loading or has errored.
///
/// Search/filter consumers should use [catalogRowMatchesQuery], which
/// inspects both [LocalizedCatalogRow.displayName] and
/// [LocalizedCatalogRow.alternateName] so a query typed in either
/// supported language matches.
final localizedMaterialEntriesProvider =
    Provider<List<LocalizedCatalogRow<MaterialEntry>>>((ref) {
  final locale = ref.watch(currentLocaleProvider);
  final entries =
      ref.watch(materialEntriesProvider).asData?.value ?? const [];
  final isDe = locale.languageCode == 'de';
  final list = [
    for (final e in entries)
      LocalizedCatalogRow<MaterialEntry>(
        row: e,
        displayName: isDe ? (e.nameDe ?? e.name) : e.name,
        alternateName: isDe ? e.name : e.nameDe,
      ),
  ];
  list.sort(
    (a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );
  return list;
});

// ── Repository class ──────────────────────────────────────────────────────────

/// Class-based repository for [MaterialEntry] entities.
///
/// Mixes in [SaveStateMixin]. [markProjectDirty] is called only for
/// user-created materials ([MaterialEntry.isBuiltIn] == false). Seed-data
/// inserts use [upsertBuiltInMaterial] which skips the dirty flag.
class MaterialRepository with SaveStateMixin {
  /// Creates a [MaterialRepository] backed by [ref].
  MaterialRepository(this.ref);

  @override
  final Ref ref;

  MaterialDao get _dao => ref.read(materialDaoProvider);

  /// Inserts or replaces a user-created [entry] and marks dirty.
  Future<void> upsertCustomMaterial(MaterialEntry entry) async {
    await _dao.upsert(_entryToCompanion(entry));
    markProjectDirty();
  }

  /// Inserts or replaces a built-in seed [entry] without marking dirty.
  Future<void> upsertBuiltInMaterial(MaterialEntry entry) =>
      _dao.upsert(_entryToCompanion(entry));

  /// Deletes the user-created material with [id] and marks dirty.
  Future<void> deleteCustomMaterial(String id) async {
    await _dao.deleteById(id);
    markProjectDirty();
  }

  /// Ensures the built-in material catalogue is up-to-date.
  ///
  /// Compares [materialDbVersion] with the value stored in [AppPreferences].
  /// When they differ (first install or catalogue update) the full
  /// `assets/materials.json` is loaded and every entry is upserted into the
  /// `material_entries` table. The preference is then updated so subsequent
  /// launches are a no-op.
  Future<void> ensureMaterialsSeeded() async {
    final prefs = ref.read(appPreferencesProvider);
    final stored = await prefs.getMaterialDbVersion();
    final rowCount = await _dao.watchAll().first.then((r) => r.length);
    if (stored == materialDbVersion && rowCount > 0) return;

    final jsonString =
        await rootBundle.loadString('assets/materials.json');
    final jsonList = json.decode(jsonString) as List<dynamic>;

    for (final raw in jsonList) {
      final map = raw as Map<String, dynamic>;
      await upsertBuiltInMaterial(
        MaterialEntry(
          id: map['id'] as String,
          name: map['name'] as String,
          category: map['category'] as String,
          subcategory: (map['subcategory'] as String?) ?? '',
          lambdaDefault: (map['lambdaDefault'] as num).toDouble(),
          densityDefault: (map['densityDefault'] as num).toDouble(),
          specificHeatDefault:
              (map['specificHeatDefault'] as num).toDouble(),
        ),
      );
    }

    // Populate `name_de` for the catalog rows just inserted. The helper
    // is idempotent (UPDATE WHERE name = ?) so re-running is safe.
    await ref.read($db.appDatabaseProvider).heatingDao.seedGermanNamesV15();

    await prefs.setMaterialDbVersion(materialDbVersion);
  }
}

/// Provides the singleton [MaterialRepository].
final materialRepositoryProvider = Provider<MaterialRepository>(
  (ref) => MaterialRepository(ref),
);

// ── Row → Model mapping ───────────────────────────────────────────────────────

MaterialEntry _entryFromRow($db.MaterialEntry row) {
  return MaterialEntry(
    id: row.id,
    name: row.name,
    nameDe: row.nameDe,
    category: row.category,
    subcategory: row.subcategory,
    lambdaDefault: row.lambdaDefault,
    densityDefault: row.densityDefault,
    specificHeatDefault: row.specificHeatDefault,
    isBuiltIn: row.isBuiltIn,
  );
}

// ── Model → Companion mapping ─────────────────────────────────────────────────

$db.MaterialEntriesCompanion _entryToCompanion(MaterialEntry entry) {
  return $db.MaterialEntriesCompanion(
    id: Value(entry.id),
    name: Value(entry.name),
    nameDe: Value(entry.nameDe),
    category: Value(entry.category),
    subcategory: Value(entry.subcategory),
    lambdaDefault: Value(entry.lambdaDefault),
    densityDefault: Value(entry.densityDefault),
    specificHeatDefault: Value(entry.specificHeatDefault),
    isBuiltIn: Value(entry.isBuiltIn),
  );
}
