import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/thermal_engine.dart';

void main() {
  // ── U-value tests ────────────────────────────────────────────────────────

  group('ThermalEngine.uValue', () {
    test('UV-1: single-layer solid brick wall', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [200.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u, closeTo(2.327, 0.001));
    });

    test('UV-2: multi-layer insulated wall', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [15.0, 100.0, 200.0, 15.0],
        layerLambdas: [1.00, 0.035, 0.44, 0.40],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u, closeTo(0.283, 0.001));
    });

    test('UV-3: zero thickness layer returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [0.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('UV-4: zero lambda returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [200.0],
        layerLambdas: [0.0],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('UV-5: empty layers returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [],
        layerLambdas: [],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('UV-6: mismatched array lengths returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [200.0, 100.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('UV-7: negative lambda returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [200.0],
        layerLambdas: [-0.5],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('negative thickness returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [-100.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('negative rsi returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [200.0],
        layerLambdas: [0.77],
        rsi: -0.1,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('zero rse returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [200.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.0,
      );
      expect(u.isNaN, isTrue);
    });
  });

  // ── totalResistance tests ──────────────────────────────────────────────

  group('ThermalEngine.totalResistance', () {
    test('UV-1 R_total matches hand calculation', () {
      final r = ThermalEngine.totalResistance(
        layerThicknessesMm: [200.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
      );
      // R = 0.13 + 0.200/0.77 + 0.04 = 0.4297
      expect(r, closeTo(0.4297, 0.001));
    });

    test('UV-2 R_total matches hand calculation', () {
      final r = ThermalEngine.totalResistance(
        layerThicknessesMm: [15.0, 100.0, 200.0, 15.0],
        layerLambdas: [1.00, 0.035, 0.44, 0.40],
        rsi: 0.13,
        rse: 0.04,
      );
      // R = 0.13 + 0.015 + 2.857 + 0.4545 + 0.0375 + 0.04 = 3.534
      expect(r, closeTo(3.534, 0.001));
    });
  });

  // ── temperatureProfile tests ───────────────────────────────────────────

  group('ThermalEngine.temperatureProfile', () {
    test('single-layer wall: correct interface temperatures', () {
      final temps = ThermalEngine.temperatureProfile(
        layerThicknessesMm: [200.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      // n=1, expect 3 values
      expect(temps.length, equals(3));
      // R_total ≈ 0.4297
      // T_surface_interior = 20 - 32*(0.13/0.4297) ≈ 10.32
      expect(temps[0], closeTo(10.32, 0.1));
      // T after brick = T_surface_int - 32*(0.2597/0.4297) ≈ -9.02
      expect(temps[1], closeTo(-9.02, 0.1));
      // T_exterior_surface = -12
      expect(temps[2], closeTo(-12.0, 0.1));
    });

    test('invalid inputs return empty list', () {
      final temps = ThermalEngine.temperatureProfile(
        layerThicknessesMm: [],
        layerLambdas: [],
        rsi: 0.13,
        rse: 0.04,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(temps, isEmpty);
    });

    test('equal indoor and outdoor temps: all temps are equal', () {
      final temps = ThermalEngine.temperatureProfile(
        layerThicknessesMm: [200.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
        tIndoorC: 20.0,
        tOutdoorC: 20.0,
      );
      expect(temps.length, equals(3));
      for (final t in temps) {
        expect(t, closeTo(20.0, 0.1));
      }
    });
  });

  // ── transmissionLoss tests ─────────────────────────────────────────────

  group('ThermalEngine.transmissionLoss', () {
    test('standard exterior wall loss', () {
      final q = ThermalEngine.transmissionLoss(
        uValue: 0.283,
        areaM2: 10.9,
        correctionF: 1.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q, closeTo(98.71, 1.0));
    });

    test('interior wall same temperature: zero loss', () {
      final q = ThermalEngine.transmissionLoss(
        uValue: 0.283,
        areaM2: 10.9,
        correctionF: 0.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q, equals(0.0));
    });

    test('zero area returns NaN', () {
      final q = ThermalEngine.transmissionLoss(
        uValue: 0.283,
        areaM2: 0.0,
        correctionF: 1.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('NaN uValue returns NaN', () {
      final q = ThermalEngine.transmissionLoss(
        uValue: double.nan,
        areaM2: 10.9,
        correctionF: 1.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('zero uValue returns NaN', () {
      final q = ThermalEngine.transmissionLoss(
        uValue: 0.0,
        areaM2: 10.9,
        correctionF: 1.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('window transmission loss', () {
      final q = ThermalEngine.transmissionLoss(
        uValue: 1.3,
        areaM2: 2.1,
        correctionF: 1.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q, closeTo(87.36, 1.0));
    });
  });

  // ── netWallAreaM2 tests ────────────────────────────────────────────────

  group('ThermalEngine.netWallAreaM2', () {
    test('HD-1 net wall area with one window', () {
      final a = ThermalEngine.netWallAreaM2(
        wallLengthMm: 5000.0,
        wallHeightMm: 2600.0,
        openings: [(widthMm: 1500, heightMm: 1400)],
      );
      // 5.0 * 2.6 - 1.5 * 1.4 = 13.0 - 2.1 = 10.9
      expect(a, closeTo(10.9, 0.01));
    });

    test('no openings returns gross area', () {
      final a = ThermalEngine.netWallAreaM2(
        wallLengthMm: 5000.0,
        wallHeightMm: 2600.0,
        openings: [],
      );
      expect(a, closeTo(13.0, 0.01));
    });

    test('openings larger than wall clamps to 0', () {
      final a = ThermalEngine.netWallAreaM2(
        wallLengthMm: 1000.0,
        wallHeightMm: 1000.0,
        openings: [(widthMm: 2000, heightMm: 2000)],
      );
      expect(a, equals(0.0));
    });

    test('zero wall length returns NaN', () {
      final a = ThermalEngine.netWallAreaM2(
        wallLengthMm: 0.0,
        wallHeightMm: 2600.0,
        openings: [],
      );
      expect(a.isNaN, isTrue);
    });

    test('negative wall height returns NaN', () {
      final a = ThermalEngine.netWallAreaM2(
        wallLengthMm: 5000.0,
        wallHeightMm: -100.0,
        openings: [],
      );
      expect(a.isNaN, isTrue);
    });
  });

  // ── interiorCorrectionFactor tests ────────────────────────────────────

  group('ThermalEngine.interiorCorrectionFactor', () {
    test('same temperature rooms: factor is 0', () {
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: 20.0,
        tAdjacentRoomC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(f, equals(0.0));
    });

    test('adjacent room cooler: positive factor', () {
      // f = (20 - 15) / (20 - (-12)) = 5/32 = 0.15625
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: 20.0,
        tAdjacentRoomC: 15.0,
        tOutdoorC: -12.0,
      );
      expect(f, closeTo(0.15625, 0.001));
    });

    test('tThisRoom == tOutdoor: returns NaN', () {
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: -12.0,
        tAdjacentRoomC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(f.isNaN, isTrue);
    });

    test('adjacent room warmer: negative factor', () {
      // f = (20 - 22) / (20 - (-12)) = -2/32 = -0.0625
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: 20.0,
        tAdjacentRoomC: 22.0,
        tOutdoorC: -12.0,
      );
      expect(f, closeTo(-0.0625, 0.001));
    });
  });

  // ── ventilationLoss tests ──────────────────────────────────────────────

  group('ThermalEngine.ventilationLoss', () {
    test('HD-1: standard room ventilation loss', () {
      final q = ThermalEngine.ventilationLoss(
        roomVolumeM3: 52.0,
        airChangeRate: 0.5,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      // 52 * 0.5 * 1.2 * 1005 * 32 / 3600 = 277.87
      expect(q, closeTo(277.87, 277.87 * 0.02));
    });

    test('zero volume returns NaN', () {
      final q = ThermalEngine.ventilationLoss(
        roomVolumeM3: 0.0,
        airChangeRate: 0.5,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('zero air change rate returns NaN', () {
      final q = ThermalEngine.ventilationLoss(
        roomVolumeM3: 52.0,
        airChangeRate: 0.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('negative volume returns NaN', () {
      final q = ThermalEngine.ventilationLoss(
        roomVolumeM3: -10.0,
        airChangeRate: 0.5,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q.isNaN, isTrue);
    });
  });

  // ── roomVolumeM3 tests ────────────────────────────────────────────────

  group('ThermalEngine.roomVolumeM3', () {
    test('standard room volume', () {
      final v = ThermalEngine.roomVolumeM3(
        floorAreaM2: 20.0,
        ceilingHeightMm: 2600.0,
      );
      expect(v, closeTo(52.0, 0.01));
    });

    test('zero area returns NaN', () {
      final v = ThermalEngine.roomVolumeM3(
        floorAreaM2: 0.0,
        ceilingHeightMm: 2600.0,
      );
      expect(v.isNaN, isTrue);
    });

    test('negative ceiling height returns NaN', () {
      final v = ThermalEngine.roomVolumeM3(
        floorAreaM2: 20.0,
        ceilingHeightMm: -1.0,
      );
      expect(v.isNaN, isTrue);
    });
  });

  // ── HD-1: combined heat demand test ────────────────────────────────────

  group('ThermalEngine combined heat demand', () {
    test('HD-1: simple rectangular room total heat demand', () {
      // Net wall area
      final netArea = ThermalEngine.netWallAreaM2(
        wallLengthMm: 5000.0,
        wallHeightMm: 2600.0,
        openings: [(widthMm: 1500, heightMm: 1400)],
      );
      expect(netArea, closeTo(10.9, 0.01));

      // Transmission loss through wall
      final qWall = ThermalEngine.transmissionLoss(
        uValue: 0.283,
        areaM2: netArea,
        correctionF: 1.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );

      // Transmission loss through window
      const windowArea = 1.5 * 1.4;
      final qWindow = ThermalEngine.transmissionLoss(
        uValue: 1.3,
        areaM2: windowArea,
        correctionF: 1.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );

      // Ventilation loss
      final qVent = ThermalEngine.ventilationLoss(
        roomVolumeM3: 52.0,
        airChangeRate: 0.5,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );

      final qTotal = qWall + qWindow + qVent;
      // Expected ≈ 463.94 W (±2%)
      expect(qTotal, closeTo(463.94, 463.94 * 0.02));
    });
  });
}
