// Widget tests for the custom-material affordances on the MaterialPicker
// (UI/UX §5.7.1).
//
// Covered scenarios:
//   - "+ New custom material…" and "Manage custom materials…" pinned
//     rows are disabled with the documented caption when no library is
//     configured.
//   - Custom rows show the "Custom" chip alongside the material name.
//   - The right-click context menu on a custom row reveals Edit /
//     Delete actions (edit affordance per UI/UX §5.7.1 item 6).

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/custom_material_library_service.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/ui/widgets/material_picker.dart';

// ── Test fixtures ────────────────────────────────────────────────────────────

const _builtIn = MaterialEntry(
  id: 'mat-built',
  name: 'Cement render',
  category: 'Plaster & Mortar',
  subcategory: 'Cement/Lime',
  lambdaDefault: 1.0,
  densityDefault: 1800,
  specificHeatDefault: 1000,
);

const _custom = MaterialEntry(
  id: 'mat-custom',
  name: 'Custom hempcrete',
  category: 'Insulation boards',
  subcategory: 'Bio-based',
  lambdaDefault: 0.07,
  densityDefault: 275,
  specificHeatDefault: 1700,
  isBuiltIn: false,
);

class _FixedPathNotifier extends CustomMaterialLibraryPathNotifier {
  _FixedPathNotifier(this._value);
  final String? _value;

  @override
  String? build() => _value;
}

Widget _buildPicker({required String? libraryPath}) {
  return ProviderScope(
    overrides: [
      customMaterialLibraryPathProvider.overrideWith(
        () => _FixedPathNotifier(libraryPath),
      ),
      materialEntriesProvider.overrideWith(
        (ref) => Stream.value(const [_builtIn, _custom]),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: MaterialPicker(
            onSelected: (_) {},
            onManageRequested: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'pinned rows are disabled with the caption when no library is configured',
    (tester) async {
      await tester.pumpWidget(_buildPicker(libraryPath: null));
      await tester.pump();

      // Both pinned rows present.
      expect(find.text('New custom material…'), findsOneWidget);
      expect(find.text('Manage custom materials…'), findsOneWidget);

      // Disabled caption shows beside each pinned row.
      expect(
        find.text('Pick a library file in Settings first'),
        findsNWidgets(2),
      );

      // Tapping the new-row does not open the dialog: nothing changes.
      await tester.tap(find.byKey(const Key('material-picker-new-custom')));
      await tester.pump();
      expect(find.text('Add Custom Material'), findsNothing);
    },
  );

  testWidgets(
    'custom rows show the Custom chip but built-in rows do not',
    (tester) async {
      await tester.pumpWidget(
        _buildPicker(libraryPath: '/tmp/lib.json'),
      );
      // Expand the grouped tree to surface the rows.
      await tester.pump();

      // Type into the search field so the rows render in flat mode and
      // both materials are visible at once.
      await tester.enterText(find.byType(TextField), 'e');
      await tester.pump();

      // Chip appears for the custom entry — once because only one
      // custom row matched.
      final chip = find.byKey(const Key('custom-material-chip'));
      expect(chip, findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // The built-in row is also visible but does not carry the chip.
      expect(find.text('Cement render'), findsOneWidget);
      expect(find.text('Custom hempcrete'), findsOneWidget);
    },
  );

  testWidgets(
    'right-click on a custom row opens Edit / Delete context menu',
    (tester) async {
      await tester.pumpWidget(
        _buildPicker(libraryPath: '/tmp/lib.json'),
      );
      await tester.enterText(find.byType(TextField), 'hemp');
      await tester.pump();

      // Right-click on the custom row to open the context menu.
      final rowCenter = tester.getCenter(find.text('Custom hempcrete'));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.addPointer(location: rowCenter);
      await gesture.down(rowCenter);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    },
  );
}
