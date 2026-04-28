// Widget tests verifying locale-specific strings render
// correctly for both supported locales.
//
// Parameterised over 'en' and 'de'. Each test pumps one
// representative widget and checks at least one
// locale-specific string.
//
// Per agent-test.md §6.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/database/app_database.dart'
    as $db;
import 'package:heating_planner/data/models/project.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/project_repository.dart';
import 'package:heating_planner/ui/screens/editor_screen.dart';
import 'package:heating_planner/ui/screens/project_list_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// ── Expected strings per locale ──────────────────────────

typedef _Strings = ({
  String toolTooltip,
  String roomCount,
  String deleteTitle,
  String deleteContent,
  String cancelLabel,
  String emptyHeading,
});

const _expected = <String, _Strings>{
  'en': (
    toolTooltip: 'Select',
    roomCount: '0 rooms',
    deleteTitle: 'Delete project?',
    deleteContent:
        'Delete "Test Villa"? This cannot be undone.',
    cancelLabel: 'Cancel',
    emptyHeading: 'No projects yet',
  ),
  'de': (
    toolTooltip: 'Auswahl',
    roomCount: '0 Räume',
    deleteTitle: 'Projekt löschen?',
    deleteContent: '"Test Villa" löschen? Dies kann '
        'nicht rückgängig gemacht werden.',
    cancelLabel: 'Abbrechen',
    emptyHeading: 'Noch keine Projekte',
  ),
};

// ── Helpers ──────────────────────────────────────────────

/// Builds an [EditorScreen] inside a localised
/// [MaterialApp] with an in-memory drift database so that
/// the editor's `initState` database queries resolve
/// cleanly instead of leaving pending timers.
Widget _buildEditorApp(
  String locale,
  ProviderContainer container,
) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates:
          AppLocalizations.localizationsDelegates,
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
      ],
      theme: AppTheme.light(),
      home: const EditorScreen(
        projectId: 'test-project',
      ),
    ),
  );
}

/// Wraps [child] in a localised MaterialApp.
Widget _buildApp(String locale, Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates:
          AppLocalizations.localizationsDelegates,
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
      ],
      theme: AppTheme.light(),
      home: child,
    ),
  );
}

/// Wraps [ProjectListScreen] in a localised MaterialApp,
/// overriding [projectsProvider] to return an empty list
/// (avoids database dependency).
Widget _buildProjectListApp(String locale) {
  return ProviderScope(
    overrides: [
      projectsProvider.overrideWith(
        (ref) => Stream.value(<Project>[]),
      ),
    ],
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates:
          AppLocalizations.localizationsDelegates,
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
      ],
      theme: AppTheme.light(),
      home: const ProjectListScreen(),
    ),
  );
}

// ── Tests ────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final locale in ['en', 'de']) {
    final s = _expected[locale]!;

    group('locale: $locale', () {
      // 1. EditorScreen toolbar — tool tooltip.
      testWidgets(
        'toolbar shows localised tool tooltip',
        (tester) async {
          tester.view.physicalSize =
              const Size(1280, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final db = $db.AppDatabase.forTesting(
            NativeDatabase.memory(),
          );
          final container = ProviderContainer(
            overrides: [
              $db.appDatabaseProvider
                  .overrideWithValue(db),
            ],
          );
          addTearDown(() async {
            container.dispose();
            await db.close();
          });

          await tester.pumpWidget(
            _buildEditorApp(locale, container),
          );
          await tester.pumpAndSettle();

          // The "Select" / "Auswahl" tooltip wraps
          // the first toolbar icon.
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Tooltip &&
                  w.message == s.toolTooltip,
            ),
            findsOneWidget,
          );
        },
      );

      // 2. EditorScreen status bar — room count.
      //
      // NOTE: PropertiesPanel room-properties strings
      // (e.g. "Target Temperature") are not yet
      // localised. The status bar's room count is the
      // closest localised string in the editor area.
      testWidgets(
        'status bar shows localised room count',
        (tester) async {
          tester.view.physicalSize =
              const Size(1280, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final db = $db.AppDatabase.forTesting(
            NativeDatabase.memory(),
          );
          final container = ProviderContainer(
            overrides: [
              $db.appDatabaseProvider
                  .overrideWithValue(db),
            ],
          );
          addTearDown(() async {
            container.dispose();
            await db.close();
          });

          await tester.pumpWidget(
            _buildEditorApp(locale, container),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(s.roomCount),
            findsOneWidget,
          );
        },
      );

      // 3. Delete-project confirmation dialog.
      testWidgets(
        'delete dialog shows localised title',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              locale,
              Builder(builder: (ctx) {
                final l10n =
                    AppLocalizations.of(ctx)!;
                return Scaffold(
                  body: AlertDialog(
                    title: Text(
                      l10n.deleteProjectTitle,
                    ),
                    content: Text(
                      l10n.deleteProjectContent(
                        'Test Villa',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {},
                        child: Text(l10n.cancel),
                      ),
                    ],
                  ),
                );
              }),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(s.deleteTitle),
            findsOneWidget,
          );
          expect(
            find.text(s.deleteContent),
            findsOneWidget,
          );
          expect(
            find.text(s.cancelLabel),
            findsOneWidget,
          );
        },
      );

      // 4. ProjectListScreen empty state.
      //
      // NOTE: SaveStateIndicator strings (e.g. "Saved")
      // are not yet localised. The project-list empty
      // state is tested as a substitute.
      testWidgets(
        'project list shows localised empty state',
        (tester) async {
          await tester.pumpWidget(
            _buildProjectListApp(locale),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(s.emptyHeading),
            findsOneWidget,
          );
        },
      );
    });
  }
}
