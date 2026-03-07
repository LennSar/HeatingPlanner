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
      // Room: 5m × 4m, height 2.6m, 20°C, n=0.5/h, outdoor -12°C.
      // One exterior wall (south, 5m): U=0.283 W/(m²K), one window
      // 1.5m × 1.4m at U=1.3 W/(m²K). Per agent-hvac.md §9.2.

      // Step 1 — net wall area after subtracting window.
      final netArea = ThermalEngine.netWallAreaM2(
        wallLengthMm: 5000.0,
        wallHeightMm: 2600.0,
        openings: [(widthMm: 1500, heightMm: 1400)],
      );
      // 5.0 × 2.6 − 1.5 × 1.4 = 13.0 − 2.1 = 10.9 m²
      expect(netArea, closeTo(10.9, 0.01));

      // Step 2 — transmission loss through the opaque wall section.
      final qWall = ThermalEngine.transmissionLoss(
        uValue: 0.283,
        areaM2: netArea,
        correctionF: 1.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      // 0.283 × 10.9 × 1.0 × 32 ≈ 98.71 W
      expect(qWall, closeTo(98.71, 1.0));

      // Step 3 — transmission loss through the window.
      const windowAreaM2 = 1.5 * 1.4; // 2.1 m²
      final qWindow = ThermalEngine.transmissionLoss(
        uValue: 1.3,
        areaM2: windowAreaM2,
        correctionF: 1.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      // 1.3 × 2.1 × 1.0 × 32 ≈ 87.36 W
      expect(qWindow, closeTo(87.36, 1.0));

      // Step 4 — ventilation loss.
      // V_room = 5.0 × 4.0 × 2.6 = 52.0 m³
      final qVent = ThermalEngine.ventilationLoss(
        roomVolumeM3: 52.0,
        airChangeRate: 0.5,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      // 52 × 0.5 × 1.2 × 1005 × 32 / 3600 ≈ 277.87 W
      expect(qVent, closeTo(277.87, 277.87 * 0.02));

      // Step 5 — total.
      final qTotal = qWall + qWindow + qVent;
      // 98.71 + 87.36 + 277.87 = 463.94 W (±2%)
      expect(qTotal, closeTo(463.94, 463.94 * 0.02));
    });
  });

  // ── HD-1 edge cases (per agent-test.md §3.2) ──────────────────────────
  //
  // Base room: 5m × 4m, height 2.6m, 20°C, n=0.5/h, outdoor -12°C.
  // All walls use U = 0.283 W/(m²K) (UV-2 insulated construction).
  // Ventilation loss Q_V = 277.87 W (verified in ventilationLoss tests).

  group('HD-1 edge cases: interior wall scenarios', () {
    const uWall = 0.283;    // W/(m²K)
    const wallAreaM2 = 13.0; // 5.0 m × 2.6 m, no openings
    const tThis = 20.0;     // °C
    const tOutdoor = -12.0; // °C

    // Ventilation loss is identical in all four cases.
    // Computed inline to keep each test self-contained.
    double computeQVent() => ThermalEngine.ventilationLoss(
          roomVolumeM3: 52.0,
          airChangeRate: 0.5,
          tIndoorC: tThis,
          tOutdoorC: tOutdoor,
        );

    test(
        'all interior walls at same temperature: '
        'Q_T = 0, Q_total equals Q_V', () {
      // f = (20 − 20) / (20 − (−12)) = 0
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: tThis,
        tAdjacentRoomC: 20.0,
        tOutdoorC: tOutdoor,
      );
      expect(f, equals(0.0));

      // Sum transmission loss over 4 walls — all zero.
      var qTransmission = 0.0;
      for (var i = 0; i < 4; i++) {
        final q = ThermalEngine.transmissionLoss(
          uValue: uWall,
          areaM2: wallAreaM2,
          correctionF: f,
          tIndoorC: tThis,
          tOutdoorC: tOutdoor,
        );
        qTransmission += q;
      }
      expect(qTransmission, equals(0.0));

      final qVent = computeQVent();
      final qTotal = qTransmission + qVent;
      // Total equals ventilation-only demand.
      expect(qTotal, closeTo(qVent, qVent * 0.02));
    });

    test(
        'interior wall to colder adjacent room (15°C): '
        'positive correction factor adds partial transmission loss', () {
      // f = (20 − 15) / (20 − (−12)) = 5/32 = 0.15625
      // Q_T = 0.283 × 13.0 × 0.15625 × 32 ≈ 18.38 W
      const tAdj = 15.0;
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: tThis,
        tAdjacentRoomC: tAdj,
        tOutdoorC: tOutdoor,
      );
      expect(f, closeTo(5.0 / 32.0, 0.001));
      expect(f, greaterThan(0.0));

      final qT = ThermalEngine.transmissionLoss(
        uValue: uWall,
        areaM2: wallAreaM2,
        correctionF: f,
        tIndoorC: tThis,
        tOutdoorC: tOutdoor,
      );
      // Q_T = 0.283 × 13.0 × (5/32) × 32 = 0.283 × 13.0 × 5 = 18.395 W
      expect(qT, closeTo(18.395, 18.395 * 0.02));

      final qVent = computeQVent();
      final qTotal = qT + qVent;
      // Total demand is greater than Q_V but less than full HD-1.
      expect(qTotal, greaterThan(qVent));
      expect(qTotal, closeTo(18.395 + 277.87, (18.395 + 277.87) * 0.02));
    });

    test(
        'interior wall to warmer adjacent room (24°C): '
        'negative correction factor reduces total demand', () {
      // f = (20 − 24) / (20 − (−12)) = −4/32 = −0.125
      // Q_T = 0.283 × 13.0 × (−0.125) × 32 ≈ −14.72 W  (heat gain)
      // Q_total ≈ −14.72 + 277.87 = 263.15 W
      const tAdj = 24.0;
      final f = ThermalEngine.interiorCorrectionFactor(
        tThisRoomC: tThis,
        tAdjacentRoomC: tAdj,
        tOutdoorC: tOutdoor,
      );
      expect(f, closeTo(-4.0 / 32.0, 0.001));
      expect(f, lessThan(0.0));

      final qT = ThermalEngine.transmissionLoss(
        uValue: uWall,
        areaM2: wallAreaM2,
        correctionF: f,
        tIndoorC: tThis,
        tOutdoorC: tOutdoor,
      );
      // Q_T is negative → heat flows into this room from warmer neighbour.
      expect(qT, lessThan(0.0));
      // Q_T = 0.283 × 13.0 × (−0.125) × 32 = −14.716 W
      expect(qT, closeTo(-14.716, 14.716 * 0.02));

      final qVent = computeQVent();
      final qTotal = qT + qVent;
      // Total demand is lower than ventilation-only demand.
      expect(qTotal, lessThan(qVent));
      expect(qTotal, closeTo(-14.716 + 277.87, 263.154 * 0.02));
    });

    test(
        'room with no constructions assigned: '
        'Q_T = 0, Q_total equals Q_V', () {
      // When no wall has a constructionId the transmission loop is
      // skipped entirely. The caller must not call transmissionLoss.
      // Total demand is pure ventilation loss.
      const qTransmission = 0.0;

      final qVent = computeQVent();
      final qTotal = qTransmission + qVent;
      expect(qTotal, closeTo(qVent, qVent * 0.02));
    });
  });
}
