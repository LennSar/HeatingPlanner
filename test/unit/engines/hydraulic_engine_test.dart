import 'dart:math' show pi;

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/hydraulic_engine.dart';
import 'package:heating_planner/data/models/point2d.dart';

void main() {
  // ── zoneTubeLength tests ──────────────────────────────────────────────

  group('HydraulicEngine.zoneTubeLength', () {
    test('standard zone: 15 m2, 150mm spacing', () {
      // L = 15 / 0.15 = 100 m
      final l = HydraulicEngine.zoneTubeLength(
        zoneAreaM2: 15.0,
        tubeSpacingMm: 150,
      );
      expect(l, closeTo(100.0, 0.1));
    });

    test('zero area returns NaN', () {
      final l = HydraulicEngine.zoneTubeLength(
        zoneAreaM2: 0.0,
        tubeSpacingMm: 150,
      );
      expect(l.isNaN, isTrue);
    });

    test('zero spacing returns NaN', () {
      final l = HydraulicEngine.zoneTubeLength(
        zoneAreaM2: 15.0,
        tubeSpacingMm: 0,
      );
      expect(l.isNaN, isTrue);
    });

    test('negative area returns NaN', () {
      final l = HydraulicEngine.zoneTubeLength(
        zoneAreaM2: -5.0,
        tubeSpacingMm: 150,
      );
      expect(l.isNaN, isTrue);
    });
  });

  // ── totalTubeLength tests ─────────────────────────────────────────────

  group('HydraulicEngine.totalTubeLength', () {
    test('zone + supply + return', () {
      final l = HydraulicEngine.totalTubeLength(
        zoneTubeLengthM: 70.0,
        supplyRouteLengthM: 5.0,
        returnRouteLengthM: 5.0,
      );
      expect(l, closeTo(80.0, 0.01));
    });

    test('zero route lengths', () {
      final l = HydraulicEngine.totalTubeLength(
        zoneTubeLengthM: 70.0,
        supplyRouteLengthM: 0.0,
        returnRouteLengthM: 0.0,
      );
      expect(l, closeTo(70.0, 0.01));
    });

    test('negative zone length returns NaN', () {
      final l = HydraulicEngine.totalTubeLength(
        zoneTubeLengthM: -10.0,
        supplyRouteLengthM: 5.0,
        returnRouteLengthM: 5.0,
      );
      expect(l.isNaN, isTrue);
    });

    test('negative supply length returns NaN', () {
      final l = HydraulicEngine.totalTubeLength(
        zoneTubeLengthM: 70.0,
        supplyRouteLengthM: -1.0,
        returnRouteLengthM: 5.0,
      );
      expect(l.isNaN, isTrue);
    });
  });

  // ── waterVolumeLitres tests ───────────────────────────────────────────

  group('HydraulicEngine.waterVolumeLitres', () {
    test('known diameter and length', () {
      // inner diam = 13mm = 0.013m, r = 0.0065m
      // V = pi * (0.0065)^2 * 80 * 1000 = pi * 4.225e-5 * 80000
      // = pi * 3.38 = 10.619 litres
      final v = HydraulicEngine.waterVolumeLitres(
        innerDiameterMm: 13.0,
        tubeLengthM: 80.0,
      );
      const manual =
          pi * (0.013 / 2.0) * (0.013 / 2.0) * 80.0 * 1000.0;
      expect(v, closeTo(manual, manual * 0.01));
    });

    test('zero diameter returns NaN', () {
      final v = HydraulicEngine.waterVolumeLitres(
        innerDiameterMm: 0.0,
        tubeLengthM: 80.0,
      );
      expect(v.isNaN, isTrue);
    });

    test('zero length returns NaN', () {
      final v = HydraulicEngine.waterVolumeLitres(
        innerDiameterMm: 13.0,
        tubeLengthM: 0.0,
      );
      expect(v.isNaN, isTrue);
    });

    test('negative diameter returns NaN', () {
      final v = HydraulicEngine.waterVolumeLitres(
        innerDiameterMm: -13.0,
        tubeLengthM: 80.0,
      );
      expect(v.isNaN, isTrue);
    });
  });

  // ── massFlowRateKgH tests ────────────────────────────────────────────

  group('HydraulicEngine.massFlowRateKgH', () {
    test('HY-1: known heat output and temp spread', () {
      // m = 1500 / (4186 * 7) * 3600 = 184.2 kg/h
      final m = HydraulicEngine.massFlowRateKgH(
        heatOutputW: 1500.0,
        tSupplyC: 35.0,
        tReturnC: 28.0,
      );
      expect(m, closeTo(184.2, 184.2 * 0.01));
    });

    test('supply equals return returns NaN', () {
      final m = HydraulicEngine.massFlowRateKgH(
        heatOutputW: 1500.0,
        tSupplyC: 35.0,
        tReturnC: 35.0,
      );
      expect(m.isNaN, isTrue);
    });

    test('return > supply returns NaN', () {
      final m = HydraulicEngine.massFlowRateKgH(
        heatOutputW: 1500.0,
        tSupplyC: 28.0,
        tReturnC: 35.0,
      );
      expect(m.isNaN, isTrue);
    });
  });

  // ── flowVelocity tests ───────────────────────────────────────────────

  group('HydraulicEngine.flowVelocity', () {
    test('HY-1: known mass flow and diameter', () {
      // v = (184.2/3600) / (992.2 * pi * (0.0065)^2)
      // = 0.05117 / (992.2 * 1.3273e-4) = 0.3886 m/s
      final v = HydraulicEngine.flowVelocity(
        massFlowRateKgH: 184.2,
        innerDiameterMm: 13.0,
      );
      expect(v, closeTo(0.3886, 0.01));
    });

    test('zero mass flow returns NaN', () {
      final v = HydraulicEngine.flowVelocity(
        massFlowRateKgH: 0.0,
        innerDiameterMm: 13.0,
      );
      expect(v.isNaN, isTrue);
    });

    test('zero diameter returns NaN', () {
      final v = HydraulicEngine.flowVelocity(
        massFlowRateKgH: 184.2,
        innerDiameterMm: 0.0,
      );
      expect(v.isNaN, isTrue);
    });

    test('negative mass flow returns NaN', () {
      final v = HydraulicEngine.flowVelocity(
        massFlowRateKgH: -50.0,
        innerDiameterMm: 13.0,
      );
      expect(v.isNaN, isTrue);
    });
  });

  // ── reynoldsNumber tests ─────────────────────────────────────────────

  group('HydraulicEngine.reynoldsNumber', () {
    test('HY-1: turbulent regime', () {
      // Re = 0.3886 * 0.013 / 6.58e-7 = 7679
      final re = HydraulicEngine.reynoldsNumber(
        velocityMs: 0.3886,
        innerDiameterMm: 13.0,
      );
      expect(re, closeTo(7679, 7679 * 0.02));
    });

    test('laminar regime (low velocity)', () {
      // Re = 0.05 * 0.013 / 6.58e-7 ≈ 988 (< 2300 → laminar)
      final re = HydraulicEngine.reynoldsNumber(
        velocityMs: 0.05,
        innerDiameterMm: 13.0,
      );
      expect(re, lessThan(2300));
      expect(re, greaterThan(0));
    });

    test('zero diameter returns NaN', () {
      final re = HydraulicEngine.reynoldsNumber(
        velocityMs: 0.3886,
        innerDiameterMm: 0.0,
      );
      expect(re.isNaN, isTrue);
    });

    test('zero nuWater returns NaN', () {
      final re = HydraulicEngine.reynoldsNumber(
        velocityMs: 0.3886,
        innerDiameterMm: 13.0,
        nuWater: 0.0,
      );
      expect(re.isNaN, isTrue);
    });
  });

  // ── darcyFrictionFactor tests ────────────────────────────────────────

  group('HydraulicEngine.darcyFrictionFactor', () {
    test('laminar: Re < 2300 gives f = 64/Re', () {
      final f = HydraulicEngine.darcyFrictionFactor(
        reynoldsNumber: 1000.0,
        roughnessMm: 0.007,
        innerDiameterMm: 13.0,
      );
      expect(f, closeTo(64.0 / 1000.0, 0.001));
    });

    test('turbulent: Re > 5000 gives Swamee-Jain', () {
      final f = HydraulicEngine.darcyFrictionFactor(
        reynoldsNumber: 7679.0,
        roughnessMm: 0.007,
        innerDiameterMm: 13.0,
      );
      // Should be approximately 0.0339 per HY-1
      expect(f, closeTo(0.0339, 0.003));
    });

    test('transition zone: 2300 < Re < 5000 interpolates', () {
      final f = HydraulicEngine.darcyFrictionFactor(
        reynoldsNumber: 3500.0,
        roughnessMm: 0.007,
        innerDiameterMm: 13.0,
      );
      // Must be between f_laminar(2300) and f_turbulent(5000)
      const fLam = 64.0 / 2300.0;
      expect(f, greaterThanOrEqualTo(fLam * 0.5));
      expect(f, lessThan(fLam * 1.5));
    });

    test('Re <= 0 returns NaN', () {
      final f = HydraulicEngine.darcyFrictionFactor(
        reynoldsNumber: 0.0,
        roughnessMm: 0.007,
        innerDiameterMm: 13.0,
      );
      expect(f.isNaN, isTrue);
    });

    test('negative Re returns NaN', () {
      final f = HydraulicEngine.darcyFrictionFactor(
        reynoldsNumber: -100.0,
        roughnessMm: 0.007,
        innerDiameterMm: 13.0,
      );
      expect(f.isNaN, isTrue);
    });

    test('zero roughness returns NaN', () {
      final f = HydraulicEngine.darcyFrictionFactor(
        reynoldsNumber: 7679.0,
        roughnessMm: 0.0,
        innerDiameterMm: 13.0,
      );
      expect(f.isNaN, isTrue);
    });

    test('zero diameter returns NaN', () {
      final f = HydraulicEngine.darcyFrictionFactor(
        reynoldsNumber: 7679.0,
        roughnessMm: 0.007,
        innerDiameterMm: 0.0,
      );
      expect(f.isNaN, isTrue);
    });

    test('boundary: exactly Re=2300 is laminar', () {
      final f = HydraulicEngine.darcyFrictionFactor(
        reynoldsNumber: 2299.99,
        roughnessMm: 0.007,
        innerDiameterMm: 13.0,
      );
      expect(f, closeTo(64.0 / 2299.99, 0.001));
    });
  });

  // ── frictionPressureLoss tests ────────────────────────────────────────

  group('HydraulicEngine.frictionPressureLoss', () {
    test('HY-1: known circuit pressure loss', () {
      final dp = HydraulicEngine.frictionPressureLoss(
        frictionFactor: 0.0339,
        tubeLengthM: 80.0,
        innerDiameterMm: 13.0,
        velocityMs: 0.3886,
      );
      // Dp = 0.0339 * (80/0.013) * (992.2 * 0.3886^2 / 2) ≈ 15660
      expect(dp, closeTo(15660, 15660 * 0.05));
    });

    test('NaN friction factor returns NaN', () {
      final dp = HydraulicEngine.frictionPressureLoss(
        frictionFactor: double.nan,
        tubeLengthM: 80.0,
        innerDiameterMm: 13.0,
        velocityMs: 0.3886,
      );
      expect(dp.isNaN, isTrue);
    });

    test('zero friction factor returns NaN', () {
      final dp = HydraulicEngine.frictionPressureLoss(
        frictionFactor: 0.0,
        tubeLengthM: 80.0,
        innerDiameterMm: 13.0,
        velocityMs: 0.3886,
      );
      expect(dp.isNaN, isTrue);
    });

    test('zero tube length returns NaN', () {
      final dp = HydraulicEngine.frictionPressureLoss(
        frictionFactor: 0.0339,
        tubeLengthM: 0.0,
        innerDiameterMm: 13.0,
        velocityMs: 0.3886,
      );
      expect(dp.isNaN, isTrue);
    });

    test('zero diameter returns NaN', () {
      final dp = HydraulicEngine.frictionPressureLoss(
        frictionFactor: 0.0339,
        tubeLengthM: 80.0,
        innerDiameterMm: 0.0,
        velocityMs: 0.3886,
      );
      expect(dp.isNaN, isTrue);
    });
  });

  // ── fittingPressureLoss tests ────────────────────────────────────────

  group('HydraulicEngine.fittingPressureLoss', () {
    test('default 40% surcharge', () {
      final dp = HydraulicEngine.fittingPressureLoss(
        frictionLossPa: 15660.0,
      );
      // 15660 * 0.40 = 6264
      expect(dp, closeTo(6264.0, 1.0));
    });

    test('custom surcharge percentage', () {
      final dp = HydraulicEngine.fittingPressureLoss(
        frictionLossPa: 10000.0,
        surchargePercent: 30.0,
      );
      expect(dp, closeTo(3000.0, 1.0));
    });

    test('with zeta values', () {
      // dynPressure = 992.2 * 0.4^2 / 2 = 79.376
      // sum of zetas * dynPressure
      final dp = HydraulicEngine.fittingPressureLoss(
        frictionLossPa: 0.0,
        zetaValues: [1.0, 0.5, 2.0],
        velocityMs: 0.4,
      );
      const dynP = 992.2 * 0.4 * 0.4 / 2.0;
      expect(dp, closeTo(3.5 * dynP, 1.0));
    });

    test('zeta values without velocity returns NaN', () {
      final dp = HydraulicEngine.fittingPressureLoss(
        frictionLossPa: 0.0,
        zetaValues: [1.0, 0.5],
      );
      expect(dp.isNaN, isTrue);
    });

    test('NaN friction loss returns NaN for surcharge', () {
      final dp = HydraulicEngine.fittingPressureLoss(
        frictionLossPa: double.nan,
      );
      expect(dp.isNaN, isTrue);
    });

    test('negative friction loss returns NaN', () {
      final dp = HydraulicEngine.fittingPressureLoss(
        frictionLossPa: -100.0,
      );
      expect(dp.isNaN, isTrue);
    });
  });

  // ── totalPressureLoss tests ──────────────────────────────────────────

  group('HydraulicEngine.totalPressureLoss', () {
    test('sum of friction and fitting losses', () {
      final dp = HydraulicEngine.totalPressureLoss(
        frictionLossPa: 15660.0,
        fittingLossPa: 6264.0,
      );
      expect(dp, closeTo(21924.0, 1.0));
    });

    test('NaN friction returns NaN', () {
      final dp = HydraulicEngine.totalPressureLoss(
        frictionLossPa: double.nan,
        fittingLossPa: 6264.0,
      );
      expect(dp.isNaN, isTrue);
    });

    test('NaN fitting returns NaN', () {
      final dp = HydraulicEngine.totalPressureLoss(
        frictionLossPa: 15660.0,
        fittingLossPa: double.nan,
      );
      expect(dp.isNaN, isTrue);
    });
  });

  // ── hydraulicBalance tests ───────────────────────────────────────────

  group('HydraulicEngine.hydraulicBalance', () {
    test('3 circuits: reference has 0 throttling', () {
      final result = HydraulicEngine.hydraulicBalance(
        circuitPressureLosses: {
          'c1': 20000.0,
          'c2': 18000.0,
          'c3': 15000.0,
        },
      );
      // c1 is reference (highest)
      expect(result['c1'], equals(0.0));
      expect(result['c2'], closeTo(2000.0, 1.0));
      expect(result['c3'], closeTo(5000.0, 1.0));
    });

    test('single circuit: zero throttling', () {
      final result = HydraulicEngine.hydraulicBalance(
        circuitPressureLosses: {'c1': 15000.0},
      );
      expect(result['c1'], equals(0.0));
    });

    test('empty map returns empty map', () {
      final result = HydraulicEngine.hydraulicBalance(
        circuitPressureLosses: {},
      );
      expect(result, isEmpty);
    });

    test('equal losses: all zero throttling', () {
      final result = HydraulicEngine.hydraulicBalance(
        circuitPressureLosses: {
          'c1': 10000.0,
          'c2': 10000.0,
        },
      );
      expect(result['c1'], equals(0.0));
      expect(result['c2'], equals(0.0));
    });
  });

  // ── polylineLengthM tests ────────────────────────────────────────────

  group('HydraulicEngine.polylineLengthM', () {
    test('straight line 5000mm = 5m', () {
      final l = HydraulicEngine.polylineLengthM([
        const Point2D(x: 0, y: 0),
        const Point2D(x: 5000, y: 0),
      ]);
      expect(l, closeTo(5.0, 0.001));
    });

    test('L-shaped path', () {
      final l = HydraulicEngine.polylineLengthM([
        const Point2D(x: 0, y: 0),
        const Point2D(x: 3000, y: 0),
        const Point2D(x: 3000, y: 4000),
      ]);
      // 3m + 4m = 7m
      expect(l, closeTo(7.0, 0.001));
    });

    test('single point returns NaN', () {
      final l = HydraulicEngine.polylineLengthM([
        const Point2D(x: 0, y: 0),
      ]);
      expect(l.isNaN, isTrue);
    });

    test('empty list returns NaN', () {
      final l = HydraulicEngine.polylineLengthM([]);
      expect(l.isNaN, isTrue);
    });
  });

  // ── HY-1: full pressure loss end-to-end ──────────────────────────────

  group('HY-1: full pressure loss calculation', () {
    test('end-to-end matches spec', () {
      // Step 1: mass flow rate
      final massFlow = HydraulicEngine.massFlowRateKgH(
        heatOutputW: 1500.0,
        tSupplyC: 35.0,
        tReturnC: 28.0,
      );
      expect(massFlow, closeTo(184.2, 184.2 * 0.01));

      // Step 2: flow velocity
      final velocity = HydraulicEngine.flowVelocity(
        massFlowRateKgH: massFlow,
        innerDiameterMm: 13.0,
      );
      expect(velocity, closeTo(0.3886, 0.01));

      // Step 3: Reynolds number
      final re = HydraulicEngine.reynoldsNumber(
        velocityMs: velocity,
        innerDiameterMm: 13.0,
      );
      expect(re, closeTo(7679, 7679 * 0.02));

      // Step 4: friction factor
      final f = HydraulicEngine.darcyFrictionFactor(
        reynoldsNumber: re,
        roughnessMm: 0.007,
        innerDiameterMm: 13.0,
      );
      expect(f, closeTo(0.0339, 0.003));

      // Step 5: friction pressure loss
      final dpFriction = HydraulicEngine.frictionPressureLoss(
        frictionFactor: f,
        tubeLengthM: 80.0,
        innerDiameterMm: 13.0,
        velocityMs: velocity,
      );

      // Step 6: fitting loss (40% surcharge)
      final dpFitting = HydraulicEngine.fittingPressureLoss(
        frictionLossPa: dpFriction,
      );

      // Step 7: total
      final dpTotal = HydraulicEngine.totalPressureLoss(
        frictionLossPa: dpFriction,
        fittingLossPa: dpFitting,
      );

      // Expected ~21,924 Pa ±5%
      expect(dpTotal, closeTo(21924, 21924 * 0.05));
    });
  });
}
