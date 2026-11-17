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
  int get schemaVersion => 24;

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
          // ADR-036 (v19): add `is_heated` flag on `rooms`. Existing rooms
          // default to heated so prior projects are unchanged.
          if (from < 19) {
            await m.database.customStatement(
              'ALTER TABLE rooms '
              'ADD COLUMN is_heated INTEGER NOT NULL DEFAULT 1',
            );
          }
          // ADR-040 (v20): connection-pipe route and its three distances
          // on `heating_circuits`, plus the insulation type (ADR-008),
          // which was never persisted before. Existing circuits keep an
          // empty centerline (two separately drawn pipes).
          if (from < 20) {
            for (final column in const [
              'supply_pipe_insulation_type TEXT',
              "centerline_path_json TEXT NOT NULL DEFAULT '[]'",
              'pipe_spacing_mm INTEGER NOT NULL DEFAULT 100',
              'zone_clearance_mm INTEGER NOT NULL DEFAULT 100',
              'wall_clearance_mm INTEGER NOT NULL DEFAULT 100',
            ]) {
              await m.database.customStatement(
                'ALTER TABLE heating_circuits ADD COLUMN $column',
              );
            }
          }
          // ADR-041 (v21): which side of the route the supply pipe runs.
          if (from < 21) {
            await m.database.customStatement(
              'ALTER TABLE heating_circuits ADD COLUMN supply_on_right '
              'INTEGER NOT NULL DEFAULT 0 CHECK (supply_on_right IN (0, 1))',
            );
          }
          // ADR-043 (v22): layout patterns renamed to the four in common
          // use. `spiral` and the old `counterflow` are both the
          // counterflow spiral; `bifilar` is the double serpentine.
          if (from < 22) {
            await m.database.customStatement(
              "UPDATE heating_zones SET layout_pattern = 'counterflow' "
              "WHERE layout_pattern = 'spiral'",
            );
            await m.database.customStatement(
              "UPDATE heating_zones SET layout_pattern = 'doubleMeander' "
              "WHERE layout_pattern = 'bifilar'",
            );
          }
          // v24: project-level default tube types for floor and wall zones.
          // Guarded per column so the step is safe whatever order the
          // parallel ADR-044 (v23) work and this one reached a database in.
          if (from < 24) {
            final existing = {
              for (final r in await m.database
                  .customSelect('PRAGMA table_info(projects)')
                  .get())
                r.read<String>('name'),
            };
            for (final column in const [
              'default_floor_tube_type_id',
              'default_wall_tube_type_id',
            ]) {
              if (existing.contains(column)) continue;
              await m.database.customStatement(
                'ALTER TABLE projects ADD COLUMN $column TEXT NOT NULL '
                "DEFAULT '10000000-0000-4000-8000-000000000001'",
              );
            }
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
