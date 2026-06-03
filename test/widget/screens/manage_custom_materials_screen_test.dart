// Widget tests for ManageCustomMaterialsScreen (UI/UX §5.7.3).
//
// Covered scenarios:
//   - Delete-blocked dialog lists the constructions that reference
//     the material (DeleteBlocked path from ADR-021 Rule 7).
//   - "Reload from file" surfaces a toast with the new count.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/custom_material_library_service.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/ui/screens/manage_custom_materials_screen.dart';

// ── Fake service ─────────────────────────────────────────────────────────────

class _FakeService extends CustomMaterialLibraryService {
  _FakeService(
    super.ref, {
    required this.deleteResult,
  });

  final DeleteResult deleteResult;
  int reloadCalls = 0;

  @override
  Stream<List<MaterialEntry>> watchCustom() => const Stream.empty();

  @override
  Future<DeleteResult> delete(String id) async => deleteResult;

  @override
  Future<void> reloadFromFile() async {
    reloadCalls += 1;
  }
}

class _FixedPathNotifier extends CustomMaterialLibraryPathNotifier {
  _FixedPathNotifier(this._value);
  final String? _value;

  @override
  String? build() => _value;
}

const _entry = MaterialEntry(
  id: 'mat-custom',
  name: 'Custom hempcrete',
  categoryPath: ['Insulation boards', 'Bio-based'],
  lambdaDefault: 0.07,
  densityDefault: 275,
  specificHeatDefault: 1700,
  isBuiltIn: false,
);

Widget _build({
  required DeleteResult deleteResult,
  List<MaterialEntry> customs = const [_entry],
}) {
  return ProviderScope(
    overrides: [
      customMaterialLibraryPathProvider.overrideWith(
        () => _FixedPathNotifier('/tmp/lib.json'),
      ),
      customMaterialsProvider.overrideWith(
        (ref) => Stream.value(customs),
      ),
      materialEntriesProvider.overrideWith(
        (ref) => Stream.value(customs),
      ),
      customMaterialLibraryServiceProvider.overrideWith(
        (ref) => _FakeService(ref, deleteResult: deleteResult),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: const ManageCustomMaterialsScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'blocked-delete dialog lists every referencing construction',
    (tester) async {
      await tester.pumpWidget(
        _build(
          deleteResult: const DeleteBlocked([
            (
              constructionId: 'wc-living',
              constructionName: 'Living Room Wall',
            ),
            (
              constructionId: 'wc-bath',
              constructionName: 'Bathroom Wall',
            ),
          ]),
        ),
      );
      await tester.pump();

      // Open the inline delete button → confirmation dialog appears.
      await tester.tap(
        find.byKey(const Key('custom-entry-mat-custom-delete')),
      );
      await tester.pumpAndSettle();

      // Confirm the delete.
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      // The fake service returned DeleteBlocked → blocked dialog shows
      // both construction names and stays open until OK is pressed.
      expect(
        find.byKey(const Key('custom-material-blocked-dialog')),
        findsOneWidget,
      );
      expect(find.text('• Living Room Wall'), findsOneWidget);
      expect(find.text('• Bathroom Wall'), findsOneWidget);
    },
  );

  testWidgets(
    '"Reload from file" surfaces a toast with the loaded count',
    (tester) async {
      await tester.pumpWidget(
        _build(deleteResult: const DeleteOk()),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('custom-materials-reload')),
      );
      // SnackBar animation in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Plural-aware via l10n: count == 1 → singular branch.
      expect(find.text('Reloaded 1 custom material'), findsOneWidget);
    },
  );
}
