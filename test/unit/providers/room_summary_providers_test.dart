// Room summary (ADR-045): per-room heat balance, hydraulics and tube
// lengths collected from the calculation providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/flow_rate_providers.dart';
import 'package:heating_planner/calculation/providers/heat_demand_providers.dart';
import 'package:heating_planner/calculation/providers/heat_output_providers.dart';
import 'package:heating_planner/calculation/providers/pressure_loss_providers.dart';
import 'package:heating_planner/calculation/providers/room_summary_providers.dart';
import 'package:heating_planner/calculation/providers/tube_length_providers.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/tube_type.dart';
import 'package:heating_planner/repositories/heating_repository.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

import '../../helpers/test_factories.dart';

class _StubEditorNotifier extends EditorStateNotifier {
  _StubEditorNotifier(this._initial);
  final EditorState _initial;

  @override
  EditorState build() => _initial;
}

ZoneSummary _zone({
  String id = 'z',
  double outputW = double.nan,
  double flowRateKgH = double.nan,
  double pressureLossPa = double.nan,
  double zoneTubeLengthM = double.nan,
  double totalTubeLengthM = double.nan,
}) => (
  zoneId: id,
  circuitId: outputW.isNaN ? null : 'c-$id',
  circuitNumber: outputW.isNaN ? null : 1,
  zoneType: ZoneType.floorHeating,
  areaM2: 10,
  supplyTempC: 35,
  returnTempC: 28,
  specificOutputWPerM2: outputW / 10,
  outputW: outputW,
  surfaceTempC: 25,
  flowRateKgH: flowRateKgH,
  velocityMPerS: 0.2,
  tubeOuterDiameterMm: 16,
  tubeWallThicknessMm: 2,
  pressureLossPa: pressureLossPa,
  zoneTubeLengthM: zoneTubeLengthM,
  totalTubeLengthM: totalTubeLengthM,
);

RoomSummary _room(double demandW, List<ZoneSummary> zones) => summariseRoom(
  roomId: 'r',
  name: 'Room',
  isHeated: true,
  targetTempC: 20,
  demandW: demandW,
  zones: zones,
);

void main() {
  group('summariseRoom', () {
    test('adds up the zones and takes the highest pressure loss', () {
      final room = _room(900, [
        _zone(
          id: 'a',
          outputW: 600,
          flowRateKgH: 70,
          pressureLossPa: 8000,
          zoneTubeLengthM: 60,
          totalTubeLengthM: 72,
        ),
        _zone(
          id: 'b',
          outputW: 500,
          flowRateKgH: 60,
          pressureLossPa: 12000,
          zoneTubeLengthM: 50,
          totalTubeLengthM: 58,
        ),
      ]);

      expect(room.outputW, 1100);
      expect(room.balanceW, 200);
      expect(room.flowRateKgH, 130);
      expect(room.maxPressureLossPa, 12000);
      expect(room.zoneTubeLengthM, 110);
      expect(room.totalTubeLengthM, 130);
    });

    test('an unconnected zone delivers nothing but its tube still counts', () {
      final room = _room(900, [
        _zone(id: 'a', outputW: 600, zoneTubeLengthM: 60, totalTubeLengthM: 72),
        _zone(id: 'b', zoneTubeLengthM: 50),
      ]);

      expect(room.outputW, 600);
      expect(room.balanceW, -300);
      expect(room.zoneTubeLengthM, 110);
      expect(room.totalTubeLengthM, 72);
    });

    test('a room without zones is short by its whole demand', () {
      final room = _room(450, const []);

      expect(room.outputW, 0);
      expect(room.balanceW, -450);
      expect(room.flowRateKgH.isNaN, isTrue);
      expect(room.maxPressureLossPa.isNaN, isTrue);
      expect(room.zoneTubeLengthM.isNaN, isTrue);
    });

    test('an unknown demand gives no balance', () {
      final room = _room(double.nan, [_zone(outputW: 600)]);

      expect(room.outputW, 600);
      expect(room.balanceW.isNaN, isTrue);
    });
  });

  group('summariseFloor', () {
    test('totals the rooms; pressure loss is the highest circuit', () {
      final floor = summariseFloor([
        _room(900, [
          _zone(outputW: 1000, flowRateKgH: 120, pressureLossPa: 9000),
        ]),
        _room(500, [
          _zone(outputW: 300, flowRateKgH: 40, pressureLossPa: 15000),
        ]),
      ]);

      expect(floor.demandW, 1400);
      expect(floor.outputW, 1300);
      expect(floor.balanceW, -100);
      expect(floor.flowRateKgH, 160);
      expect(floor.maxPressureLossPa, 15000);
      expect(floor.demandIncomplete, isFalse);
    });

    test('flags rooms whose demand is unknown and leaves them out', () {
      final floor = summariseFloor([
        _room(900, [_zone(outputW: 1000)]),
        _room(double.nan, [_zone(outputW: 300)]),
      ]);

      expect(floor.demandIncomplete, isTrue);
      expect(floor.demandW, 900);
      expect(floor.outputW, 1300);
    });
  });

  group('floorSummaryProvider', () {
    const zone = HeatingZone(
      id: 'zone-1',
      roomId: 'room-1',
      polygon: [
        Point2D(x: 0, y: 0),
        Point2D(x: 4000, y: 0),
        Point2D(x: 4000, y: 3000),
        Point2D(x: 0, y: 3000),
      ],
      tubeTypeId: 'tube-1',
      flooringMaterialId: 'mat-1',
      circuitId: 'circuit-1',
    );
    const loose = HeatingZone(
      id: 'zone-2',
      roomId: 'room-1',
      tubeTypeId: 'tube-1',
      flooringMaterialId: 'mat-1',
    );
    const circuit = HeatingCircuit(
      id: 'circuit-1',
      distributorId: 'dist-1',
      heatingZoneId: 'zone-1',
    );
    const distributor = Distributor(
      id: 'dist-1',
      floorId: 'floor-1',
      position: Point2D(x: -1000, y: 0),
      supplyTempC: 38,
      returnTempC: 31,
    );

    ProviderContainer container() {
      final container = ProviderContainer(
        overrides: [
          editorStateProvider.overrideWith(
            () => _StubEditorNotifier(
              EditorState(
                rooms: [
                  createTestRoom(name: 'Living'),
                  createTestRoom(id: 'room-2', name: 'Store', isHeated: false),
                ],
                zones: const [zone, loose],
                circuits: const [circuit],
                distributor: distributor,
              ),
            ),
          ),
          roomHeatDemandProvider.overrideWith(
            (ref, id) => id == 'room-1' ? 800.0 : 0.0,
          ),
          zoneHeatedAreaM2Provider.overrideWith((ref, id) => 12.0),
          zoneHeatOutputProvider.overrideWith(
            (ref, id) => id == 'zone-1' ? 60.0 : double.nan,
          ),
          zoneHeatOutputWProvider.overrideWith(
            (ref, id) => id == 'zone-1' ? 720.0 : double.nan,
          ),
          zoneSurfaceTempProvider.overrideWith(
            (ref, id) => id == 'zone-1' ? 25.7 : double.nan,
          ),
          flowRateProvider.overrideWith((ref, id) => 88.5),
          flowVelocityProvider.overrideWith((ref, id) => 0.19),
          pressureLossProvider.overrideWith((ref, id) async => 6400.0),
          zoneTubeLengthProvider.overrideWith(
            (ref, id) => id == 'zone-1' ? 78.0 : 20.0,
          ),
          tubeLengthProvider.overrideWith((ref, id) => 91.0),
          tubeTypeByIdProvider.overrideWith(
            (ref, id) => Stream.value(
              const TubeType(
                id: 'tube-1',
                name: 'PE-Xa 16 × 2',
                material: TubeMaterial.peXa,
                innerDiameterMm: 12,
                wallThicknessMm: 2,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('collects the values of every room and zone', () async {
      final c = container();
      // Let the async upstream values (tube type, pressure loss) arrive.
      c.listen(floorSummaryProvider, (_, _) {});
      await c.read(pressureLossProvider('circuit-1').future);
      await c.read(tubeTypeByIdProvider('tube-1').future);
      await Future<void>.delayed(Duration.zero);

      final floor = c.read(floorSummaryProvider);
      expect(floor.rooms.map((r) => r.name), ['Living', 'Store']);

      final living = floor.rooms.first;
      expect(living.demandW, 800);
      expect(living.outputW, 720);
      expect(living.balanceW, -80);
      expect(living.zoneTubeLengthM, 98);
      expect(living.totalTubeLengthM, 91);
      expect(living.maxPressureLossPa, 6400);

      final connected = living.zones.first;
      expect(connected.circuitNumber, 1);
      expect(connected.supplyTempC, 38);
      expect(connected.returnTempC, 31);
      expect(connected.flowRateKgH, 88.5);
      expect(connected.specificOutputWPerM2, 60);
      expect(connected.surfaceTempC, 25.7);
      expect(connected.tubeOuterDiameterMm, 16);
      expect(connected.tubeWallThicknessMm, 2);
      expect(connected.pressureLossPa, 6400);
      expect(connected.zoneTubeLengthM, 78);
      expect(connected.totalTubeLengthM, 91);

      final unconnected = living.zones.last;
      expect(unconnected.circuitId, isNull);
      expect(unconnected.circuitNumber, isNull);
      expect(unconnected.outputW.isNaN, isTrue);
      expect(unconnected.flowRateKgH.isNaN, isTrue);
      expect(unconnected.supplyTempC.isNaN, isTrue);
      expect(unconnected.zoneTubeLengthM, 20);
      expect(unconnected.totalTubeLengthM.isNaN, isTrue);

      final store = floor.rooms.last;
      expect(store.isHeated, isFalse);
      expect(store.zones, isEmpty);

      expect(floor.demandW, 800);
      expect(floor.outputW, 720);
      expect(floor.balanceW, -80);
    });
  });
}
