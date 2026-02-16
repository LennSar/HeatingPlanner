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
}
