import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/material_layers_table.dart';
import '../tables/wall_constructions_table.dart';

part 'construction_dao.g.dart';

/// DAO for wall constructions and their material layers.
@DriftAccessor(tables: [WallConstructions, MaterialLayers])
class ConstructionDao extends DatabaseAccessor<AppDatabase>
    with _$ConstructionDaoMixin {
  /// Creates a [ConstructionDao] bound to [db].
  ConstructionDao(super.db);

  // ── WallConstructions ─────────────────────────────────────────────────────

  /// All wall constructions, ordered by name.
  Stream<List<WallConstruction>> watchAll() =>
      (select(wallConstructions)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  /// Single wall construction by [id].
  Stream<WallConstruction> watchById(String id) =>
      (select(wallConstructions)..where((t) => t.id.equals(id))).watchSingle();

  /// Inserts or replaces a wall-construction row.
  Future<void> upsertConstruction(WallConstructionsCompanion companion) =>
      into(wallConstructions).insertOnConflictUpdate(companion);

  /// Deletes the wall construction with the given [id].
  Future<void> deleteConstruction(String id) =>
      (delete(wallConstructions)..where((t) => t.id.equals(id))).go();

  // ── MaterialLayers ────────────────────────────────────────────────────────

  /// All layers for [constructionId] ordered by [sortOrder] ascending.
  Stream<List<MaterialLayer>> watchLayers(String constructionId) =>
      (select(materialLayers)
            ..where((t) => t.constructionId.equals(constructionId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  /// Inserts or replaces a material-layer row.
  Future<void> upsertLayer(MaterialLayersCompanion companion) =>
      into(materialLayers).insertOnConflictUpdate(companion);

  /// Deletes the material layer with the given [id].
  Future<void> deleteLayer(String id) =>
      (delete(materialLayers)..where((t) => t.id.equals(id))).go();
}
