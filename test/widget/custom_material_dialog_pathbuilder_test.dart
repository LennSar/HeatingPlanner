// Widget tests for the path builder inside CustomMaterialDialog
// (ADR-022 Rule 6 / UI/UX §5.7.2).
//
// Scenarios:
//   (a) "(root)" + typed ["Brand New Branch"] → Save produces
//       categoryPath == ["Brand New Branch"].
//   (b) Start = "Insulation boards" + typed
//       ["custom insulations", "funky new materials"] →
//       categoryPath == ["Insulation boards", "custom insulations",
//                        "funky new materials"].
//   (c) Cascade-remove: pressing ✕ on the middle segment removes the
//       middle and the bottom; final stack length is 1.
//   (d) "+ Add subcategory" is disabled when the last typed segment is
//       empty, and enabled once a non-empty character is typed.
//   (e) Edit mode pre-fills "Start under" with categoryPath[:-1] and
//       the last segment in the typed field.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/custom_material_library_service.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/ui/dialogs/custom_material_dialog.dart';

// ── Stub service ───────────────────────────────────────────────────────────

/// Stub [CustomMaterialLibraryService] that bypasses every file-system
/// interaction by overriding the two methods the dialog calls. Echoes
/// the input back so the dialog's `Navigator.pop(result)` carries the
/// payload the user composed.
class _StubLibraryService extends CustomMaterialLibraryService {
  _StubLibraryService(super.ref);

  MaterialEntry? lastCreated;
  MaterialEntry? lastUpdated;

  @override
  Future<MaterialEntry> create(MaterialEntry entry) async {
    final created = entry.copyWith(id: 'stub-${entry.name}');
    lastCreated = created;
    return created;
  }

  @override
  Future<void> update(MaterialEntry entry) async {
    lastUpdated = entry;
  }
}

// ── Fixtures ───────────────────────────────────────────────────────────────

const _insulationWoodFibre = MaterialEntry(
  id: 'mat-wf',
  name: 'STEICO flex',
  categoryPath: ['Insulation boards', 'Wood fibre'],
  lambdaDefault: 0.038,
  densityDefault: 50,
  specificHeatDefault: 2100,
);

const _insulationStoneWool = MaterialEntry(
  id: 'mat-sw',
  name: 'Rockwool board',
  categoryPath: ['Insulation boards', 'Stone wool board'],
  lambdaDefault: 0.035,
  densityDefault: 100,
  specificHeatDefault: 1030,
);

const _editFixture = MaterialEntry(
  id: 'mat-edit',
  name: 'Editable hempcrete',
  categoryPath: ['Insulation boards', 'Bio-based', 'Hemp'],
  lambdaDefault: 0.07,
  densityDefault: 275,
  specificHeatDefault: 1700,
  isBuiltIn: false,
);

// ── Harness ────────────────────────────────────────────────────────────────

class _Harness {
  _Harness({
    this.all = const <MaterialEntry>[],
    this.customs = const <MaterialEntry>[],
  });

  final List<MaterialEntry> all;
  final List<MaterialEntry> customs;

  late final _StubLibraryService stub;
  MaterialEntry? lastDialogResult;

  Widget build({MaterialEntry? edit}) {
    return ProviderScope(
      overrides: [
        materialEntriesProvider.overrideWith((ref) => Stream.value(all)),
        customMaterialsProvider.overrideWith((ref) => Stream.value(customs)),
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
                  lastDialogResult = edit == null
                      ? await showAddCustomMaterialDialog(ctx)
                      : await showEditCustomMaterialDialog(ctx, edit);
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

/// The [DropdownMenu] widget renders an inner [TextField] for its
/// filterable input; tapping the outer keyed wrapper hits a layout pad
/// that doesn't open the menu. Tap the descendant TextField to surface
/// the option list, then tap the [MenuItemButton] carrying [label].
Future<void> _pickStartUnder(WidgetTester tester, String label) async {
  final dropdownField = find.descendant(
    of: find.byKey(const Key('custom-material-path-start')),
    matching: find.byType(TextField),
  );
  await tester.tap(dropdownField);
  await tester.pumpAndSettle();
  final option = find.descendant(
    of: find.byType(MenuItemButton),
    matching: find.text(label),
  );
  await tester.tap(option.first);
  await tester.pumpAndSettle();
}

/// Returns the live text inside the Start-under dropdown's internal
/// editing controller (for edit-mode pre-fill verification).
String _startUnderText(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.descendant(
      of: find.byKey(const Key('custom-material-path-start')),
      matching: find.byType(TextField),
    ),
  );
  return field.controller?.text ?? '';
}

Future<void> _addSegmentAndType(WidgetTester tester, int index, String text) async {
  await tester.tap(find.byKey(const Key('custom-material-add-subcategory')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(Key('custom-material-path-segment-$index')),
    text,
  );
  await tester.pump();
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

/// The dialog's contents live inside a [SingleChildScrollView]; with
/// the path builder plus six form rows the Save button can be below
/// the visible area on the default 800x600 test surface. Scroll to it
/// before tapping.
Future<void> _tapSave(WidgetTester tester) async {
  final save = find.byKey(const Key('custom-material-save'));
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

bool _isAddSubcategoryEnabled(WidgetTester tester) {
  final btn = tester.widget<TextButton>(
    find.byKey(const Key('custom-material-add-subcategory')),
  );
  return btn.onPressed != null;
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  testWidgets(
    '(a) "(root)" + typed ["Brand New Branch"] → categoryPath = '
    '["Brand New Branch"]',
    (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await _openDialog(tester);

      await _pickStartUnder(tester, '(root)');
      await _addSegmentAndType(tester, 0, 'Brand New Branch');
      await _fillRequiredScalars(tester, 'Top-level material');

      await _tapSave(tester);

      expect(h.stub.lastCreated, isNotNull);
      expect(h.stub.lastCreated!.categoryPath, ['Brand New Branch']);
      expect(h.lastDialogResult!.categoryPath, ['Brand New Branch']);
    },
  );

  testWidgets(
    '(b) Start = "Insulation boards › Wood fibre" + typed '
    '["custom insulations", "funky new materials"] composes the full path',
    (tester) async {
      final h = _Harness(all: const [_insulationWoodFibre, _insulationStoneWool]);
      await tester.pumpWidget(h.build());
      await _openDialog(tester);

      // Existing breadcrumb appears in the Start dropdown.
      await _pickStartUnder(tester, 'Insulation boards › Wood fibre');
      await _addSegmentAndType(tester, 0, 'custom insulations');
      await _addSegmentAndType(tester, 1, 'funky new materials');
      await _fillRequiredScalars(tester, 'flux compensating plates');

      await _tapSave(tester);

      expect(
        h.stub.lastCreated!.categoryPath,
        [
          'Insulation boards',
          'Wood fibre',
          'custom insulations',
          'funky new materials',
        ],
      );
    },
  );

  testWidgets(
    '(c) cascade-remove: ✕ on a middle segment drops the middle and '
    'every segment below it — final stack length is 1',
    (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await _openDialog(tester);

      await _pickStartUnder(tester, '(root)');
      await _addSegmentAndType(tester, 0, 'first');
      await _addSegmentAndType(tester, 1, 'middle');
      await _addSegmentAndType(tester, 2, 'last');

      // Pre-condition: three typed-segment fields rendered.
      expect(
        find.byKey(const Key('custom-material-path-segment-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('custom-material-path-segment-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('custom-material-path-segment-2')),
        findsOneWidget,
      );

      // ✕ on the middle segment removes index 1 AND 2 (cascade).
      await tester.tap(
        find.byKey(const Key('custom-material-path-segment-1-remove')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('custom-material-path-segment-0')),
        findsOneWidget,
        reason: 'first segment survives',
      );
      expect(
        find.byKey(const Key('custom-material-path-segment-1')),
        findsNothing,
        reason: 'middle segment removed',
      );
      expect(
        find.byKey(const Key('custom-material-path-segment-2')),
        findsNothing,
        reason: 'bottom segment cascade-removed',
      );
    },
  );

  testWidgets(
    '(d) "+ Add subcategory" is disabled while the last typed segment '
    'is empty; enabled once a non-empty character is typed',
    (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await _openDialog(tester);

      await _pickStartUnder(tester, '(root)');

      // No typed segments yet → button enabled.
      expect(_isAddSubcategoryEnabled(tester), isTrue);

      // Add an empty segment by tapping the button once.
      await tester.tap(find.byKey(const Key('custom-material-add-subcategory')));
      await tester.pumpAndSettle();
      // Last (and only) segment is empty → button disabled.
      expect(_isAddSubcategoryEnabled(tester), isFalse);

      // Type a non-empty character → button re-enables.
      await tester.enterText(
        find.byKey(const Key('custom-material-path-segment-0')),
        'something',
      );
      await tester.pump();
      expect(_isAddSubcategoryEnabled(tester), isTrue);
    },
  );

  testWidgets(
    '(e) edit mode pre-fills "Start under" with categoryPath[:-1] and '
    'the last segment as the typed field',
    (tester) async {
      final h = _Harness(
        all: const [_insulationWoodFibre, _editFixture],
        customs: const [_editFixture],
      );
      await tester.pumpWidget(h.build(edit: _editFixture));
      await _openDialog(tester);

      // The DropdownMenu's internal text-editing controller carries
      // the breadcrumb of categoryPath[:-1].
      expect(
        _startUnderText(tester),
        'Insulation boards › Bio-based',
        reason: '"Start under" pre-filled with categoryPath[:-1]',
      );

      // The typed extension field carries the last segment.
      final lastSegmentField = tester.widget<TextField>(
        find.byKey(const Key('custom-material-path-segment-0')),
      );
      expect(lastSegmentField.controller!.text, 'Hemp');
    },
  );
}
