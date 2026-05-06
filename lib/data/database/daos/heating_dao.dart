import 'dart:ui' show Locale;

import 'package:drift/drift.dart';

import '../../models/flooring_material.dart' show kCustomFlooringMaterialId;
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

  /// All heating zones for any of [roomIds] — one-shot fetch.
  Future<List<HeatingZone>> getZonesForRooms(List<String> roomIds) {
    if (roomIds.isEmpty) return Future.value([]);
    return (select(heatingZones)
          ..where((t) => t.roomId.isIn(roomIds)))
        .get();
  }

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

  /// The distributor for [floorId], or null — one-shot fetch.
  Future<Distributor?> getDistributorForFloor(String floorId) =>
      (select(distributors)..where((t) => t.floorId.equals(floorId)))
          .getSingleOrNull();

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

  /// All circuits for [distributorId] — one-shot fetch.
  Future<List<HeatingCircuit>> getCircuitsForDistributor(
    String distributorId,
  ) =>
      (select(heatingCircuits)
            ..where((t) => t.distributorId.equals(distributorId)))
          .get();

  /// Inserts or replaces a heating-circuit row.
  Future<void> upsertCircuit(HeatingCircuitsCompanion companion) =>
      into(heatingCircuits).insertOnConflictUpdate(companion);

  /// Deletes the heating circuit with the given [id].
  Future<void> deleteCircuit(String id) =>
      (delete(heatingCircuits)..where((t) => t.id.equals(id))).go();

  // ── Localized name helpers ────────────────────────────────────────

  /// Returns the locale-appropriate display name for the tube-type [row].
  ///
  /// Falls back to the canonical English [TubeType.name] when the
  /// requested locale is German but no German translation has been set.
  String localizedTubeTypeNameFor(TubeType row, Locale locale) =>
      locale.languageCode == 'de' ? (row.nameDe ?? row.name) : row.name;

  /// Returns the locale-appropriate display name for the
  /// flooring-material [row].
  ///
  /// Falls back to the canonical English [FlooringMaterial.name] when
  /// the requested locale is German but no German translation has been set.
  String localizedFlooringMaterialNameFor(
    FlooringMaterial row,
    Locale locale,
  ) =>
      locale.languageCode == 'de' ? (row.nameDe ?? row.name) : row.name;

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

    await _upsertAllSurfaceMaterials();
    await seedGermanNamesV15();
  }

  // ── Seed helpers ───────────────────────────────────────────────────────────

  /// Upserts every built-in surface material with correct R values.
  ///
  /// Uses [insertOnConflictUpdate], so calling this when rows already
  /// exist corrects their values — safe to call from any migration.
  ///
  /// R values are traceable per EN 1264-2 §6 (floor) and EN 15377 §6
  /// (wall). Format of inline comments: d=thickness, λ=conductivity,
  /// R=d/λ or standard reference value.
  Future<void> _upsertAllSurfaceMaterials() async {
    // ── Floor and shared coverings ────────────────────────────────────
    const floorRows = [
      (
        // d=10 mm, λ=1.00 W/mK (EN ISO 10456, ceramic) → R=0.010 m²K/W
        id: '20000000-0000-4000-8000-000000000001',
        name: 'Ceramic tile',
        r: 0.010,
        surfaceType: 'both',
      ),
      (
        // d=18 mm solid oak, λ=0.18 W/mK (EN ISO 10456) → R=0.100 m²K/W
        id: '20000000-0000-4000-8000-000000000002',
        name: 'Parquet (oak)',
        r: 0.100,
        surfaceType: 'floor',
      ),
      (
        // d=8 mm board only (no underlay), λ=0.12 W/mK → R=0.067 m²K/W
        id: '20000000-0000-4000-8000-000000000003',
        name: 'Laminate',
        r: 0.067,
        surfaceType: 'floor',
      ),
      (
        // Combined carpet + foam underlay; EN 1264-2 Annex B typical
        // value of 0.15 m²K/W — at the recommended upper limit.
        id: '20000000-0000-4000-8000-000000000004',
        name: 'Carpet + underlay',
        r: 0.150,
        surfaceType: 'floor',
      ),
      (
        // d=2 mm sheet vinyl, λ=0.17 W/mK (EN ISO 10456, PVC)
        // → R=0.012 m²K/W
        id: '20000000-0000-4000-8000-000000000005',
        name: 'Vinyl sheet',
        r: 0.012,
        surfaceType: 'floor',
      ),
      (
        // d=4 mm rigid-core LVT, λ=0.17 W/mK (manufacturer data)
        // → R=0.024 m²K/W; product class rated for underfloor heating.
        id: '20000000-0000-4000-8000-000000000006',
        name: 'LVT (Luxury Vinyl Tile)',
        r: 0.024,
        surfaceType: 'floor',
      ),
      (
        // d=10 mm expanded cork, λ=0.065 W/mK (EN ISO 10456)
        // → R=0.154 m²K/W; at EN 1264-2 upper limit — pair with
        // elevated supply temperature.
        id: '20000000-0000-4000-8000-000000000007',
        name: 'Cork tiles',
        r: 0.154,
        surfaceType: 'floor',
      ),
      (
        // d=3 mm cement-mineral finish, λ=0.75 W/mK → R=0.004 m²K/W;
        // excellent thermal contact for floor and wall heating.
        id: '20000000-0000-4000-8000-000000000008',
        name: 'Micro cement',
        r: 0.004,
        surfaceType: 'both',
      ),
    ];

    // ── Wall and shared coverings ─────────────────────────────────────
    const wallRows = [
      (
        // d=10 mm finish coat, λ=0.35 W/mK (EN ISO 10456, gypsum
        // plaster) → R=0.029 m²K/W
        id: '20000000-0000-4000-8000-000000000010',
        name: 'Gypsum plaster',
        r: 0.029,
        surfaceType: 'wall',
      ),
      (
        // d=15 mm, λ=0.70 W/mK (EN ISO 10456, lime plaster)
        // → R=0.021 m²K/W
        id: '20000000-0000-4000-8000-000000000011',
        name: 'Lime plaster',
        r: 0.021,
        surfaceType: 'wall',
      ),
      (
        // d=15 mm, λ=0.60 W/mK (typical clay-based plaster)
        // → R=0.025 m²K/W
        id: '20000000-0000-4000-8000-000000000012',
        name: 'Clay plaster',
        r: 0.025,
        surfaceType: 'wall',
      ),
      (
        // d=12.5 mm standard board, λ=0.21 W/mK (EN ISO 10456)
        // → R=0.060 m²K/W
        id: '20000000-0000-4000-8000-000000000013',
        name: 'Gypsum board',
        r: 0.060,
        surfaceType: 'wall',
      ),
      (
        // d=15 mm slab, λ=2.00 W/mK (EN ISO 10456, limestone)
        // → R=0.008 m²K/W; applies to marble, granite, limestone.
        id: '20000000-0000-4000-8000-000000000014',
        name: 'Natural stone',
        r: 0.008,
        surfaceType: 'both',
      ),
      (
        // d=15 mm softwood boards, λ=0.13 W/mK (EN ISO 10456)
        // → R=0.115 m²K/W; within EN 15377 max of ~0.15 m²K/W.
        id: '20000000-0000-4000-8000-000000000015',
        name: 'Wood paneling',
        r: 0.115,
        surfaceType: 'wall',
      ),
    ];

    for (final row in [...floorRows, ...wallRows]) {
      await upsertFlooringMaterial(
        FlooringMaterialsCompanion.insert(
          id: row.id,
          name: row.name,
          thermalResistance: row.r,
          surfaceType: Value(row.surfaceType),
        ),
      );
    }

    // ── Custom R-value sentinel ───────────────────────────────────────
    // Placeholder row required by the FK constraint on heating_zones.
    // The actual resistance is stored in HeatingZone.customFlooringResistance.
    await upsertFlooringMaterial(
      FlooringMaterialsCompanion.insert(
        id: kCustomFlooringMaterialId,
        name: 'Custom',
        thermalResistance: 0.0,
        surfaceType: const Value('both'),
      ),
    );
  }

  // ── Migration helpers ──────────────────────────────────────────────────────

  /// Seeds schema-v4 migration: adds wall surface materials and
  /// corrects the [SurfaceType] of ceramic tile.
  ///
  /// Called from [AppDatabase.onUpgrade] for schema v3 → v4.
  Future<void> seedSurfaceTypeMigration() async {
    await _upsertAllSurfaceMaterials();
  }

  /// Corrects R values that were inaccurate in schema v4, renames
  /// materials for clarity, and seeds new materials added in v5.
  ///
  /// Called from [AppDatabase.onUpgrade] for schema v4 → v5.
  ///
  /// Corrections (all traceable per EN ISO 10456 / EN 1264-2 /
  /// EN 15377):
  /// - Gypsum plaster 0.020 → 0.029 (d=10 mm, λ=0.35)
  /// - Gypsum board   0.040 → 0.060 (d=12.5 mm, λ=0.21)
  /// - Clay plaster   0.030 → 0.025 (d=15 mm, λ=0.60)
  /// - Lime plaster   0.020 → 0.021 (d=15 mm, λ=0.70)
  /// - Natural stone  0.010 → 0.008 (d=15 mm, λ=2.00)
  /// - Laminate       0.070 → 0.067 (d=8 mm, λ=0.12)
  /// - Vinyl sheet    0.010 → 0.012 (d=2 mm, λ=0.17)
  ///
  /// New materials: LVT, Cork tiles, Micro cement, Wood paneling,
  /// Custom sentinel.
  Future<void> seedMaterialCorrectionsV5() async {
    await _upsertAllSurfaceMaterials();
  }

  /// Populates `name_de` for built-in catalog rows seeded with English
  /// canonical names.
  ///
  /// Called from [AppDatabase.onUpgrade] for schema v14 → v15 and from
  /// the seed entry points ([seedDefaults] and
  /// [MaterialRepository.ensureMaterialsSeeded]) so that both fresh
  /// installs and migrating users get the same German catalog terms.
  ///
  /// Each UPDATE matches by canonical English `name`, never by id —
  /// ids may differ across user databases that imported `.hsp` files
  /// or were seeded by older builds. User-created rows whose names do
  /// not appear in the lists below are left untouched.
  ///
  /// Translations follow established DIN 4108 / EN 1264 / EN 15377
  /// terminology. Brand-name products (Rockwool, STEICO, Wienerberger,
  /// etc.) are intentionally NOT translated — the brand name is
  /// identical in both locales and the JSON catalog already uses the
  /// German-market spelling.
  Future<void> seedGermanNamesV15() async {
    // ── flooring_materials (seeded by HeatingDao.seedDefaults) ──────
    const flooringTranslations = <String, String>{
      'Ceramic tile': 'Keramikfliese',
      'Parquet (oak)': 'Parkett (Eiche)',
      'Laminate': 'Laminat',
      'Carpet + underlay': 'Teppich mit Trittschalldämmung',
      'Vinyl sheet': 'Vinyl-Bahnware',
      'LVT (Luxury Vinyl Tile)': 'Designvinyl (LVT)',
      'Cork tiles': 'Korkfliesen',
      'Micro cement': 'Mikrozement',
      'Gypsum plaster': 'Gipsputz',
      'Lime plaster': 'Kalkputz',
      'Clay plaster': 'Lehmputz',
      'Gypsum board': 'Gipskarton',
      'Natural stone': 'Naturstein',
      'Wood paneling': 'Holzvertäfelung',
      'Custom': 'Benutzerdefiniert',
    };
    for (final entry in flooringTranslations.entries) {
      await customStatement(
        'UPDATE flooring_materials SET name_de = ? WHERE name = ?',
        <Object?>[entry.value, entry.key],
      );
    }

    // ── material_entries (seeded from assets/materials.json) ───────
    //
    // Translations are limited to DIN 4108 / EN 1264 generic terms.
    // Manufacturer-branded entries (Poroton, Ytong, Rockwool, STEICO,
    // Knauf, Isover, Celotex, Kingspan, isofloc, Homatherm, Climacell,
    // Calsitherm, Multipor, Foamglas, Neopor) are intentionally
    // omitted because the brand spelling is identical in German.
    const materialTranslations = <String, String>{
      // Historic brick (AMz-Bericht 8/2005 / DIN 4108 1952–1981)
      'Solid brick (pre-1952, ρ≥1900)': 'Vollziegel (vor 1952, ρ≥1900)',
      'Solid brick (1952–1968, ρ=1800)':
          'Vollziegel (1952–1968, ρ=1800)',
      'Hollow brick (1969, ρ=1000)': 'Hochlochziegel (1969, ρ=1000)',
      'Hollow brick (1969, ρ=1200)': 'Hochlochziegel (1969, ρ=1200)',
      'Hollow brick (1969, ρ=1400)': 'Hochlochziegel (1969, ρ=1400)',
      'Solid brick (post-1981, ρ=1800)':
          'Vollziegel (nach 1981, ρ=1800)',
      'Solid brick (post-1981, ρ=2000)':
          'Vollziegel (nach 1981, ρ=2000)',
      'Clinker brick (ρ=2200)': 'Klinkerziegel (ρ=2200)',
      'Hollow brick HLz A+B (ρ=700, normal mortar)':
          'Hochlochziegel HLz A+B (ρ=700, Normalmörtel)',
      'Hollow brick HLz A+B (ρ=700, lightweight mortar)':
          'Hochlochziegel HLz A+B (ρ=700, Leichtmörtel)',
      'Hollow brick HLz A+B (ρ=900)': 'Hochlochziegel HLz A+B (ρ=900)',
      'Hollow brick HLz A+B (ρ=1000)':
          'Hochlochziegel HLz A+B (ρ=1000)',
      'Hollow brick (post-1981, ρ=1200)':
          'Hochlochziegel (nach 1981, ρ=1200)',
      'Hollow brick (post-1981, ρ=1400)':
          'Hochlochziegel (nach 1981, ρ=1400)',
      'Hollow brick (post-1981, ρ=1600)':
          'Hochlochziegel (nach 1981, ρ=1600)',
      // Calcium silicate (DIN 4108-4)
      'Calcium silicate (ρ=1200)': 'Kalksandstein (ρ=1200)',
      'Calcium silicate (ρ=1400)': 'Kalksandstein (ρ=1400)',
      'Calcium silicate (ρ=1600)': 'Kalksandstein (ρ=1600)',
      'Calcium silicate (ρ=1800)': 'Kalksandstein (ρ=1800)',
      'Calcium silicate (ρ=2000)': 'Kalksandstein (ρ=2000)',
      // AAC / Aerated concrete (Porenbeton, DIN 4108-4)
      'AAC block (ρ=500)': 'Porenbeton (ρ=500)',
      'AAC block (ρ=600)': 'Porenbeton (ρ=600)',
      'AAC block (ρ=700)': 'Porenbeton (ρ=700)',
      // Concrete & screed (DIN 4108-4)
      'Normal concrete (ρ=2300)': 'Normalbeton (ρ=2300)',
      'Reinforced concrete (1% steel)': 'Stahlbeton (1 % Bewehrung)',
      'Reinforced concrete (2% steel)': 'Stahlbeton (2 % Bewehrung)',
      'Lightweight concrete (ρ=800)': 'Leichtbeton (ρ=800)',
      'Lightweight concrete (ρ=1000)': 'Leichtbeton (ρ=1000)',
      'Lightweight concrete (ρ=1200)': 'Leichtbeton (ρ=1200)',
      'Lightweight concrete (ρ=1400)': 'Leichtbeton (ρ=1400)',
      'Lightweight concrete (ρ=1600)': 'Leichtbeton (ρ=1600)',
      'Cement screed': 'Zementestrich',
      'Calcium sulfate screed': 'Calciumsulfatestrich',
      'Mastic asphalt screed': 'Gussasphaltestrich',
      // EPS / PUR / generic mineral wool (DIN 4108-4)
      'EPS white WLG 040': 'EPS weiß WLG 040',
      'EPS white WLG 035': 'EPS weiß WLG 035',
      'EPS white WLG 032': 'EPS weiß WLG 032',
      'EPS grey (graphite) WLG 032': 'EPS grau (Graphit) WLG 032',
      'EPS grey (graphite) WLG 031': 'EPS grau (Graphit) WLG 031',
      'PUR/PIR generic WLG 025': 'PUR/PIR generisch WLG 025',
      'PUR/PIR generic WLG 023': 'PUR/PIR generisch WLG 023',
      'Stone wool generic WLG 038': 'Steinwolle generisch WLG 038',
      'Stone wool generic WLG 035': 'Steinwolle generisch WLG 035',
      'Glass wool generic WLG 040': 'Glaswolle generisch WLG 040',
      'Glass wool generic WLG 035': 'Glaswolle generisch WLG 035',
      'Cork insulation board': 'Korkdämmplatte',
      // Loose fill / blow-in
      'Cellulose generic': 'Zellulose generisch',
      'Perlite (loose fill)': 'Perlit (Schüttdämmung)',
      'Vermiculite (loose fill)': 'Vermiculit (Schüttdämmung)',
      'Hemp insulation (loose fill)': 'Hanfdämmung (Schüttdämmung)',
      "Sheep's wool insulation": 'Schafwolldämmung',
      'Straw bale': 'Strohballen',
      // Wood (DIN 4108-4)
      'Softwood (spruce/pine)': 'Nadelholz (Fichte/Kiefer)',
      'Hardwood (oak)': 'Laubholz (Eiche)',
      'Hardwood (beech)': 'Laubholz (Buche)',
      'Plywood': 'Sperrholz',
      'OSB': 'OSB-Platte',
      'Chipboard / particle board': 'Spanplatte',
      'MDF': 'MDF-Platte',
      'CLT (cross-laminated timber)': 'Brettsperrholz (BSP)',
      // Plaster & mortar (DIN 4108-4)
      'Cement render': 'Zementputz',
      'Lime-cement plaster': 'Kalkzementputz',
      'Thermal insulation plaster': 'Wärmedämmputz',
      'Lightweight plaster': 'Leichtputz',
      // Board materials
      'Gypsum plasterboard (12.5mm)': 'Gipskartonplatte (12,5 mm)',
      // Floor coverings (DIN 4108-4)
      'Granite': 'Granit',
      'Marble': 'Marmor',
      'Limestone': 'Kalkstein',
      'Sandstone': 'Sandstein',
      'Laminate flooring': 'Laminatboden',
      'Carpet': 'Teppich',
      'Vinyl / PVC flooring': 'Vinyl-/PVC-Bodenbelag',
      'Linoleum': 'Linoleum',
      // Glass
      'Float glass': 'Floatglas',
    };
    for (final entry in materialTranslations.entries) {
      await customStatement(
        'UPDATE material_entries SET name_de = ? WHERE name = ?',
        <Object?>[entry.value, entry.key],
      );
    }
  }
}
