// EN 1264-2 (floor, system type A) and EN 1264-5 (wall) heat output
// (ADR-045). Expected values are worked by hand from the standard's
// equation and Annex A tables; the arithmetic is given with each test.

import 'dart:math' show log, pow;

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/heating_output_engine.dart';
import 'package:heating_planner/core/constants/en1264_tables.dart';

double _kH({
  int spacingMm = 100,
  double outerMm = 16,
  double wallMm = 2,
  double lambda = 0.35,
  double r = 0,
  double screedCoverMm = 45,
}) => HeatingOutputEngine.heatTransferCoefficientTypeA(
  tubeSpacingMm: spacingMm,
  tubeOuterDiameterMm: outerMm,
  tubeWallThicknessMm: wallMm,
  tubeConductivityWPerMK: lambda,
  coveringResistanceM2KPerW: r,
  screedCoverMm: screedCoverMm,
);

void main() {
  group('EN1264Tables', () {
    test('a_T follows Table A.1 and interpolates between columns', () {
      expect(EN1264Tables.spacingFactorAT(0), 1.23);
      expect(EN1264Tables.spacingFactorAT(0.10), closeTo(1.156, 1e-9));
      expect(EN1264Tables.spacingFactorAT(0.025), closeTo(1.209, 1e-9));
      // Clamped outside 0 … 0.15 m²K/W.
      expect(EN1264Tables.spacingFactorAT(-1), 1.23);
      expect(EN1264Tables.spacingFactorAT(0.4), closeTo(1.134, 1e-9));
    });

    test('a_U and a_D follow Tables A.2 / A.3', () {
      expect(EN1264Tables.coveringFactorAU(0.15, 0.10), closeTo(1.035, 1e-9));
      expect(EN1264Tables.diameterFactorAD(0.15, 0.10), closeTo(1.029, 1e-9));
      // Halfway between T = 0.10 and 0.15 m at R = 0.
      expect(
        EN1264Tables.diameterFactorAD(0.125, 0),
        closeTo((1.029 + 1.04) / 2, 1e-9),
      );
      expect(EN1264Tables.coveringFactorAU(0.375, 0.15), closeTo(1.015, 1e-9));
    });

    test('a_B is 1 for the reference screed without covering', () {
      expect(
        EN1264Tables.coveringFactorAB(
          coveringResistanceM2KPerW: 0,
          screedConductivityWPerMK: 1.0,
        ),
        closeTo(1.0, 1e-12),
      );
      // (1/10.8 + 0.045) / (1/10.8 + 0.045/1.2 + 0.10) = 0.5980
      expect(
        EN1264Tables.coveringFactorAB(coveringResistanceM2KPerW: 0.10),
        closeTo(0.5980, 5e-4),
      );
    });
  });

  group('HeatingOutputEngine.heatTransferCoefficientTypeA', () {
    test('tiles on 100 mm spacing, 16 × 2 PE-X', () {
      // a_B = 0.13759 / 0.13009 = 1.0577
      // a_T^m_T = 1.23^(1 − 0.1/0.075) = 0.9333
      // a_U^m_U = 1 (s_u = 45 mm), a_D^m_D = 1.029^−1 = 0.9718
      // K_H = 6.7 × 1.0577 × 0.9333 × 0.9718 = 6.43 W/(m²K)
      expect(_kH(), closeTo(6.43, 0.01));
    });

    test('carpet (0.10 m²K/W) on 150 mm spacing', () {
      // a_B = 0.5980, a_T^−1 = 1/1.156, a_D^−1 = 1/1.029
      // K_H = 6.7 × 0.5980 / 1.156 / 1.029 = 3.37 W/(m²K)
      expect(_kH(spacingMm: 150, r: 0.10), closeTo(3.37, 0.01));
    });

    test('thicker screed lowers the output through m_U', () {
      // m_U = 100 × (0.045 − 0.065) = −2, a_U = 1.035
      final thin = _kH(spacingMm: 150, r: 0.10);
      final thick = _kH(spacingMm: 150, r: 0.10, screedCoverMm: 65);
      expect(thick, closeTo(thin / pow(1.035, 2), 1e-9));
    });

    test('closer spacing and lower covering resistance raise the output', () {
      expect(_kH(spacingMm: 100), greaterThan(_kH(spacingMm: 200)));
      expect(_kH(r: 0.02), greaterThan(_kH(r: 0.10)));
    });

    test('a thinner or more conductive pipe wall raises B above 6.7', () {
      final reference = _kH(spacingMm: 150);
      expect(_kH(spacingMm: 150, wallMm: 1.5), greaterThan(reference));
      expect(_kH(spacingMm: 150, lambda: 0.43), greaterThan(reference));
      // Same wall and conductivity as the reference pipe: B stays B₀.
      // 1/B = 1/6.7 + 1.1/π × Π × T × [ln(16/13)/0.7 − ln(16/12)/0.7]
      final product = reference / 6.7;
      final inverseB =
          1 / 6.7 +
          1.1 /
              3.141592653589793 *
              product *
              0.15 *
              (log(16 / 13) / 0.7 - log(16 / 12) / 0.7);
      expect(
        _kH(spacingMm: 150, wallMm: 1.5),
        closeTo(product / inverseB, 1e-9),
      );
    });

    test('spacing above 375 mm scales with 0.375 / T', () {
      expect(
        _kH(spacingMm: 450),
        closeTo(_kH(spacingMm: 375) * 375 / 450, 1e-9),
      );
    });

    test('invalid input returns NaN', () {
      expect(_kH(spacingMm: 0).isNaN, isTrue);
      expect(_kH(outerMm: 0).isNaN, isTrue);
      expect(_kH(wallMm: 8).isNaN, isTrue);
      expect(_kH(lambda: 0).isNaN, isTrue);
      expect(_kH(r: double.nan).isNaN, isTrue);
      expect(_kH(screedCoverMm: 0).isNaN, isTrue);
    });
  });

  group('HeatingOutputEngine.heatFluxDensity', () {
    test('35/28 °C in a 20 °C room on tiles delivers about 72 W/m²', () {
      // Δθ_H = 7 / ln(15 / 8) = 11.14 K; q = 6.43 × 11.14 = 71.6 W/m²
      final deltaT = HeatingOutputEngine.logMeanTempDifference(
        tSupplyC: 35,
        tReturnC: 28,
        tRoomC: 20,
      );
      final q = HeatingOutputEngine.heatFluxDensity(
        heatTransferCoefficientWPerM2K: _kH(),
        deltaT: deltaT,
      );
      expect(q, closeTo(71.6, 0.3));
    });

    test('is linear in the temperature difference', () {
      final q10 = HeatingOutputEngine.heatFluxDensity(
        heatTransferCoefficientWPerM2K: 5,
        deltaT: 10,
      );
      final q20 = HeatingOutputEngine.heatFluxDensity(
        heatTransferCoefficientWPerM2K: 5,
        deltaT: 20,
      );
      expect(q10, 50);
      expect(q20, 100);
    });

    test('invalid input returns NaN', () {
      expect(
        HeatingOutputEngine.heatFluxDensity(
          heatTransferCoefficientWPerM2K: double.nan,
          deltaT: 10,
        ).isNaN,
        isTrue,
      );
      expect(
        HeatingOutputEngine.heatFluxDensity(
          heatTransferCoefficientWPerM2K: 5,
          deltaT: 0,
        ).isNaN,
        isTrue,
      );
    });
  });

  group('HeatingOutputEngine.heatTransferCoefficientWall', () {
    double wall(double r) => HeatingOutputEngine.heatTransferCoefficientWall(
      tubeSpacingMm: 100,
      tubeOuterDiameterMm: 16,
      tubeWallThicknessMm: 2,
      tubeConductivityWPerMK: 0.35,
      coveringResistanceM2KPerW: r,
    );

    test('follows the EN 1264-5 conversion of the floor values', () {
      final k0 = _kH();
      final kStar = _kH(r: 0.15);
      const deltaRAlpha = 1 / 8.0 - 1 / 10.8;
      expect(
        wall(0),
        closeTo(k0 / (1 + deltaRAlpha / 0.15 * (k0 / kStar - 1)), 1e-9),
      );
    });

    test('a wall delivers less than the same build-up as a floor', () {
      expect(wall(0), lessThan(_kH()));
      expect(wall(0.05), lessThan(wall(0)));
    });
  });

  group('HeatingOutputEngine.floorSurfaceTemperature', () {
    test('100 W/m² is 9 K above the room (basic characteristic curve)', () {
      expect(
        HeatingOutputEngine.floorSurfaceTemperature(
          tRoomC: 20,
          specificOutputWPerM2: 100,
        ),
        closeTo(29.0, 0.01),
      );
    });

    test('inverts q = 8.92 × Δθ^1.1', () {
      final t = HeatingOutputEngine.floorSurfaceTemperature(
        tRoomC: 22,
        specificOutputWPerM2: 60,
      );
      expect(8.92 * pow(t - 22, 1.1), closeTo(60, 1e-9));
    });

    test('no output leaves the surface at room temperature', () {
      expect(
        HeatingOutputEngine.floorSurfaceTemperature(
          tRoomC: 20,
          specificOutputWPerM2: 0,
        ),
        20,
      );
      expect(
        HeatingOutputEngine.floorSurfaceTemperature(
          tRoomC: 20,
          specificOutputWPerM2: double.nan,
        ).isNaN,
        isTrue,
      );
    });
  });
}
