import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart' as $db;
import '../data/database/daos/construction_dao.dart';
import '../data/models/material_layer.dart';
import '../data/models/wall_construction.dart';

// ── DAO provider ──────────────────────────────────────────────────────────────

/// Provides the [ConstructionDao] from the singleton [AppDatabase].
final constructionDaoProvider = Provider<ConstructionDao>((ref) {
  return ref.watch($db.appDatabaseProvider).constructionDao;
});

// ── Stream providers ──────────────────────────────────────────────────────────

/// Reactive stream of a single [WallConstruction] by ID.
///
/// Returns `null` if the construction does not exist.
final constructionProvider =
    StreamProvider.family<WallConstruction?, String>(
  (ref, constructionId) {
    return ref
        .watch(constructionDaoProvider)
        .watchByIdNullable(constructionId)
        .map((row) => row == null ? null : _constructionFromRow(row));
  },
);

/// Reactive stream of all [MaterialLayer]s for a construction.
///
/// Layers are unordered; consumers must sort by [MaterialLayer.sortOrder].
final layersProvider =
    StreamProvider.family<List<MaterialLayer>, String>(
  (ref, constructionId) {
    return ref
        .watch(constructionDaoProvider)
        .watchLayers(constructionId)
        .map((rows) => rows.map(_layerFromRow).toList());
  },
);

// ── WallConstruction CRUD ─────────────────────────────────────────────────────

/// Inserts or replaces [construction] in the database.
Future<void> upsertConstruction(
  ConstructionDao dao,
  WallConstruction construction,
) =>
    dao.upsertConstruction(_constructionToCompanion(construction));

/// Deletes the [WallConstruction] with the given [id].
Future<void> deleteConstruction(ConstructionDao dao, String id) =>
    dao.deleteConstruction(id);

// ── MaterialLayer CRUD ────────────────────────────────────────────────────────

/// Inserts or replaces [layer] in the database.
Future<void> upsertLayer(
  ConstructionDao dao,
  MaterialLayer layer,
) =>
    dao.upsertLayer(_layerToCompanion(layer));

/// Deletes the [MaterialLayer] with the given [id].
Future<void> deleteLayer(ConstructionDao dao, String id) =>
    dao.deleteLayer(id);

// ── Row → Model mapping ───────────────────────────────────────────────────────

WallConstruction _constructionFromRow($db.WallConstruction row) {
  return WallConstruction(
    id: row.id,
    name: row.name,
    rsi: row.rsi,
    rse: row.rse,
  );
}

MaterialLayer _layerFromRow($db.MaterialLayer row) {
  return MaterialLayer(
    id: row.id,
    constructionId: row.constructionId,
    sortOrder: row.sortOrder,
    materialId: row.materialId,
    thicknessMm: row.thicknessMm,
    thermalConductivity: row.thermalConductivity,
    density: row.density,
    specificHeat: row.specificHeat,
  );
}

// ── Model → Companion mapping ─────────────────────────────────────────────────

$db.WallConstructionsCompanion _constructionToCompanion(
  WallConstruction construction,
) {
  return $db.WallConstructionsCompanion(
    id: Value(construction.id),
    name: Value(construction.name),
    rsi: Value(construction.rsi),
    rse: Value(construction.rse),
  );
}

$db.MaterialLayersCompanion _layerToCompanion(MaterialLayer layer) {
  return $db.MaterialLayersCompanion(
    id: Value(layer.id),
    constructionId: Value(layer.constructionId),
    sortOrder: Value(layer.sortOrder),
    materialId: Value(layer.materialId),
    thicknessMm: Value(layer.thicknessMm),
    thermalConductivity: Value(layer.thermalConductivity),
    density: Value(layer.density),
    specificHeat: Value(layer.specificHeat),
  );
}
