// Widget tests for PropertiesPanel routing — agent-test.md §6.1.
//
// Covered scenarios:
//   PP-1  Null selection          → ProjectSummary is rendered.
//   PP-2  ('room', 'room-1')      → RoomProperties content appears.
//   PP-3  ('wall', 'wall-1')      → _WallInfo content appears.
//   PP-4  ('zone', 'zone-1')      → HeatingZoneProperties content appears.
//   PP-5  ('distributor','dist-1')→ DistributorProperties content appears.
//   PP-6  ('circuit','circuit-1') → CircuitProperties content appears.
//
// All heavy providers (repositories, DB, calculation engines) are overridden
// with stubs.  No database access occurs during these tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/flow_rate_providers.dart';
import 'package:heating_planner/calculation/providers/heat_demand_providers.dart';
import 'package:heating_planner/calculation/providers/heat_output_providers.dart';
import 'package:heating_planner/calculation/providers/pressure_loss_providers.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/repositories/heating_repository.dart';
import 'package:heating_planner/ui/panels/properties_panel.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Stub notifiers ────────────────────────────────────────────────────────────

/// Stub [SelectedElementNotifier] that always returns a fixed selection.
class _StubSelectionNotifier extends SelectedElementNotifier {
  _StubSelectionNotifier(this._fixed);
  final SelectedElement? _fixed;

  @override
  SelectedElement? build() => _fixed;
}

/// Stub [EditorStateNotifier] that works purely in memory — no DB access.
class _StubEditorNotifier extends EditorStateNotifier {
  _StubEditorNotifier(this._initial);
  final EditorState _initial;

  @override
  EditorState build() => _initial;

  @override
  void updateRoom(Room room) {
    state = state.copyWith(
      rooms: state.rooms.map((r) => r.id == room.id ? room : r).toList(),
    );
  }

  @override
  void updateZone(HeatingZone zone) {
    state = state.copyWith(
      zones: state.zones.map((z) => z.id == zone.id ? zone : z).toList(),
    );
  }

  @override
  void markProjectDirty() {}
}

// ── Shared test data ──────────────────────────────────────────────────────────

const _testRoom = Room(
  id: 'room-1',
  floorId: 'floor-1',
  name: 'Living Room',
  targetTempC: 21.0,
);

const _testWall = WallSegment(
  id: 'wall-1',
  roomId: 'room-1',
  startPoint: Point2D(x: 0, y: 0),
  endPoint: Point2D(x: 5000, y: 0),
  wallType: WallType.exterior,
  orientation: CardinalDirection.south,
);

const _testZone = HeatingZone(
  id: 'zone-1',
  roomId: 'room-1',
  tubeTypeId: 'tube-1',
  flooringMaterialId: 'floor-mat-1',
  tubeSpacingMm: 150,
  polygon: [
    Point2D(x: 0, y: 0),
    Point2D(x: 5000, y: 0),
    Point2D(x: 5000, y: 4000),
    Point2D(x: 0, y: 4000),
  ],
);

const _testDistributor = Distributor(
  id: 'dist-1',
  floorId: 'floor-1',
  position: Point2D(x: 500, y: 500),
  supplyTempC: 35.0,
  returnTempC: 28.0,
);

const _testCircuit = HeatingCircuit(
  id: 'circuit-1',
  distributorId: 'dist-1',
  heatingZoneId: 'zone-1',
);

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _buildPanel({
  required SelectedElement? selection,
  required EditorState editorState,
}) {
  return ProviderScope(
    overrides: [
      selectedElementProvider.overrideWith(
        () => _StubSelectionNotifier(selection),
      ),
      editorStateProvider.overrideWith(
        () => _StubEditorNotifier(editorState),
      ),
      // Calculation providers — return NaN / empty so rows show "—"
      roomHeatDemandProvider.overrideWith((ref, _) => double.nan),
      zoneHeatOutputProvider.overrideWith((ref, _) => double.nan),
      zoneSurfaceTempProvider.overrideWith((ref, _) => double.nan),
      flowRateProvider.overrideWith((ref, _) => double.nan),
      flowVelocityProvider.overrideWith((ref, _) => double.nan),
      pressureLossProvider.overrideWith((ref, _) async => double.nan),
      // Stream providers — return empty lists
      tubeTypesProvider.overrideWith((ref) => Stream.value([])),
      flooringMaterialsProvider.overrideWith((ref) => Stream.value([])),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: PropertiesPanel(),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // PP-1 ─────────────────────────────────────────────────────────────────────

  testWidgets(
    'PP-1: null selection renders ProjectSummary',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildPanel(
          selection: null,
          editorState: const EditorState(),
        ),
      );
      await tester.pump();

      expect(find.text('Project Summary'), findsOneWidget);
      expect(find.text('Total Heat Demand'), findsOneWidget);
    },
  );

  // PP-2 ─────────────────────────────────────────────────────────────────────

  testWidgets(
    'PP-2: room selection renders RoomProperties with room name',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildPanel(
          selection: const SelectedElement(type: 'room', id: 'room-1'),
          editorState: const EditorState(rooms: [_testRoom]),
        ),
      );
      await tester.pump();

      // Room name appears in the name text field value or heading
      expect(find.text('Living Room'), findsWidgets);
    },
  );

  // PP-3 ─────────────────────────────────────────────────────────────────────

  testWidgets(
    'PP-3: wall selection renders _WallInfo with "Wall Segment" heading',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildPanel(
          selection: const SelectedElement(type: 'wall', id: 'wall-1'),
          editorState: const EditorState(walls: [_testWall]),
        ),
      );
      await tester.pump();

      expect(find.text('Wall Segment'), findsOneWidget);
    },
  );

  // PP-4 ─────────────────────────────────────────────────────────────────────

  testWidgets(
    'PP-4: zone selection renders HeatingZoneProperties with "Heating Zone" heading',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildPanel(
          selection: const SelectedElement(type: 'zone', id: 'zone-1'),
          editorState: const EditorState(zones: [_testZone]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Heating Zone'), findsOneWidget);
    },
  );

  // PP-5 ─────────────────────────────────────────────────────────────────────

  testWidgets(
    'PP-5: distributor selection renders DistributorProperties with "Distributor" heading',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildPanel(
          selection: const SelectedElement(
            type: 'distributor',
            id: 'dist-1',
          ),
          editorState: const EditorState(distributor: _testDistributor),
        ),
      );
      await tester.pump();

      expect(find.text('Distributor'), findsOneWidget);
    },
  );

  // PP-6 ─────────────────────────────────────────────────────────────────────

  testWidgets(
    'PP-6: circuit selection renders CircuitProperties with "Heating Circuit" heading',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildPanel(
          selection: const SelectedElement(
            type: 'circuit',
            id: 'circuit-1',
          ),
          editorState: const EditorState(
            circuits: [_testCircuit],
            zones: [_testZone],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Heating Circuit'), findsOneWidget);
    },
  );
}
