import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'platform/keyboard_shortcuts.dart' show ensureSavedBeforeLeaving;
import 'platform/menu_bar_host.dart';
import 'repositories/app_preferences.dart';
import 'repositories/custom_material_library_service.dart';
import 'repositories/document_service.dart';
import 'repositories/material_repository.dart';
import 'repositories/project_repository.dart';
import 'repositories/save_state_notifier.dart';
import 'ui/screens/editor_screen.dart';
import 'ui/screens/project_list_screen.dart';

// ── Startup routing provider ───────────────────────────────────────────────────

/// Resolves to the project ID to open on startup, or `null` if the project
/// list should be shown instead.
///
/// Document storage model: session restore is driven by the last-opened `.hsp`
/// file path. The file is loaded into the database working copy on startup; if
/// it is missing or fails to load, the project list is shown instead.
final _startupProjectIdProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  // Ensure the built-in material catalogue is seeded / up-to-date.
  // Idempotent: skips immediately when the stored version matches.
  await ref.read(materialRepositoryProvider).ensureMaterialsSeeded();
  // ADR-021 Rule 4: seed the custom-material library from the
  // user-pickable JSON file before the editor loads.
  await ref
      .read(customMaterialLibraryServiceProvider)
      .initializeOnStartup();

  // One-time migration of legacy DB-resident projects into `.hsp` files.
  await ref.read(documentServiceProvider).migrateLegacyProjectsIfNeeded();

  final prefs = ref.read(appPreferencesProvider);
  final path = await prefs.getLastOpenedDocumentPath();
  if (path == null) return null;
  if (!File(path).existsSync()) {
    // File moved or deleted — forget it and fall back to the project list.
    await ref.read(recentDocumentsProvider.notifier).forget(path);
    await prefs.setLastOpenedDocumentPath(null);
    return null;
  }
  try {
    return await ref.read(documentServiceProvider).openDocument(path);
  } catch (_) {
    await prefs.setLastOpenedDocumentPath(null);
    return null;
  }
});

// ── Root widget ────────────────────────────────────────────────────────────────

/// Root widget for the HeatingPlanner application.
///
/// Owns the [AppLifecycleListener] that handles:
/// - Desktop window close: intercepts with an unsaved-changes confirmation
///   dialog when the `.hsp` export is out of date (§12.5).
/// - Tablet background (iOS/Android): calls [exportNow] on [onInactive] so
///   that the last export is always current when the OS may terminate the app.
class HeatingPlannerApp extends ConsumerStatefulWidget {
  /// Creates the [HeatingPlannerApp].
  const HeatingPlannerApp({super.key});

  @override
  ConsumerState<HeatingPlannerApp> createState() =>
      _HeatingPlannerAppState();
}

class _HeatingPlannerAppState
    extends ConsumerState<HeatingPlannerApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: _handleExitRequested,
      onInactive: _handleInactive,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// Intercepts the desktop window close button.
  ///
  /// Prompts to save the open project (when it has unsaved changes or has never
  /// been saved) via the shared [ensureSavedBeforeLeaving] flow, then clears the
  /// in-database working copy so a discarded draft does not linger. The
  /// last-opened-document path is preserved so the next launch restores the
  /// session.
  Future<AppExitResponse> _handleExitRequested() async {
    final context = _navigatorKey.currentContext;
    if (context == null) return AppExitResponse.exit;

    final proceed = await ensureSavedBeforeLeaving(context, ref);
    if (!proceed) return AppExitResponse.cancel;

    await ref.read(projectRepositoryProvider).clearWorkingCopy();
    return AppExitResponse.exit;
  }

  /// Called when the app moves to inactive state.
  ///
  /// On iOS and Android (tablet) the OS may terminate the app shortly after
  /// this callback fires, so we eagerly flush the `.hsp` export here.
  /// On desktop this is a no-op — the close handler covers that path.
  void _handleInactive() {
    if (Platform.isIOS || Platform.isAndroid) {
      unawaited(ref.read(saveStateProvider.notifier).exportNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = ref.watch(languageCodeProvider).maybeWhen(
          data: (v) => v,
          orElse: () => 'en',
        );

    return MaterialApp(
      title: 'HeatingPlanner',
      theme: AppTheme.light(),
      locale: Locale(langCode),
      localizationsDelegates:
          AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en'), Locale('de')],
      navigatorKey: _navigatorKey,
      // Single application-wide native menu bar, mounted above the Navigator so
      // it persists across route changes. Screens contribute their menus via
      // MenuBarScope (Flutter forbids more than one live PlatformMenuBar).
      builder: (context, child) =>
          AppMenuBar(child: child ?? const SizedBox.shrink()),
      home: const _StartupRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ── Startup router ─────────────────────────────────────────────────────────────

/// Reads [_startupProjectIdProvider] and routes to either [EditorScreen]
/// (session restore) or [ProjectListScreen] (fresh start).
///
/// Shows a minimal spinner while the async lookup completes; on error falls
/// back to the project list so the user is never blocked.
class _StartupRouter extends ConsumerWidget {
  const _StartupRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupAsync = ref.watch(_startupProjectIdProvider);

    return startupAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const ProjectListScreen(),
      data: (projectId) => projectId != null
          ? EditorScreen(projectId: projectId)
          : const ProjectListScreen(),
    );
  }
}

