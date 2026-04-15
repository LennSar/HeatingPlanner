import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'repositories/app_preferences.dart';
import 'repositories/material_repository.dart';
import 'repositories/project_repository.dart';
import 'repositories/save_state_notifier.dart';
import 'ui/providers/editor_state_provider.dart';
import 'ui/screens/editor_screen.dart';
import 'ui/screens/project_list_screen.dart';

// ── Startup routing provider ───────────────────────────────────────────────────

/// Resolves to the project ID to open on startup, or `null` if the project
/// list should be shown instead.
///
/// Reads the persisted last-opened project ID and verifies the project still
/// exists in SQLite before returning it.
final _startupProjectIdProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  // Ensure the built-in material catalogue is seeded / up-to-date.
  // Idempotent: skips immediately when the stored version matches.
  await ref.read(materialRepositoryProvider).ensureMaterialsSeeded();
  final id = await ref.read(lastOpenedProjectIdProvider.future);
  if (id == null) return null;
  final project = await ref.read(projectRepositoryProvider).findById(id);
  return project != null ? id : null;
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
  /// Returns [AppExitResponse.exit] immediately when there is nothing to save.
  /// Otherwise shows [_UnsavedChangesDialog] and waits for the user's choice.
  Future<AppExitResponse> _handleExitRequested() async {
    final saveState = ref.read(saveStateProvider);
    if (!saveState.isDirty || saveState.lastExportPath == null) {
      return AppExitResponse.exit;
    }

    final context = _navigatorKey.currentContext;
    if (context == null) return AppExitResponse.exit;

    final result = await showDialog<_ExitChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UnsavedChangesDialog(
        projectName: ref.read(currentProjectNameProvider),
      ),
    );

    switch (result) {
      case _ExitChoice.saveAndQuit:
        await ref.read(saveStateProvider.notifier).exportNow();
        return AppExitResponse.exit;
      case _ExitChoice.quitAnyway:
        return AppExitResponse.exit;
      case null:
      case _ExitChoice.cancel:
        return AppExitResponse.cancel;
    }
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
    return MaterialApp(
      title: 'HeatingPlanner',
      theme: AppTheme.light(),
      navigatorKey: _navigatorKey,
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

// ── Unsaved changes dialog (§12.5) ─────────────────────────────────────────────

enum _ExitChoice { saveAndQuit, quitAnyway, cancel }

/// Shown when the user tries to close the window while the `.hsp` export is
/// out of date. Wording per agent-ui-ux.md §12.5.
class _UnsavedChangesDialog extends StatelessWidget {
  const _UnsavedChangesDialog({required this.projectName});

  final String projectName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unsaved export file'),
      content: Text(
        '"$projectName" has changes that have not been saved to the '
        '.hsp file.\n\n'
        'Your project data is safely stored in the app — only the '
        'portable export file is out of date.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_ExitChoice.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_ExitChoice.quitAnyway),
          child: const Text('Quit Anyway'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_ExitChoice.saveAndQuit),
          child: const Text('Save File and Quit'),
        ),
      ],
    );
  }
}
