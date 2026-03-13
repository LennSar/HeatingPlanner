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
  int get schemaVersion => 4;

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
