// Widget tests for the material picker dropdown's full-path breadcrumb
// grouping (ADR-022 Rule 5 / UI/UX §5.7.1 item 4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/ui/widgets/material_picker.dart';

const _aB = MaterialEntry(
  id: 'mat-ab',
  name: 'AB material',
  categoryPath: ['A', 'B'],
  lambdaDefault: 0.10,
  densityDefault: 100,
  specificHeatDefault: 1000,
);

const _aBC = MaterialEntry(
  id: 'mat-abc',
  name: 'ABC material',
  categoryPath: ['A', 'B', 'C'],
  lambdaDefault: 0.20,
  densityDefault: 200,
  specificHeatDefault: 1000,
);

const _customBranch = MaterialEntry(
  id: 'mat-custom-branch',
  name: 'Branch material',
  categoryPath: ['Custom', 'Branch'],
  lambdaDefault: 0.30,
  densityDefault: 300,
  specificHeatDefault: 1000,
  isBuiltIn: false,
);

Widget _build({required List<MaterialEntry> all}) {
  return ProviderScope(
    overrides: [
      materialEntriesProvider.overrideWith((ref) => Stream.value(all)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: MaterialPicker(
            onSelected: (_) {},
            onManageRequested: () {},
          ),
        ),
      ),
    ),
  );
}

/// Returns the on-screen ordering (top → bottom) of three breadcrumb
/// strings, asserting they all render exactly once.
List<String> _renderedHeaderOrder(WidgetTester tester) {
  const expected = ['A › B', 'A › B › C', 'Custom › Branch'];
  for (final s in expected) {
    expect(find.text(s), findsOneWidget,
        reason: 'breadcrumb header "$s" must render exactly once');
  }
  final positions = {
    for (final s in expected) s: tester.getTopLeft(find.text(s)).dy,
  };
  final order = expected.toList()
    ..sort((a, b) => positions[a]!.compareTo(positions[b]!));
  return order;
}

void main() {
  testWidgets(
    'three group headers render with the expected breadcrumb text, '
    'sorted alphabetically by full path',
    (tester) async {
      await tester.pumpWidget(_build(all: const [_aB, _aBC, _customBranch]));
      await tester.pump();

      final order = _renderedHeaderOrder(tester);
      expect(
        order,
        ['A › B', 'A › B › C', 'Custom › Branch'],
        reason:
            'groups sort alphabetically by canonical English breadcrumb '
            '(built-in vs custom interleave naturally — no built-in-first '
            'override, ADR-022 Rule 5)',
      );
    },
  );

  testWidgets(
    'search field non-empty hides headers and shows flat filtered list',
    (tester) async {
      await tester.pumpWidget(_build(all: const [_aB, _aBC, _customBranch]));
      await tester.pump();

      // Pre-condition: headers are visible.
      expect(find.text('A › B'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ABC');
      await tester.pump();

      // The breadcrumb headers must disappear in search mode.
      expect(find.text('A › B'), findsNothing);
      expect(find.text('A › B › C'), findsNothing);
      // The flat list still shows the matching material name.
      expect(find.text('ABC material'), findsOneWidget);
    },
  );
}
