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
  Future<void> upsert(MaterialEntriesCompanion companion) =>
      into(materialEntries).insertOnConflictUpdate(companion);

  /// Deletes the material entry with the given [id].
  Future<void> deleteById(String id) =>
      (delete(materialEntries)..where((t) => t.id.equals(id))).go();

  /// Returns the locale-appropriate display name for [row].
  ///
  /// Falls back to the canonical English [MaterialEntry.name] when the
  /// requested locale is German but no German translation has been set.
  String localizedNameFor(MaterialEntry row, Locale locale) =>
      locale.languageCode == 'de' ? (row.nameDe ?? row.name) : row.name;
}
