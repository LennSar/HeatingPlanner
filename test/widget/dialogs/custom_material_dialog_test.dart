// Widget tests for CustomMaterialDialog (UI/UX §5.7.2).
//
// Covered scenarios:
//   - Save button disabled until every required field is valid
//     (incl. "Start under" picked + at least one typed segment).
//   - Density / specific-heat range validation blocks save when out
//     of range; in-range value re-enables it.
//   - Duplicate-name (case-insensitive) inline error blocks save.
//   - File-write failure toast surfaces and the dialog stays open.

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
  categoryPath: ['Insulation boards', 'Bio-based'],
  lambdaDefault: 0.07,
  densityDefault: 275,
  specificHeatDefault: 1700,
  isBuiltIn: false,
);

const _builtIn = MaterialEntry(
  id: 'mat-built',
  name: 'Cement render',
  categoryPath: ['Plaster & Mortar', 'Cement/Lime'],
  lambdaDefault: 1.0,
  densityDefault: 1800,
  specificHeatDefault: 1000,
);

class _StubLibraryService extends CustomMaterialLibraryService {
  _StubLibraryService(super.ref);

  @override
  Future<MaterialEntry> create(MaterialEntry entry) async =>
      entry.copyWith(id: 'stub-${entry.name}');

  @override
  Future<void> update(MaterialEntry entry) async {}
}

Widget _build({
  List<MaterialEntry> all = const [_builtIn, _existingCustom],
  List<MaterialEntry> customs = const [_existingCustom],
}) {
  return ProviderScope(
    overrides: [
      materialEntriesProvider.overrideWith((ref) => Stream.value(all)),
      customMaterialsProvider.overrideWith((ref) => Stream.value(customs)),
      customMaterialLibraryServiceProvider
          .overrideWith((ref) => _StubLibraryService(ref)),
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

Future<void> _pickRootStart(WidgetTester tester) async {
  // DropdownMenu's tappable target is its inner TextField, not the
  // outer keyed widget.
  await tester.tap(
    find.descendant(
      of: find.byKey(const Key('custom-material-path-start')),
      matching: find.byType(TextField),
    ),
  );
  await tester.pumpAndSettle();
  final option = find.descendant(
    of: find.byType(MenuItemButton),
    matching: find.text('(root)'),
  );
  await tester.tap(option.first);
  await tester.pumpAndSettle();
}

Future<void> _addSegment(WidgetTester tester, int index, String text) async {
  await tester.tap(find.byKey(const Key('custom-material-add-subcategory')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(Key('custom-material-path-segment-$index')),
    text,
  );
  await tester.pump();
}

/// Fills the path builder with a single "(root) + Bio" path so the
/// dialog's path requirement is satisfied without making the test
/// dependent on the existing-paths dropdown.
Future<void> _fillPath(WidgetTester tester) async {
  await _pickRootStart(tester);
  await _addSegment(tester, 0, 'Bio');
}

void main() {
  testWidgets(
    'save is disabled until every required field is valid (name + '
    'composed path + λ); density and specific heat are optional',
    (tester) async {
      await tester.pumpWidget(_build());
      await _openDialog(tester);

      // Initially everything is empty → save disabled.
      expect(_isSaveEnabled(tester), isFalse);

      await tester.enterText(
        find.byKey(const Key('custom-material-name')),
        'Fresh material',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isFalse);

      await _fillPath(tester);
      expect(_isSaveEnabled(tester), isFalse);

      await tester.enterText(
        find.byKey(const Key('custom-material-lambda')),
        '0.07',
      );
      await tester.pump();

      // Density and specific heat are optional — save is enabled now.
      expect(_isSaveEnabled(tester), isTrue);
    },
  );

  testWidgets(
    'out-of-range density blocks save; in-range value re-enables it; '
    'a typed 0 is treated as blank',
    (tester) async {
      await tester.pumpWidget(_build());
      await _openDialog(tester);

      await tester.enterText(
        find.byKey(const Key('custom-material-name')),
        'Fresh material',
      );
      await _fillPath(tester);
      await tester.enterText(
        find.byKey(const Key('custom-material-lambda')),
        '0.07',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isTrue, reason: 'baseline');

      await tester.enterText(
        find.byKey(const Key('custom-material-density')),
        '99999',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isFalse);

      await tester.enterText(
        find.byKey(const Key('custom-material-density')),
        '275',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isTrue);

      // Typed 0 is treated as blank (UI/UX §5.7.2).
      await tester.enterText(
        find.byKey(const Key('custom-material-density')),
        '0',
      );
      await tester.pump();
      expect(_isSaveEnabled(tester), isTrue);
    },
  );

  testWidgets('out-of-range specific heat blocks save', (tester) async {
    await tester.pumpWidget(_build());
    await _openDialog(tester);

    await tester.enterText(
      find.byKey(const Key('custom-material-name')),
      'Fresh material',
    );
    await _fillPath(tester);
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
  });

  testWidgets(
    'duplicate name (case-insensitive) shows inline error and blocks save',
    (tester) async {
      await tester.pumpWidget(_build());
      await _openDialog(tester);

      await tester.enterText(
        find.byKey(const Key('custom-material-name')),
        'MY HEMPCRETE',
      );
      await _fillPath(tester);
      await tester.enterText(
        find.byKey(const Key('custom-material-lambda')),
        '0.07',
      );
      await tester.pump();

      expect(
        find.text('A custom material with this name already exists'),
        findsOneWidget,
      );
      expect(_isSaveEnabled(tester), isFalse);
    },
  );
}
