import 'dart:ui' show Locale;

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/material_entries_table.dart';

part 'material_dao.g.dart';

/// DAO for the material entries database.
@DriftAccessor(tables: [MaterialEntries])
class MaterialDao extends DatabaseAccessor<AppDatabase>
    with _$MaterialDaoMixin {
  /// Creates a [MaterialDao] bound to [db].
  MaterialDao(super.db);

  /// All material entries ordered by [category] then [name].
  Stream<List<MaterialEntry>> watchAll() =>
      (select(materialEntries)
            ..orderBy([
              (t) => OrderingTerm.asc(t.category),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .watch();

  /// Single material entry by [id].
  Stream<MaterialEntry> watchById(String id) =>
      (select(materialEntries)..where((t) => t.id.equals(id))).watchSingle();

  /// Inserts or replaces a material-entry row.
  ///
  /// ADR-021 Rule 13: rows where `isBuiltIn = false` (custom materials)
  /// must be written via `CustomMaterialLibraryService`. Calling this
  /// with such a companion throws [StateError].
  Future<void> upsert(MaterialEntriesCompanion companion) {
    if (companion.isBuiltIn.present && companion.isBuiltIn.value == false) {
      throw StateError(
        'MaterialDao.upsert may only insert built-in materials. '
        'Use CustomMaterialLibraryService to mutate custom rows '
        '(ADR-021 Rule 13).',
      );
    }
    return into(materialEntries).insertOnConflictUpdate(companion);
  }

  /// Deletes the material entry with the given [id].
  ///
  /// ADR-021 Rule 13: deleting `isBuiltIn = false` rows must go
  /// through `CustomMaterialLibraryService`. Calls that target a
  /// custom row throw [StateError].
  Future<void> deleteById(String id) async {
    final row = await (select(materialEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row != null && !row.isBuiltIn) {
      throw StateError(
        'MaterialDao.deleteById may only delete built-in materials. '
        'Use CustomMaterialLibraryService to delete custom rows '
        '(ADR-021 Rule 13).',
      );
    }
    await (delete(materialEntries)..where((t) => t.id.equals(id))).go();
  }

  /// Returns the locale-appropriate display name for [row].
  ///
  /// Falls back to the canonical English [MaterialEntry.name] when the
  /// requested locale is German but no German translation has been set.
  String localizedNameFor(MaterialEntry row, Locale locale) =>
      locale.languageCode == 'de' ? (row.nameDe ?? row.name) : row.name;
}
