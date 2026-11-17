// ADR-046: a manual tube path replaces the automatic layout, keeps its
// shape when the connection pipes move (only its ends follow them), and
// the tube length is measured along it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/geometry_engine.dart';
import 'package:heating_planner/calculation/engines/pipe_layout_engine.dart';
import 'package:heating_planner/calculation/providers/pipe_layout_providers.dart';
import 'package:heating_planner/calculation/providers/tube_length_providers.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/repositories/heating_repository.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

class _StubEditorNotifier extends EditorStateNotifier {
  _StubEditorNotifier(this._initial);
  final EditorState _initial;

  @override
  EditorState build() => _initial;

  void set(EditorState next) => state = next;
}

// 4 m × 3 m zone; the distributor stands 2 m to its left.
const _zone = HeatingZone(
  id: 'zone-1',
  roomId: 'room-1',
  polygon: [
    Point2D(x: 2000, y: 0),
    Point2D(x: 6000, y: 0),
    Point2D(x: 6000, y: 3000),
    Point2D(x: 2000, y: 3000),
  ],
  tubeSpacingMm: 150,
  borderDistanceMm: 100,
  tubeTypeId: 'tube-1',
  flooringMaterialId: 'mat-1',
  circuitId: 'circuit-1',
);

const _distributor = Distributor(
  id: 'dist-1',
  floorId: 'floor-1',
  position: Point2D(x: 0, y: 1500),
);

HeatingCircuit _circuitAtY(double y) => relaidConnectionPipes(
  const HeatingCircuit(
    id: 'circuit-1',
    distributorId: 'dist-1',
    heatingZoneId: 'zone-1',
  ),
  const [],
  centerline: [
    Point2D(x: 0, y: y),
    Point2D(x: 3000, y: y),
  ],
);

// A hand-drawn single loop: in at the left edge, across, back.
const _manual = [
  Point2D(x: 2000, y: 1450),
  Point2D(x: 5800, y: 1450),
  Point2D(x: 5800, y: 1550),
  Point2D(x: 2000, y: 1550),
];

ProviderContainer _container(EditorState state) {
  final container = ProviderContainer(
    overrides: [
      editorStateProvider.overrideWith(() => _StubEditorNotifier(state)),
      tubeTypesProvider.overrideWith((ref) => Stream.value([])),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a manual path replaces the automatic layout', () {
    final container = _container(
      EditorState(
        zones: [_zone.copyWith(manualTubePath: _manual)],
        circuits: [_circuitAtY(1500)],
        distributor: _distributor,
      ),
    );
    final corners = container.read(zoneTubeCornersProvider)['zone-1']!;
    expect(corners.length, _manual.length);
    expect(corners.sublist(1, 3), _manual.sublist(1, 3));
  });

  test('its ends follow the connection pipes, its corners stay', () {
    final container = _container(
      EditorState(
        zones: [_zone.copyWith(manualTubePath: _manual)],
        circuits: [_circuitAtY(1500)],
        distributor: _distributor,
      ),
    );
    final before = container.read(zoneTubeCornersProvider)['zone-1']!;

    final notifier =
        container.read(editorStateProvider.notifier) as _StubEditorNotifier;
    notifier.set(
      EditorState(
        zones: [_zone.copyWith(manualTubePath: _manual)],
        circuits: [_circuitAtY(1000)],
        distributor: _distributor,
      ),
    );
    final after = container.read(zoneTubeCornersProvider)['zone-1']!;

    expect(after.first, isNot(before.first));
    expect(after.first.y, lessThan(before.first.y));
    expect(after.sublist(1, 3), _manual.sublist(1, 3));
  });

  test('tube length is measured along the manual path', () {
    final container = _container(
      EditorState(
        zones: [_zone.copyWith(manualTubePath: _manual)],
        circuits: [_circuitAtY(1500)],
        distributor: _distributor,
      ),
    );
    final corners = container.read(zoneTubeCornersProvider)['zone-1']!;
    final expectedM =
        GeometryEngine.polylineLengthMm(
          PipeLayoutEngine.filletPolyline(
            corners,
            PipeLayoutEngine.minBendRadiusMm(fallbackTubeOuterDiameterMm),
          ),
        ) /
        1000.0;
    expect(
      container.read(zoneTubeLengthProvider('zone-1')),
      closeTo(expectedM, 1e-9),
    );
    // Much shorter than the automatic serpentine filling the zone.
    final auto = _container(
      EditorState(
        zones: const [_zone],
        circuits: [_circuitAtY(1500)],
        distributor: _distributor,
      ),
    ).read(zoneTubeLengthProvider('zone-1'));
    expect(expectedM, lessThan(auto / 4));
  });

  test('issues are reported only for manual paths', () {
    final outside = [..._manual]..[1] = const Point2D(x: 6500, y: 1450);
    final container = _container(
      EditorState(
        zones: [
          _zone.copyWith(manualTubePath: outside),
          _zone.copyWith(id: 'zone-2', circuitId: null),
        ],
        circuits: [_circuitAtY(1500)],
        distributor: _distributor,
      ),
    );
    expect(
      container.read(manualTubePathIssuesProvider('zone-1')).leavesZone,
      isTrue,
    );
    expect(
      container.read(manualTubePathIssuesProvider('zone-2')).leavesZone,
      isFalse,
    );
  });
}
