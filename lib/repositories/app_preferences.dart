import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/recent_document.dart';

// ── Keys ──────────────────────────────────────────────────────────────────────

const _kLastOpenedProjectId = 'lastOpenedProjectId';
const _kLastOpenedDocumentPath = 'lastOpenedDocumentPath';
const _kRecentDocuments = 'recentDocuments';
const _kDocumentMigrationDone = 'documentMigrationDone';
const _kLastOpenedFloorId = 'lastOpenedFloorId';
const _kCanvasZoom = 'canvasZoom';
const _kCanvasPanX = 'canvasPanX';
const _kCanvasPanY = 'canvasPanY';
const _kGridSpacingMm = 'gridSpacingMm';
const _kLanguageCode = 'languageCode';
const _kTubeSnapEnabled = 'tubeSnapEnabled';
const _kMaterialDbVersion = 'materialDbVersion';
const _kCustomMaterialLibraryPath = 'customMaterialLibraryPath';
const _kDefaultGridSpacingMm = 100;

/// Maximum number of entries retained in the recent-documents list.
const _kMaxRecentDocuments = 30;

// ── AppPreferences ────────────────────────────────────────────────────────────

/// Thin wrapper around [SharedPreferencesAsync] that exposes typed
/// getters and setters for all application-level session keys.
///
/// All reads and writes are asynchronous — [SharedPreferencesAsync] requires
/// no upfront initialisation call, so [AppPreferences] can be constructed
/// synchronously inside a provider.
class AppPreferences {
  /// Creates an [AppPreferences] instance backed by [SharedPreferencesAsync].
  AppPreferences() : _prefs = SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  // ── lastOpenedProjectId ──────────────────────────────────────────────────

  /// UUID of the project that was open when the app was last closed, or
  /// `null` on first launch.
  Future<String?> getLastOpenedProjectId() =>
      _prefs.getString(_kLastOpenedProjectId);

  /// Persists [id] as the last-opened project. Pass `null` to clear.
  Future<void> setLastOpenedProjectId(String? id) async {
    if (id == null) {
      await _prefs.remove(_kLastOpenedProjectId);
    } else {
      await _prefs.setString(_kLastOpenedProjectId, id);
    }
  }

  // ── lastOpenedDocumentPath ───────────────────────────────────────────────

  /// Absolute path of the `.hsp` document that was open when the app was last
  /// closed, or `null` if no document was open. Drives session restore in the
  /// document-based storage model.
  Future<String?> getLastOpenedDocumentPath() =>
      _prefs.getString(_kLastOpenedDocumentPath);

  /// Persists [path] as the last-opened document. Pass `null` to clear.
  Future<void> setLastOpenedDocumentPath(String? path) async {
    if (path == null) {
      await _prefs.remove(_kLastOpenedDocumentPath);
    } else {
      await _prefs.setString(_kLastOpenedDocumentPath, path);
    }
  }

  // ── recentDocuments ──────────────────────────────────────────────────────

  /// The recent-documents list, most-recent first.
  ///
  /// Returns an empty list when nothing has been opened yet, or when the
  /// stored value cannot be decoded.
  Future<List<RecentDocument>> getRecentDocuments() async {
    final raw = await _prefs.getString(_kRecentDocuments);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map(RecentDocument.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Inserts or refreshes the entry for [doc], moving it to the front and
  /// de-duplicating by path. Trims the list to [_kMaxRecentDocuments].
  Future<List<RecentDocument>> touchRecentDocument(
    RecentDocument doc,
  ) async {
    final current = await getRecentDocuments();
    final next = <RecentDocument>[
      doc,
      ...current.where((d) => d.path != doc.path),
    ].take(_kMaxRecentDocuments).toList();
    await _writeRecentDocuments(next);
    return next;
  }

  /// Removes the entry for [path] from the recent-documents list.
  Future<List<RecentDocument>> removeRecentDocument(String path) async {
    final current = await getRecentDocuments();
    final next = current.where((d) => d.path != path).toList();
    await _writeRecentDocuments(next);
    return next;
  }

  Future<void> _writeRecentDocuments(List<RecentDocument> docs) =>
      _prefs.setString(
        _kRecentDocuments,
        jsonEncode(docs.map((d) => d.toJson()).toList()),
      );

  // ── documentMigrationDone ────────────────────────────────────────────────

  /// Whether the one-time migration of legacy DB-resident projects to `.hsp`
  /// files has already run. Defaults to `false`.
  Future<bool> getDocumentMigrationDone() async =>
      (await _prefs.getBool(_kDocumentMigrationDone)) ?? false;

  /// Records that the legacy-project migration has completed.
  Future<void> setDocumentMigrationDone(bool done) =>
      _prefs.setBool(_kDocumentMigrationDone, done);

  // ── lastOpenedFloorId ────────────────────────────────────────────────────

  /// UUID of the floor that was active when the app was last closed, or
  /// `null` if not set.
  Future<String?> getLastOpenedFloorId() =>
      _prefs.getString(_kLastOpenedFloorId);

  /// Persists [id] as the last-opened floor. Pass `null` to clear.
  Future<void> setLastOpenedFloorId(String? id) async {
    if (id == null) {
      await _prefs.remove(_kLastOpenedFloorId);
    } else {
      await _prefs.setString(_kLastOpenedFloorId, id);
    }
  }

  // ── canvasZoom ───────────────────────────────────────────────────────────

  /// Last canvas zoom level, or `null` if not yet persisted.
  Future<double?> getCanvasZoom() => _prefs.getDouble(_kCanvasZoom);

  /// Persists the canvas zoom level. Pass `null` to clear.
  Future<void> setCanvasZoom(double? zoom) async {
    if (zoom == null) {
      await _prefs.remove(_kCanvasZoom);
    } else {
      await _prefs.setDouble(_kCanvasZoom, zoom);
    }
  }

  // ── canvasPanX ───────────────────────────────────────────────────────────

  /// Last canvas horizontal pan offset in pixels, or `null`.
  Future<double?> getCanvasPanX() => _prefs.getDouble(_kCanvasPanX);

  /// Persists the horizontal pan offset. Pass `null` to clear.
  Future<void> setCanvasPanX(double? x) async {
    if (x == null) {
      await _prefs.remove(_kCanvasPanX);
    } else {
      await _prefs.setDouble(_kCanvasPanX, x);
    }
  }

  // ── canvasPanY ───────────────────────────────────────────────────────────

  /// Last canvas vertical pan offset in pixels, or `null`.
  Future<double?> getCanvasPanY() => _prefs.getDouble(_kCanvasPanY);

  /// Persists the vertical pan offset. Pass `null` to clear.
  Future<void> setCanvasPanY(double? y) async {
    if (y == null) {
      await _prefs.remove(_kCanvasPanY);
    } else {
      await _prefs.setDouble(_kCanvasPanY, y);
    }
  }

  // ── gridSpacingMm ────────────────────────────────────────────────────────

  /// Drawing grid spacing in mm. Defaults to 100 if not yet set.
  Future<int> getGridSpacingMm() async =>
      (await _prefs.getInt(_kGridSpacingMm)) ?? _kDefaultGridSpacingMm;

  /// Persists the grid spacing in mm.
  Future<void> setGridSpacingMm(int spacingMm) =>
      _prefs.setInt(_kGridSpacingMm, spacingMm);

  // ── tubeSnapEnabled ───────────────────────────────────────────────────────

  /// Whether tube corners snap while a tube is edited or drawn by hand
  /// (ADR-046). Defaults to true.
  Future<bool> getTubeSnapEnabled() async =>
      (await _prefs.getBool(_kTubeSnapEnabled)) ?? true;

  /// Persists the tube snapping choice.
  Future<void> setTubeSnapEnabled(bool enabled) =>
      _prefs.setBool(_kTubeSnapEnabled, enabled);

  // ── languageCode ──────────────────────────────────────────────────────────

  /// Two-letter language code (`en`, `de`), or `null` to follow the
  /// system locale.
  Future<String?> getLanguageCode() =>
      _prefs.getString(_kLanguageCode);

  /// Persists [code] as the user-chosen language. Pass `null` to
  /// revert to the system default.
  Future<void> setLanguageCode(String? code) async {
    if (code == null) {
      await _prefs.remove(_kLanguageCode);
    } else {
      await _prefs.setString(_kLanguageCode, code);
    }
  }

  // ── customMaterialLibraryPath ────────────────────────────────────────────

  /// Absolute path to the user-pickable JSON custom-material library, or
  /// `null` when no library is configured.
  ///
  /// See `DECISIONS.md` ADR-021 Rule 1.
  Future<String?> getCustomMaterialLibraryPath() =>
      _prefs.getString(_kCustomMaterialLibraryPath);

  /// Persists [path] as the absolute path to the user-pickable JSON
  /// custom-material library. Pass `null` to clear.
  Future<void> setCustomMaterialLibraryPath(String? path) async {
    if (path == null) {
      await _prefs.remove(_kCustomMaterialLibraryPath);
    } else {
      await _prefs.setString(_kCustomMaterialLibraryPath, path);
    }
  }

  // ── materialDbVersion ─────────────────────────────────────────────────────

  /// Version of the built-in material database that has been seeded.
  ///
  /// `null` means no seeding has been recorded yet (fresh install or
  /// pre-versioning schema).
  Future<int?> getMaterialDbVersion() =>
      _prefs.getInt(_kMaterialDbVersion);

  /// Stores [version] after a successful material re-seed.
  Future<void> setMaterialDbVersion(int version) =>
      _prefs.setInt(_kMaterialDbVersion, version);
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Singleton [AppPreferences] instance.
///
/// Constructed synchronously — [SharedPreferencesAsync] needs no async
/// initialisation.
final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return AppPreferences();
});

// ── lastOpenedProjectIdProvider ───────────────────────────────────────────────

/// Notifier that persists the last-opened project ID to [AppPreferences].
///
/// On first read it loads the stored value asynchronously. After that,
/// callers update it via [LastOpenedProjectIdNotifier.set].
class LastOpenedProjectIdNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.read(appPreferencesProvider).getLastOpenedProjectId();
  }

  /// Updates the stored project ID and persists it immediately.
  Future<void> set(String? id) async {
    await ref.read(appPreferencesProvider).setLastOpenedProjectId(id);
    state = AsyncValue.data(id);
  }
}

/// Persisted last-opened project ID.
///
/// Resolves to `null` on first launch or after the stored project has been
/// deleted. The UI layer reads this during app startup to decide whether to
/// reopen the last project or show the Project List Screen.
final lastOpenedProjectIdProvider =
    AsyncNotifierProvider<LastOpenedProjectIdNotifier, String?>(
  LastOpenedProjectIdNotifier.new,
);

// ── recentDocumentsProvider ───────────────────────────────────────────────────

/// Notifier that exposes the recent-documents list and persists changes.
///
/// In the document-based storage model this is the source of truth for the
/// project-selection screen (replacing the SQLite `projectsProvider` stream).
class RecentDocumentsNotifier extends AsyncNotifier<List<RecentDocument>> {
  @override
  Future<List<RecentDocument>> build() {
    return ref.read(appPreferencesProvider).getRecentDocuments();
  }

  /// Inserts or refreshes the entry for ([path], [name], [modifiedAt]),
  /// moving it to the front of the list.
  Future<void> touch({
    required String path,
    required String name,
    required DateTime modifiedAt,
  }) async {
    final next = await ref.read(appPreferencesProvider).touchRecentDocument(
          RecentDocument(path: path, name: name, modifiedAt: modifiedAt),
        );
    state = AsyncValue.data(next);
  }

  /// Removes the entry for [path] from the list (the file on disk is untouched).
  Future<void> forget(String path) async {
    final next =
        await ref.read(appPreferencesProvider).removeRecentDocument(path);
    state = AsyncValue.data(next);
  }
}

/// Persisted list of recently opened/saved `.hsp` documents, most-recent first.
final recentDocumentsProvider =
    AsyncNotifierProvider<RecentDocumentsNotifier, List<RecentDocument>>(
  RecentDocumentsNotifier.new,
);

// ── gridSpacingMmProvider ─────────────────────────────────────────────────────

/// Notifier that persists the drawing grid spacing to [AppPreferences].
///
/// Defaults to 100 mm on first launch. Callers update it via
/// [GridSpacingMmNotifier.set].
class GridSpacingMmNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() {
    return ref.read(appPreferencesProvider).getGridSpacingMm();
  }

  /// Updates the grid spacing and persists it immediately.
  Future<void> set(int spacingMm) async {
    await ref.read(appPreferencesProvider).setGridSpacingMm(spacingMm);
    state = AsyncValue.data(spacingMm);
  }
}

/// Persisted drawing grid spacing in mm.
///
/// Valid values are 5, 10, 25, 50, 100. Defaults to 100 on first launch.
/// Changes take effect immediately on the canvas and are persisted across
/// sessions.
final gridSpacingMmProvider =
    AsyncNotifierProvider<GridSpacingMmNotifier, int>(
  GridSpacingMmNotifier.new,
);

// ── tubeSnapEnabledProvider ───────────────────────────────────────────────────

/// Notifier that persists the tube snapping choice to [AppPreferences].
class TubeSnapEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.read(appPreferencesProvider).getTubeSnapEnabled();

  /// Turns tube snapping on or off and persists the choice.
  Future<void> set(bool enabled) async {
    state = AsyncValue.data(enabled);
    await ref.read(appPreferencesProvider).setTubeSnapEnabled(enabled);
  }
}

/// Whether tube corners snap in the tube edit and draw tools (ADR-046):
/// 0°/90° segments, rows a whole tube spacing apart, turns in line.
/// Holding Alt places a single point freely either way.
final tubeSnapEnabledProvider =
    AsyncNotifierProvider<TubeSnapEnabledNotifier, bool>(
  TubeSnapEnabledNotifier.new,
);

// ── languageCodeProvider ─────────────────────────────────────────────────────

/// Notifier that persists the user-chosen language code to
/// [AppPreferences].
///
/// Defaults to `'en'` when no preference has been stored.
class LanguageCodeNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    return await ref
            .read(appPreferencesProvider)
            .getLanguageCode() ??
        'en';
  }

  /// Updates the language code and persists it immediately.
  Future<void> set(String code) async {
    await ref
        .read(appPreferencesProvider)
        .setLanguageCode(code);
    state = AsyncValue.data(code);
  }
}

/// Persisted two-letter language code (`en` or `de`).
///
/// Defaults to `'en'` on first launch. The root [MaterialApp]
/// watches this provider to set the active [Locale].
final languageCodeProvider =
    AsyncNotifierProvider<LanguageCodeNotifier, String>(
  LanguageCodeNotifier.new,
);

// ── currentLocaleProvider ────────────────────────────────────────────────────

/// Current UI [Locale] derived from [languageCodeProvider].
///
/// Synchronous: emits `Locale('en')` while the underlying preference is
/// still loading (or has errored), then switches to the persisted code as
/// soon as the [LanguageCodeNotifier] resolves. Catalog providers and
/// DAO `localizedNameFor` helpers consume this to apply the correct
/// fallback rules without each call site having to repeat the
/// `AsyncValue.maybeWhen` boilerplate.
final currentLocaleProvider = Provider<Locale>((ref) {
  final code = ref.watch(languageCodeProvider).maybeWhen(
        data: (v) => v,
        orElse: () => 'en',
      );
  return Locale(code);
});
