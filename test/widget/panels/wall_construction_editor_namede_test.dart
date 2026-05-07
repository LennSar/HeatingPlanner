// Round-trip test for the v15 German-name field on the wall construction
// editor.
//
//   WCE-NDE-1  Editor pre-fills the German name field from
//              `WallConstruction.nameDe` when reopened, and persists
//              empty input as null (not '').
//   WCE-NDE-2  Editor persists a typed German name when Save is pressed
//              and round-trips on reopen.
//
// Per agent-test.md §6.1 these run as widget tests through the
// production code path (`showWallConstructionEditor`) so the test
// validates the controllers, the save handler, and the editor's
// re-init path together.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/data/models/material_layer.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/wall_construction.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/ui/panels/wall_construction_editor.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Stub notifier — keeps writes in-memory only ───────────────────────────────

/// Editor-state notifier that mutates state directly and skips every
/// repository write. The production [EditorStateNotifier] writes to
/// the DAO via `unawaited(upsertConstruction(...))`, which would
/// require an in-memory database; for this round-trip we only need
/// the in-memory state path.
class _StubEditorNotifier extends EditorStateNotifier {
  _StubEditorNotifier(this._initial);
  final EditorState _initial;

  @override
  EditorState build() => _initial;

  @override
  void markProjectDirty() {}

  @override
  void addConstruction(WallConstruction construction) {
    state = state.copyWith(
      constructions: [...state.constructions, construction],
    );
  }

  @override
  void updateConstruction(WallConstruction construction) {
    state = state.copyWith(
      constructions: state.constructions
          .map((c) => c.id == construction.id ? construction : c)
          .toList(),
    );
  }

  @override
  void replaceLayersForConstruction(
    String constructionId,
    List<MaterialLayer> newLayers,
  ) {
    final retained = state.materialLayers
        .where((l) => l.constructionId != constructionId)
        .toList();
    state = state.copyWith(
      materialLayers: [...retained, ...newLayers],
    );
  }

  @override
  void updateWall(WallSegment wall) {
    state = state.copyWith(
      walls: state.walls
          .map((w) => w.id == wall.id ? wall : w)
          .toList(),
    );
  }
}

// ── Test fixtures ─────────────────────────────────────────────────────────────

const _cid = 'wce-nde-construction';

const _layer = MaterialLayer(
  id: 'wce-nde-layer',
  constructionId: _cid,
  sortOrder: 0,
  materialId: 'mat-001',
  thicknessMm: 200,
  thermalConductivity: 0.77,
  density: 1800,
  specificHeat: 900,
);

const _wall = WallSegment(
  id: 'wce-nde-wall',
  roomId: 'wce-nde-room',
  startPoint: Point2D(x: 0, y: 0),
  endPoint: Point2D(x: 5000, y: 0),
  wallType: WallType.exterior,
  orientation: CardinalDirection.south,
  constructionId: _cid,
);

const _testMaterial = MaterialEntry(
  id: 'mat-001',
  name: 'Solid brick',
  category: 'Masonry',
  lambdaDefault: 0.77,
  densityDefault: 1800,
  specificHeatDefault: 900,
);

ProviderContainer? _capturedContainer;

Widget _buildTrigger({required WallConstruction initialConstruction}) {
  final initialState = EditorState(
    constructions: [initialConstruction],
    materialLayers: const [_layer],
    walls: const [_wall],
  );
  return ProviderScope(
    overrides: [
      editorStateProvider.overrideWith(
        () => _StubEditorNotifier(initialState),
      ),
      materialEntriesProvider.overrideWith(
        (ref) => Stream.value(const [_testMaterial]),
      ),
    ],
    child: Consumer(
      builder: (ctx, ref, _) {
        // Capture the container so the test can read the editor state
        // directly after Save closes the dialog.
        _capturedContainer = ProviderScope.containerOf(ctx);
        return MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () =>
                    showWallConstructionEditor(innerCtx, _wall),
                child: const Text('Open'),
              ),
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

Future<void> _tearDownDialog(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

WallConstruction _readConstruction(ProviderContainer c) =>
    c.read(editorStateProvider).constructions.firstWhere(
          (x) => x.id == _cid,
        );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'WCE-NDE-1: editor opens with empty German-name field for a '
    'construction whose nameDe is null',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const initial = WallConstruction(
        id: _cid,
        name: 'Brick wall',
      );
      await tester.pumpWidget(
        _buildTrigger(initialConstruction: initial),
      );
      await _openDialog(tester);

      // The English name is pre-filled.
      expect(find.widgetWithText(TextField, 'Brick wall'), findsOneWidget);

      // Locate the German-name TextField via its label and verify it
      // is empty rather than showing the English fallback.
      final germanField = tester.widget<TextField>(
        find.ancestor(
          of: find.text('German name'),
          matching: find.byType(TextField),
        ),
      );
      expect(germanField.controller!.text, '');

      await _tearDownDialog(tester);
    },
  );

  testWidgets(
    'WCE-NDE-2: typing a German name and saving persists nameDe; '
    'reopening the editor pre-fills both fields',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const initial = WallConstruction(
        id: _cid,
        name: 'Brick wall',
      );
      await tester.pumpWidget(
        _buildTrigger(initialConstruction: initial),
      );
      await _openDialog(tester);

      // Pre-condition: nameDe is null in state.
      expect(_readConstruction(_capturedContainer!).nameDe, isNull);

      // Type a German translation into the German-name field.
      await tester.enterText(
        find.ancestor(
          of: find.text('German name'),
          matching: find.byType(TextField),
        ),
        'Ziegelwand',
      );
      await tester.pump();

      // Save and dismiss.
      await _tapSave(tester);

      // State should now carry nameDe = 'Ziegelwand'.
      final afterSave = _readConstruction(_capturedContainer!);
      expect(afterSave.name, 'Brick wall');
      expect(afterSave.nameDe, 'Ziegelwand');

      // Re-open the editor; both fields should be pre-filled.
      await _openDialog(tester);

      expect(
        find.widgetWithText(TextField, 'Brick wall'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Ziegelwand'),
        findsOneWidget,
      );

      await _tearDownDialog(tester);
    },
  );

  testWidgets(
    'WCE-NDE-3: clearing the German-name field persists nameDe as null, '
    'not as the empty string',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const initial = WallConstruction(
        id: _cid,
        name: 'Brick wall',
        nameDe: 'Ziegelwand',
      );
      await tester.pumpWidget(
        _buildTrigger(initialConstruction: initial),
      );
      await _openDialog(tester);

      // Clear the German-name field (empty string + whitespace both
      // round-trip to null per the v15 editor contract).
      await tester.enterText(
        find.ancestor(
          of: find.text('German name'),
          matching: find.byType(TextField),
        ),
        '   ',
      );
      await tester.pump();

      await _tapSave(tester);

      final afterSave = _readConstruction(_capturedContainer!);
      expect(afterSave.name, 'Brick wall');
      expect(
        afterSave.nameDe,
        isNull,
        reason: 'whitespace-only input must persist as NULL, not "" or "   "',
      );

      await _tearDownDialog(tester);
    },
  );
}
