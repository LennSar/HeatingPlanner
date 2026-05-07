// Tests covering the wall-construction editor's behaviour around
// the localised display name column.
//
// Prompt 6 added a "German name" / "Deutscher Name" field directly to
// the editor. Prompt 8 reverted that decision: the editor again
// surfaces a single name field, and the `wall_constructions.name_de`
// column is written by other code paths (built-in seed, .hsp import,
// localised provider). The editor must NOT clobber an existing
// German name when the user saves an unrelated change.
//
//   WCE-NDE-1  The editor renders only one name field — no German /
//              Deutscher labels appear and the existing `nameDe`
//              value is not exposed as a user-editable string.
//   WCE-NDE-2  Editing the canonical name and saving preserves the
//              row's pre-existing `nameDe`; reopening shows the same
//              persisted value.

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
/// require an in-memory database; the localised-name preservation
/// contract only depends on the in-memory state path.
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
        // Capture the container so the test can read editor state
        // directly after Save closes the dialog.
        _capturedContainer = ProviderScope.containerOf(ctx);
        return MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en'), Locale('de')],
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
    'WCE-NDE-1: editor renders a single name field — no localised-name '
    'label is visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The construction starts with a localised display name set by
      // some other code path (built-in seed / .hsp import / earlier
      // build with the deprecated field).
      const initial = WallConstruction(
        id: _cid,
        name: 'Brick wall',
        nameDe: 'Ziegelwand',
      );
      await tester.pumpWidget(
        _buildTrigger(initialConstruction: initial),
      );
      await _openDialog(tester);

      // The canonical name field is pre-filled.
      expect(find.widgetWithText(TextField, 'Brick wall'), findsOneWidget);

      // The localised display value must NOT be surfaced as an
      // editable field, and neither label variant may appear.
      expect(find.widgetWithText(TextField, 'Ziegelwand'), findsNothing);
      expect(find.text('German name'), findsNothing);
      expect(find.text('Deutscher Name'), findsNothing);

      await _tearDownDialog(tester);
    },
  );

  testWidgets(
    'WCE-NDE-2: editing the canonical name and saving preserves the '
    'row\'s pre-existing localised display name',
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

      // Edit the canonical name only.
      await tester.enterText(
        find.widgetWithText(TextField, 'Brick wall'),
        'Brick wall (renamed)',
      );
      await tester.pump();

      await _tapSave(tester);

      // The edit lands and the localised display value is untouched.
      final afterSave = _readConstruction(_capturedContainer!);
      expect(afterSave.name, 'Brick wall (renamed)');
      expect(
        afterSave.nameDe,
        'Ziegelwand',
        reason:
            'Saving from this editor must preserve any pre-existing '
            'localised display name written by other code paths.',
      );

      // Reopening shows the new canonical name; the localised value
      // is still in state but never surfaced in the UI.
      await _openDialog(tester);
      expect(
        find.widgetWithText(TextField, 'Brick wall (renamed)'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'Ziegelwand'), findsNothing);

      await _tearDownDialog(tester);
    },
  );
}
