// ADR-046 Rule 6: the "Tube path" section of the floor zone panel.
//
//   ZT-1  an automatic zone: status, Edit / Draw switch tools, no Reset
//   ZT-2  a manual zone: status, pattern hint, Reset (undoable)
//   ZT-3  choosing a pattern on a manual zone resets it to automatic
//   ZT-4  the snap switch updates the preference
//   ZT-5  wall zones have no tube path section

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/flow_rate_providers.dart';
import 'package:heating_planner/calculation/providers/heat_output_providers.dart';
import 'package:heating_planner/calculation/providers/pressure_loss_providers.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:heating_planner/repositories/heating_repository.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';
import 'package:heating_planner/ui/panels/heating_zone_properties.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';
import 'package:heating_planner/ui/screens/editor_screen.dart';

class _StubEditorNotifier extends EditorStateNotifier {
  _StubEditorNotifier(this._initial);
  final EditorState _initial;

  @override
  EditorState build() => _initial;

  @override
  void updateZone(HeatingZone zone) {
    state = state.copyWith(
      zones: state.zones.map((z) => z.id == zone.id ? zone : z).toList(),
    );
  }

  @override
  void markProjectDirty() {}
}

class _StubSnapNotifier extends TubeSnapEnabledNotifier {
  @override
  Future<bool> build() async => true;

  @override
  Future<void> set(bool enabled) async => state = AsyncValue.data(enabled);
}

const _zone = HeatingZone(
  id: 'zone-1',
  roomId: 'room-1',
  tubeTypeId: 'tube-1',
  flooringMaterialId: 'mat-1',
  polygon: [
    Point2D(x: 0, y: 0),
    Point2D(x: 4000, y: 0),
    Point2D(x: 4000, y: 3000),
    Point2D(x: 0, y: 3000),
  ],
);

const _manual = [
  Point2D(x: 0, y: 200),
  Point2D(x: 3800, y: 200),
  Point2D(x: 3800, y: 350),
  Point2D(x: 0, y: 350),
];

Future<ProviderContainer> _pump(WidgetTester tester, HeatingZone zone) async {
  await tester.binding.setSurfaceSize(const Size(800, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      editorStateProvider.overrideWith(
        () => _StubEditorNotifier(EditorState(zones: [zone])),
      ),
      tubeSnapEnabledProvider.overrideWith(_StubSnapNotifier.new),
      zoneHeatOutputProvider.overrideWith((ref, _) => double.nan),
      zoneSurfaceTempProvider.overrideWith((ref, _) => double.nan),
      flowRateProvider.overrideWith((ref, _) => double.nan),
      flowVelocityProvider.overrideWith((ref, _) => double.nan),
      pressureLossProvider.overrideWith((ref, _) async => double.nan),
      tubeTypesProvider.overrideWith((ref) => Stream.value([])),
      flooringMaterialsProvider.overrideWith((ref) => Stream.value([])),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const Scaffold(
          body: SingleChildScrollView(
            child: HeatingZoneProperties(zoneId: 'zone-1'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

HeatingZone _current(ProviderContainer c) =>
    c.read(editorStateProvider).zones.single;

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ZT-1 automatic zone: Edit and Draw switch tools', (
    tester,
  ) async {
    final c = await _pump(tester, _zone);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.zoneTubePathAutomatic), findsOneWidget);
    expect(find.byKey(const Key('zone-tube-reset')), findsNothing);
    expect(find.byKey(const Key('zone-tube-pattern-ignored')), findsNothing);

    await _tap(tester, const Key('zone-tube-edit'));
    expect(c.read(selectedToolProvider), DrawingTool.editTube);
    await _tap(tester, const Key('zone-tube-draw'));
    expect(c.read(selectedToolProvider), DrawingTool.drawTube);
  });

  testWidgets('ZT-2 manual zone: Reset makes it automatic, undo restores', (
    tester,
  ) async {
    final c = await _pump(tester, _zone.copyWith(manualTubePath: _manual));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.zoneTubePathManual), findsOneWidget);
    expect(find.byKey(const Key('zone-tube-pattern-ignored')), findsOneWidget);

    await _tap(tester, const Key('zone-tube-reset'));
    expect(_current(c).manualTubePath, isNull);
    expect(find.text(l10n.zoneTubePathAutomatic), findsOneWidget);

    c.read(undoRedoProvider).undo();
    expect(_current(c).manualTubePath, _manual);
  });

  testWidgets('ZT-3 choosing a pattern resets a manual tube', (tester) async {
    final c = await _pump(tester, _zone.copyWith(manualTubePath: _manual));

    await _tap(tester, const ValueKey('layout-pattern-counterflow'));
    expect(_current(c).layoutPattern, LayoutPattern.counterflow);
    expect(_current(c).manualTubePath, isNull);
  });

  testWidgets('ZT-4 the snap switch updates the preference', (tester) async {
    final c = await _pump(tester, _zone);
    expect(c.read(tubeSnapEnabledProvider).value, isTrue);

    await _tap(tester, const Key('zone-tube-snap'));
    expect(c.read(tubeSnapEnabledProvider).value, isFalse);
  });

  testWidgets('ZT-5 wall zones have no tube path section', (tester) async {
    await _pump(
      tester,
      _zone.copyWith(zoneType: ZoneType.wallHeating, wallSegmentId: 'w'),
    );
    expect(find.byKey(const Key('zone-tube-edit')), findsNothing);
  });
}
