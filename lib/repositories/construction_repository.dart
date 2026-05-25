import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart' as $db;
import '../data/database/daos/construction_dao.dart';
import '../data/models/material_layer.dart';
import '../data/models/wall_construction.dart';
import 'save_state_notifier.dart';

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
    nameDe: row.nameDe,
    rsi: row.rsi,
    rse: row.rse,
    isPreset: row.isPreset == 1,
    isAutoDefault: row.isAutoDefault == 1,
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
    studWidthMm: row.studWidthMm,
    studClearGapMm: row.studClearGapMm,
    studLambda: row.studLambda,
  );
}

// ── Model → Companion mapping ─────────────────────────────────────────────────

$db.WallConstructionsCompanion _constructionToCompanion(
  WallConstruction construction,
) {
  return $db.WallConstructionsCompanion(
    id: Value(construction.id),
    name: Value(construction.name),
    nameDe: Value(construction.nameDe),
    rsi: Value(construction.rsi),
    rse: Value(construction.rse),
    isPreset: Value(construction.isPreset ? 1 : 0),
    isAutoDefault: Value(construction.isAutoDefault ? 1 : 0),
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
    studWidthMm: Value(layer.studWidthMm),
    studClearGapMm: Value(layer.studClearGapMm),
    studLambda: Value(layer.studLambda),
  );
}

// ── Repository class ──────────────────────────────────────────────────────────

/// Class-based repository for construction and layer entities.
///
/// Mixes in [SaveStateMixin] so every successful write marks dirty.
class ConstructionRepository with SaveStateMixin {
  /// Creates a [ConstructionRepository] backed by [ref].
  ConstructionRepository(this.ref);

  @override
  final Ref ref;

  ConstructionDao get _dao => ref.read(constructionDaoProvider);

  /// Returns all [WallConstruction]s.
  Future<List<WallConstruction>> getAllConstructions() async {
    final rows = await _dao.getAllConstructions();
    return rows.map(_constructionFromRow).toList();
  }

  /// Returns all [MaterialLayer]s.
  Future<List<MaterialLayer>> getAllLayers() async {
    final rows = await _dao.getAllLayers();
    return rows.map(_layerFromRow).toList();
  }

  /// Inserts or replaces [construction] and marks dirty.
  Future<void> upsertConstruction(WallConstruction construction) async {
    await _dao.upsertConstruction(_constructionToCompanion(construction));
    markProjectDirty();
  }

  /// Deletes the construction with [id] and marks dirty.
  Future<void> deleteConstruction(String id) async {
    await _dao.deleteConstruction(id);
    markProjectDirty();
  }

  /// Inserts or replaces [layer] and marks dirty.
  Future<void> upsertLayer(MaterialLayer layer) async {
    await _dao.upsertLayer(_layerToCompanion(layer));
    markProjectDirty();
  }

  /// Deletes the layer with [id] and marks dirty.
  Future<void> deleteLayer(String id) async {
    await _dao.deleteLayer(id);
    markProjectDirty();
  }
}

/// Provides the singleton [ConstructionRepository].
final constructionRepositoryProvider = Provider<ConstructionRepository>(
  (ref) => ConstructionRepository(ref),
);
