import 'dart:math' show pow;

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/heating_output_engine.dart';

void main() {
  // ── logMeanTempDifference tests ────────────────────────────────────────

  group('HeatingOutputEngine.logMeanTempDifference', () {
    test('normal case: supply 35, return 28, room 20', () {
      // dSup = 15, dRet = 8
      // ln(15/8) = ln(1.875) ≈ 0.6286
      // deltaT = (35 - 28) / 0.6286 ≈ 11.135
      final dt = HeatingOutputEngine.logMeanTempDifference(
        tSupplyC: 35.0,
        tReturnC: 28.0,
        tRoomC: 20.0,
      );
      expect(dt, closeTo(11.135, 0.1));
    });

    test('supply close to return: arithmetic fallback', () {
      // supply = 35.5, return = 35.0, room = 20
      // dSup = 15.5, dRet = 15.0
      // ln(15.5/15.0) = ln(1.0333) ≈ 0.0328 < 0.1 → fallback
      // arithmetic mean = (15.5 + 15.0)/2 = 15.25
      final dt = HeatingOutputEngine.logMeanTempDifference(
        tSupplyC: 35.5,
        tReturnC: 35.0,
        tRoomC: 20.0,
      );
      expect(dt, closeTo(15.25, 0.1));
    });

    test('supply equals return: arithmetic fallback (log=0)', () {
      // dSup = dRet = 15, ln(1) = 0 < 0.1 → fallback
      // arithmetic mean = (15 + 15)/2 = 15
      final dt = HeatingOutputEngine.logMeanTempDifference(
        tSupplyC: 35.0,
        tReturnC: 35.0,
        tRoomC: 20.0,
      );
      expect(dt, closeTo(15.0, 0.1));
    });

    test('supply <= room: returns NaN', () {
      final dt = HeatingOutputEngine.logMeanTempDifference(
        tSupplyC: 20.0,
        tReturnC: 28.0,
        tRoomC: 20.0,
      );
      expect(dt.isNaN, isTrue);
    });

    test('return <= room: returns NaN', () {
      final dt = HeatingOutputEngine.logMeanTempDifference(
        tSupplyC: 35.0,
        tReturnC: 19.0,
        tRoomC: 20.0,
      );
      expect(dt.isNaN, isTrue);
    });
  });

  // ── specificHeatOutput tests ───────────────────────────────────────────

  group('HeatingOutputEngine.specificHeatOutput', () {
    test('known correction factors produce expected output', () {
      // q = B * aB * aT * aU * aD * deltaT^n
      // Use B=6.7, all factors=1.0, deltaT=10, n=1.1
      // q = 6.7 * 1.0 * 1.0 * 1.0 * 1.0 * 10^1.1
      final expected = 6.7 * pow(10.0, 1.1);
      final q = HeatingOutputEngine.specificHeatOutput(
        deltaT: 10.0,
        systemConstantB: 6.7,
        coveringFactorAB: 1.0,
        spacingFactorAT: 1.0,
        diameterFactorAU: 1.0,
        conductFactorAD: 1.0,
        exponentN: 1.1,
      );
      expect(q, closeTo(expected, expected * 0.01));
    });

    test('with realistic correction factors', () {
      // B=6.7, aB=0.85, aT=1.02, aU=1.0, aD=1.0, deltaT=11.1, n=1.1
      final expected =
          6.7 * 0.85 * 1.02 * 1.0 * 1.0 * pow(11.1, 1.1);
      final q = HeatingOutputEngine.specificHeatOutput(
        deltaT: 11.1,
        systemConstantB: 6.7,
        coveringFactorAB: 0.85,
        spacingFactorAT: 1.02,
        diameterFactorAU: 1.0,
        conductFactorAD: 1.0,
        exponentN: 1.1,
      );
      expect(q, closeTo(expected, expected * 0.01));
    });

    test('zero deltaT returns NaN', () {
      final q = HeatingOutputEngine.specificHeatOutput(
        deltaT: 0.0,
        systemConstantB: 6.7,
        coveringFactorAB: 1.0,
        spacingFactorAT: 1.0,
        diameterFactorAU: 1.0,
        conductFactorAD: 1.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('negative deltaT returns NaN', () {
      final q = HeatingOutputEngine.specificHeatOutput(
        deltaT: -5.0,
        systemConstantB: 6.7,
        coveringFactorAB: 1.0,
        spacingFactorAT: 1.0,
        diameterFactorAU: 1.0,
        conductFactorAD: 1.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('NaN deltaT returns NaN', () {
      final q = HeatingOutputEngine.specificHeatOutput(
        deltaT: double.nan,
        systemConstantB: 6.7,
        coveringFactorAB: 1.0,
        spacingFactorAT: 1.0,
        diameterFactorAU: 1.0,
        conductFactorAD: 1.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('zero systemConstantB returns NaN', () {
      final q = HeatingOutputEngine.specificHeatOutput(
        deltaT: 10.0,
        systemConstantB: 0.0,
        coveringFactorAB: 1.0,
        spacingFactorAT: 1.0,
        diameterFactorAU: 1.0,
        conductFactorAD: 1.0,
      );
      expect(q.isNaN, isTrue);
    });
  });

  // ── zoneHeatOutput tests ──────────────────────────────────────────────

  group('HeatingOutputEngine.zoneHeatOutput', () {
    test('known specific output and area', () {
      final q = HeatingOutputEngine.zoneHeatOutput(
        specificOutputWPerM2: 50.0,
        zoneAreaM2: 15.0,
      );
      expect(q, closeTo(750.0, 0.01));
    });

    test('zero area returns NaN', () {
      final q = HeatingOutputEngine.zoneHeatOutput(
        specificOutputWPerM2: 50.0,
        zoneAreaM2: 0.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('NaN specific output returns NaN', () {
      final q = HeatingOutputEngine.zoneHeatOutput(
        specificOutputWPerM2: double.nan,
        zoneAreaM2: 15.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('zero specific output returns NaN', () {
      final q = HeatingOutputEngine.zoneHeatOutput(
        specificOutputWPerM2: 0.0,
        zoneAreaM2: 15.0,
      );
      expect(q.isNaN, isTrue);
    });

    test('negative area returns NaN', () {
      final q = HeatingOutputEngine.zoneHeatOutput(
        specificOutputWPerM2: 50.0,
        zoneAreaM2: -5.0,
      );
      expect(q.isNaN, isTrue);
    });
  });

  // ── surfaceTemperature tests ──────────────────────────────────────────

  group('HeatingOutputEngine.surfaceTemperature', () {
    test('standard floor: q=50 W/m2, room=20C, alpha=10.8', () {
      // T = 20 + 50/10.8 = 20 + 4.63 = 24.63
      final t = HeatingOutputEngine.surfaceTemperature(
        tRoomC: 20.0,
        specificOutputWPerM2: 50.0,
      );
      expect(t, closeTo(24.63, 0.1));
    });

    test('high output reaches limit', () {
      // T = 20 + 100/10.8 = 29.26 → just above 29C occupied limit
      final t = HeatingOutputEngine.surfaceTemperature(
        tRoomC: 20.0,
        specificOutputWPerM2: 100.0,
      );
      expect(t, closeTo(29.26, 0.1));
    });

    test('NaN specific output returns NaN', () {
      final t = HeatingOutputEngine.surfaceTemperature(
        tRoomC: 20.0,
        specificOutputWPerM2: double.nan,
      );
      expect(t.isNaN, isTrue);
    });

    test('zero alphaTotal returns NaN', () {
      final t = HeatingOutputEngine.surfaceTemperature(
        tRoomC: 20.0,
        specificOutputWPerM2: 50.0,
        alphaTotal: 0.0,
      );
      expect(t.isNaN, isTrue);
    });

    test('negative alphaTotal returns NaN', () {
      final t = HeatingOutputEngine.surfaceTemperature(
        tRoomC: 20.0,
        specificOutputWPerM2: 50.0,
        alphaTotal: -1.0,
      );
      expect(t.isNaN, isTrue);
    });
  });

  // ── surfaceTempLimitExceeded tests ────────────────────────────────────

  group('HeatingOutputEngine.surfaceTempLimitExceeded', () {
    test('occupied floor: 28C is within limit', () {
      final result = HeatingOutputEngine.surfaceTempLimitExceeded(
        surfaceTempC: 28.0,
        zoneType: SurfaceZoneType.occupiedFloor,
      );
      expect(result, isNull);
    });

    test('occupied floor: 29C is within limit (not exceeded)', () {
      final result = HeatingOutputEngine.surfaceTempLimitExceeded(
        surfaceTempC: 29.0,
        zoneType: SurfaceZoneType.occupiedFloor,
      );
      expect(result, isNull);
    });

    test('occupied floor: 29.1C exceeds 29C limit', () {
      final result = HeatingOutputEngine.surfaceTempLimitExceeded(
        surfaceTempC: 29.1,
        zoneType: SurfaceZoneType.occupiedFloor,
      );
      expect(result, equals(29.0));
    });

    test('peripheral floor: 35.5C exceeds 35C limit', () {
      final result = HeatingOutputEngine.surfaceTempLimitExceeded(
        surfaceTempC: 35.5,
        zoneType: SurfaceZoneType.peripheralFloor,
      );
      expect(result, equals(35.0));
    });

    test('peripheral floor: 34C is within limit', () {
      final result = HeatingOutputEngine.surfaceTempLimitExceeded(
        surfaceTempC: 34.0,
        zoneType: SurfaceZoneType.peripheralFloor,
      );
      expect(result, isNull);
    });

    test('bathroom floor: 33.5C exceeds 33C limit', () {
      final result = HeatingOutputEngine.surfaceTempLimitExceeded(
        surfaceTempC: 33.5,
        zoneType: SurfaceZoneType.bathroomFloor,
      );
      expect(result, equals(33.0));
    });

    test('bathroom floor: 32C is within limit', () {
      final result = HeatingOutputEngine.surfaceTempLimitExceeded(
        surfaceTempC: 32.0,
        zoneType: SurfaceZoneType.bathroomFloor,
      );
      expect(result, isNull);
    });

    test('wall heating: 41C exceeds 40C limit', () {
      final result = HeatingOutputEngine.surfaceTempLimitExceeded(
        surfaceTempC: 41.0,
        zoneType: SurfaceZoneType.wallHeating,
      );
      expect(result, equals(40.0));
    });

    test('wall heating: 39C is within limit', () {
      final result = HeatingOutputEngine.surfaceTempLimitExceeded(
        surfaceTempC: 39.0,
        zoneType: SurfaceZoneType.wallHeating,
      );
      expect(result, isNull);
    });

    test('NaN surface temp returns null', () {
      final result = HeatingOutputEngine.surfaceTempLimitExceeded(
        surfaceTempC: double.nan,
        zoneType: SurfaceZoneType.occupiedFloor,
      );
      expect(result, isNull);
    });
  });
}
