// Widget tests for the Custom Material dialog's "Start under" picker
// after ADR-022 Rule 6 was amended: the option set is now **every
// distinct prefix** of every existing categoryPath (plus "(root)"), so
// an intermediate node like "Concrete & Screed" is a first-class option
// — not just the leaf paths beneath it (UI/UX §5.7.2).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/custom_material_library_service.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/ui/dialogs/custom_material_dialog.dart';

// ── Stub service (echoes the composed entry back) ──────────────────────────

class _StubLibraryService extends CustomMaterialLibraryService {
  _StubLibraryService(super.ref);

  MaterialEntry? lastCreated;

  @override
  Future<MaterialEntry> create(MaterialEntry entry) async {
    final created = entry.copyWith(id: 'stub-${entry.name}');
    lastCreated = created;
    return created;
  }

  @override
  Future<void> update(MaterialEntry entry) async {}
}

// ── Fixtures: two leaf paths under "Concrete & Screed" ─────────────────────

const _normalConcrete = MaterialEntry(
  id: 'mat-normal',
  name: 'C25/30',
  categoryPath: ['Concrete & Screed', 'Normal concrete'],
  lambdaDefault: 2.3,
  densityDefault: 2400,
  specificHeatDefault: 1000,
);

const _lightweightConcrete = MaterialEntry(
  id: 'mat-light',
  name: 'LC16/18',
  categoryPath: ['Concrete & Screed', 'Lightweight concrete'],
  lambdaDefault: 0.8,
  densityDefault: 1200,
  specificHeatDefault: 1000,
);

const _all = [_normalConcrete, _lightweightConcrete];

// ── Harness ────────────────────────────────────────────────────────────────

class _Harness {
  late final _StubLibraryService stub;
  MaterialEntry? lastDialogResult;

  Widget build() {
    return ProviderScope(
      overrides: [
        materialEntriesProvider.overrideWith((ref) => Stream.value(_all)),
        customMaterialsProvider.overrideWith((ref) => Stream.value(const [])),
        customMaterialLibraryServiceProvider.overrideWith((ref) {
          stub = _StubLibraryService(ref);
          return stub;
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  lastDialogResult = await showAddCustomMaterialDialog(ctx);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _openStartUnder(WidgetTester tester) async {
  final dropdownField = find.descendant(
    of: find.byKey(const Key('custom-material-path-start')),
    matching: find.byType(TextField),
  );
  await tester.tap(dropdownField);
  await tester.pumpAndSettle();
}

Finder _menuOption(String label) => find.descendant(
      of: find.byType(MenuItemButton),
      matching: find.text(label),
    );

Future<void> _pickStartUnder(WidgetTester tester, String label) async {
  await _openStartUnder(tester);
  await tester.tap(_menuOption(label).first);
  await tester.pumpAndSettle();
}

Future<void> _fillRequiredScalars(WidgetTester tester, String name) async {
  await tester.enterText(
    find.byKey(const Key('custom-material-name')),
    name,
  );
  await tester.enterText(
    find.byKey(const Key('custom-material-lambda')),
    '0.04',
  );
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.byKey(const Key('custom-material-save'));
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Start picker lists "(root)", the intermediate "Concrete & Screed", '
    'and both leaf prefixes',
    (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await _openDialog(tester);
      await _openStartUnder(tester);

      // DropdownMenu renders each entry twice (an offstage copy is used
      // for sizing), so assert presence with findsWidgets.
      expect(_menuOption('(root)'), findsWidgets);
      expect(
        _menuOption('Concrete & Screed'),
        findsWidgets,
        reason: 'the intermediate prefix is a first-class option '
            '(ADR-022 Rule 6)',
      );
      expect(
        _menuOption('Concrete & Screed › Lightweight concrete'),
        findsWidgets,
      );
      expect(
        _menuOption('Concrete & Screed › Normal concrete'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'picking the intermediate "Concrete & Screed" with no typed segments '
    'saves categoryPath == ["Concrete & Screed"]',
    (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await _openDialog(tester);

      await _pickStartUnder(tester, 'Concrete & Screed');
      await _fillRequiredScalars(tester, 'My screed additive');

      await _tapSave(tester);

      expect(h.stub.lastCreated, isNotNull);
      expect(h.stub.lastCreated!.categoryPath, ['Concrete & Screed']);
      expect(h.lastDialogResult!.categoryPath, ['Concrete & Screed']);
    },
  );
}
