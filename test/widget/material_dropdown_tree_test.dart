// Widget tests for the material picker dropdown's inline-disclosure
// taxonomy tree (ADR-022 Rule 5 / UI/UX §5.7.1 item 4).
//
// Supersedes the prior flat-breadcrumb-headers grouping test: the tree
// is collapsed by default and discloses children on tap. Expansion
// state lives in the editor-scoped [materialTreeExpansionProvider] and
// survives the dropdown reopening; closing the editor resets it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/ui/providers/material_tree_expansion_provider.dart';
import 'package:heating_planner/ui/widgets/material_picker.dart';

const _matAB = MaterialEntry(
  id: 'mat-ab',
  name: 'Material AB',
  categoryPath: ['A', 'B'],
  lambdaDefault: 0.10,
  densityDefault: 100,
  specificHeatDefault: 1000,
);

const _matABC = MaterialEntry(
  id: 'mat-abc',
  name: 'Material ABC',
  categoryPath: ['A', 'B', 'C'],
  lambdaDefault: 0.20,
  densityDefault: 200,
  specificHeatDefault: 1000,
);

const _matAD = MaterialEntry(
  id: 'mat-ad',
  name: 'Material AD',
  categoryPath: ['A', 'D'],
  lambdaDefault: 0.30,
  densityDefault: 300,
  specificHeatDefault: 1000,
);

const _all = [_matAB, _matABC, _matAD];

/// Mounts a [MaterialPicker] inside a single [ProviderScope] so the
/// editor-scoped expansion provider persists across rebuilds. A toggle
/// flag lets the test "close" and "reopen" the dropdown (unmount /
/// remount the picker) without tearing down the container.
class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _open = !_open),
                child: const Text('toggle-dropdown'),
              ),
              Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => ref
                      .read(materialTreeExpansionProvider.notifier)
                      .reset(),
                  child: const Text('close-editor'),
                ),
              ),
            ],
          ),
          if (_open)
            Expanded(
              child: MaterialPicker(
                onSelected: (_) {},
                onManageRequested: () {},
              ),
            ),
        ],
      ),
    );
  }
}

Widget _build() {
  return ProviderScope(
    overrides: [
      materialEntriesProvider.overrideWith((ref) => Stream.value(_all)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: const _Host(),
    ),
  );
}

void main() {
  testWidgets(
    'initial render shows only the top-level node "A" (collapsed)',
    (tester) async {
      await tester.pumpWidget(_build());
      await tester.pump();

      expect(find.text('A'), findsOneWidget);
      // Sub-nodes and materials are hidden until "A" is expanded.
      expect(find.text('B'), findsNothing);
      expect(find.text('D'), findsNothing);
      expect(find.text('Material AB'), findsNothing);
      // Collapsed node shows the ▶ chevron.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    },
  );

  testWidgets(
    'tapping "A" reveals sub-nodes "B" and "D" (still collapsed)',
    (tester) async {
      await tester.pumpWidget(_build());
      await tester.pump();

      await tester.tap(find.text('A'));
      await tester.pump();

      expect(find.text('B'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      // Their own children remain hidden.
      expect(find.text('C'), findsNothing);
      expect(find.text('Material AB'), findsNothing);
      expect(find.text('Material AD'), findsNothing);
    },
  );

  testWidgets(
    'tapping "B" reveals sub-node "C" before the material at ["A","B"]',
    (tester) async {
      await tester.pumpWidget(_build());
      await tester.pump();

      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('B'));
      await tester.pump();

      expect(find.text('C'), findsOneWidget);
      expect(find.text('Material AB'), findsOneWidget);
      // Sub-node "C" sorts above the material (sub-nodes before
      // materials, UI/UX §5.7.1 item 4).
      final cY = tester.getTopLeft(find.text('C')).dy;
      final matY = tester.getTopLeft(find.text('Material AB')).dy;
      expect(cY, lessThan(matY));
      // "C" is itself collapsed — its material is hidden.
      expect(find.text('Material ABC'), findsNothing);
    },
  );

  testWidgets(
    'searching "C" hides the tree and shows the leaf with breadcrumb '
    'subtitle "A › B › C"',
    (tester) async {
      await tester.pumpWidget(_build());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();

      // The tree node rows are gone in search mode.
      expect(find.text('A'), findsNothing);
      // The matching material renders with its full breadcrumb subtitle.
      expect(find.text('Material ABC'), findsOneWidget);
      expect(find.text('A › B › C'), findsOneWidget);
    },
  );

  testWidgets(
    'reopening the dropdown preserves expansion; closing the editor '
    'resets it',
    (tester) async {
      await tester.pumpWidget(_build());
      await tester.pump();

      // Expand A → B.
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(find.text('C'), findsOneWidget);

      // Close the dropdown (unmount the picker) and reopen it.
      await tester.tap(find.text('toggle-dropdown'));
      await tester.pump();
      expect(find.text('A'), findsNothing); // dropdown closed
      await tester.tap(find.text('toggle-dropdown'));
      await tester.pump();

      // Expansion survived: B's sub-node "C" is still visible.
      expect(find.text('C'), findsOneWidget);

      // Simulate closing the wall construction editor → reset.
      await tester.tap(find.text('close-editor'));
      await tester.pump();

      // Tree is back to fully collapsed: only "A" shows.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);
      expect(find.text('C'), findsNothing);
    },
  );
}
