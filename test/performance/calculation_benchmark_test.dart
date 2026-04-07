/// Performance benchmarks — §8 of agent-test.md.
///
/// Each test runs the target calculation 100 times, sorts the elapsed
/// microsecond samples, and asserts that the median (index 50) is below the
/// latency target specified in the spec.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/hydraulic_engine.dart';
import 'package:heating_planner/calculation/engines/thermal_engine.dart';
import 'package:heating_planner/data/models/point2d.dart';

import '../helpers/test_factories.dart';

void main() {
  group('Calculation performance benchmarks', () {
    // ── Benchmark 1: U-value ──────────────────────────────────────────────────

    test('U-value calculation < 5 ms per assembly', () {
      // Build layer inputs from the UV-2 insulated wall (four layers).
      final layers = createInsulatedWallLayers();
      final thicknessesMm = layers.map((l) => l.thicknessMm).toList();
      final lambdas = layers.map((l) => l.thermalConductivity).toList();

      final sw = Stopwatch();
      final times = <int>[];

      for (var i = 0; i < 100; i++) {
        sw.reset();
        sw.start();
        ThermalEngine.uValue(
          layerThicknessesMm: thicknessesMm,
          layerLambdas: lambdas,
          rsi: 0.13,
          rse: 0.04,
        );
        sw.stop();
        times.add(sw.elapsedMicroseconds);
      }

      times.sort();
      final medianUs = times[50];
      expect(medianUs, lessThan(5000)); // 5 ms = 5 000 µs
    });

    // ── Benchmark 2: single-room heat demand ──────────────────────────────────

    test('room heat demand < 20 ms per room (4 walls, 3 windows, 1 door)', () {
      // Pre-build the wall construction from the insulated wall factory.
      final layers = createInsulatedWallLayers();
      final thicknessesMm = layers.map((l) => l.thicknessMm).toList();
      final lambdas = layers.map((l) => l.thermalConductivity).toList();

      // Room: 5 m × 4 m, 2.5 m ceiling height, 20 °C target, n=0.5 ACH.
      final room = createTestRoom();

      // Four walls (south/north: 5 000 mm, east/west: 4 000 mm), 2 500 mm tall.
      final walls = [
        createTestWall(
          id: 'wall-s',
          startPoint: const Point2D(x: 0, y: 0),
          endPoint: const Point2D(x: 5000, y: 0),
        ),
        createTestWall(
          id: 'wall-e',
          startPoint: const Point2D(x: 5000, y: 0),
          endPoint: const Point2D(x: 5000, y: 4000),
        ),
        createTestWall(
          id: 'wall-n',
          startPoint: const Point2D(x: 5000, y: 4000),
          endPoint: const Point2D(x: 0, y: 4000),
        ),
        createTestWall(
          id: 'wall-w',
          startPoint: const Point2D(x: 0, y: 4000),
          endPoint: const Point2D(x: 0, y: 0),
        ),
      ];

      // Openings: walls 0-2 carry one 1 500 × 1 400 mm window each;
      // wall 3 carries one 900 × 2 100 mm door.
      const wallHeightMm = 2500.0;
      const tOutdoor = -12.0;
      // room volume = 5 × 4 × 2.5 = 50 m³
      const roomVolumeM3 = 50.0;

      final sw = Stopwatch();
      final times = <int>[];
      var lastDemand = 0.0;

      for (var iter = 0; iter < 100; iter++) {
        sw.reset();
        sw.start();

        final uWall = ThermalEngine.uValue(
          layerThicknessesMm: thicknessesMm,
          layerLambdas: lambdas,
          rsi: 0.13,
          rse: 0.04,
        );

        var demand = 0.0;

        // Walls 0-2: one window each.
        for (var wi = 0; wi < 3; wi++) {
          final w = walls[wi];
          final wallLenMm = _wallLengthMm(w.startPoint, w.endPoint);

          final netArea = ThermalEngine.netWallAreaM2(
            wallLengthMm: wallLenMm,
            wallHeightMm: wallHeightMm,
            openings: [const (widthMm: 1500, heightMm: 1400)],
          );
          demand += ThermalEngine.transmissionLoss(
            uValue: uWall,
            areaM2: netArea,
            correctionF: 1.0,
            tIndoorC: room.targetTempC,
            tOutdoorC: tOutdoor,
          );
          // Window (U = 1.3 W/(m²K)).
          demand += ThermalEngine.transmissionLoss(
            uValue: 1.3,
            areaM2: 1500 * 1400 / 1e6,
            correctionF: 1.0,
            tIndoorC: room.targetTempC,
            tOutdoorC: tOutdoor,
          );
        }

        // Wall 3: one door.
        final doorWall = walls[3];
        final doorWallLenMm = _wallLengthMm(doorWall.startPoint, doorWall.endPoint);
        final netAreaDoor = ThermalEngine.netWallAreaM2(
          wallLengthMm: doorWallLenMm,
          wallHeightMm: wallHeightMm,
          openings: [const (widthMm: 900, heightMm: 2100)],
        );
        demand += ThermalEngine.transmissionLoss(
          uValue: uWall,
          areaM2: netAreaDoor,
          correctionF: 1.0,
          tIndoorC: room.targetTempC,
          tOutdoorC: tOutdoor,
        );
        // Door (U = 2.0 W/(m²K)).
        demand += ThermalEngine.transmissionLoss(
          uValue: 2.0,
          areaM2: 900 * 2100 / 1e6,
          correctionF: 1.0,
          tIndoorC: room.targetTempC,
          tOutdoorC: tOutdoor,
        );

        // Ventilation loss.
        demand += ThermalEngine.ventilationLoss(
          roomVolumeM3: roomVolumeM3,
          airChangeRate: room.airChangeRate,
          tIndoorC: room.targetTempC,
          tOutdoorC: tOutdoor,
        );

        sw.stop();
        times.add(sw.elapsedMicroseconds);
        lastDemand = demand;
      }

      expect(lastDemand, greaterThan(0));
      times.sort();
      final medianUs = times[50];
      expect(medianUs, lessThan(20000)); // 20 ms = 20 000 µs
    });

    // ── Benchmark 3: full building demand (50 rooms) ──────────────────────────

    test('full building heat demand < 100 ms for 50 rooms', () {
      final layers = createInsulatedWallLayers();
      final thicknessesMm = layers.map((l) => l.thicknessMm).toList();
      final lambdas = layers.map((l) => l.thermalConductivity).toList();

      // 50 rooms, each 5 m × 4 m × 2.5 m, 4 exterior walls with windows.
      final rooms = List.generate(
        50,
        (i) => createTestRoom(id: 'room-$i', name: 'Room $i'),
      );

      // Shared wall length: south/north = 5 000 mm, east/west = 4 000 mm.
      const wallDefs = [
        (lengthMm: 5000.0, openings: [(widthMm: 1500, heightMm: 1400)]),
        (lengthMm: 4000.0, openings: [(widthMm: 1500, heightMm: 1400)]),
        (lengthMm: 5000.0, openings: [(widthMm: 1500, heightMm: 1400)]),
        (lengthMm: 4000.0, openings: [(widthMm: 900, heightMm: 2100)]),
      ];
      const wallHeightMm = 2500.0;
      const tOutdoor = -12.0;
      const roomVolumeM3 = 50.0;

      final sw = Stopwatch();
      final times = <int>[];
      var lastBuildingDemand = 0.0;

      for (var iter = 0; iter < 100; iter++) {
        sw.reset();
        sw.start();

        var buildingDemand = 0.0;

        for (final room in rooms) {
          final uWall = ThermalEngine.uValue(
            layerThicknessesMm: thicknessesMm,
            layerLambdas: lambdas,
            rsi: 0.13,
            rse: 0.04,
          );

          for (final wd in wallDefs) {
            final netArea = ThermalEngine.netWallAreaM2(
              wallLengthMm: wd.lengthMm,
              wallHeightMm: wallHeightMm,
              openings: wd.openings,
            );
            buildingDemand += ThermalEngine.transmissionLoss(
              uValue: uWall,
              areaM2: netArea,
              correctionF: 1.0,
              tIndoorC: room.targetTempC,
              tOutdoorC: tOutdoor,
            );
            // Opening transmission (U = 1.3 for windows, 2.0 for door).
            final openingU = (wd.openings.first.widthMm == 900) ? 2.0 : 1.3;
            buildingDemand += ThermalEngine.transmissionLoss(
              uValue: openingU,
              areaM2: wd.openings.first.widthMm * wd.openings.first.heightMm / 1e6,
              correctionF: 1.0,
              tIndoorC: room.targetTempC,
              tOutdoorC: tOutdoor,
            );
          }

          buildingDemand += ThermalEngine.ventilationLoss(
            roomVolumeM3: roomVolumeM3,
            airChangeRate: room.airChangeRate,
            tIndoorC: room.targetTempC,
            tOutdoorC: tOutdoor,
          );
        }

        sw.stop();
        times.add(sw.elapsedMicroseconds);
        lastBuildingDemand = buildingDemand;
      }

      expect(lastBuildingDemand, greaterThan(0));
      times.sort();
      final medianUs = times[50];
      expect(medianUs, lessThan(100000)); // 100 ms = 100 000 µs
    });

    // ── Benchmark 4: pressure loss per circuit ────────────────────────────────

    test('pressure loss per circuit < 50 ms', () {
      // Circuit: 80 m tube, 16 mm inner diameter, 800 W heat output,
      // supply 35 °C / return 28 °C, PEX roughness 0.007 mm.
      final circuit = createTestCircuit(
        id: 'bench-circuit',
        tubeLengthM: 80.0,
      );
      const innerDiameterMm = 16.0;
      const roughnessMm = 0.007;
      const heatOutputW = 800.0;
      const tSupply = 35.0;
      const tReturn = 28.0;

      final sw = Stopwatch();
      final times = <int>[];
      var lastTotalLoss = 0.0;

      for (var i = 0; i < 100; i++) {
        sw.reset();
        sw.start();

        final massFlow = HydraulicEngine.massFlowRateKgH(
          heatOutputW: heatOutputW,
          tSupplyC: tSupply,
          tReturnC: tReturn,
        );
        final velocity = HydraulicEngine.flowVelocity(
          massFlowRateKgH: massFlow,
          innerDiameterMm: innerDiameterMm,
        );
        final re = HydraulicEngine.reynoldsNumber(
          velocityMs: velocity,
          innerDiameterMm: innerDiameterMm,
        );
        final f = HydraulicEngine.darcyFrictionFactor(
          reynoldsNumber: re,
          roughnessMm: roughnessMm,
          innerDiameterMm: innerDiameterMm,
        );
        final frictionLoss = HydraulicEngine.frictionPressureLoss(
          frictionFactor: f,
          tubeLengthM: circuit.tubeLengthM,
          innerDiameterMm: innerDiameterMm,
          velocityMs: velocity,
        );
        final fittingLoss = HydraulicEngine.fittingPressureLoss(
          frictionLossPa: frictionLoss,
        );
        final totalLoss = HydraulicEngine.totalPressureLoss(
          frictionLossPa: frictionLoss,
          fittingLossPa: fittingLoss,
        );

        sw.stop();
        times.add(sw.elapsedMicroseconds);
        lastTotalLoss = totalLoss;
      }

      expect(lastTotalLoss, greaterThan(0));
      times.sort();
      final medianUs = times[50];
      expect(medianUs, lessThan(50000)); // 50 ms = 50 000 µs
    });

    // ── Benchmark 5: full hydraulic balance (12 circuits) ─────────────────────

    test('full hydraulic balance < 200 ms for 12 circuits', () {
      // 12 circuits with tube lengths 40–95 m (step 5 m) to produce varied losses.
      final circuits = List.generate(
        12,
        (i) => createTestCircuit(
          id: 'hb-circuit-$i',
          tubeLengthM: 40.0 + i * 5.0,
        ),
      );

      const innerDiameterMm = 16.0;
      const roughnessMm = 0.007;
      const heatOutputW = 500.0;
      const tSupply = 35.0;
      const tReturn = 28.0;

      final sw = Stopwatch();
      final times = <int>[];
      var lastBalanceSize = 0;

      for (var iter = 0; iter < 100; iter++) {
        sw.reset();
        sw.start();

        final pressureLosses = <String, double>{};

        for (final circuit in circuits) {
          final massFlow = HydraulicEngine.massFlowRateKgH(
            heatOutputW: heatOutputW,
            tSupplyC: tSupply,
            tReturnC: tReturn,
          );
          final velocity = HydraulicEngine.flowVelocity(
            massFlowRateKgH: massFlow,
            innerDiameterMm: innerDiameterMm,
          );
          final re = HydraulicEngine.reynoldsNumber(
            velocityMs: velocity,
            innerDiameterMm: innerDiameterMm,
          );
          final f = HydraulicEngine.darcyFrictionFactor(
            reynoldsNumber: re,
            roughnessMm: roughnessMm,
            innerDiameterMm: innerDiameterMm,
          );
          final frictionLoss = HydraulicEngine.frictionPressureLoss(
            frictionFactor: f,
            tubeLengthM: circuit.tubeLengthM,
            innerDiameterMm: innerDiameterMm,
            velocityMs: velocity,
          );
          final fittingLoss = HydraulicEngine.fittingPressureLoss(
            frictionLossPa: frictionLoss,
          );
          pressureLosses[circuit.id] = HydraulicEngine.totalPressureLoss(
            frictionLossPa: frictionLoss,
            fittingLossPa: fittingLoss,
          );
        }

        final balance = HydraulicEngine.hydraulicBalance(
          circuitPressureLosses: pressureLosses,
        );

        sw.stop();
        times.add(sw.elapsedMicroseconds);
        lastBalanceSize = balance.length;
      }

      expect(lastBalanceSize, equals(12));
      times.sort();
      final medianUs = times[50];
      expect(medianUs, lessThan(200000)); // 200 ms = 200 000 µs
    });
  });
}

// ── Local helpers ─────────────────────────────────────────────────────────────

/// Euclidean length of an axis-aligned wall segment (mm).
///
/// Walls in this project are always horizontal or vertical, so the
/// Manhattan and Euclidean distances are equal — no sqrt needed.
double _wallLengthMm(Point2D start, Point2D end) {
  final dx = (end.x - start.x).abs().toDouble();
  final dy = (end.y - start.y).abs().toDouble();
  return dx + dy;
}
