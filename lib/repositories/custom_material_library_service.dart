import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/utils/id_generator.dart';
import '../data/database/app_database.dart' as $db;
import '../data/models/material_entry.dart';
import 'app_preferences.dart';

/// File-format version embedded in the JSON library file.
const String _libraryFileFormatVersion = '1.0';

/// Skeleton content used when bootstrapping a fresh library file
/// (Rule 14).
const String _emptyLibrarySkeleton = '{"version":"1.0","materials":[]}';

/// Default sub-directory under the application documents directory
/// that hosts the default custom-material library file (Rule 14).
const String _defaultLibraryDirName = 'HeatingPlanner';

/// File name of the default custom-material library (Rule 14).
const String _defaultLibraryFileName = 'custom_materials.matlib.json';

// ── DeleteResult ──────────────────────────────────────────────────────────────

/// Outcome of [CustomMaterialLibraryService.delete].
sealed class DeleteResult {
  const DeleteResult();
}

/// Delete succeeded — the SQLite row and the JSON entry are both gone.
class DeleteOk extends DeleteResult {
  /// Creates a [DeleteOk].
  const DeleteOk();
}

/// Delete refused because the material is referenced by one or more
/// [MaterialLayer] rows. [usages] enumerates the affected constructions
/// (one record per unique construction).
class DeleteBlocked extends DeleteResult {
  /// Creates a [DeleteBlocked].
  const DeleteBlocked(this.usages);

  /// One record per unique construction that references this material.
  final List<({String constructionId, String constructionName})> usages;
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Owns the custom-material library JSON file and mirrors its entries
/// into `material_entries` with `isBuiltIn = false`.
///
/// Sole code path that mutates `isBuiltIn = false` rows — see
/// `DECISIONS.md` ADR-021 Rule 13. The library file is *always*
/// available: when [AppPreferences.customMaterialLibraryPath] is
/// `null` the service falls back to the Rule 14 default under
/// `<applicationDocumentsDirectory>/HeatingPlanner/`.
class CustomMaterialLibraryService {
  /// Creates a [CustomMaterialLibraryService] bound to [ref].
  ///
  /// [appDocumentsDir] is a test back door for redirecting the
  /// default-path resolution onto a temporary directory; production
  /// callers leave it null and the service uses
  /// `path_provider.getApplicationDocumentsDirectory()`.
  CustomMaterialLibraryService(
    this._ref, {
    Future<Directory> Function()? appDocumentsDir,
  }) : _appDocumentsDir =
            appDocumentsDir ?? getApplicationDocumentsDirectory;

  static final _log = Logger('CustomMaterialLibraryService');

  final Ref _ref;
  final Future<Directory> Function() _appDocumentsDir;

  $db.AppDatabase get _db => _ref.read($db.appDatabaseProvider);

  AppPreferences get _prefs => _ref.read(appPreferencesProvider);

  /// Reactive stream of all custom material entries, ordered by
  /// category then name.
  Stream<List<MaterialEntry>> watchCustom() {
    return (_db.select(_db.materialEntries)
          ..where((t) => t.isBuiltIn.equals(false))
          ..orderBy([
            (t) => drift.OrderingTerm.asc(t.category),
            (t) => drift.OrderingTerm.asc(t.name),
          ]))
        .watch()
        .map((rows) => rows.map(_entryFromRow).toList());
  }

  /// Effective path of the library file (ADR-021 Rule 13).
  ///
  /// Returns the stored override when
  /// `AppPreferences.customMaterialLibraryPath != null`; otherwise the
  /// Rule 14 default path. Calling this does **not** create the file
  /// or directory; use [_ensureLibraryFile] when a write is imminent.
  Future<String> resolvedLibraryPath() async {
    final stored = _ref.read(customMaterialLibraryPathProvider);
    if (stored != null) return stored;
    final dir = await _appDocumentsDir();
    return p.join(
      dir.path,
      _defaultLibraryDirName,
      _defaultLibraryFileName,
    );
  }

  /// Updates the stored library path in [AppPreferences] and re-runs
  /// the sync pass (ADR-021 Rule 4).
  ///
  /// Passing `null` reverts to the Rule 14 default location. The
  /// default file is created on disk if it does not yet exist.
  Future<void> setLibraryPath(String? path) async {
    await _prefs.setCustomMaterialLibraryPath(path);
    _ref.read(customMaterialLibraryPathProvider.notifier).set(path);
    await _runSyncPass();
  }

  /// Re-runs the sync pass against the current effective path.
  Future<void> reloadFromFile() => _runSyncPass();

  /// Runs the sync pass at app startup using the path persisted in
  /// [AppPreferences].
  ///
  /// Must be called once before the editor loads.
  Future<void> initializeOnStartup() async {
    final stored = await _prefs.getCustomMaterialLibraryPath();
    _ref.read(customMaterialLibraryPathProvider.notifier).set(stored);
    await _runSyncPass();
  }

  /// Creates a new custom material with a fresh UUID v4 id.
  Future<MaterialEntry> create(MaterialEntry entry) async {
    final path = await resolvedLibraryPath();
    await _ensureLibraryFile(path);
    final created = entry.copyWith(
      id: IdGenerator.newId(),
      isBuiltIn: false,
    );
    await _writeThrough(
      path: path,
      mutate: () => _db.into(_db.materialEntries).insertOnConflictUpdate(
            _entryToCompanion(created),
          ),
      undo: () => (_db.delete(_db.materialEntries)
            ..where((t) => t.id.equals(created.id)))
          .go(),
    );
    return created;
  }

  /// Updates an existing custom material in SQLite and rewrites the
  /// JSON file. Rolls back on file-write failure (ADR-021 Rule 5).
  Future<void> update(MaterialEntry entry) async {
    final path = await resolvedLibraryPath();
    await _ensureLibraryFile(path);
    final next = entry.copyWith(isBuiltIn: false);
    final before = await _fetchById(next.id);
    await _writeThrough(
      path: path,
      mutate: () => _db.into(_db.materialEntries).insertOnConflictUpdate(
            _entryToCompanion(next),
          ),
      undo: () async {
        if (before != null) {
          await _db.into(_db.materialEntries).insertOnConflictUpdate(
                _entryToCompanion(before),
              );
        } else {
          await (_db.delete(_db.materialEntries)
                ..where((t) => t.id.equals(next.id)))
              .go();
        }
      },
    );
  }

  /// Deletes a custom material by [id].
  ///
  /// Returns [DeleteBlocked] without touching either store when any
  /// [MaterialLayer] row references the material (ADR-021 Rule 7).
  Future<DeleteResult> delete(String id) async {
    final path = await resolvedLibraryPath();
    await _ensureLibraryFile(path);
    final usages = await _findUsages(id);
    if (usages.isNotEmpty) {
      return DeleteBlocked(usages);
    }
    final before = await _fetchById(id);
    if (before == null) {
      return const DeleteOk();
    }
    await _writeThrough(
      path: path,
      mutate: () =>
          (_db.delete(_db.materialEntries)..where((t) => t.id.equals(id)))
              .go(),
      undo: () => _db.into(_db.materialEntries).insertOnConflictUpdate(
            _entryToCompanion(before),
          ),
    );
    return const DeleteOk();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  /// Runs the sync pass per ADR-021 Rule 4:
  ///
  /// 1. Resolve the effective path.
  /// 2. Delete every `material_entries` row where `isBuiltIn = false`.
  /// 3. Ensure the effective path's file exists (create the empty
  ///    skeleton if missing).
  /// 4. Read and decode the file; insert each entry with
  ///    `isBuiltIn = false`, preserving every `id`.
  /// 5. On unreadable / malformed: keep the empty custom set; never
  ///    throw.
  Future<void> _runSyncPass() async {
    final path = await resolvedLibraryPath();

    await (_db.delete(_db.materialEntries)
          ..where((t) => t.isBuiltIn.equals(false)))
        .go();

    try {
      await _ensureLibraryFile(path);
    } catch (e, st) {
      _log.warning(
        'Could not ensure custom material library file at $path',
        e,
        st,
      );
      return;
    }

    final List<MaterialEntry> entries;
    try {
      final raw = await File(path).readAsString();
      entries = _decodeLibraryFile(raw);
    } catch (e, st) {
      _log.warning(
        'Failed to parse custom material library at $path',
        e,
        st,
      );
      return;
    }

    for (final entry in entries) {
      await _db.into(_db.materialEntries).insertOnConflictUpdate(
            _entryToCompanion(entry.copyWith(isBuiltIn: false)),
          );
    }
  }

  /// Creates the parent directory and an empty skeleton file at
  /// [path] when the file does not exist (ADR-021 Rule 14).
  Future<void> _ensureLibraryFile(String path) async {
    final file = File(path);
    if (file.existsSync()) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(_emptyLibrarySkeleton, flush: true);
  }

  Future<MaterialEntry?> _fetchById(String id) async {
    final rows = await (_db.select(_db.materialEntries)
          ..where((t) => t.id.equals(id)))
        .get();
    if (rows.isEmpty) return null;
    return _entryFromRow(rows.first);
  }

  Future<List<({String constructionId, String constructionName})>>
      _findUsages(String materialId) async {
    final query = _db.select(_db.materialLayers).join([
      drift.innerJoin(
        _db.wallConstructions,
        _db.wallConstructions.id
            .equalsExp(_db.materialLayers.constructionId),
      ),
    ])
      ..where(_db.materialLayers.materialId.equals(materialId));

    final rows = await query.get();
    final seen = <String>{};
    final result = <({String constructionId, String constructionName})>[];
    for (final r in rows) {
      final wc = r.readTable(_db.wallConstructions);
      if (seen.add(wc.id)) {
        result.add((constructionId: wc.id, constructionName: wc.name));
      }
    }
    return result;
  }

  Future<void> _writeThrough({
    required String path,
    required Future<void> Function() mutate,
    required Future<void> Function() undo,
  }) async {
    await mutate();
    try {
      await _writeLibraryFile(path);
    } catch (e, st) {
      _log.severe('Custom material library file write failed', e, st);
      try {
        await undo();
      } catch (rollbackError, rollbackStack) {
        _log.severe(
          'Rollback after failed library write also failed',
          rollbackError,
          rollbackStack,
        );
      }
      rethrow;
    }
  }

  Future<void> _writeLibraryFile(String path) async {
    final rows = await (_db.select(_db.materialEntries)
          ..where((t) => t.isBuiltIn.equals(false))
          ..orderBy([
            (t) => drift.OrderingTerm.asc(t.category),
            (t) => drift.OrderingTerm.asc(t.name),
          ]))
        .get();

    final materials = <Map<String, dynamic>>[];
    for (final row in rows) {
      final json = _entryFromRow(row).toJson()..remove('isBuiltIn');
      materials.add(json);
    }

    final payload = <String, dynamic>{
      'version': _libraryFileFormatVersion,
      'materials': materials,
    };

    final target = File(path);
    await target.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(jsonEncode(payload), flush: true);
    await tmp.rename(path);
  }

  List<MaterialEntry> _decodeLibraryFile(String raw) {
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Library file root must be a JSON object');
    }
    final version = root['version'];
    if (version is String && version != _libraryFileFormatVersion) {
      _log.warning(
        'Custom material library version "$version" differs from '
        'expected "$_libraryFileFormatVersion" — reading forward-compat',
      );
    }
    final rawMaterials = root['materials'];
    if (rawMaterials is! List) {
      throw const FormatException('"materials" must be a JSON array');
    }
    final result = <MaterialEntry>[];
    for (final raw in rawMaterials) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Each material entry must be an object');
      }
      final json = Map<String, dynamic>.from(raw)..['isBuiltIn'] = false;
      result.add(MaterialEntry.fromJson(json));
    }
    return result;
  }
}

// ── Row ↔ Model mapping ───────────────────────────────────────────────────────

MaterialEntry _entryFromRow($db.MaterialEntry row) {
  return MaterialEntry(
    id: row.id,
    name: row.name,
    nameDe: row.nameDe,
    category: row.category,
    subcategory: row.subcategory,
    lambdaDefault: row.lambdaDefault,
    densityDefault: row.densityDefault,
    specificHeatDefault: row.specificHeatDefault,
    isBuiltIn: row.isBuiltIn,
  );
}

$db.MaterialEntriesCompanion _entryToCompanion(MaterialEntry entry) {
  return $db.MaterialEntriesCompanion(
    id: drift.Value(entry.id),
    name: drift.Value(entry.name),
    nameDe: drift.Value(entry.nameDe),
    category: drift.Value(entry.category),
    subcategory: drift.Value(entry.subcategory),
    lambdaDefault: drift.Value(entry.lambdaDefault),
    densityDefault: drift.Value(entry.densityDefault),
    specificHeatDefault: drift.Value(entry.specificHeatDefault),
    isBuiltIn: drift.Value(entry.isBuiltIn),
  );
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Notifier backing [customMaterialLibraryPathProvider].
///
/// Only [CustomMaterialLibraryService] is expected to call [set] —
/// direct callers bypass the sync pass.
class CustomMaterialLibraryPathNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Replaces the current path. Use
  /// [CustomMaterialLibraryService.setLibraryPath] from UI code so the
  /// sync pass and [AppPreferences] write happen alongside the state
  /// update.
  void set(String? path) {
    state = path;
  }
}

/// Stored library-path override, or `null` for "use the Rule 14
/// default location" (not "no library").
///
/// Seeded from [AppPreferences] by
/// [CustomMaterialLibraryService.initializeOnStartup].
final customMaterialLibraryPathProvider =
    NotifierProvider<CustomMaterialLibraryPathNotifier, String?>(
  CustomMaterialLibraryPathNotifier.new,
);

/// Singleton [CustomMaterialLibraryService].
final customMaterialLibraryServiceProvider =
    Provider<CustomMaterialLibraryService>(
  CustomMaterialLibraryService.new,
);

/// Reactive stream of all custom (`isBuiltIn = false`) [MaterialEntry]
/// records.
///
/// The wall construction editor's dropdown keeps using the union view
/// [materialEntriesProvider]; this provider is for the Manage Custom
/// Materials screen.
final customMaterialsProvider =
    StreamProvider<List<MaterialEntry>>((ref) {
  return ref.watch(customMaterialLibraryServiceProvider).watchCustom();
});

/// Resolves the effective library path (ADR-021 Rule 13 / Rule 14)
/// and caches it until [customMaterialLibraryPathProvider] changes.
///
/// Widgets should watch this provider instead of calling
/// `service.resolvedLibraryPath()` inline in their `build` method — an
/// inline `FutureBuilder` recreates the future on every rebuild and
/// can cause `pumpAndSettle` to hang in tests.
final resolvedLibraryPathProvider = FutureProvider<String>((ref) async {
  // Watching the stored-path provider re-runs this future whenever the
  // user picks a different path or resets to default.
  ref.watch(customMaterialLibraryPathProvider);
  return ref
      .read(customMaterialLibraryServiceProvider)
      .resolvedLibraryPath();
});
