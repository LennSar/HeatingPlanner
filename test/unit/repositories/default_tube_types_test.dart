// Project-level default tube types for floor and wall zones: they default to
// the seeded PE-Xa 16x2 tube and survive a database round trip.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/project_settings_provider.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/data/models/project.dart';
import 'package:heating_planner/repositories/project_repository.dart';

const _seededTubeId = '10000000-0000-4000-8000-000000000001';
const _otherTubeId = '10000000-0000-4000-8000-000000000002';

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

  Project newProject() => Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
  );

  test('a v22 database gains both columns with the seeded default', () async {
    final old = $db.AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute('CREATE TABLE projects (id TEXT NOT NULL PRIMARY KEY)')
            ..execute("INSERT INTO projects (id) VALUES ('old')")
            // The v23 step (ADR-044) alters these two tables.
            ..execute('CREATE TABLE distributors (id TEXT PRIMARY KEY)')
            ..execute(
              'CREATE TABLE heating_circuits '
              '(id TEXT PRIMARY KEY, distributor_id TEXT)',
            )
            ..execute('PRAGMA user_version = 22');
        },
      ),
    );
    addTearDown(old.close);

    final row = await old
        .customSelect(
          'SELECT default_floor_tube_type_id AS f, '
          'default_wall_tube_type_id AS w FROM projects',
        )
        .getSingle();
    expect(row.read<String>('f'), _seededTubeId);
    expect(row.read<String>('w'), _seededTubeId);
  });

  test('defaults are the seeded PE-Xa 16x2 tube for floor and wall', () {
    final project = newProject();
    expect(project.defaultFloorTubeTypeId, _seededTubeId);
    expect(project.defaultWallTubeTypeId, _seededTubeId);
    const settings = ProjectSettings();
    expect(settings.defaultFloorTubeTypeId, _seededTubeId);
    expect(settings.defaultWallTubeTypeId, _seededTubeId);
  });

  test('floor and wall defaults persist independently', () async {
    final repo = container.read(projectRepositoryProvider);
    await repo.upsertProject(
      newProject().copyWith(
        defaultFloorTubeTypeId: _otherTubeId,
        defaultWallTubeTypeId: _seededTubeId,
      ),
    );

    final loaded = await repo.findById('p1');
    expect(loaded!.defaultFloorTubeTypeId, _otherTubeId);
    expect(loaded.defaultWallTubeTypeId, _seededTubeId);
  });

  test('settings notifier writes the new defaults to the project', () async {
    final repo = container.read(projectRepositoryProvider);
    await repo.upsertProject(newProject());
    container.read(currentProjectIdProvider.notifier).set('p1');
    // Keep the stream-backed project provider alive and loaded.
    container.listen(projectProvider('p1'), (_, __) {});
    await container.read(projectProvider('p1').future);

    final notifier = container.read(projectSettingsProvider.notifier);
    notifier.setDefaultWallTubeTypeId(_otherTubeId);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final loaded = await repo.findById('p1');
    expect(loaded!.defaultWallTubeTypeId, _otherTubeId);
    expect(loaded.defaultFloorTubeTypeId, _seededTubeId);
  });
}
