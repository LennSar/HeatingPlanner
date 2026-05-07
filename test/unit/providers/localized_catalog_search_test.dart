// Tests for the localized catalog providers' search and sort behavior.
//
// Cross-locale search is the headline guarantee: a query typed in
// English must find a row whose German name matches (and vice versa)
// even when the active UI locale is the other language. Sorting must
// follow the active locale's display name.
//
// These tests override the canonical Stream providers
// (`materialEntriesProvider`, `tubeTypesProvider`,
// `flooringMaterialsProvider`) so the localized variants resolve from
// in-test data without touching Drift.

import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/flooring_material.dart';
import 'package:heating_planner/data/models/localized_catalog_row.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/data/models/tube_type.dart';
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:heating_planner/repositories/heating_repository.dart';
import 'package:heating_planner/repositories/material_repository.dart';

ProviderContainer _container({
  required Locale locale,
  List<MaterialEntry> materials = const [],
  List<TubeType> tubes = const [],
  List<FlooringMaterial> flooring = const [],
}) {
  return ProviderContainer(
    overrides: [
      currentLocaleProvider.overrideWithValue(locale),
      materialEntriesProvider
          .overrideWith((ref) => Stream.value(materials)),
      tubeTypesProvider.overrideWith((ref) => Stream.value(tubes)),
      flooringMaterialsProvider
          .overrideWith((ref) => Stream.value(flooring)),
    ],
  );
}

/// Reads the localized provider after the canonical stream has
/// emitted at least once.
///
/// Riverpod's StreamProvider only stays subscribed while a listener
/// exists; reading `.future` without an active subscription races the
/// auto-dispose. Listening here keeps the subscription alive so the
/// `Stream.value(...)` override has time to deliver, then the derived
/// Provider can be read synchronously.
Future<List<LocalizedCatalogRow<MaterialEntry>>> _readMaterials(
  ProviderContainer c,
) async {
  final sub = c.listen(materialEntriesProvider, (_, __) {});
  try {
    await c.read(materialEntriesProvider.future);
    return c.read(localizedMaterialEntriesProvider);
  } finally {
    sub.close();
  }
}

Future<List<LocalizedCatalogRow<TubeType>>> _readTubes(
  ProviderContainer c,
) async {
  final sub = c.listen(tubeTypesProvider, (_, __) {});
  try {
    await c.read(tubeTypesProvider.future);
    return c.read(localizedTubeTypesProvider);
  } finally {
    sub.close();
  }
}

Future<List<LocalizedCatalogRow<FlooringMaterial>>> _readFlooring(
  ProviderContainer c,
) async {
  final sub = c.listen(flooringMaterialsProvider, (_, __) {});
  try {
    await c.read(flooringMaterialsProvider.future);
    return c.read(localizedFlooringMaterialsProvider);
  } finally {
    sub.close();
  }
}

void main() {
  // ── Cross-locale search ────────────────────────────────────────────────────

  group('catalogRowMatchesQuery — cross-locale search', () {
    const brick = MaterialEntry(
      id: 'm-brick',
      name: 'Solid brick',
      nameDe: 'Vollziegel',
      category: 'Masonry',
      lambdaDefault: 0.77,
      densityDefault: 1900,
      specificHeatDefault: 900,
    );
    const stone = MaterialEntry(
      id: 'm-stone',
      name: 'Granite',
      nameDe: 'Granit',
      category: 'Floor covering',
      lambdaDefault: 3.5,
      densityDefault: 2800,
      specificHeatDefault: 790,
    );
    const untranslated = MaterialEntry(
      id: 'm-custom',
      name: 'User custom asbestos',
      category: 'Masonry',
      lambdaDefault: 0.4,
      densityDefault: 1000,
      specificHeatDefault: 900,
    );

    test(
      'in DE locale, an English query still matches via alternateName',
      () async {
        final c = _container(
          locale: const Locale('de'),
          materials: [brick, stone, untranslated],
        );
        addTearDown(c.dispose);

        final rows = await _readMaterials(c);
        final hits = rows
            .where((r) => catalogRowMatchesQuery(r, 'brick'))
            .toList();

        expect(hits, hasLength(1));
        expect(hits.single.row.id, 'm-brick');
        // displayName is the German term in DE locale.
        expect(hits.single.displayName, 'Vollziegel');
        // alternateName is the canonical English term.
        expect(hits.single.alternateName, 'Solid brick');
      },
    );

    test(
      'in EN locale, a German query still matches via alternateName',
      () async {
        final c = _container(
          locale: const Locale('en'),
          materials: [brick, stone, untranslated],
        );
        addTearDown(c.dispose);

        final rows = await _readMaterials(c);
        final hits = rows
            .where((r) => catalogRowMatchesQuery(r, 'granit'))
            .toList();

        expect(hits, hasLength(1));
        expect(hits.single.row.id, 'm-stone');
        expect(hits.single.displayName, 'Granite');
        expect(hits.single.alternateName, 'Granit');
      },
    );

    test(
      'rows without a German translation still match the canonical name '
      'in DE locale (displayName falls back to English)',
      () async {
        final c = _container(
          locale: const Locale('de'),
          materials: [untranslated],
        );
        addTearDown(c.dispose);

        final rows = await _readMaterials(c);
        expect(rows, hasLength(1));
        // Both displayName and alternateName resolve to the canonical
        // English name when no German translation has been set.
        expect(rows.single.displayName, 'User custom asbestos');
        // The English fragment matches (whether via displayName or
        // alternateName, both contain the same string here).
        expect(
          catalogRowMatchesQuery(rows.single, 'custom asbestos'),
          isTrue,
        );
        // A query with no overlap still misses.
        expect(
          catalogRowMatchesQuery(rows.single, 'völlig fremd'),
          isFalse,
        );
      },
    );
  });

  // ── Sort order ─────────────────────────────────────────────────────────────

  group('localized providers — sort order follows active locale', () {
    // Three rows that sort differently in EN vs DE:
    //   EN order:  Aaron < Brick < Marble
    //   DE order:  Brettsperrholz < Marmor < Ziegel  →
    //              Marble (Marmor) < Brick (Ziegel) < Aaron (Brettsperrholz)
    // (Aaron's nameDe sorts first in DE; in EN it sorts first by name
    // alone — choose names so the orderings are unambiguous.)
    const aaron = MaterialEntry(
      id: 'm-aaron',
      name: 'Aaron material',
      nameDe: 'Zellulose-Variante',
      category: 'X',
      lambdaDefault: 1,
      densityDefault: 1,
      specificHeatDefault: 1,
    );
    const brick = MaterialEntry(
      id: 'm-brick',
      name: 'Brick',
      nameDe: 'Backstein',
      category: 'X',
      lambdaDefault: 1,
      densityDefault: 1,
      specificHeatDefault: 1,
    );
    const marble = MaterialEntry(
      id: 'm-marble',
      name: 'Marble',
      nameDe: 'Marmor',
      category: 'X',
      lambdaDefault: 1,
      densityDefault: 1,
      specificHeatDefault: 1,
    );

    test('EN locale sorts by canonical name', () async {
      final c = _container(
        locale: const Locale('en'),
        materials: [marble, aaron, brick],
      );
      addTearDown(c.dispose);

      final rows = await _readMaterials(c);
      expect(
        rows.map((r) => r.displayName).toList(),
        ['Aaron material', 'Brick', 'Marble'],
      );
    });

    test('DE locale sorts by German display name', () async {
      final c = _container(
        locale: const Locale('de'),
        materials: [marble, aaron, brick],
      );
      addTearDown(c.dispose);

      final rows = await _readMaterials(c);
      // Backstein < Marmor < Zellulose-Variante
      expect(
        rows.map((r) => r.displayName).toList(),
        ['Backstein', 'Marmor', 'Zellulose-Variante'],
      );
    });

    test('flooring + tube providers sort by displayName too', () async {
      const tubeA = TubeType(
        id: 't-a',
        name: 'Aluminium pipe',
        nameDe: 'Zink-Rohr',
        material: TubeMaterial.peXa,
      );
      const tubeB = TubeType(
        id: 't-b',
        name: 'Brass pipe',
        nameDe: 'Aluminium-Rohr',
        material: TubeMaterial.peXa,
      );
      const flooringA = FlooringMaterial(
        id: 'f-a',
        name: 'Aaa flooring',
        nameDe: 'Zzz Belag',
        thermalResistance: 0.01,
      );
      const flooringB = FlooringMaterial(
        id: 'f-b',
        name: 'Zzz flooring',
        nameDe: 'Aaa Belag',
        thermalResistance: 0.02,
      );

      final c = _container(
        locale: const Locale('de'),
        tubes: [tubeA, tubeB],
        flooring: [flooringA, flooringB],
      );
      addTearDown(c.dispose);

      final tubes = await _readTubes(c);
      expect(
        tubes.map((r) => r.displayName).toList(),
        ['Aluminium-Rohr', 'Zink-Rohr'],
      );
      final flooring = await _readFlooring(c);
      expect(
        flooring.map((r) => r.displayName).toList(),
        ['Aaa Belag', 'Zzz Belag'],
      );
    });
  });
}
