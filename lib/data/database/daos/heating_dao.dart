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

  // ── HeatingZones ──────────────────────────────────────────────────

  /// All heating zones for [roomId].
  Stream<List<HeatingZone>> watchZones(String roomId) =>
      (select(heatingZones)
            ..where((t) => t.roomId.equals(roomId)))
          .watch();

  /// Reactive stream for a single heating zone by [id].
  Stream<HeatingZone> watchZoneById(String id) =>
      (select(heatingZones)..where((t) => t.id.equals(id)))
          .watchSingle();

  /// Inserts or replaces a heating-zone row.
  Future<void> upsertZone(HeatingZonesCompanion companion) =>
      into(heatingZones).insertOnConflictUpdate(companion);

  /// Deletes the heating zone with the given [id].
  Future<void> deleteZone(String id) =>
      (delete(heatingZones)..where((t) => t.id.equals(id))).go();

  // ── TubeTypes ─────────────────────────────────────────────────────

  /// All tube types ordered by name.
  Stream<List<TubeType>> watchTubeTypes() =>
      (select(tubeTypes)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  /// Reactive stream for a single tube type by [id].
  Stream<TubeType> watchTubeTypeById(String id) =>
      (select(tubeTypes)..where((t) => t.id.equals(id)))
          .watchSingle();

  /// Inserts or replaces a tube-type row.
  Future<void> upsertTubeType(TubeTypesCompanion companion) =>
      into(tubeTypes).insertOnConflictUpdate(companion);

  /// Deletes the tube type with the given [id].
  Future<void> deleteTubeType(String id) =>
      (delete(tubeTypes)..where((t) => t.id.equals(id))).go();

  // ── FlooringMaterials ─────────────────────────────────────────────

  /// All flooring materials ordered by name.
  Stream<List<FlooringMaterial>> watchFlooringMaterials() =>
      (select(flooringMaterials)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  /// Reactive stream for a single flooring material by [id].
  Stream<FlooringMaterial> watchFlooringMaterialById(String id) =>
      (select(flooringMaterials)..where((t) => t.id.equals(id)))
          .watchSingle();

  /// Inserts or replaces a flooring-material row.
  Future<void> upsertFlooringMaterial(
    FlooringMaterialsCompanion companion,
  ) =>
      into(flooringMaterials).insertOnConflictUpdate(companion);

  /// Deletes the flooring material with the given [id].
  Future<void> deleteFlooringMaterial(String id) =>
      (delete(flooringMaterials)..where((t) => t.id.equals(id))).go();

  // ── Distributors ──────────────────────────────────────────────────

  /// The distributor for [floorId], if one exists.
  Stream<Distributor?> watchDistributor(String floorId) =>
      (select(distributors)
            ..where((t) => t.floorId.equals(floorId)))
          .watchSingleOrNull();

  /// Reactive stream for a single distributor by [id].
  Stream<Distributor> watchDistributorById(String id) =>
      (select(distributors)..where((t) => t.id.equals(id)))
          .watchSingle();

  /// Inserts or replaces a distributor row.
  Future<void> upsertDistributor(DistributorsCompanion companion) =>
      into(distributors).insertOnConflictUpdate(companion);

  /// Deletes the distributor with the given [id].
  Future<void> deleteDistributor(String id) =>
      (delete(distributors)..where((t) => t.id.equals(id))).go();

  // ── HeatingCircuits ───────────────────────────────────────────────

  /// All circuits for [distributorId].
  Stream<List<HeatingCircuit>> watchCircuits(String distributorId) =>
      (select(heatingCircuits)
            ..where((t) => t.distributorId.equals(distributorId)))
          .watch();

  /// Reactive stream for a single heating circuit by [id].
  Stream<HeatingCircuit> watchCircuitById(String id) =>
      (select(heatingCircuits)..where((t) => t.id.equals(id)))
          .watchSingle();

  /// Inserts or replaces a heating-circuit row.
  Future<void> upsertCircuit(HeatingCircuitsCompanion companion) =>
      into(heatingCircuits).insertOnConflictUpdate(companion);

  /// Deletes the heating circuit with the given [id].
  Future<void> deleteCircuit(String id) =>
      (delete(heatingCircuits)..where((t) => t.id.equals(id))).go();

  // ── Seed data ─────────────────────────────────────────────────────

  /// Seeds built-in [TubeType] and [FlooringMaterial] rows if none
  /// exist yet.
  ///
  /// This method is idempotent: calling it when rows are already
  /// present is a no-op.
  Future<void> seedDefaults() async {
    final existing = await (select(tubeTypes)..limit(1)).get();
    if (existing.isNotEmpty) return;

    // ── Default tube types ──────────────────────────────────────────
    const tubeRows = [
      (
        id: '10000000-0000-4000-8000-000000000001',
        name: 'PE-Xa 16\u00d72',
        material: 'peXa',
        outerDiameter: 16.0,
        innerDiameter: 12.0,
        wallThickness: 2.0,
        lambda: 0.38,
      ),
      (
        id: '10000000-0000-4000-8000-000000000002',
        name: 'PE-Xa 20\u00d72',
        material: 'peXa',
        outerDiameter: 20.0,
        innerDiameter: 16.0,
        wallThickness: 2.0,
        lambda: 0.38,
      ),
      (
        id: '10000000-0000-4000-8000-000000000004',
        name: 'PE-Xa 17\u00d72',
        material: 'peXa',
        outerDiameter: 17.0,
        innerDiameter: 13.0,
        wallThickness: 2.0,
        lambda: 0.38,
      ),
      (
        id: '10000000-0000-4000-8000-000000000003',
        name: 'PE-RT 16\u00d72',
        material: 'peRt',
        outerDiameter: 16.0,
        innerDiameter: 12.0,
        wallThickness: 2.0,
        lambda: 0.35,
      ),
    ];

    for (final r in tubeRows) {
      await upsertTubeType(
        TubeTypesCompanion.insert(
          id: r.id,
          name: r.name,
          material: r.material,
          outerDiameterMm: Value(r.outerDiameter),
          innerDiameterMm: Value(r.innerDiameter),
          wallThicknessMm: Value(r.wallThickness),
          thermalConductivity: Value(r.lambda),
        ),
      );
    }

    // ── Default flooring materials ──────────────────────────────────
    const flooringRows = [
      (
        id: '20000000-0000-4000-8000-000000000001',
        name: 'Ceramic tile',
        r: 0.01,
      ),
      (
        id: '20000000-0000-4000-8000-000000000002',
        name: 'Parquet',
        r: 0.10,
      ),
      (
        id: '20000000-0000-4000-8000-000000000003',
        name: 'Laminate',
        r: 0.07,
      ),
      (
        id: '20000000-0000-4000-8000-000000000004',
        name: 'Carpet',
        r: 0.15,
      ),
      (
        id: '20000000-0000-4000-8000-000000000005',
        name: 'Vinyl',
        r: 0.01,
      ),
    ];

    for (final r in flooringRows) {
      await upsertFlooringMaterial(
        FlooringMaterialsCompanion.insert(
          id: r.id,
          name: r.name,
          thermalResistance: r.r,
        ),
      );
    }
  }
}
