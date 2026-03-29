import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/projects_table.dart';

part 'project_dao.g.dart';

/// DAO for CRUD operations on the [Projects] table.
@DriftAccessor(tables: [Projects])
class ProjectDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectDaoMixin {
  /// Creates a [ProjectDao] bound to [db].
  ProjectDao(super.db);

  /// Reactive stream of all projects ordered by [modifiedAt] descending.
  Stream<List<Project>> watchAll() =>
      (select(projects)
            ..orderBy([(t) => OrderingTerm.desc(t.modifiedAt)]))
          .watch();

  /// Reactive stream for a single project by [id].
  Stream<Project> watchById(String id) =>
      (select(projects)..where((t) => t.id.equals(id))).watchSingle();

  /// Reactive stream for a single project by [id], or null if absent.
  Stream<Project?> watchByIdNullable(String id) =>
      (select(projects)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  /// One-shot fetch for a single project by [id], or null if absent.
  Future<Project?> findById(String id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Inserts or replaces a project row.
  Future<void> upsert(ProjectsCompanion companion) =>
      into(projects).insertOnConflictUpdate(companion);

  /// Deletes the project with the given [id].
  Future<void> deleteById(String id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();
}
