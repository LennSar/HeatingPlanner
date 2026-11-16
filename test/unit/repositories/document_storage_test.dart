// Tests for the document-based storage model (see DECISIONS.md):
// - ProjectRepository.clearWorkingCopy removes the project subtree without
//   leaving orphan rows, while preserving the shared library (preset
//   constructions, custom materials, seeded lookups).
// - HspImporter.importSnapshotPreservingIds round-trips entity UUIDs and, after
//   a clear, re-opening the same snapshot does not duplicate the project.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/repositories/hsp_exporter.dart';
import 'package:heating_planner/repositories/hsp_importer.dart';
import 'package:heating_planner/repositories/project_repository.dart';

Future<void> _seedProject(
  $db.AppDatabase db, {
  required String projectId,
}) async {
  await db
      .into(db.projects)
      .insert(
        $db.ProjectsCompanion.insert(
          id: projectId,
          name: 'Test Project',
          createdAt: DateTime(2026, 1, 1),
          modifiedAt: DateTime(2026, 1, 2),
        ),
      );
  await db
      .into(db.floors)
      .insert(
        $db.FloorsCompanion.insert(
          id: 'floor-1',
          projectId: projectId,
          name: 'Ground floor',
        ),
      );
  await db
      .into(db.rooms)
      .insert(
        $db.RoomsCompanion.insert(
          id: 'room-1',
          floorId: 'floor-1',
          name: 'Living room',
        ),
      );
  await db
      .into(db.wallSegments)
      .insert(
        $db.WallSegmentsCompanion.insert(
          id: 'wall-1',
          roomId: 'room-1',
          startPointJson: '{"x":0,"y":0}',
          endPointJson: '{"x":1000,"y":0}',
          thicknessMm: 240,
          anchorMode: 0,
        ),
      );
}

void main() {
  late $db.AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = $db.AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [$db.appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('ProjectRepository.clearWorkingCopy', () {
    test('removes the whole project subtree with no orphan rows', () async {
      await _seedProject(db, projectId: 'p-1');

      await container.read(projectRepositoryProvider).clearWorkingCopy();

      expect(await db.select(db.projects).get(), isEmpty);
      expect(await db.select(db.floors).get(), isEmpty);
      expect(await db.select(db.rooms).get(), isEmpty);
      expect(await db.select(db.wallSegments).get(), isEmpty);
    });

    test('preserves preset constructions and custom materials', () async {
      // Shared library: a preset construction + a custom material.
      await db
          .into(db.wallConstructions)
          .insert(
            $db.WallConstructionsCompanion.insert(
              id: 'preset-1',
              name: 'My preset wall',
              isPreset: const Value(1),
            ),
          );
      await db
          .into(db.materialEntries)
          .insert(
            $db.MaterialEntriesCompanion.insert(
              id: 'custom-1',
              name: 'Custom insulation',
              categoryPath: '["Insulation"]',
              lambdaDefault: 0.035,
              densityDefault: 30,
              specificHeatDefault: 1450,
              isBuiltIn: const Value(false),
            ),
          );
      // Project-owned construction + layer (must be deleted).
      await db
          .into(db.wallConstructions)
          .insert(
            $db.WallConstructionsCompanion.insert(id: 'proj-c-1', name: 'Wall'),
          );
      await db
          .into(db.materialLayers)
          .insert(
            $db.MaterialLayersCompanion.insert(
              id: 'layer-1',
              constructionId: 'proj-c-1',
              sortOrder: 0,
              materialId: 'custom-1',
              thicknessMm: 100,
              thermalConductivity: 0.035,
              density: 30,
              specificHeat: 1450,
            ),
          );

      await container.read(projectRepositoryProvider).clearWorkingCopy();

      final constructions = await db.select(db.wallConstructions).get();
      expect(constructions.map((c) => c.id), ['preset-1']);
      expect(await db.select(db.materialLayers).get(), isEmpty);
      // Custom material library is untouched.
      final materials = await db.select(db.materialEntries).get();
      expect(materials.map((m) => m.id), contains('custom-1'));
    });
  });

  group('HspImporter.importSnapshotPreservingIds', () {
    test(
      'round-trips the project UUID and does not duplicate on reopen',
      () async {
        await _seedProject(db, projectId: 'keep-me');
        final snapshot = await HspExporter(db).buildSnapshot('keep-me');

        // First close + reopen.
        await container.read(projectRepositoryProvider).clearWorkingCopy();
        final id1 = await HspImporter(db).importSnapshotPreservingIds(snapshot);

        expect(id1, 'keep-me');
        expect((await db.select(db.projects).get()).single.id, 'keep-me');

        // Second close + reopen of the same snapshot — still exactly one project.
        await container.read(projectRepositoryProvider).clearWorkingCopy();
        final id2 = await HspImporter(db).importSnapshotPreservingIds(snapshot);

        expect(id2, 'keep-me');
        expect((await db.select(db.projects).get()).length, 1);
        expect((await db.select(db.floors).get()).length, 1);
      },
    );
  });
}
