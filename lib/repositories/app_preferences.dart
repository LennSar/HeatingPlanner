import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Keys ──────────────────────────────────────────────────────────────────────

const _kLastOpenedProjectId = 'lastOpenedProjectId';
const _kLastOpenedFloorId = 'lastOpenedFloorId';
const _kCanvasZoom = 'canvasZoom';
const _kCanvasPanX = 'canvasPanX';
const _kCanvasPanY = 'canvasPanY';

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
