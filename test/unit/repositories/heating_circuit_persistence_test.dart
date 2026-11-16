// A heating circuit survives a round trip through the database with its
// route, its three connection-pipe distances (ADR-040) and its insulation
// type (ADR-008 — never persisted before schema v20).

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/repositories/heating_repository.dart';

void main() {
  upgradeTests();

  late $db.AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = $db.AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [heatingDaoProvider.overrideWithValue(db.heatingDao)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('schema v22: heating_circuits has the ADR-040/041 columns', () async {
    expect(db.schemaVersion, 22);
    final cols = await db
        .customSelect('PRAGMA table_info(heating_circuits)')
        .get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>[
        'supply_pipe_insulation_type',
        'centerline_path_json',
        'pipe_spacing_mm',
        'zone_clearance_mm',
        'wall_clearance_mm',
        'supply_on_right',
      ]),
    );
  });

  test(
    'route, distances and insulation type are written and read back',
    () async {
      const circuit = HeatingCircuit(
        id: 'circuit-1',
        distributorId: 'dist-1',
        heatingZoneId: 'zone-1',
        centerlinePath: [
          Point2D(x: 500, y: 500),
          Point2D(x: 2000, y: 500),
          Point2D(x: 2000, y: 2000),
        ],
        supplyRoutePath: [
          Point2D(x: 500, y: 500),
          Point2D(x: 500, y: 560),
          Point2D(x: 1940, y: 560),
          Point2D(x: 1940, y: 2000),
        ],
        returnRoutePath: [
          Point2D(x: 2060, y: 2000),
          Point2D(x: 2060, y: 440),
          Point2D(x: 500, y: 440),
          Point2D(x: 500, y: 500),
        ],
        pipeSpacingMm: 120,
        zoneClearanceMm: 180,
        wallClearanceMm: 60,
        supplyPipeInsulationType: SupplyPipeInsulationType.insulationLayer,
        supplyOnRight: true,
      );

      await upsertHeatingCircuit(db.heatingDao, circuit);
      final restored =
          (await container
                  .read(heatingRepositoryProvider)
                  .getCircuitsForDistributor('dist-1'))
              .single;

      expect(restored, circuit);
    },
  );

  test('a circuit with no insulation choice stays without one', () async {
    const circuit = HeatingCircuit(
      id: 'circuit-2',
      distributorId: 'dist-1',
      heatingZoneId: 'zone-1',
    );
    await upsertHeatingCircuit(db.heatingDao, circuit);
    final restored =
        (await container
                .read(heatingRepositoryProvider)
                .getCircuitsForDistributor('dist-1'))
            .single;

    expect(restored.supplyPipeInsulationType, isNull);
    expect(restored.centerlinePath, isEmpty);
    expect(restored.pipeSpacingMm, 100);
  });
}

// ── Upgrade of an existing database ──────────────────────────────────────────

/// `heating_circuits` exactly as schema v19 created it.
const _v19HeatingCircuits = '''
CREATE TABLE heating_circuits (
  id TEXT NOT NULL,
  distributor_id TEXT NOT NULL,
  heating_zone_id TEXT NOT NULL,
  supply_route_path_json TEXT NOT NULL DEFAULT '[]',
  return_route_path_json TEXT NOT NULL DEFAULT '[]',
  tube_length_m REAL NOT NULL DEFAULT 0.0,
  flow_rate_kg_h REAL NOT NULL DEFAULT 0.0,
  pressure_loss_pa REAL NOT NULL DEFAULT 0.0,
  valve_setting REAL NOT NULL DEFAULT 0.0,
  PRIMARY KEY (id)
)''';

void upgradeTests() {
  test('a v19 database upgrades to v22 and keeps its circuits', () async {
    final db = $db.AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(_v19HeatingCircuits)
            ..execute(
              'INSERT INTO heating_circuits '
              '(id, distributor_id, heating_zone_id, '
              'supply_route_path_json) VALUES '
              "('old', 'dist-1', 'zone-1', "
              '\'[{"x":0.0,"y":0.0},{"x":1000.0,"y":0.0}]\')',
            )
            // Only the columns the v22 rename touches.
            ..execute(
              'CREATE TABLE heating_zones '
              '(id TEXT NOT NULL PRIMARY KEY, layout_pattern TEXT NOT NULL)',
            )
            ..execute(
              'INSERT INTO heating_zones (id, layout_pattern) VALUES '
              "('z-spiral', 'spiral'), ('z-bifilar', 'bifilar'), "
              "('z-counterflow', 'counterflow'), ('z-meander', 'meander')",
            )
            ..execute('PRAGMA user_version = 19');
        },
      ),
    );
    addTearDown(db.close);

    final rows = await db.select(db.heatingCircuits).get();

    final row = rows.single;
    expect(row.id, 'old');
    expect(row.supplyRoutePathJson, contains('1000.0'));
    // New columns arrive with their defaults.
    expect(row.centerlinePathJson, '[]');
    expect(row.pipeSpacingMm, 100);
    expect(row.zoneClearanceMm, 100);
    expect(row.wallClearanceMm, 100);
    expect(row.supplyPipeInsulationType, isNull);
    expect(row.supplyOnRight, isFalse);

    // ADR-043 (v22): layout patterns renamed to the four in common use.
    final zones = await db
        .customSelect('SELECT id, layout_pattern FROM heating_zones')
        .get();
    final patterns = {
      for (final r in zones)
        r.read<String>('id'): r.read<String>('layout_pattern'),
    };
    expect(patterns, {
      'z-spiral': 'counterflow',
      'z-bifilar': 'doubleMeander',
      'z-counterflow': 'counterflow',
      'z-meander': 'meander',
    });
  });
}
