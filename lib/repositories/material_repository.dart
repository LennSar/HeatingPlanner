import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart' as $db;
import '../data/database/daos/material_dao.dart';
import '../data/models/material_entry.dart';
import 'save_state_notifier.dart';

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
    category: row.category,
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
    category: Value(entry.category),
    lambdaDefault: Value(entry.lambdaDefault),
    densityDefault: Value(entry.densityDefault),
    specificHeatDefault: Value(entry.specificHeatDefault),
    isBuiltIn: Value(entry.isBuiltIn),
  );
}
