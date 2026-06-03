// Widget tests for the Manage Custom Materials screen's full-path
// breadcrumb grouping (ADR-022 Rule 9 / UI/UX §5.7.3).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/custom_material_library_service.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/ui/screens/manage_custom_materials_screen.dart';

/// Fake service — the manage screen only reads `customMaterialsProvider`
/// for the grouping logic and would otherwise need a live SQLite
/// connection through `watchCustom()`. We stub `watchCustom` to an
/// empty stream so any leaked sync pass is a no-op.
class _FakeService extends CustomMaterialLibraryService {
  _FakeService(super.ref);

  @override
  Stream<List<MaterialEntry>> watchCustom() => const Stream.empty();
}

class _FixedPathNotifier extends CustomMaterialLibraryPathNotifier {
  _FixedPathNotifier(this._value);
  final String? _value;

  @override
  String? build() => _value;
}

// Fixture with three distinct paths of mixed depth.
const _depth2 = MaterialEntry(
  id: 'mat-d2',
  name: 'D2 material',
  categoryPath: ['A', 'B'],
  lambdaDefault: 0.1,
  densityDefault: 100,
  specificHeatDefault: 1000,
  isBuiltIn: false,
);

const _depth3 = MaterialEntry(
  id: 'mat-d3',
  name: 'D3 material',
  categoryPath: ['A', 'B', 'C'],
  lambdaDefault: 0.2,
  densityDefault: 200,
  specificHeatDefault: 1000,
  isBuiltIn: false,
);

const _depth1 = MaterialEntry(
  id: 'mat-d1',
  name: 'D1 material',
  categoryPath: ['Z-only'],
  lambdaDefault: 0.3,
  densityDefault: 300,
  specificHeatDefault: 1000,
  isBuiltIn: false,
);

Widget _build(List<MaterialEntry> customs) {
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
        (ref) => _FakeService(ref),
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
    'groups render by full breadcrumb (mixed depths), sorted '
    'alphabetically by full path',
    (tester) async {
      await tester.pumpWidget(_build(const [_depth2, _depth3, _depth1]));
      await tester.pumpAndSettle();

      const expected = ['A › B', 'A › B › C', 'Z-only'];
      for (final s in expected) {
        expect(find.text(s), findsOneWidget,
            reason: 'breadcrumb header "$s" must render exactly once');
      }

      final ys = {
        for (final s in expected) s: tester.getTopLeft(find.text(s)).dy,
      };
      final order = expected.toList()
        ..sort((a, b) => ys[a]!.compareTo(ys[b]!));
      expect(
        order,
        expected,
        reason: 'sorted alphabetically by canonical English breadcrumb',
      );

      // Each material renders under its group header.
      expect(find.text('D1 material'), findsOneWidget);
      expect(find.text('D2 material'), findsOneWidget);
      expect(find.text('D3 material'), findsOneWidget);
    },
  );
}
