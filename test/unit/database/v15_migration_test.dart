// Tests for the v14 → v15 schema migration that introduced the
// `name_de` columns and the `seedGermanNamesV15` helper.
//
// The fresh in-memory database created by [AppDatabase.forTesting]
// runs through `onCreate`, which executes the same `seedDefaults` →
// `seedGermanNamesV15` chain that v14 → v15 upgrades execute, so we
// can validate both the column-creation half and the
// row-population half from a single test surface.

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;

void main() {
  group('v15 migration', () {
    late $db.AppDatabase db;

    setUp(() {
      db = $db.AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'name_de columns exist on every catalog table',
      () async {
        // PRAGMA table_info returns one row per column with `name`
        // among other fields. We assert each affected catalog table
        // exposes the `name_de` column added in schema v15.
        const tables = [
          'material_entries',
          'flooring_materials',
          'tube_types',
          'wall_constructions',
        ];
        for (final table in tables) {
          final cols = await db
              .customSelect('PRAGMA table_info($table)')
              .get();
          final names = cols.map((r) => r.read<String>('name')).toSet();
          expect(
            names,
            contains('name_de'),
            reason: '$table is missing the v15 name_de column',
          );
        }
      },
    );

    test(
      'seedGermanNamesV15 populates name_de for known built-in defaults '
      'matched by canonical English name',
      () async {
        // seedDefaults → seedGermanNamesV15 already ran in onCreate.
        // Spot-check a representative selection of the flooring rows
        // that ship with the app.
        final flooring = await db.select(db.flooringMaterials).get();
        Map<String, String?> deByName = {
          for (final row in flooring) row.name: row.nameDe,
        };

        expect(deByName['Ceramic tile'], equals('Keramikfliese'));
        expect(deByName['Parquet (oak)'], equals('Parkett (Eiche)'));
        expect(deByName['Laminate'], equals('Laminat'));
        expect(deByName['Custom'], equals('Benutzerdefiniert'));
        expect(deByName['Gypsum board'], equals('Gipskarton'));
        expect(deByName['Natural stone'], equals('Naturstein'));
      },
    );

    test(
      'seedGermanNamesV15 leaves user-created rows untouched',
      () async {
        // Insert a row with a name that isn't in the translation map.
        await db.into(db.flooringMaterials).insert(
              $db.FlooringMaterialsCompanion.insert(
                id: 'user-flooring-1',
                name: 'Bespoke poured terrazzo (custom)',
                thermalResistance: 0.020,
                surfaceType: const Value('floor'),
              ),
            );

        // Re-running the helper after the user row exists must not
        // touch it — the matching is keyed on canonical English name
        // and only the seeded names appear in the translation map.
        await db.heatingDao.seedGermanNamesV15();

        final user = await (db.select(db.flooringMaterials)
              ..where((t) => t.id.equals('user-flooring-1')))
            .getSingle();
        expect(user.nameDe, isNull);
      },
    );

    test(
      'seedGermanNamesV15 matches by name, not by id, so rows imported '
      'from .hsp under a different id still get translated',
      () async {
        // Simulate an .hsp import where a built-in flooring material
        // landed in the user database under a fresh UUID rather than
        // the seeded id.
        await db.customStatement(
          'UPDATE flooring_materials SET name_de = NULL '
          "WHERE name = 'Ceramic tile'",
        );
        await db.into(db.flooringMaterials).insert(
              $db.FlooringMaterialsCompanion.insert(
                id: 'imported-uuid-not-seeded',
                name: 'Ceramic tile',
                thermalResistance: 0.010,
                surfaceType: const Value('both'),
              ),
              mode: InsertMode.insertOrReplace,
            );

        await db.heatingDao.seedGermanNamesV15();

        // Both the seeded row (whose nameDe we cleared) and the
        // imported row should now carry the German term.
        final tiles = await (db.select(db.flooringMaterials)
              ..where((t) => t.name.equals('Ceramic tile')))
            .get();
        expect(tiles, isNotEmpty);
        for (final row in tiles) {
          expect(row.nameDe, equals('Keramikfliese'));
        }
      },
    );

    test(
      'tube_types name_de stays NULL — pipe specs are universal '
      'and the helper intentionally skips them',
      () async {
        final tubes = await db.select(db.tubeTypes).get();
        expect(tubes, isNotEmpty);
        for (final row in tubes) {
          expect(
            row.nameDe,
            isNull,
            reason: 'Pipe-spec naming is identical in both locales; '
                'the helper should not assign a redundant German '
                'translation.',
          );
        }
      },
    );
  });
}
