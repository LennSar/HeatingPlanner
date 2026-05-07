// Tests for the per-DAO `localizedNameFor` helpers added in schema v15.
//
// Each helper takes a Drift row plus a `Locale` and returns
// `name_de` when the locale is German and the German translation is
// non-null, otherwise the canonical English `name`.

import 'dart:ui' show Locale;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;

const _en = Locale('en');
const _de = Locale('de');

void main() {
  late $db.AppDatabase db;

  setUp(() {
    db = $db.AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('MaterialDao.localizedNameFor', () {
    test('returns name_de for de-locale when set', () async {
      await db.into(db.materialEntries).insert(
            $db.MaterialEntriesCompanion.insert(
              id: 'm-translated',
              name: 'Solid brick',
              category: 'Masonry',
              lambdaDefault: 0.77,
              densityDefault: 1900,
              specificHeatDefault: 900,
              nameDe: const Value('Vollziegel'),
            ),
          );
        final row = await (db.select(db.materialEntries)
              ..where((t) => t.id.equals('m-translated')))
            .getSingle();
        expect(db.materialDao.localizedNameFor(row, _de), 'Vollziegel');
    });

    test(
      'falls back to name for de-locale when name_de is NULL',
      () async {
        await db.into(db.materialEntries).insert(
              $db.MaterialEntriesCompanion.insert(
                id: 'm-untranslated',
                name: 'User custom material',
                category: 'Masonry',
                lambdaDefault: 0.42,
                densityDefault: 800,
                specificHeatDefault: 900,
              ),
            );
        final row = await (db.select(db.materialEntries)
              ..where((t) => t.id.equals('m-untranslated')))
            .getSingle();
        expect(
          db.materialDao.localizedNameFor(row, _de),
          'User custom material',
        );
      },
    );

    test('returns canonical name for en-locale regardless of name_de',
        () async {
      await db.into(db.materialEntries).insert(
            $db.MaterialEntriesCompanion.insert(
              id: 'm-en',
              name: 'Solid brick',
              category: 'Masonry',
              lambdaDefault: 0.77,
              densityDefault: 1900,
              specificHeatDefault: 900,
              nameDe: const Value('Vollziegel'),
            ),
          );
      final row = await (db.select(db.materialEntries)
            ..where((t) => t.id.equals('m-en')))
          .getSingle();
      expect(db.materialDao.localizedNameFor(row, _en), 'Solid brick');
    });
  });

  group('ConstructionDao.localizedNameFor', () {
    test('translates de when name_de is set', () async {
      await db.into(db.wallConstructions).insert(
            $db.WallConstructionsCompanion.insert(
              id: 'wc-translated',
              name: 'Cavity wall',
              nameDe: const Value('Hohlwand'),
            ),
          );
      final row = await (db.select(db.wallConstructions)
            ..where((t) => t.id.equals('wc-translated')))
          .getSingle();
      expect(db.constructionDao.localizedNameFor(row, _de), 'Hohlwand');
      expect(db.constructionDao.localizedNameFor(row, _en), 'Cavity wall');
    });

    test('falls back to name for de when name_de is NULL', () async {
      await db.into(db.wallConstructions).insert(
            $db.WallConstructionsCompanion.insert(
              id: 'wc-untranslated',
              name: 'My custom wall',
            ),
          );
      final row = await (db.select(db.wallConstructions)
            ..where((t) => t.id.equals('wc-untranslated')))
          .getSingle();
      expect(
        db.constructionDao.localizedNameFor(row, _de),
        'My custom wall',
      );
    });
  });

  group('HeatingDao.localizedTubeTypeNameFor', () {
    test('returns canonical name when nameDe is NULL', () async {
      // Seeded tubes carry NULL name_de (pipe specs are universal).
      final tube = await (db.select(db.tubeTypes)
            ..where((t) => t.name.equals('PE-Xa 16×2')))
          .getSingle();
      expect(
        db.heatingDao.localizedTubeTypeNameFor(tube, _de),
        'PE-Xa 16×2',
      );
      expect(
        db.heatingDao.localizedTubeTypeNameFor(tube, _en),
        'PE-Xa 16×2',
      );
    });

    test('returns nameDe when set', () async {
      await db.into(db.tubeTypes).insert(
            $db.TubeTypesCompanion.insert(
              id: 'tt-translated',
              name: 'Translated tube',
              material: 'peXa',
              nameDe: const Value('Übersetztes Rohr'),
            ),
          );
      final tube = await (db.select(db.tubeTypes)
            ..where((t) => t.id.equals('tt-translated')))
          .getSingle();
      expect(
        db.heatingDao.localizedTubeTypeNameFor(tube, _de),
        'Übersetztes Rohr',
      );
      expect(
        db.heatingDao.localizedTubeTypeNameFor(tube, _en),
        'Translated tube',
      );
    });
  });

  group('HeatingDao.localizedFlooringMaterialNameFor', () {
    test('translates a seeded built-in flooring material', () async {
      // 'Ceramic tile' was translated to 'Keramikfliese' by
      // seedGermanNamesV15 during onCreate.
      final row = await (db.select(db.flooringMaterials)
            ..where((t) => t.name.equals('Ceramic tile')))
          .getSingle();
      expect(
        db.heatingDao.localizedFlooringMaterialNameFor(row, _de),
        'Keramikfliese',
      );
      expect(
        db.heatingDao.localizedFlooringMaterialNameFor(row, _en),
        'Ceramic tile',
      );
    });

    test('falls back to name for a user-created flooring material',
        () async {
      await db.into(db.flooringMaterials).insert(
            $db.FlooringMaterialsCompanion.insert(
              id: 'fm-user',
              name: 'Studio epoxy resin',
              thermalResistance: 0.005,
              surfaceType: const Value('floor'),
            ),
          );
      final row = await (db.select(db.flooringMaterials)
            ..where((t) => t.id.equals('fm-user')))
          .getSingle();
      expect(
        db.heatingDao.localizedFlooringMaterialNameFor(row, _de),
        'Studio epoxy resin',
      );
    });
  });
}
