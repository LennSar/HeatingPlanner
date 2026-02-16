import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/distributors_table.dart';
import '../tables/flooring_materials_table.dart';
import '../tables/heating_circuits_table.dart';
import '../tables/heating_zones_table.dart';
import '../tables/tube_types_table.dart';

part 'heating_dao.g.dart';

/// DAO for heating zones, tube types, flooring materials,
/// distributors, and heating circuits.
@DriftAccessor(
  tables: [
    HeatingZones,
    TubeTypes,
    FlooringMaterials,
    Distributors,
    HeatingCircuits,
  ],
)
class HeatingDao extends DatabaseAccessor<AppDatabase>
    with _$HeatingDaoMixin {
  /// Creates a [HeatingDao] bound to [db].
  HeatingDao(super.db);

  // ── HeatingZones ──────────────────────────────────────────────────────────

  /// All heating zones for [roomId].
  Stream<List<HeatingZone>> watchZones(String roomId) =>
      (select(heatingZones)..where((t) => t.roomId.equals(roomId))).watch();

  /// Inserts or replaces a heating-zone row.
  Future<void> upsertZone(HeatingZonesCompanion companion) =>
      into(heatingZones).insertOnConflictUpdate(companion);

  /// Deletes the heating zone with the given [id].
  Future<void> deleteZone(String id) =>
      (delete(heatingZones)..where((t) => t.id.equals(id))).go();

  // ── TubeTypes ─────────────────────────────────────────────────────────────

  /// All tube types ordered by name.
  Stream<List<TubeType>> watchTubeTypes() =>
      (select(tubeTypes)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  /// Inserts or replaces a tube-type row.
  Future<void> upsertTubeType(TubeTypesCompanion companion) =>
      into(tubeTypes).insertOnConflictUpdate(companion);

  // ── FlooringMaterials ─────────────────────────────────────────────────────

  /// All flooring materials ordered by name.
  Stream<List<FlooringMaterial>> watchFlooringMaterials() =>
      (select(flooringMaterials)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  /// Inserts or replaces a flooring-material row.
  Future<void> upsertFlooringMaterial(FlooringMaterialsCompanion companion) =>
      into(flooringMaterials).insertOnConflictUpdate(companion);

  // ── Distributors ──────────────────────────────────────────────────────────

  /// The distributor for [floorId], if one exists.
  Stream<Distributor?> watchDistributor(String floorId) =>
      (select(distributors)..where((t) => t.floorId.equals(floorId)))
          .watchSingleOrNull();

  /// Inserts or replaces a distributor row.
  Future<void> upsertDistributor(DistributorsCompanion companion) =>
      into(distributors).insertOnConflictUpdate(companion);

  /// Deletes the distributor with the given [id].
  Future<void> deleteDistributor(String id) =>
      (delete(distributors)..where((t) => t.id.equals(id))).go();

  // ── HeatingCircuits ───────────────────────────────────────────────────────

  /// All circuits for [distributorId].
  Stream<List<HeatingCircuit>> watchCircuits(String distributorId) =>
      (select(heatingCircuits)
            ..where((t) => t.distributorId.equals(distributorId)))
          .watch();

  /// Inserts or replaces a heating-circuit row.
  Future<void> upsertCircuit(HeatingCircuitsCompanion companion) =>
      into(heatingCircuits).insertOnConflictUpdate(companion);

  /// Deletes the heating circuit with the given [id].
  Future<void> deleteCircuit(String id) =>
      (delete(heatingCircuits)..where((t) => t.id.equals(id))).go();
}
