import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../core/utils/id_generator.dart';
import '../data/database/app_database.dart' as $db;
import '../data/models/material_entry.dart';
import 'app_preferences.dart';

/// File-format version embedded in the JSON library file.
const String _libraryFileFormatVersion = '1.0';

// ── Exceptions ────────────────────────────────────────────────────────────────

/// Thrown by mutating methods on [CustomMaterialLibraryService] when no
/// library path is configured.
///
/// Per `DECISIONS.md` ADR-021 Rule 13 the UI must disable affordances when
/// no library is configured rather than catch this exception.
class LibraryNotConfiguredException implements Exception {
  /// Creates a [LibraryNotConfiguredException].
  const LibraryNotConfiguredException();

  @override
  String toString() =>
      'LibraryNotConfiguredException: no custom material library path set';
}

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

/// Owns the user-pickable JSON custom-material library file and mirrors
/// its entries into `material_entries` with `isBuiltIn = false`.
///
/// Sole code path that mutates `isBuiltIn = false` rows — see
/// `DECISIONS.md` ADR-021 Rule 13.
class CustomMaterialLibraryService {
  /// Creates a [CustomMaterialLibraryService] bound to [ref].
  CustomMaterialLibraryService(this._ref);

  static final _log = Logger('CustomMaterialLibraryService');

  final Ref _ref;

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

  /// Updates the library path in [AppPreferences] and runs the sync
  /// pass (ADR-021 Rule 4).
  Future<void> setLibraryPath(String? path) async {
    await _prefs.setCustomMaterialLibraryPath(path);
    _ref.read(customMaterialLibraryPathProvider.notifier).set(path);
    await _runSyncPass(path);
  }

  /// Re-runs the sync pass against the currently configured path.
  Future<void> reloadFromFile() async {
    final path = _ref.read(customMaterialLibraryPathProvider);
    await _runSyncPass(path);
  }

  /// Runs the sync pass at app startup using the path persisted in
  /// [AppPreferences].
  ///
  /// Must be called once before the editor loads.
  Future<void> initializeOnStartup() async {
    final path = await _prefs.getCustomMaterialLibraryPath();
    _ref.read(customMaterialLibraryPathProvider.notifier).set(path);
    await _runSyncPass(path);
  }

  /// Creates a new custom material with a fresh UUID v4 id.
  ///
  /// Writes through to SQLite and rewrites the JSON file. Rolls the
  /// SQLite mutation back if the file write throws (ADR-021 Rule 5).
  Future<MaterialEntry> create(MaterialEntry entry) async {
    final path = _requireLibraryPath();
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
    final path = _requireLibraryPath();
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
  /// Otherwise removes the SQLite row, rewrites the JSON file, and
  /// returns [DeleteOk] — rolling back on file-write failure.
  Future<DeleteResult> delete(String id) async {
    final path = _requireLibraryPath();
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

  String _requireLibraryPath() {
    final path = _ref.read(customMaterialLibraryPathProvider);
    if (path == null) {
      throw const LibraryNotConfiguredException();
    }
    return path;
  }

  /// Runs the sync pass per ADR-021 Rule 4.
  ///
  /// 1. Delete every `material_entries` row where `isBuiltIn = false`.
  /// 2. If [path] is non-null and the file parses, re-insert each
  ///    entry from the file with `isBuiltIn = false`, preserving
  ///    every `id`.
  /// 3. If the file is missing, unreadable, or malformed, keep the
  ///    empty custom set and do not throw — the UI surfaces a toast
  ///    when reading the path back.
  Future<void> _runSyncPass(String? path) async {
    await (_db.delete(_db.materialEntries)
          ..where((t) => t.isBuiltIn.equals(false)))
        .go();

    if (path == null) return;

    final file = File(path);
    if (!file.existsSync()) {
      _log.warning('Custom material library file not found at $path');
      return;
    }

    final List<MaterialEntry> entries;
    try {
      final raw = await file.readAsString();
      entries = _decodeLibraryFile(raw);
    } catch (e, st) {
      _log.warning('Failed to parse custom material library at $path', e, st);
      return;
    }

    for (final entry in entries) {
      await _db.into(_db.materialEntries).insertOnConflictUpdate(
            _entryToCompanion(entry.copyWith(isBuiltIn: false)),
          );
    }
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

/// Currently configured absolute path of the custom-material library
/// JSON file, or `null` when no library is configured.
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
