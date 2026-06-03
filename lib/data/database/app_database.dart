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
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await heatingDao.seedDefaults();
        },
        onUpgrade: (m, from, to) async {
          // ADR-017 (v16) introduced the dev-stage drop-and-recreate
          // strategy; ADR-020 (v17) adds three material-default columns
          // on `projects` and an `is_auto_default` flag on
          // `wall_constructions`. Same dev-stage convention — wipe and
          // recreate. Project files (.hsp) re-import normally after
          // re-seeding because the new columns have safe defaults.
          if (from < 17) {
            await m.database.customStatement('PRAGMA foreign_keys = OFF');
            for (final table in allTables.toList().reversed) {
              await m.database.customStatement(
                'DROP TABLE IF EXISTS ${table.actualTableName}',
              );
            }
            await m.createAll();
            await heatingDao.seedDefaults();
            await m.database.customStatement('PRAGMA foreign_keys = ON');
            return;
          }
          // ADR-022 (v18): drop `category` + `subcategory` from
          // `material_entries` and add `category_path` carrying the
          // JSON-encoded path. Order is [category, subcategory]
          // (outside → inside).
          if (from < 18) {
            await m.database.customStatement(
              "ALTER TABLE material_entries "
              "ADD COLUMN category_path TEXT NOT NULL DEFAULT '[]'",
            );
            await m.database.customStatement(
              'UPDATE material_entries '
              'SET category_path = json_array(category, subcategory)',
            );
            await m.database.customStatement(
              'ALTER TABLE material_entries DROP COLUMN subcategory',
            );
            await m.database.customStatement(
              'ALTER TABLE material_entries DROP COLUMN category',
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
