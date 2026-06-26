import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database/app_database.dart' as $db;
import 'app_preferences.dart';
import 'hsp_exporter.dart';
import 'hsp_importer.dart';
import 'project_repository.dart';
import 'save_state_notifier.dart';

/// Coordinates the lifecycle of `.hsp` documents in the document-based storage
/// model (see `DECISIONS.md`).
///
/// `.hsp` files are the canonical store; the database is only a working copy of
/// the project currently open in the editor. This service centralises the
/// open / close / migrate flows so the menu, shortcuts, startup router, and
/// app-exit handler all share one implementation.
class DocumentService {
  /// Creates a [DocumentService] backed by [ref].
  DocumentService(this.ref);

  /// The Riverpod [Ref] used to reach repositories and providers.
  final Ref ref;

  static final _log = Logger('DocumentService');

  /// Sub-directory of the user's documents folder where new and migrated
  /// projects are saved by default.
  static const defaultFolderName = 'HeatingPlanner';

  $db.AppDatabase get _db => ref.read($db.appDatabaseProvider);

  // ── Open ──────────────────────────────────────────────────────────────────

  /// Loads the `.hsp` file at [path] into the database as the working copy and
  /// returns the opened project's UUID.
  ///
  /// Clears any previous working copy first, imports preserving the original
  /// UUIDs (so reopening the same file maps back to the same project), marks
  /// save-state clean against [path], and refreshes the recent-documents list
  /// and last-opened-document pointer.
  ///
  /// Throws if the file cannot be read or decoded.
  Future<String> openDocument(String path) async {
    final snapshot = await _readSnapshot(path);

    await ref.read(projectRepositoryProvider).clearWorkingCopy();
    final projectId =
        await HspImporter(_db).importSnapshotPreservingIds(snapshot);

    ref.read(saveStateProvider.notifier).markOpenedFrom(path);

    final name =
        (snapshot['project'] as Map<String, dynamic>)['name'] as String;
    await ref.read(recentDocumentsProvider.notifier).touch(
          path: path,
          name: name,
          modifiedAt: DateTime.now(),
        );
    await ref.read(appPreferencesProvider).setLastOpenedDocumentPath(path);
    return projectId;
  }

  // ── Close ─────────────────────────────────────────────────────────────────

  /// Tears down the in-database working copy after a project has been saved to
  /// (or discarded from) its `.hsp` file.
  ///
  /// Clears the project rows, resets save-state, and forgets the last-opened
  /// pointer so the next launch shows the project list.
  Future<void> closeWorkingCopy() async {
    await ref.read(projectRepositoryProvider).clearWorkingCopy();
    ref.read(saveStateProvider.notifier).reset();
    ref.read(currentProjectIdProvider.notifier).set('');
    await ref.read(appPreferencesProvider).setLastOpenedDocumentPath(null);
  }

  // ── Duplicate / delete ──────────────────────────────────────────────────────

  /// Copies the `.hsp` file at [path] to a uniquely-named sibling whose project
  /// name is [copyName], registers it in the recent-documents list, and returns
  /// the new file path.
  ///
  /// The copy keeps the original entity UUIDs — harmless because at most one
  /// project is ever loaded into the database at a time.
  Future<String> duplicateDocument(String path, String copyName) async {
    final snapshot = await _readSnapshot(path);
    (snapshot['project'] as Map<String, dynamic>)['name'] = copyName;

    final dir = Directory(p.dirname(path));
    final file = _uniqueFile(dir, copyName, <String>{});
    final jsonBytes = utf8.encode(jsonEncode(snapshot));
    final compressed = const GZipEncoder().encode(jsonBytes);
    await file.writeAsBytes(Uint8List.fromList(compressed));

    await ref.read(recentDocumentsProvider.notifier).touch(
          path: file.path,
          name: copyName,
          modifiedAt: DateTime.now(),
        );
    return file.path;
  }

  /// Deletes the `.hsp` file at [path] (if it still exists) and removes it from
  /// the recent-documents list.
  Future<void> deleteDocumentFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
    await ref.read(recentDocumentsProvider.notifier).forget(path);
  }

  // ── Migration ───────────────────────────────────────────────────────────────

  /// One-time migration from the legacy library model: exports every project
  /// still living in the database to an `.hsp` file under
  /// `<documents>/HeatingPlanner/`, registers each in the recent-documents
  /// list, then clears the database working copy.
  ///
  /// Idempotent — guarded by [AppPreferences.getDocumentMigrationDone]; runs at
  /// most once per installation.
  Future<void> migrateLegacyProjectsIfNeeded() async {
    final prefs = ref.read(appPreferencesProvider);
    if (await prefs.getDocumentMigrationDone()) return;

    try {
      final projects = await _db.select(_db.projects).get();
      if (projects.isNotEmpty) {
        final dir = await _defaultFolder();
        final exporter = HspExporter(_db);
        final usedNames = <String>{};

        for (final project in projects) {
          final snapshot = await exporter.buildSnapshot(project.id);
          final file = _uniqueFile(dir, project.name, usedNames);
          final jsonBytes = utf8.encode(jsonEncode(snapshot));
          final compressed = const GZipEncoder().encode(jsonBytes);
          await file.writeAsBytes(Uint8List.fromList(compressed));

          await ref.read(recentDocumentsProvider.notifier).touch(
                path: file.path,
                name: project.name,
                modifiedAt: project.modifiedAt,
              );
        }

        // All projects are now on disk — clear the database in one pass.
        await ref.read(projectRepositoryProvider).clearWorkingCopy();
        await _db.customStatement('VACUUM');
        _log.info('Migrated ${projects.length} project(s) to .hsp files.');
      }
    } catch (e, st) {
      _log.severe('Legacy project migration failed', e, st);
      // Leave the flag unset so migration is retried next launch rather than
      // silently dropping un-exported projects.
      return;
    }

    await prefs.setDocumentMigrationDone(true);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _readSnapshot(String path) async {
    final bytes = await File(path).readAsBytes();
    final jsonStr = utf8.decode(const GZipDecoder().decodeBytes(bytes));
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  Future<Directory> _defaultFolder() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, defaultFolderName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns a non-colliding `<dir>/<name>.hsp` file, appending ` (2)`, ` (3)`…
  /// when needed. [usedNames] guards against collisions within a single run
  /// before the files are written.
  File _uniqueFile(Directory dir, String name, Set<String> usedNames) {
    final base = _sanitize(name);
    var candidate = base;
    var n = 2;
    while (usedNames.contains(candidate) ||
        File(p.join(dir.path, '$candidate.hsp')).existsSync()) {
      candidate = '$base ($n)';
      n++;
    }
    usedNames.add(candidate);
    return File(p.join(dir.path, '$candidate.hsp'));
  }

  static String _sanitize(String name) {
    final cleaned =
        name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'Project' : cleaned;
  }
}

/// Provides the singleton [DocumentService].
final documentServiceProvider = Provider<DocumentService>(
  (ref) => DocumentService(ref),
);
