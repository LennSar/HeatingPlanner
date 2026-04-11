import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/building_dao.dart';
import 'daos/construction_dao.dart';
import 'daos/heating_dao.dart';
import 'daos/material_dao.dart';
import 'daos/project_dao.dart';
import 'tables/distributors_table.dart';
import 'tables/doors_table.dart';
import 'tables/flooring_materials_table.dart';
import 'tables/floors_table.dart';
import 'tables/heating_circuits_table.dart';
import 'tables/heating_zones_table.dart';
import 'tables/material_entries_table.dart';
import 'tables/material_layers_table.dart';
import 'tables/projects_table.dart';
import 'tables/rooms_table.dart';
import 'tables/tube_types_table.dart';
import 'tables/wall_constructions_table.dart';
import 'tables/wall_segments_table.dart';
import 'tables/windows_table.dart';

part 'app_database.g.dart';

/// Central Drift database for the HeatingPlanner application.
///
/// Schema version starts at 1. Increment and add a migration step in
/// [MigrationStrategy.onUpgrade] on every schema change.
@DriftDatabase(
  tables: [
    Projects,
    Floors,
    Rooms,
    WallSegments,
    Windows,
    Doors,
    WallConstructions,
    MaterialLayers,
    MaterialEntries,
    HeatingZones,
    TubeTypes,
    FlooringMaterials,
    Distributors,
    HeatingCircuits,
  ],
  daos: [
    ProjectDao,
    BuildingDao,
    ConstructionDao,
    MaterialDao,
    HeatingDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database at the default application-documents path.
  AppDatabase() : super(_openConnection());

  /// Constructor for testing — accepts a custom [QueryExecutor].
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await heatingDao.seedDefaults();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(
              heatingZones,
              heatingZones.wallSegmentId,
            );
            await m.addColumn(heatingZones, heatingZones.heightMm);
          }
          if (from < 3) {
            await m.addColumn(
              heatingZones,
              heatingZones.positionOnWallMm,
            );
            await m.addColumn(heatingZones, heatingZones.widthMm);
          }
          if (from < 4) {
            await m.addColumn(
              flooringMaterials,
              flooringMaterials.surfaceType,
            );
            await heatingDao.seedSurfaceTypeMigration();
          }
          if (from < 5) {
            await m.addColumn(
              heatingZones,
              heatingZones.customFlooringResistance,
            );
            await heatingDao.seedMaterialCorrectionsV5();
          }
          if (from < 6) {
            await m.addColumn(
              distributors,
              distributors.pumpCapacityPa,
            );
          }
          if (from < 7) {
            await m.addColumn(rooms, rooms.floorConstructionId);
            await m.addColumn(rooms, rooms.ceilingConstructionId);
            await m.addColumn(rooms, rooms.floorBoundary);
            await m.addColumn(rooms, rooms.ceilingBoundary);
            // These columns were renamed in schema v8; added here via
            // raw SQL so the Dart table class doesn't need them.
            await m.database.customStatement(
              'ALTER TABLE rooms ADD COLUMN '
              'floor_unheated_correction_factor REAL',
            );
            await m.database.customStatement(
              'ALTER TABLE rooms ADD COLUMN '
              'ceiling_unheated_correction_factor REAL',
            );
          }
          if (from < 8) {
            await m.database.customStatement(
              'ALTER TABLE rooms ADD COLUMN '
              'floor_adjacent_temp_c REAL',
            );
            await m.database.customStatement(
              'ALTER TABLE rooms ADD COLUMN '
              'ceiling_adjacent_temp_c REAL',
            );
          }
          if (from < 9) {
            await m.database.customStatement(
              'ALTER TABLE wall_constructions ADD COLUMN '
              'is_preset INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (from < 10) {
            await m.addColumn(projects, projects.floorHeightMm);
            await m.addColumn(projects, projects.unheatedSpaceTempC);
          }
          if (from < 11) {
            await m.database.customStatement(
              'ALTER TABLE distributors ADD COLUMN '
              'width_mm INTEGER NOT NULL DEFAULT 500',
            );
            await m.database.customStatement(
              'ALTER TABLE distributors ADD COLUMN '
              'rotation_deg INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (from < 12) {
            await m.database.customStatement(
              'ALTER TABLE material_layers ADD COLUMN '
              'stud_width_mm REAL',
            );
            await m.database.customStatement(
              'ALTER TABLE material_layers ADD COLUMN '
              'stud_clear_gap_mm REAL',
            );
            await m.database.customStatement(
              'ALTER TABLE material_layers ADD COLUMN '
              'stud_lambda REAL',
            );
          }
        },
      );
}

/// Opens a [NativeDatabase] at `<documents>/heating_planner.db`.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'heating_planner.db'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Provides the singleton [AppDatabase] instance.
///
/// Disposes the database connection when the provider is disposed.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
