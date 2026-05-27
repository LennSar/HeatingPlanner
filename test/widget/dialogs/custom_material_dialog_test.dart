// Widget tests for CustomMaterialDialog (UI/UX §5.7.2).
//
// Covered scenarios:
//   - Save button disabled until all required fields are valid.
//   - Unique-name violation surfaces an inline error in the Name field.
//   - The Category and Subcategory two-segment toggles switch between
//     "Pick existing" and "Create new" controls as specified.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/custom_material_library_service.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/ui/dialogs/custom_material_dialog.dart';

const _existingCustom = MaterialEntry(
  id: 'mat-existing',
  name: 'My Hempcrete',
  category: 'Insulation boards',
  subcategory: 'Bio-based',
  lambdaDefault: 0.07,
  densityDefault: 275,
  specificHeatDefault: 1700,
  isBuiltIn: false,
);

const _builtIn = MaterialEntry(
  id: 'mat-built',
  name: 'Cement render',
  category: 'Plaster & Mortar',
  subcategory: 'Cement/Lime',
  lambdaDefault: 1.0,
  densityDefault: 1800,
  specificHeatDefault: 1000,
);

Widget _build({
  List<MaterialEntry> all = const [_builtIn, _existingCustom],
  List<MaterialEntry> customs = const [_existingCustom],
}) {
  return ProviderScope(
    overrides: [
      materialEntriesProvider.overrideWith(
        (ref) => Stream.value(all),
      ),
      customMaterialsProvider.overrideWith(
        (ref) => Stream.value(customs),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => showAddCustomMaterialDialog(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

bool _isSaveEnabled(WidgetTester tester) {
  final btn = tester.widget<FilledButton>(
    find.byKey(const Key('custom-material-save')),
  );
  return btn.onPressed != null;
}

void main() {
  testWidgets(
    'save is disabled until every required field is valid; '
    'density and specific heat are optional (UI/UX §5.7.2)',
    (tester) async {
      await tester.pumpWidget(_build());
      await _openDialog(tester);

      // Initially everything is empty → save disabled.
      expect(_isSaveEnabled(tester), isFalse);

      // Fill required fields one at a time. Save stays disabled until
      // the last required field (λ) is filled.
      await tester.enterText(
        find.byKey(const Key('custom-material-name')),
        'Fresh material',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isFalse);

      await tester.enterText(
        find.byKey(const Key('custom-material-category-new')),
        'Bio',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isFalse);

      await tester.enterText(
        find.byKey(const Key('custom-material-subcategory-new')),
        'Plant',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isFalse);

      await tester.enterText(
        find.byKey(const Key('custom-material-lambda')),
        '0.07',
      );
      await tester.pump();

      // Density and specific heat are optional — save is already
      // enabled while both fields remain blank.
      expect(_isSaveEnabled(tester), isTrue);
    },
  );

  testWidgets(
    'out-of-range density blocks save; in-range value re-enables it',
    (tester) async {
      await tester.pumpWidget(_build());
      await _openDialog(tester);

      // Fill the four required fields so the gating field is density.
      await tester.enterText(
        find.byKey(const Key('custom-material-name')),
        'Fresh material',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-category-new')),
        'Bio',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-subcategory-new')),
        'Plant',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-lambda')),
        '0.07',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isTrue,
          reason: 'baseline — required fields filled, optional blank');

      // Out-of-range density (> maxDensity = 10 000) → save blocks.
      await tester.enterText(
        find.byKey(const Key('custom-material-density')),
        '99999',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isFalse);

      // In-range value → save re-enables.
      await tester.enterText(
        find.byKey(const Key('custom-material-density')),
        '275',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isTrue);

      // Typed `0` is treated as blank (UI/UX §5.7.2 Rule 4).
      await tester.enterText(
        find.byKey(const Key('custom-material-density')),
        '0',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isTrue);
    },
  );

  testWidgets(
    'out-of-range specific heat blocks save',
    (tester) async {
      await tester.pumpWidget(_build());
      await _openDialog(tester);

      await tester.enterText(
        find.byKey(const Key('custom-material-name')),
        'Fresh material',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-category-new')),
        'Bio',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-subcategory-new')),
        'Plant',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-lambda')),
        '0.07',
      );

      // Above maxSpecificHeat = 5000 → out of range.
      await tester.enterText(
        find.byKey(const Key('custom-material-specific-heat')),
        '99999',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isFalse);
    },
  );

  testWidgets(
    'duplicate name (case-insensitive) shows inline error and blocks save',
    (tester) async {
      await tester.pumpWidget(_build());
      await _openDialog(tester);

      // Fill required fields, but use a name that clashes with an
      // existing custom entry — case differs.
      await tester.enterText(
        find.byKey(const Key('custom-material-name')),
        'MY HEMPCRETE',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-category-new')),
        'Bio',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-subcategory-new')),
        'Plant',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-lambda')),
        '0.07',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-density')),
        '275',
      );
      await tester.enterText(
        find.byKey(const Key('custom-material-specific-heat')),
        '1700',
      );
      await tester.pump();

      expect(
        find.text('A custom material with this name already exists'),
        findsOneWidget,
      );
      expect(_isSaveEnabled(tester), isFalse);
    },
  );

  testWidgets(
    'category toggle switches between Pick existing and Create new controls',
    (tester) async {
      await tester.pumpWidget(_build());
      await _openDialog(tester);

      // Default is "Create new" — text field for category is present.
      expect(
        find.byKey(const Key('custom-material-category-new')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('custom-material-category-pick')),
        findsNothing,
      );

      // Tap "Pick existing" → control swaps to a dropdown.
      await tester.tap(find.text('Pick existing').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('custom-material-category-new')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('custom-material-category-pick')),
        findsOneWidget,
      );

      // Tap "Create new" → swaps back.
      await tester.tap(find.text('Create new').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('custom-material-category-new')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('custom-material-category-pick')),
        findsNothing,
      );
    },
  );
}
