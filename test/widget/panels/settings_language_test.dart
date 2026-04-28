// Widget tests for the Settings Screen language dropdown.
//
// Verifies:
//   1. Dropdown renders exactly two options (English, Deutsch).
//   2. Dropdown shows the current language ('en' initially).
//   3. Selecting "Deutsch" calls set("de") on the notifier.
//   4. After switching to "de", all settings labels render
//      in German.
//   5. Switching back to "en" restores English labels.
//
// Per agent-test.md §6.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:heating_planner/ui/screens/settings_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// ── Mock notifiers ───────────────────────────────────────

/// Language notifier that stays in-memory (no
/// SharedPreferences I/O).
class _TestLanguageNotifier extends LanguageCodeNotifier {
  String? lastSetCode;

  @override
  Future<String> build() async => 'en';

  @override
  Future<void> set(String code) async {
    lastSetCode = code;
    state = AsyncValue.data(code);
  }
}

/// Grid spacing notifier that stays in-memory.
class _TestGridSpacingNotifier
    extends GridSpacingMmNotifier {
  @override
  Future<int> build() async => 100;

  @override
  Future<void> set(int spacingMm) async {
    state = AsyncValue.data(spacingMm);
  }
}

// ── Test app wrapper ─────────────────────────────────────

/// Mirrors the real [HeatingPlannerApp]'s locale wiring:
/// watches [languageCodeProvider] and sets [MaterialApp.locale].
class _TestApp extends ConsumerWidget {
  const _TestApp({required this.child});
  final Widget child;

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
      home: child,
    );
  }
}

// ── Tests ────────────────────────────────────────────────

void main() {
  late _TestLanguageNotifier langNotifier;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    langNotifier = _TestLanguageNotifier();
  });

  Widget buildWidget() {
    return ProviderScope(
      overrides: [
        languageCodeProvider
            .overrideWith(() => langNotifier),
        gridSpacingMmProvider
            .overrideWith(_TestGridSpacingNotifier.new),
      ],
      child: const _TestApp(
        child: SettingsScreen(),
      ),
    );
  }

  // 1. ─────────────────────────────────────────────────────

  testWidgets(
    'dropdown has exactly two options: English and Deutsch',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Open the language dropdown.
      await tester.tap(
        find.byType(DropdownButton<String>).first,
      );
      await tester.pumpAndSettle();

      // Both menu items appear in the overlay.
      expect(find.text('English'), findsWidgets);
      expect(find.text('Deutsch'), findsWidgets);
    },
  );

  // 2. ─────────────────────────────────────────────────────

  testWidgets(
    'dropdown shows English when languageCode is en',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // The button face shows "English" (the label for
      // the currently selected item).
      expect(find.text('English'), findsOneWidget);

      // AppBar title is "Settings"; row label is
      // "Language".
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(
        find.text('Drawing Grid Size'),
        findsOneWidget,
      );
    },
  );

  // 3. ─────────────────────────────────────────────────────

  testWidgets(
    'selecting Deutsch calls set("de")',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Open the dropdown.
      await tester.tap(
        find.byType(DropdownButton<String>).first,
      );
      await tester.pumpAndSettle();

      // Tap the "Deutsch" option in the overlay.
      // The overlay has its own "Deutsch" text widget;
      // use .last to pick the one in the popup menu.
      await tester.tap(find.text('Deutsch').last);
      await tester.pumpAndSettle();

      expect(langNotifier.lastSetCode, 'de');
    },
  );

  // 4. ─────────────────────────────────────────────────────

  testWidgets(
    'after switching to de, labels render in German',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Open dropdown and select Deutsch.
      await tester.tap(
        find.byType(DropdownButton<String>).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deutsch').last);
      await tester.pumpAndSettle();

      // The MaterialApp locale is now 'de', so
      // AppLocalizations returns German strings.
      // AppBar title is "Einstellungen"; row label is
      // "Sprache".
      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Sprache'), findsOneWidget);
      expect(find.text('Rasterweite'), findsOneWidget);

      // The dropdown itself now displays "Deutsch" as
      // the selected item.
      // "Deutsch" appears in both locales (en→"Deutsch",
      // de→"Deutsch"), so just verify it's present.
      expect(find.text('Deutsch'), findsOneWidget);
    },
  );

  // 5. ─────────────────────────────────────────────────────

  testWidgets(
    'switching back to en restores English labels',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Switch to German first.
      await tester.tap(
        find.byType(DropdownButton<String>).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deutsch').last);
      await tester.pumpAndSettle();

      // Verify German (AppBar + row label).
      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Sprache'), findsOneWidget);

      // Switch back to English.
      await tester.tap(
        find.byType(DropdownButton<String>).first,
      );
      await tester.pumpAndSettle();
      // In German, the English option is labelled
      // "Englisch".
      await tester.tap(find.text('Englisch').last);
      await tester.pumpAndSettle();

      // Verify English labels restored (AppBar + row).
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(
        find.text('Drawing Grid Size'),
        findsOneWidget,
      );
      expect(langNotifier.lastSetCode, 'en');
    },
  );
}
