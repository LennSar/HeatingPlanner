// Integration test: language switch persistence and UI
// update.
//
// Exercises the end-to-end flow:
//   1. App starts with English (no persisted preference).
//   2. Verify English strings on the project list screen.
//   3. Navigate to Settings and switch to "Deutsch".
//   4. Navigate back — project list renders German strings.
//   5. Simulate restart (re-pump the root widget).
//   6. Verify "Deutsch" persisted — German strings still
//      shown after restart.
//   7. Switch back to English and verify restoration.
//
// Uses a standard testWidgets approach with ProviderScope
// since IntegrationTestWidgetsFlutterBinding is not
// configured. Navigation uses Navigator.push / pop on the
// test widget tree.
//
// pumpAndSettle is safe here because projectsProvider is
// overridden with a synchronous stream (no drift timers).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/database/app_database.dart'
    as $db;
import 'package:heating_planner/data/models/project.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:heating_planner/repositories/project_repository.dart';
import 'package:heating_planner/ui/screens/project_list_screen.dart';
import 'package:heating_planner/ui/screens/settings_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// ── Test app ─────────────────────────────────────────────

/// Root widget that mirrors [HeatingPlannerApp]'s locale
/// wiring but replaces the startup router with a simple
/// [ProjectListScreen] to avoid full database bootstrap.
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langCode =
        ref.watch(languageCodeProvider).maybeWhen(
              data: (v) => v,
              orElse: () => 'en',
            );
    return MaterialApp(
      locale: Locale(langCode),
      localizationsDelegates:
          AppLocalizations.localizationsDelegates,
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
      ],
      theme: AppTheme.light(),
      home: const ProjectListScreen(),
    );
  }
}

// ── Tests ────────────────────────────────────────────────

void main() {
  testWidgets(
    'language switch persists across simulated restart',
    (tester) async {
      // ── Setup ─────────────────────────────────────────
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();

      // In-memory database for drift providers that the
      // project list indirectly depends on.
      final db = $db.AppDatabase.forTesting(
        NativeDatabase.memory(),
      );
      addTearDown(db.close);

      Widget buildApp() {
        return ProviderScope(
          overrides: [
            $db.appDatabaseProvider
                .overrideWithValue(db),
            projectsProvider.overrideWith(
              (ref) => Stream.value(<Project>[]),
            ),
          ],
          child: const _TestApp(),
        );
      }

      // ── 1. Launch — English by default ────────────────
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Spot-check English strings on the project list.
      expect(
        find.text('HeatingPlanner'),
        findsOneWidget,
        reason: 'App title should be in English',
      );
      // "New Project" appears twice: AppBar action +
      // empty state button.
      expect(
        find.text('New Project'),
        findsNWidgets(2),
        reason: 'New Project button should be English',
      );
      expect(
        find.text('No projects yet'),
        findsOneWidget,
        reason: 'Empty state heading should be English',
      );

      // ── 2. Navigate to Settings ───────────────────────
      final ctx = tester
          .element(find.byType(ProjectListScreen));
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Settings is now visible with English labels.
      // AppBar title is "Settings"; row label is
      // "Language".
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);

      // ── 3. Switch to Deutsch ──────────────────────────
      await tester.tap(
        find.byType(DropdownButton<String>).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deutsch').last);
      await tester.pumpAndSettle();

      // Settings labels are now in German.
      expect(
        find.text('Einstellungen'),
        findsOneWidget,
        reason: 'Settings AppBar should switch to German',
      );
      expect(
        find.text('Sprache'),
        findsOneWidget,
        reason: 'Language row label should switch to German',
      );
      expect(
        find.text('Rasterweite'),
        findsOneWidget,
        reason: 'Grid size label should be German',
      );

      // ── 4. Navigate back to project list ──────────────
      Navigator.of(
        tester.element(find.byType(SettingsScreen)),
      ).pop();
      await tester.pumpAndSettle();

      // Project list now shows German strings.
      expect(
        find.text('Neues Projekt'),
        findsNWidgets(2),
        reason: 'New Project button should now be German',
      );
      expect(
        find.text('Noch keine Projekte'),
        findsOneWidget,
        reason: 'Empty state should be German',
      );

      // ── 5. Simulate restart ───────────────────────────
      // Re-pumping a fresh widget tree simulates an app
      // restart. The in-memory SharedPreferences persist
      // across pumps (same platform instance), so the
      // stored language code survives.
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // ── 6. Verify German survived restart ─────────────
      expect(
        find.text('Neues Projekt'),
        findsNWidgets(2),
        reason: 'German should persist after restart',
      );
      expect(
        find.text('Noch keine Projekte'),
        findsOneWidget,
        reason:
            'German empty state should persist after '
            'restart',
      );

      // ── 7. Switch back to English ─────────────────────
      final ctx2 = tester
          .element(find.byType(ProjectListScreen));
      Navigator.of(ctx2).push(
        MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open the language dropdown (now showing German
      // labels).
      await tester.tap(
        find.byType(DropdownButton<String>).first,
      );
      await tester.pumpAndSettle();

      // In the German locale, the English option is
      // labelled "Englisch".
      await tester.tap(find.text('Englisch').last);
      await tester.pumpAndSettle();

      // Settings labels back to English.
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);

      // Go back to the project list.
      Navigator.of(
        tester.element(find.byType(SettingsScreen)),
      ).pop();
      await tester.pumpAndSettle();

      // ── 8. Verify English restored ────────────────────
      expect(
        find.text('New Project'),
        findsNWidgets(2),
        reason: 'English labels should be restored',
      );
      expect(
        find.text('No projects yet'),
        findsOneWidget,
        reason:
            'English empty state should be restored',
      );
    },
  );
}
