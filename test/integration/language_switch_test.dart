// Integration test: language switch persistence and UI
// update.
//
// Exercises the end-to-end flow:
//   1. App starts with English (no persisted preference).
//   2. Verify English strings on the project list screen.
//   3. Open the Project Settings dialog and switch to
//      "Deutsch".
//   4. Close the dialog — project list renders German
//      strings.
//   5. Simulate restart (re-pump the root widget).
//   6. Verify "Deutsch" persisted — German strings still
//      shown after restart.
//   7. Switch back to English and verify restoration.
//
// Uses a standard testWidgets approach with ProviderScope
// since IntegrationTestWidgetsFlutterBinding is not
// configured. The Project Settings dialog is invoked
// directly via showProjectSettingsDialog because the
// project list screen no longer has a settings entry point.
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
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/data/models/project.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/repositories/project_repository.dart';
import 'package:heating_planner/ui/dialogs/project_settings_dialog.dart';
import 'package:heating_planner/ui/screens/project_list_screen.dart';
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

Future<void> _selectLanguage(
  WidgetTester tester,
  String optionText,
) async {
  // The Project Settings dialog's language dropdown is the
  // DropdownButton tagged with the ValueKey('languageDropdown')
  // exposed by the language-row widget (ADR-020 added three
  // material-default DropdownButton<String>s above it, so the bare
  // type-match would now find four matches). The dialog is taller
  // than the test viewport, so scroll its SingleChildScrollView to
  // bring the dropdown into view.
  final dropdown = find.byKey(const ValueKey('languageDropdown'));
  final scrollable = find
      .descendant(
        of: find.byType(ProjectSettingsDialog),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    dropdown,
    100,
    scrollable: scrollable,
  );
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
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
            // ADR-020: the project settings dialog now opens
            // material-default dropdowns that subscribe to
            // [materialEntriesProvider]. Override with a synchronous
            // single-value stream so Drift doesn't keep a watch open
            // and produce a "Timer still pending" assertion when the
            // test tree is torn down.
            materialEntriesProvider.overrideWith(
              (ref) => Stream.value(<MaterialEntry>[
                const MaterialEntry(
                  id: 'mat-016',
                  name: 'Vertical coring brick',
                  category: 'Masonry',
                  subcategory: 'Historic brick',
                  lambdaDefault: 0.50,
                  densityDefault: 1200,
                  specificHeatDefault: 900,
                ),
              ]),
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

      // ── 2. Open Project Settings dialog ───────────────
      final ctx = tester
          .element(find.byType(ProjectListScreen));
      unawaitedShow(showProjectSettingsDialog(ctx));
      await tester.pumpAndSettle();

      // Dialog now visible with English labels.
      expect(find.text('Language'), findsOneWidget);
      expect(
        find.text('Drawing Grid Size'),
        findsOneWidget,
      );

      // ── 3. Switch to Deutsch ──────────────────────────
      await _selectLanguage(tester, 'Deutsch');

      // Dialog labels are now in German.
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

      // ── 4. Close dialog and verify project list ───────
      Navigator.of(
        tester.element(find.byType(ProjectSettingsDialog)),
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
      unawaitedShow(showProjectSettingsDialog(ctx2));
      await tester.pumpAndSettle();

      // In the German locale, the English option is
      // labelled "Englisch".
      await _selectLanguage(tester, 'Englisch');

      // Dialog labels back to English.
      expect(find.text('Language'), findsOneWidget);

      // Close the dialog.
      Navigator.of(
        tester.element(find.byType(ProjectSettingsDialog)),
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

/// Fire-and-forget for a dialog future — the test does not
/// await dismissal of the dialog (the test pops it
/// explicitly), so silence the unused-future lint.
void unawaitedShow(Future<void> _) {}
