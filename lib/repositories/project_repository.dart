// TODO(architect): implement ProjectRepository wrapping ProjectDao.
// Exposes Stream<Project> watch(id) and CRUD methods.
// Maps between Drift row types and Freezed models.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/project.dart';

/// Reactive stream of a [Project] by ID.
///
/// Returns `null` if the project does not exist.
/// TODO(architect): replace stub with ProjectDao.watchById(projectId).
final projectProvider =
    StreamProvider.family<Project?, String>((ref, projectId) async* {
  yield null;
});
