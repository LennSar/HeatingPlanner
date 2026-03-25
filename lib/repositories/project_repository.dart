import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart' as $db;
import '../data/database/daos/project_dao.dart';
import '../data/models/project.dart';
import 'save_state_notifier.dart';

// ── DAO provider ──────────────────────────────────────────────────────────────

/// Provides the [ProjectDao] from the singleton [AppDatabase].
final projectDaoProvider = Provider<ProjectDao>((ref) {
  return ref.watch($db.appDatabaseProvider).projectDao;
});

// ── Stream providers ──────────────────────────────────────────────────────────

/// Reactive stream of all projects, ordered newest-first by
/// [Project.modifiedAt].
final projectsProvider = StreamProvider<List<Project>>((ref) {
  return ref
      .watch(projectDaoProvider)
      .watchAll()
      .map((rows) => rows.map(_projectFromRow).toList());
});

/// Reactive stream of a [Project] by ID.
///
/// Returns `null` if the project does not exist.
final projectProvider =
    StreamProvider.family<Project?, String>((ref, projectId) {
  return ref
      .watch(projectDaoProvider)
      .watchByIdNullable(projectId)
      .map((row) => row == null ? null : _projectFromRow(row));
});

// ── CRUD helpers ──────────────────────────────────────────────────────────────

/// Inserts or replaces [project] in the database.
Future<void> upsertProject(ProjectDao dao, Project project) =>
    dao.upsert(_projectToCompanion(project));

/// Deletes the project with [id] from the database.
Future<void> deleteProject(ProjectDao dao, String id) =>
    dao.deleteById(id);

// ── Row → Model mapping ───────────────────────────────────────────────────────

Project _projectFromRow($db.Project row) {
  GeoLocation? location;
  if (row.locationJson != null) {
    final map =
        jsonDecode(row.locationJson!) as Map<String, dynamic>;
    location = GeoLocation.fromJson(map);
  }
  return Project(
    id: row.id,
    name: row.name,
    createdAt: row.createdAt,
    modifiedAt: row.modifiedAt,
    designOutdoorTempC: row.designOutdoorTempC,
    defaultIndoorTempC: row.defaultIndoorTempC,
    location: location,
  );
}

// ── Repository class ──────────────────────────────────────────────────────────

/// Class-based repository for [Project] entities.
///
/// Mixes in [SaveStateMixin] so that every successful write marks the
/// in-database state as dirty relative to the last `.hsp` export.
class ProjectRepository with SaveStateMixin {
  /// Creates a [ProjectRepository] backed by [ref].
  ProjectRepository(this.ref);

  @override
  final Ref ref;

  ProjectDao get _dao => ref.read(projectDaoProvider);

  /// Inserts or replaces [project] and marks dirty.
  Future<void> upsertProject(Project project) async {
    await _dao.upsert(_projectToCompanion(project));
    markProjectDirty();
  }

  /// Deletes the project with [id] and marks dirty.
  Future<void> deleteProject(String id) async {
    await _dao.deleteById(id);
    markProjectDirty();
  }
}

/// Provides the singleton [ProjectRepository].
final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref),
);

// ── Model → Companion mapping ─────────────────────────────────────────────────

$db.ProjectsCompanion _projectToCompanion(Project p) {
  final locationJson =
      p.location != null ? jsonEncode(p.location!.toJson()) : null;
  return $db.ProjectsCompanion(
    id: Value(p.id),
    name: Value(p.name),
    createdAt: Value(p.createdAt),
    modifiedAt: Value(p.modifiedAt),
    designOutdoorTempC: Value(p.designOutdoorTempC),
    defaultIndoorTempC: Value(p.defaultIndoorTempC),
    locationJson: Value(locationJson),
  );
}
