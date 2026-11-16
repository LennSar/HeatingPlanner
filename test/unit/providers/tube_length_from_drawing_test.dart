// ADR-042 Rule 4: tube lengths are measured along the drawing — the tube
// laid out in the zone plus the connection pipes — not estimated from
// area ÷ spacing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/geometry_engine.dart';
import 'package:heating_planner/calculation/engines/hydraulic_engine.dart';
import 'package:heating_planner/calculation/engines/pipe_layout_engine.dart';
import 'package:heating_planner/calculation/providers/pipe_layout_providers.dart';
import 'package:heating_planner/calculation/providers/tube_length_providers.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/enums.dart';
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

// Route: straight east from the distributor, 1 m into the zone.
final _circuit = relaidConnectionPipes(
  const HeatingCircuit(
    id: 'circuit-1',
    distributorId: 'dist-1',
    heatingZoneId: 'zone-1',
  ),
  const [],
  centerline: const [Point2D(x: 0, y: 1500), Point2D(x: 3000, y: 1500)],
);

ProviderContainer _container(EditorState state) {
  final container = ProviderContainer(
    overrides: [
      editorStateProvider.overrideWith(() => _StubEditorNotifier(state)),
      // No tube catalogue → the 16 mm fallback, bend radius 80 mm.
      tubeTypesProvider.overrideWith((ref) => Stream.value([])),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('connectionPipeLengthsM measures each pipe up to the zone boundary', () {
    final lengths = connectionPipeLengthsM(
      _circuit,
      zone: _zone,
      bendRadiusMm: 80,
    );
    // Supply: 50 mm stub at the distributor, then 2 m to the zone edge;
    // the corner between them is rounded, so slightly under 2.05 m.
    expect(lengths.supplyM, closeTo(2.05, 0.03));
    expect(lengths.supplyM, lessThan(2.05));
    expect(lengths.returnM, closeTo(lengths.supplyM, 1e-9));

    // Without a zone the whole polylines are measured (1 m more each).
    final full = connectionPipeLengthsM(_circuit, bendRadiusMm: 80);
    expect(full.supplyM, closeTo(lengths.supplyM + 1.0, 1e-6));
  });

  test('zone tube length is the length of the drawn tube', () {
    final container = _container(
      EditorState(
        zones: const [_zone],
        circuits: [_circuit],
        distributor: _distributor,
      ),
    );

    final drawn = container.read(zonePipeLayoutsProvider)['zone-1']!.pipePath;
    expect(drawn.length, greaterThan(10));
    expect(
      container.read(zoneTubeLengthProvider('zone-1')),
      closeTo(GeometryEngine.polylineLengthMm(drawn) / 1000.0, 1e-9),
    );

    // The tube starts where the supply pipe enters the zone and ends
    // where the return pipe leaves it.
    expect(drawn.first, const Point2D(x: 2000, y: 1550));
    expect(drawn.last, const Point2D(x: 2000, y: 1450));
  });

  test('it is not the area ÷ spacing estimate', () {
    final container = _container(
      EditorState(
        zones: const [_zone],
        circuits: [_circuit],
        distributor: _distributor,
      ),
    );
    final estimate = HydraulicEngine.zoneTubeLength(
      zoneAreaM2: 12.0,
      perimeterM: 14.0,
      tubeSpacingMm: 150,
      borderDistanceMm: 100,
    );
    final drawn = container.read(zoneTubeLengthProvider('zone-1'));
    expect((drawn - estimate).abs(), greaterThan(0.5));
    // … but of the same order: a 12 m² zone at 150 mm.
    expect(drawn, inInclusiveRange(65, 90));
  });

  test('circuit length = supply pipe + tube in the zone + return pipe', () {
    final container = _container(
      EditorState(
        zones: const [_zone],
        circuits: [_circuit],
        distributor: _distributor,
      ),
    );
    final pipes = connectionPipeLengthsM(
      _circuit,
      zone: _zone,
      bendRadiusMm: 80,
    );
    expect(
      container.read(tubeLengthProvider('circuit-1')),
      closeTo(
        pipes.supplyM +
            container.read(zoneTubeLengthProvider('zone-1')) +
            pipes.returnM,
        1e-9,
      ),
    );
  });

  test('the length follows the drawing: another layout pattern, another '
      'length', () {
    final lengths = <LayoutPattern, double>{};
    for (final pattern in LayoutPattern.values) {
      final container = _container(
        EditorState(
          zones: [_zone.copyWith(layoutPattern: pattern)],
          circuits: [_circuit],
          distributor: _distributor,
        ),
      );
      final drawn = container.read(zonePipeLayoutsProvider)['zone-1']!.pipePath;
      lengths[pattern] = container.read(zoneTubeLengthProvider('zone-1'));
      expect(drawn, isNotEmpty, reason: '${pattern.name} must draw a tube');
      expect(
        lengths[pattern],
        greaterThan(50),
        reason: '${pattern.name} must have a length',
      );
    }
    expect(
      lengths[LayoutPattern.counterflow],
      isNot(closeTo(lengths[LayoutPattern.meander]!, 0.01)),
    );
  });

  test('the length follows the drawing: a longer connection pipe adds '
      'exactly its extra length', () {
    final container = _container(
      EditorState(
        zones: const [_zone],
        circuits: [_circuit],
        distributor: _distributor,
      ),
    );
    final before = container.read(tubeLengthProvider('circuit-1'));

    // Same route, started 1 m further west.
    final longer = relaidConnectionPipes(
      _circuit,
      const [],
      centerline: const [Point2D(x: -1000, y: 1500), Point2D(x: 3000, y: 1500)],
    );
    (container.read(editorStateProvider.notifier) as _StubEditorNotifier).set(
      EditorState(
        zones: const [_zone],
        circuits: [longer],
        distributor: _distributor,
      ),
    );
    expect(
      container.read(tubeLengthProvider('circuit-1')),
      closeTo(before + 2.0, 1e-6), // 1 m supply + 1 m return
    );
  });

  test('the drawn tube carries bend radii, so it is shorter than its '
      'corner polyline', () {
    final container = _container(
      EditorState(
        zones: const [_zone],
        circuits: [_circuit],
        distributor: _distributor,
      ),
    );
    final corners = PipeLayoutEngine.tubePath(
      pattern: LayoutPattern.meander,
      polygon: _zone.polygon,
      tubeSpacingMm: 150,
      borderDistanceMm: 100,
      entryPoint: const Point2D(x: 2000, y: 1550),
      exitPoint: const Point2D(x: 2000, y: 1450),
    );
    expect(
      container.read(zoneTubeLengthProvider('zone-1')),
      lessThan(GeometryEngine.polylineLengthMm(corners) / 1000.0),
    );
  });

  test('unknown ids give NaN; a zone too small for any tube gives 0', () {
    final container = _container(
      EditorState(
        zones: [
          _zone.copyWith(
            id: 'tiny',
            polygon: const [
              Point2D(x: 0, y: 0),
              Point2D(x: 250, y: 0),
              Point2D(x: 250, y: 250),
              Point2D(x: 0, y: 250),
            ],
          ),
        ],
      ),
    );
    expect(container.read(zoneTubeLengthProvider('nope')).isNaN, isTrue);
    expect(container.read(tubeLengthProvider('nope')).isNaN, isTrue);
    expect(container.read(zoneTubeLengthProvider('tiny')), 0.0);
  });

  test('neighbouring zones get different identity colours', () {
    final container = _container(
      EditorState(
        zones: [
          _zone,
          _zone.copyWith(
            id: 'zone-2',
            polygon: const [
              Point2D(x: 6000, y: 0),
              Point2D(x: 9000, y: 0),
              Point2D(x: 9000, y: 3000),
              Point2D(x: 6000, y: 3000),
            ],
          ),
        ],
      ),
    );
    final indices = container.read(zoneColorIndicesProvider);
    expect(indices.keys, containsAll(<String>['zone-1', 'zone-2']));
    expect(indices['zone-1'], isNot(indices['zone-2']));
  });
}
