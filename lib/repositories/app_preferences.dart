import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Keys ──────────────────────────────────────────────────────────────────────

const _kLastOpenedProjectId = 'lastOpenedProjectId';
const _kLastOpenedFloorId = 'lastOpenedFloorId';
const _kCanvasZoom = 'canvasZoom';
const _kCanvasPanX = 'canvasPanX';
const _kCanvasPanY = 'canvasPanY';
const _kGridSpacingMm = 'gridSpacingMm';
const _kLanguageCode = 'languageCode';
const _kMaterialDbVersion = 'materialDbVersion';
const _kCustomMaterialLibraryPath = 'customMaterialLibraryPath';
const _kDefaultGridSpacingMm = 100;

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
