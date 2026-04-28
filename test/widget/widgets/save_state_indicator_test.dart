// Widget tests for SaveStateIndicator.
//
// Per agent-test.md §6.1 and §12. Each test overrides [saveStateProvider]
// with a stub notifier that returns a fixed [SaveState], so no real I/O or
// timers are involved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/save_state_notifier.dart';
import 'package:heating_planner/ui/widgets/save_state_indicator.dart';

// ── Stub notifier ─────────────────────────────────────────────────────────────

/// Returns a fixed [SaveState]; overrides no real I/O.
class _StubSaveStateNotifier extends SaveStateNotifier {
  _StubSaveStateNotifier(this._fixedState);
  final SaveState _fixedState;

  @override
  SaveState build() => _fixedState;
}

// ── Test widget builder ───────────────────────────────────────────────────────

Widget _buildApp(SaveState state, {ThemeData? theme}) {
  return ProviderScope(
    overrides: [
      saveStateProvider.overrideWith(() => _StubSaveStateNotifier(state)),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: const Scaffold(
        body: Center(child: SaveStateIndicator()),
      ),
    ),
  );
}

// ── Shared state fixtures ─────────────────────────────────────────────────────

const _neverExported = SaveState(
  isDirty: false,
  lastExportedAt: null,
  lastExportPath: null, // <-- no file path → hidden
  isAutoExporting: false,
);

const _clean = SaveState(
  isDirty: false,
  lastExportedAt: null,
  lastExportPath: '/tmp/project.hsp',
  isAutoExporting: false,
);

const _dirty = SaveState(
  isDirty: true,
  lastExportedAt: null,
  lastExportPath: '/tmp/project.hsp',
  isAutoExporting: false,
);

const _saving = SaveState(
  isDirty: true,
  lastExportedAt: null,
  lastExportPath: '/tmp/project.hsp',
  isAutoExporting: true,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── lastExportPath == null ─────────────────────────────────────────────────

  group('SaveStateIndicator — lastExportPath is null', () {
    testWidgets('renders SizedBox.shrink — no visible content', (tester) async {
      await tester.pumpWidget(_buildApp(_neverExported));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Saving…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // The widget itself returns SizedBox.shrink() — confirm zero size.
      final sizedBoxFinder = find.descendant(
        of: find.byType(SaveStateIndicator),
        matching: find.byType(SizedBox),
      );
      expect(sizedBoxFinder, findsOneWidget);
      final box = tester.widget<SizedBox>(sizedBoxFinder);
      expect(box.width, equals(0.0));
      expect(box.height, equals(0.0));
    });
  });

  // ── Clean state ────────────────────────────────────────────────────────────

  group('SaveStateIndicator — clean (isDirty=false, isAutoExporting=false)', () {
    testWidgets('renders check icon and "Saved" label', (tester) async {
      await tester.pumpWidget(_buildApp(_clean));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('does NOT show unsaved dot or spinner', (tester) async {
      await tester.pumpWidget(_buildApp(_clean));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      // No circular Container (the unsaved dot).
      final hasCircularDot = tester
          .widgetList<Container>(find.byType(Container))
          .any(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration! as BoxDecoration).shape == BoxShape.circle,
          );
      expect(hasCircularDot, isFalse);
    });
  });

  // ── Dirty state ────────────────────────────────────────────────────────────

  group('SaveStateIndicator — isDirty=true, isAutoExporting=false', () {
    testWidgets('renders the amber unsaved dot (circular Container)',
        (tester) async {
      await tester.pumpWidget(_buildApp(_dirty));
      await tester.pumpAndSettle();

      final hasCircularDot = tester
          .widgetList<Container>(find.byType(Container))
          .any(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration! as BoxDecoration).shape == BoxShape.circle,
          );
      expect(hasCircularDot, isTrue);
    });

    testWidgets('does NOT show "Saved" text or check icon', (tester) async {
      await tester.pumpWidget(_buildApp(_dirty));
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });

  // ── Exporting state ────────────────────────────────────────────────────────

  group('SaveStateIndicator — isAutoExporting=true', () {
    testWidgets('renders spinning micro-indicator and "Saving…" text',
        (tester) async {
      await tester.pumpWidget(_buildApp(_saving));
      // Single pump — CircularProgressIndicator animates forever;
      // pumpAndSettle would time out.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving…'), findsOneWidget);
    });

    testWidgets('does NOT show "Saved" text or check icon', (tester) async {
      await tester.pumpWidget(_buildApp(_saving));
      await tester.pump();

      expect(find.text('Saved'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });

  // ── Tooltip ────────────────────────────────────────────────────────────────

  group('SaveStateIndicator — tooltip', () {
    testWidgets(
        'unsaved dot tooltip reads "Changes not yet saved to file"',
        (tester) async {
      await tester.pumpWidget(_buildApp(_dirty));
      await tester.pumpAndSettle();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, equals('Changes not yet saved to file'));
    });
  });

  // ── Colour token ───────────────────────────────────────────────────────────

  group('SaveStateIndicator — colour token', () {
    testWidgets(
        'unsaved dot uses warningAmber from theme extension, '
        'not a hard-coded value', (tester) async {
      // Use a distinctive sentinel colour that differs from the default amber
      // so we can be sure the widget reads from the theme extension.
      const sentinelAmber = Color(0xFF112233);
      final testTheme = AppTheme.light().copyWith(
        extensions: [
          HeatingPlannerColors.light().copyWith(warningAmber: sentinelAmber),
        ],
      );

      await tester.pumpWidget(_buildApp(_dirty, theme: testTheme));
      await tester.pumpAndSettle();

      final dot = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration! as BoxDecoration).shape == BoxShape.circle,
            orElse: () => throw TestFailure(
              'No circular dot Container found in the widget tree.',
            ),
          );

      final decoration = dot.decoration! as BoxDecoration;
      expect(
        decoration.color,
        equals(sentinelAmber),
        reason: 'Dot colour must come from HeatingPlannerColors.warningAmber, '
            'not a literal hex value.',
      );
    });
  });
}
