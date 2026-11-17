// ADR-046 Rule 7: validation rule TP-01 — a manual tube path that leaves
// its zone, runs through another circuit's connection pipes or crosses
// itself is reported as a warning on the zone. Automatic layouts never are.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/heat_output_providers.dart';
import 'package:heating_planner/calculation/providers/hydraulic_balance_providers.dart';
import 'package:heating_planner/calculation/providers/tube_length_providers.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/validation_result.dart';
import 'package:heating_planner/repositories/heating_repository.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';
import 'package:heating_planner/validation/validation_service.dart';

class _StubEditorStateNotifier extends EditorStateNotifier {
  _StubEditorStateNotifier(this._fixed);
  final EditorState _fixed;

  @override
  EditorState build() => _fixed;
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

const _inside = [
  Point2D(x: 0, y: 200),
  Point2D(x: 3800, y: 200),
  Point2D(x: 3800, y: 350),
  Point2D(x: 0, y: 350),
];

List<ValidationResult> _tp01(HeatingZone zone) {
  final c = ProviderContainer(
    overrides: [
      editorStateProvider.overrideWith(
        () => _StubEditorStateNotifier(EditorState(zones: [zone])),
      ),
      tubeLengthProvider.overrideWith((ref, _) => double.nan),
      zoneSurfaceTempProvider.overrideWith((ref, _) => double.nan),
      hydraulicBalanceProvider.overrideWith((ref, _) async => {}),
      tubeTypesProvider.overrideWith((ref) => Stream.value([])),
    ],
  );
  addTearDown(c.dispose);
  return c
      .read(validationResultsProvider(''))
      .where((r) => r.message.startsWith('The hand-drawn tube path'))
      .toList();
}

void main() {
  test('an automatic layout is never reported', () {
    expect(_tp01(_zone), isEmpty);
  });

  test('a manual path inside the zone is not reported', () {
    expect(_tp01(_zone.copyWith(manualTubePath: _inside)), isEmpty);
  });

  test('a manual path leaving the zone is a warning on the zone', () {
    final outside = [..._inside]..[1] = const Point2D(x: 4500, y: 200);
    final results = _tp01(_zone.copyWith(manualTubePath: outside));
    expect(results, hasLength(1));
    expect(results.single.severity, WarningSeverity.warning);
    expect(results.single.elementId, 'zone-1');
    expect(results.single.message, contains('leaves the heating zone'));
  });

  test('a manual path crossing itself is reported', () {
    const crossing = [
      Point2D(x: 0, y: 200),
      Point2D(x: 3000, y: 200),
      Point2D(x: 3000, y: 1000),
      Point2D(x: 1000, y: 1000),
      Point2D(x: 1000, y: 0),
    ];
    final results = _tp01(_zone.copyWith(manualTubePath: crossing));
    expect(results.single.message, contains('crosses itself'));
  });
}
