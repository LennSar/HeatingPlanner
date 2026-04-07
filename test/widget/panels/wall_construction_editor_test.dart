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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/material_layer.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/wall_construction.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
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
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
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

// ── Helper ────────────────────────────────────────────────────────────────────

/// Opens the dialog and waits for it to settle.
Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
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

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(find.text('Solid brick'), findsNothing);
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
    },
  );
}
