// Tests for CustomMaterialLibraryService (ADR-021).
//
// Uses an in-memory AppDatabase and a temporary directory for the
// JSON library file. SharedPreferencesAsync is replaced with the
// in-memory backend so AppPreferences round-trips do not touch a
// platform channel.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/repositories/custom_material_library_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────

MaterialEntry _sampleEntry({
  String id = 'mat-1',
  String name = 'Hempcrete',
  String category = 'Insulation',
  String subcategory = 'Bio-based',
  double lambda = 0.07,
  double density = 275,
  double specificHeat = 1700,
}) {
  return MaterialEntry(
    id: id,
    name: name,
    category: category,
    subcategory: subcategory,
    lambdaDefault: lambda,
    densityDefault: density,
    specificHeatDefault: specificHeat,
    isBuiltIn: false,
  );
}

ProviderContainer _buildContainer($db.AppDatabase db) {
  return ProviderContainer(
    overrides: [
      $db.appDatabaseProvider.overrideWithValue(db),
    ],
  );
}

Future<List<$db.MaterialEntry>> _customRows($db.AppDatabase db) {
  return (db.select(db.materialEntries)
        ..where((t) => t.isBuiltIn.equals(false)))
      .get();
}

Future<void> _insertConstruction(
  $db.AppDatabase db, {
  required String id,
  required String name,
}) {
  return db.into(db.wallConstructions).insert(
        $db.WallConstructionsCompanion.insert(
          id: id,
          name: name,
        ),
      );
}

Future<void> _insertLayer(
  $db.AppDatabase db, {
  required String id,
  required String constructionId,
  required String materialId,
}) {
  return db.into(db.materialLayers).insert(
        $db.MaterialLayersCompanion.insert(
          id: id,
          constructionId: constructionId,
          sortOrder: 0,
          materialId: materialId,
          thicknessMm: 100.0,
          thermalConductivity: 0.04,
          density: 50.0,
          specificHeat: 1030.0,
        ),
      );
}

Future<void> _seedCustomRow(
  $db.AppDatabase db,
  MaterialEntry entry,
) async {
  await db.into(db.materialEntries).insertOnConflictUpdate(
        $db.MaterialEntriesCompanion(
          id: Value(entry.id),
          name: Value(entry.name),
          nameDe: Value(entry.nameDe),
          category: Value(entry.category),
          subcategory: Value(entry.subcategory),
          lambdaDefault: Value(entry.lambdaDefault),
          densityDefault: Value(entry.densityDefault),
          specificHeatDefault: Value(entry.specificHeatDefault),
          isBuiltIn: const Value(false),
        ),
      );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tempDir = await Directory.systemTemp.createTemp('custom-mat-lib-test-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ── Round-trip ──────────────────────────────────────────────────────────

  test(
    'create writes through to the JSON file and re-sync preserves the id',
    () async {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = _buildContainer(db);
      addTearDown(container.dispose);

      final service =
          container.read(customMaterialLibraryServiceProvider);

      final libraryPath = '${tempDir.path}/library.json';
      await service.setLibraryPath(libraryPath);

      final created = await service.create(_sampleEntry(id: 'placeholder'));
      expect(created.id, isNot('placeholder'),
          reason: 'create() must mint a fresh UUID');
      expect(created.isBuiltIn, isFalse);

      // File now contains exactly one entry with the new id.
      final raw = await File(libraryPath).readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['version'], '1.0');
      final list = decoded['materials'] as List;
      expect(list, hasLength(1));
      expect((list.first as Map)['id'], created.id);

      // Drop the SQLite mirror to prove the sync pass repopulates from the
      // file.
      await (db.delete(db.materialEntries)
            ..where((t) => t.isBuiltIn.equals(false)))
          .go();
      expect(await _customRows(db), isEmpty);

      await service.reloadFromFile();

      final rows = await _customRows(db);
      expect(rows, hasLength(1));
      expect(rows.single.id, created.id);
      expect(rows.single.name, created.name);
      expect(rows.single.isBuiltIn, isFalse);
    },
  );

  // ── Sync pass replaces previous custom set ─────────────────────────────

  test(
    'changing the library path replaces the previous custom set',
    () async {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = _buildContainer(db);
      addTearDown(container.dispose);

      final service =
          container.read(customMaterialLibraryServiceProvider);

      final pathA = '${tempDir.path}/lib-a.json';
      await File(pathA).writeAsString(jsonEncode({
        'version': '1.0',
        'materials': [
          _sampleEntry(id: 'a-1', name: 'A-One').toJson()
            ..remove('isBuiltIn'),
          _sampleEntry(id: 'a-2', name: 'A-Two').toJson()
            ..remove('isBuiltIn'),
        ],
      }));
      await service.setLibraryPath(pathA);

      var rows = await _customRows(db);
      expect(rows.map((r) => r.id).toSet(), {'a-1', 'a-2'});

      final pathB = '${tempDir.path}/lib-b.json';
      await File(pathB).writeAsString(jsonEncode({
        'version': '1.0',
        'materials': [
          _sampleEntry(id: 'b-1', name: 'B-One').toJson()
            ..remove('isBuiltIn'),
        ],
      }));
      await service.setLibraryPath(pathB);

      rows = await _customRows(db);
      expect(rows.map((r) => r.id).toSet(), {'b-1'},
          reason:
              'previous custom entries must be removed when the path changes');
    },
  );

  // ── Malformed JSON does not throw ──────────────────────────────────────

  test(
    'malformed JSON leaves the custom set empty and does not throw '
    '(Rule 4.3)',
    () async {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = _buildContainer(db);
      addTearDown(container.dispose);

      final service =
          container.read(customMaterialLibraryServiceProvider);

      // Pre-seed a custom row to prove the sync pass still clears it.
      await _seedCustomRow(db, _sampleEntry(id: 'pre-existing'));
      expect(await _customRows(db), hasLength(1));

      final brokenPath = '${tempDir.path}/broken.json';
      await File(brokenPath)
          .writeAsString('this is not valid JSON at all {');

      await expectLater(service.setLibraryPath(brokenPath), completes);

      expect(await _customRows(db), isEmpty);
    },
  );

  // ── Delete blocked when referenced ─────────────────────────────────────

  test(
    'delete blocked when a MaterialLayer references the entry; '
    'DeleteBlocked includes the construction name list',
    () async {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = _buildContainer(db);
      addTearDown(container.dispose);

      final service =
          container.read(customMaterialLibraryServiceProvider);

      final libraryPath = '${tempDir.path}/library.json';
      await service.setLibraryPath(libraryPath);
      final entry = await service.create(_sampleEntry());

      await _insertConstruction(db,
          id: 'wc-living', name: 'Living Room Wall');
      await _insertConstruction(db,
          id: 'wc-bath', name: 'Bathroom Wall');
      await _insertLayer(db,
          id: 'lay-1', constructionId: 'wc-living', materialId: entry.id);
      await _insertLayer(db,
          id: 'lay-2', constructionId: 'wc-living', materialId: entry.id);
      await _insertLayer(db,
          id: 'lay-3', constructionId: 'wc-bath', materialId: entry.id);

      final result = await service.delete(entry.id);

      expect(result, isA<DeleteBlocked>());
      final blocked = result as DeleteBlocked;
      final names = blocked.usages.map((u) => u.constructionName).toSet();
      expect(names, {'Living Room Wall', 'Bathroom Wall'});
      // The row must still exist — block must not mutate SQLite.
      expect(await _customRows(db), hasLength(1));
    },
  );

  // ── File-write failure rolls back the SQLite mutation ───────────────────

  test(
    'file-write failure rolls the SQLite mutation back',
    () async {
      final db = $db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = _buildContainer(db);
      addTearDown(container.dispose);

      final service =
          container.read(customMaterialLibraryServiceProvider);

      // Configure a path inside a directory we'll delete to force the
      // atomic write to fail (the parent.create call also fails because
      // the parent is a file).
      final blockingFile = File('${tempDir.path}/not-a-dir');
      await blockingFile.writeAsString('placeholder');
      // The library path is *under* a file rather than a directory —
      // writing to its parent fails with a FileSystemException.
      final libraryPath = '${blockingFile.path}/library.json';
      // Bypass setLibraryPath's sync pass (it only deletes rows when
      // the file is missing) and inject the path directly via the
      // notifier. Subsequent mutating ops must still see this path.
      container
          .read(customMaterialLibraryPathProvider.notifier)
          .set(libraryPath);

      Object? thrown;
      try {
        await service.create(_sampleEntry());
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isNotNull,
          reason: 'create must rethrow when the JSON write fails');
      expect(await _customRows(db), isEmpty,
          reason: 'SQLite must be rolled back when the file write fails');
    },
  );
}
