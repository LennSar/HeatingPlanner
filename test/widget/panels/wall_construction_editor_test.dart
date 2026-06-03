// Widget tests for WallConstructionEditor — agent-test.md §6.1.
//
// Covered scenarios:
//   WCE-1  U-value (computed from one layer) is displayed in the summary row.
//   WCE-2  The initial material layer name appears in the layer list.
//   WCE-3  The "Add Layer" button is present.
//   WCE-4  Tapping "Add Layer" adds a new row to the layer list.
//   WCE-5  Changing a layer's thickness causes the displayed U-value to update.
//   WCE-6  Tapping the delete button on a layer removes that row.
//   WCE-7  A CustomPaint (temperature gradient bar) is present when layers exist.
//
// The dialog is opened via showWallConstructionEditor() to stay consistent
// with the production code path.  Only editorStateProvider is overridden;
// all calculations run through ThermalEngine static methods inline.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/material_entry.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/data/models/material_layer.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/wall_construction.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/repositories/material_repository.dart';
import 'package:heating_planner/ui/panels/wall_construction_editor.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Stub notifier ─────────────────────────────────────────────────────────────

/// In-memory [EditorStateNotifier] — skips all database and save-state I/O.
class _StubEditorNotifier extends EditorStateNotifier {
  _StubEditorNotifier(this._initial);
  final EditorState _initial;

  @override
  EditorState build() => _initial;

  @override
  void markProjectDirty() {}
}

// ── Test data ─────────────────────────────────────────────────────────────────

// Construction and its single layer:
//   material  = 'mat-001' → Solid brick, λ = 0.77 W/(m·K)
//   thickness = 200 mm  → 0.200 m
//   Rsi = 0.13, Rse = 0.04
//   R_total = 0.13 + 0.200/0.77 + 0.04 ≈ 0.4297
//   U       ≈ 2.327 W/(m²K)
const _cid = 'const-1';

const _testConstruction = WallConstruction(
  id: _cid,
  name: 'Test Wall',
  rsi: 0.13,
  rse: 0.04,
);

const _testLayer = MaterialLayer(
  id: 'layer-1',
  constructionId: _cid,
  sortOrder: 0,
  materialId: 'mat-001', // Solid brick
  thicknessMm: 200.0,
  thermalConductivity: 0.77,
  density: 1800,
  specificHeat: 900,
);

const _testWall = WallSegment(
  id: 'wall-1',
  roomId: 'room-1',
  startPoint: Point2D(x: 0, y: 0),
  endPoint: Point2D(x: 5000, y: 0),
  wallType: WallType.exterior,
  orientation: CardinalDirection.south,
  constructionId: _cid,
);

/// Wall without a constructionId — triggers the "New Construction" path
/// in the dialog, matching the scenario where the user opens the editor
/// for a wall that has no construction assigned yet.
const _testWallNew = WallSegment(
  id: 'wall-2',
  roomId: 'room-1',
  startPoint: Point2D(x: 0, y: 0),
  endPoint: Point2D(x: 5000, y: 0),
  wallType: WallType.exterior,
  orientation: CardinalDirection.south,
);

// ── Test material entry ───────────────────────────────────────────────────────

const _testMaterial = MaterialEntry(
  id: 'mat-001',
  name: 'Solid brick',
  categoryPath: ['Masonry'],
  lambdaDefault: 0.77,
  densityDefault: 1800,
  specificHeatDefault: 900,
);

// ── Widget builder ────────────────────────────────────────────────────────────

/// Renders a trigger button that opens the wall-construction dialog.
///
/// The [ProviderScope] wrapping the [MaterialApp] means the Navigator's
/// overlay — and therefore the dialog — inherit the same provider overrides.
Widget _buildTrigger({
  WallConstruction construction = _testConstruction,
  List<MaterialLayer> layers = const [_testLayer],
}) {
  final initialState = EditorState(
    constructions: [construction],
    materialLayers: layers,
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
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showWallConstructionEditor(ctx, _testWall),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

/// German-locale variant of [_buildTrigger].
Widget _buildTriggerDe({
  WallConstruction construction = _testConstruction,
  List<MaterialLayer> layers = const [_testLayer],
}) {
  final initialState = EditorState(
    constructions: [construction],
    materialLayers: layers,
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
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('de')],
      locale: const Locale('de'),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showWallConstructionEditor(ctx, _testWall),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

/// Builds the trigger with a custom [StreamProvider] override for
/// [materialEntriesProvider], allowing the test to control when and
/// what the stream emits.
Widget _buildTriggerWithStreamOverride({
  WallConstruction construction = _testConstruction,
  List<MaterialLayer> layers = const [_testLayer],
  required Stream<List<MaterialEntry>> materialStream,
  WallSegment wall = _testWall,
}) {
  final initialState = EditorState(
    constructions: [construction],
    materialLayers: layers,
  );
  return ProviderScope(
    overrides: [
      editorStateProvider.overrideWith(
        () => _StubEditorNotifier(initialState),
      ),
      materialEntriesProvider.overrideWith(
        (ref) => materialStream,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showWallConstructionEditor(ctx, wall),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

// ── Helper ────────────────────────────────────────────────────────────────────

/// Opens the dialog and waits for it to settle.
Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// Replaces the widget tree and drains pending timers so the
/// test framework does not complain about leaked timers from
/// the dialog's route animation or tooltip hover.
Future<void> _tearDownDialog(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() async {
    // Provide enough surface height for the constrained 700 px dialog.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // WCE-1 ────────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-1: U-value is displayed in the summary row',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildTrigger());
      await _openDialog(tester);

      // 200 mm Solid brick (λ=0.77) with Rsi=0.13, Rse=0.04
      // → U ≈ 2.327 W/(m²K)
      expect(find.textContaining('2.327'), findsOneWidget);
      await _tearDownDialog(tester);
    },
  );

  // WCE-2 ────────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-2: initial material layer name appears in the layer list',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildTrigger());
      await _openDialog(tester);

      // mat-001 is 'Solid brick' in the built-in catalogue.
      expect(find.text('Solid brick'), findsOneWidget);
      await _tearDownDialog(tester);
    },
  );

  // WCE-3 ────────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-3: "Add Layer" button is present',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildTrigger());
      await _openDialog(tester);

      expect(find.text('Add Layer'), findsOneWidget);
      await _tearDownDialog(tester);
    },
  );

  // WCE-4 ────────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-4: tapping "Add Layer" adds a new row to the layer list',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildTrigger());
      await _openDialog(tester);

      // One row before.
      expect(find.text('Solid brick'), findsOneWidget);

      await tester.tap(find.text('Add Layer'));
      await tester.pump();

      // The default new layer also uses mat-001 (Solid brick), so two rows.
      expect(find.text('Solid brick'), findsNWidgets(2));
      await _tearDownDialog(tester);
    },
  );

  // WCE-5 ────────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-5: changing a layer thickness updates the displayed U-value',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildTrigger());
      await _openDialog(tester);

      // Confirm initial U ≈ 2.327.
      expect(find.textContaining('2.327'), findsOneWidget);

      // The thickness field shows '200' (200.0.round().toString()).
      // Changing to 400 mm → R = 0.13 + 0.4/0.77 + 0.04 ≈ 0.6895
      //                      → U ≈ 1.450 W/(m²K).
      final thicknessField = find.widgetWithText(TextField, '200');
      await tester.enterText(thicknessField, '400');
      await tester.pump();

      expect(find.textContaining('1.450'), findsOneWidget);
      // Old value is gone.
      expect(find.textContaining('2.327'), findsNothing);
      await _tearDownDialog(tester);
    },
  );

  // WCE-6 ────────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-6: tapping the delete button removes the layer row',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildTrigger());
      await _openDialog(tester);

      expect(find.text('Solid brick'), findsOneWidget);

      // ADR-020 Rule 5: removing the *last* layer is disallowed.
      // Add a second layer first so we can exercise the delete path.
      await tester.tap(find.text('Add Layer'));
      await tester.pump();
      expect(find.text('Solid brick'), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();

      expect(find.text('Solid brick'), findsOneWidget);
      await _tearDownDialog(tester);
    },
  );

  // WCE-7 ────────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-7: CustomPaint (temperature gradient bar) is present when layers exist',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildTrigger());
      await _openDialog(tester);

      // The temperature profile bar requires profile.length >= 2, which is
      // satisfied by one layer (profile has indoor + outdoor + 1 interface = 3).
      expect(find.byType(CustomPaint), findsWidgets);
      await _tearDownDialog(tester);
    },
  );

  // WCE-4a ───────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-4a: tapping Add Layer works in German locale',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildTriggerDe());
      await _openDialog(tester);

      // One row before.
      expect(find.text('Solid brick'), findsOneWidget);

      // German localised button text: "Schicht hinzufügen"
      await tester.tap(find.text('Schicht hinzufügen'));
      await tester.pump();

      // The default new layer also uses mat-001 (Solid brick), so two rows.
      expect(find.text('Solid brick'), findsNWidgets(2));
      await _tearDownDialog(tester);
    },
  );

  // WCE-4b ───────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-4b: tapping Add Layer works when starting with zero layers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildTrigger(layers: const []));
      await _openDialog(tester);

      // No layer rows initially.
      expect(find.text('Solid brick'), findsNothing);

      // The Add Layer button should still be present.
      expect(find.text('Add Layer'), findsOneWidget);

      await tester.tap(find.text('Add Layer'));
      await tester.pump();

      // One layer row appears.
      expect(find.text('Solid brick'), findsOneWidget);
      await _tearDownDialog(tester);
    },
  );

  // WCE-4c ───────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-4c: Add Layer button onPressed is not null',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // TextButton.icon uses a private subclass, so find.byType(TextButton)
      // won't match.  Use an `is` predicate instead.
      Finder addLayerButton(String label) => find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is TextButton),
          );

      // English locale.
      await tester.pumpWidget(_buildTrigger());
      await _openDialog(tester);

      expect(addLayerButton('Add Layer'), findsOneWidget);
      expect(
        tester.widget<TextButton>(addLayerButton('Add Layer')).onPressed,
        isNotNull,
      );
      await _tearDownDialog(tester);

      // German locale.
      await tester.pumpWidget(_buildTriggerDe());
      await _openDialog(tester);

      expect(addLayerButton('Schicht hinzufügen'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(addLayerButton('Schicht hinzufügen'))
            .onPressed,
        isNotNull,
      );
      await _tearDownDialog(tester);
    },
  );

  // WCE-4d ───────────────────────────────────────────────────────────────────

  testWidgets(
    'WCE-4d: Add Layer works with async material delivery (StreamController)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = StreamController<List<MaterialEntry>>();
      addTearDown(controller.close);

      // Use a wall without constructionId — matches the real-app scenario
      // where the dialog displays "New Construction" with an empty layer
      // stack.  The material stream has NOT emitted yet.
      await tester.pumpWidget(
        _buildTriggerWithStreamOverride(
          layers: const [],
          materialStream: controller.stream,
          wall: _testWallNew,
        ),
      );
      await _openDialog(tester);

      // Dialog shows "New Construction" — no layers yet.
      expect(find.text('New Construction'), findsOneWidget);
      expect(find.text('Solid brick'), findsNothing);

      // Emit materials (simulates the database stream delivering data
      // after the dialog has already opened and rendered).
      controller.add(const [_testMaterial]);
      await tester.pumpAndSettle();

      // The provider has now received data via ref.watch in build().
      // Tapping Add Layer must add a layer using the materials that
      // build() already resolved — _addLayer must not independently
      // re-read the provider.
      await tester.tap(find.text('Add Layer'));
      await tester.pump();

      // A layer row must appear.
      expect(find.text('Solid brick'), findsOneWidget);
      await _tearDownDialog(tester);
    },
  );

  // ADR-020-WCE-A ────────────────────────────────────────────────────────────
  //
  // Rule 4: any layer-affecting mutation through the construction editor
  // flips the construction's `isAutoDefault` flag to `false` on save.
  // We pre-seed an `isAutoDefault: true` construction, open the editor,
  // add a layer (mutation), and then read state via the provider.

  testWidgets(
    'ADR-020-WCE-A: mutating layers flips isAutoDefault to false on save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const autoCid = 'auto-1';
      const autoConstruction = WallConstruction(
        id: autoCid,
        name: 'Auto-default exterior',
        isAutoDefault: true,
      );
      const autoLayer = MaterialLayer(
        id: 'auto-layer-1',
        constructionId: autoCid,
        sortOrder: 0,
        materialId: 'mat-001',
        thicknessMm: 240,
        thermalConductivity: 0.77,
        density: 1800,
        specificHeat: 900,
      );
      const autoWall = WallSegment(
        id: 'wall-auto',
        roomId: 'room-1',
        startPoint: Point2D(x: 0, y: 0),
        endPoint: Point2D(x: 5000, y: 0),
        wallType: WallType.exterior,
        orientation: CardinalDirection.south,
        thicknessMm: 240,
        anchorMode: WallAnchorMode.innerFace,
        constructionId: autoCid,
      );

      // Build a custom trigger so we can read the post-save state via
      // a captured ProviderContainer.
      const initialState = EditorState(
        walls: [autoWall],
        constructions: [autoConstruction],
        materialLayers: [autoLayer],
      );
      ProviderContainer? captured;
      Widget app = ProviderScope(
        overrides: [
          editorStateProvider.overrideWith(
            () => _StubEditorNotifier(initialState),
          ),
          materialEntriesProvider.overrideWith(
            (ref) => Stream.value(const [_testMaterial]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) {
                captured = ProviderScope.containerOf(ctx, listen: false);
                return ElevatedButton(
                  onPressed: () =>
                      showWallConstructionEditor(ctx, autoWall),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(app);
      await _openDialog(tester);

      // Mutation: add a second layer.
      await tester.tap(find.text('Add Layer'));
      await tester.pumpAndSettle();

      // Save: tap the FilledButton with the localized "Save" label.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final post = captured!.read(editorStateProvider);
      final saved = post.constructions
          .firstWhere((c) => c.id == autoCid);
      expect(
        saved.isAutoDefault,
        isFalse,
        reason: 'ADR-020 Rule 4: any layer mutation must clear isAutoDefault',
      );
      await _tearDownDialog(tester);
    },
  );

  // ADR-020-WCE-B ────────────────────────────────────────────────────────────
  //
  // Rule 4 — load-preset cleanup. When a preset is loaded over an
  // auto-default construction, the resulting wall.constructionId points
  // at a fresh non-auto-default copy and the original auto-default row
  // is deleted (orphaned).

  testWidgets(
    'ADR-020-WCE-B: loading a preset over an auto-default construction '
    'orphan-deletes the old row on save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const autoCid = 'auto-2';
      const presetCid = 'preset-1';
      const autoConstruction = WallConstruction(
        id: autoCid,
        name: 'Auto-default exterior',
        isAutoDefault: true,
      );
      const presetConstruction = WallConstruction(
        id: presetCid,
        name: 'Brick + EPS 16 cm',
        isPreset: true,
      );
      const autoLayer = MaterialLayer(
        id: 'auto-layer-2',
        constructionId: autoCid,
        sortOrder: 0,
        materialId: 'mat-001',
        thicknessMm: 240,
        thermalConductivity: 0.77,
        density: 1800,
        specificHeat: 900,
      );
      const presetLayer = MaterialLayer(
        id: 'preset-layer-1',
        constructionId: presetCid,
        sortOrder: 0,
        materialId: 'mat-001',
        thicknessMm: 380,
        thermalConductivity: 0.77,
        density: 1800,
        specificHeat: 900,
      );
      const autoWall = WallSegment(
        id: 'wall-auto-2',
        roomId: 'room-1',
        startPoint: Point2D(x: 0, y: 0),
        endPoint: Point2D(x: 5000, y: 0),
        wallType: WallType.exterior,
        orientation: CardinalDirection.south,
        thicknessMm: 240,
        anchorMode: WallAnchorMode.innerFace,
        constructionId: autoCid,
      );

      const initialState = EditorState(
        walls: [autoWall],
        constructions: [autoConstruction, presetConstruction],
        materialLayers: [autoLayer, presetLayer],
      );
      ProviderContainer? captured;
      Widget app = ProviderScope(
        overrides: [
          editorStateProvider.overrideWith(
            () => _StubEditorNotifier(initialState),
          ),
          materialEntriesProvider.overrideWith(
            (ref) => Stream.value(const [_testMaterial]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) {
                captured = ProviderScope.containerOf(ctx, listen: false);
                return ElevatedButton(
                  onPressed: () =>
                      showWallConstructionEditor(ctx, autoWall),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(app);
      await _openDialog(tester);

      // Tap "Load" then pick the preset.
      await tester.tap(find.text('Load'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Brick + EPS 16 cm'));
      await tester.pumpAndSettle();

      // Save.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final post = captured!.read(editorStateProvider);
      // The orphaned auto-default row must be gone.
      expect(
        post.constructions.where((c) => c.id == autoCid),
        isEmpty,
        reason: 'ADR-020 Rule 4: load-preset must delete the orphaned '
            'auto-default construction',
      );
      // The wall must point at a fresh non-auto-default copy with
      // non-auto-default flag and a brand-new id (≠ presetCid, ≠ autoCid).
      final wall =
          post.walls.firstWhere((w) => w.id == 'wall-auto-2');
      expect(wall.constructionId, isNot(autoCid));
      expect(wall.constructionId, isNot(presetCid));
      expect(wall.constructionId, isNotNull);
      final fresh =
          post.constructions.firstWhere((c) => c.id == wall.constructionId);
      expect(fresh.isAutoDefault, isFalse);
      expect(fresh.isPreset, isFalse);
      await _tearDownDialog(tester);
    },
  );
}
