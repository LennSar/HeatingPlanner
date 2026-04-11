// Tests for ThermalEngine.uValueCombined — EN ISO 6946:2017 §6.9.
//
// UVC-1  Fully homogeneous assembly matches uValue.
// UVC-2  Single inhomogeneous layer: R_T = (R'_T + R''_T) / 2.
// UVC-3  f_stud ≥ 1 returns double.nan.
// UVC-4  Multiple homogeneous layers match uValue.
// UVC-5  Invalid inputs return double.nan.

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/thermal_engine.dart';

void main() {
  // ── UVC-1: fully homogeneous assembly matches uValue ──────────────────────

  group('UVC-1: homogeneous assembly equals uValue', () {
    test('single-layer solid brick wall', () {
      // UV-1 reference: U ≈ 2.327 W/(m²·K)
      final uOld = ThermalEngine.uValue(
        layerThicknessesMm: [200.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
      );
      final uNew = ThermalEngine.uValueCombined(
        layers: [
          const HomogeneousLayerSpec(thicknessMm: 200.0, lambda: 0.77),
        ],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(uNew, closeTo(uOld, 1e-9));
    });

    test('UV-2 multi-layer insulated wall', () {
      // UV-2 reference: U ≈ 0.283 W/(m²·K)
      final uOld = ThermalEngine.uValue(
        layerThicknessesMm: [15.0, 100.0, 200.0, 15.0],
        layerLambdas: [1.00, 0.035, 0.44, 0.40],
        rsi: 0.13,
        rse: 0.04,
      );
      final uNew = ThermalEngine.uValueCombined(
        layers: [
          const HomogeneousLayerSpec(thicknessMm: 15.0, lambda: 1.00),
          const HomogeneousLayerSpec(thicknessMm: 100.0, lambda: 0.035),
          const HomogeneousLayerSpec(thicknessMm: 200.0, lambda: 0.44),
          const HomogeneousLayerSpec(thicknessMm: 15.0, lambda: 0.40),
        ],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(uNew, closeTo(uOld, 1e-9));
    });
  });

  // ── UVC-2: single inhomogeneous layer — hand-verified EN ISO 6946 §6.9 ───

  group('UVC-2: single inhomogeneous layer R_T = (R\'_T + R\'\'_T) / 2', () {
    // Assembly: rsi=0.13, rse=0.04
    // Layer: d=140mm, λ_main=0.035 (mineral wool), λ_stud=0.13 (timber)
    //        studWidth=38mm, studClearGap=562mm (600mm c/c spacing)
    //
    // f_stud = 38/600 = 0.06333…   f_main = 562/600 = 0.93667…
    //
    // Upper limit R'_T (parallel paths):
    //   R_T_main = 0.13 + 0.14/0.035 + 0.04 = 4.17
    //   R_T_stud = 0.13 + 0.14/0.13  + 0.04 ≈ 1.24692
    //   R'_T = 1 / (0.93667/4.17 + 0.06333/1.24692)
    //        = 1 / (0.22462 + 0.05079)
    //        ≈ 3.6308 m²·K/W
    //
    // Lower limit R''_T (series with parallel conductances):
    //   conductance = f_stud/r_stud + f_main/r_main
    //               = 0.06333/1.07692 + 0.93667/4.0
    //               ≈ 0.05881 + 0.23417 = 0.29298
    //   R_layer = 1/0.29298 ≈ 3.4133
    //   R''_T = 0.13 + 3.4133 + 0.04 ≈ 3.5833 m²·K/W
    //
    // R_T = (3.6308 + 3.5833) / 2 ≈ 3.6071 m²·K/W
    // U = 1/3.6071 ≈ 0.2772 W/(m²·K)

    const rsi = 0.13;
    const rse = 0.04;
    const d = 140.0; // mm
    const lambdaMain = 0.035;
    const lambdaStud = 0.13;
    const studWidth = 38.0;
    const studClearGap = 562.0;

    test('R_T matches (R\'_T + R\'\'_T) / 2', () {
      // Hand-compute expected R_T.
      const fStud = studWidth / (studWidth + studClearGap);
      const fMain = 1.0 - fStud;
      const rMain = d / 1000.0 / lambdaMain; // 4.0
      const rStud = d / 1000.0 / lambdaStud; // ≈ 1.07692

      // Upper limit
      const rTMain = rsi + rMain + rse;
      const rTStud = rsi + rStud + rse;
      const rPrimeT = 1.0 / (fMain / rTMain + fStud / rTStud);

      // Lower limit
      const conductance = fStud / rStud + fMain / rMain;
      const rDoublePrimeT = rsi + 1.0 / conductance + rse;

      const expectedRT = (rPrimeT + rDoublePrimeT) / 2.0;
      const expectedU = 1.0 / expectedRT;

      final u = ThermalEngine.uValueCombined(
        layers: [
          const InhomogeneousLayerSpec(
            thicknessMm: d,
            lambdaMain: lambdaMain,
            studWidthMm: studWidth,
            studClearGapMm: studClearGap,
            lambdaStud: lambdaStud,
          ),
        ],
        rsi: rsi,
        rse: rse,
      );

      expect(u, closeTo(expectedU, 1e-9));
      // Confirm ballpark against hand-worked value
      expect(u, closeTo(0.277, 0.001));
    });

    test('result is lower than homogeneous mineral-wool-only assembly', () {
      // Studs are more conductive than mineral wool, so the bridged assembly
      // should have a higher U (worse performance) than the pure fill.
      final uHomogeneous = ThermalEngine.uValueCombined(
        layers: [
          const HomogeneousLayerSpec(thicknessMm: d, lambda: lambdaMain),
        ],
        rsi: rsi,
        rse: rse,
      );
      final uBridged = ThermalEngine.uValueCombined(
        layers: [
          const InhomogeneousLayerSpec(
            thicknessMm: d,
            lambdaMain: lambdaMain,
            studWidthMm: studWidth,
            studClearGapMm: studClearGap,
            lambdaStud: lambdaStud,
          ),
        ],
        rsi: rsi,
        rse: rse,
      );
      expect(uBridged, greaterThan(uHomogeneous));
    });
  });

  // ── UVC-3: f_stud ≥ 1 returns double.nan ──────────────────────────────────

  group('UVC-3: f_stud ≥ 1 returns double.nan', () {
    test('f_stud == 1 (studClearGap = 0) returns NaN', () {
      final u = ThermalEngine.uValueCombined(
        layers: [
          const InhomogeneousLayerSpec(
            thicknessMm: 140.0,
            lambdaMain: 0.035,
            studWidthMm: 38.0,
            studClearGapMm: 0.0, // f_stud = 38/(38+0) = 1
            lambdaStud: 0.13,
          ),
        ],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('f_stud > 1 (negative studClearGap) returns NaN', () {
      final u = ThermalEngine.uValueCombined(
        layers: [
          const InhomogeneousLayerSpec(
            thicknessMm: 140.0,
            lambdaMain: 0.035,
            studWidthMm: 38.0,
            studClearGapMm: -10.0, // f_stud > 1
            lambdaStud: 0.13,
          ),
        ],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });
  });

  // ── UVC-4: additional validity checks ─────────────────────────────────────

  group('UVC-4 & UVC-5: invalid inputs return double.nan', () {
    test('empty layer list returns NaN', () {
      expect(
        ThermalEngine.uValueCombined(
          layers: [],
          rsi: 0.13,
          rse: 0.04,
        ).isNaN,
        isTrue,
      );
    });

    test('zero lambda returns NaN', () {
      expect(
        ThermalEngine.uValueCombined(
          layers: [const HomogeneousLayerSpec(thicknessMm: 200.0, lambda: 0.0)],
          rsi: 0.13,
          rse: 0.04,
        ).isNaN,
        isTrue,
      );
    });

    test('zero thickness returns NaN', () {
      expect(
        ThermalEngine.uValueCombined(
          layers: [const HomogeneousLayerSpec(thicknessMm: 0.0, lambda: 0.77)],
          rsi: 0.13,
          rse: 0.04,
        ).isNaN,
        isTrue,
      );
    });

    test('zero rsi returns NaN', () {
      expect(
        ThermalEngine.uValueCombined(
          layers: [const HomogeneousLayerSpec(thicknessMm: 200.0, lambda: 0.77)],
          rsi: 0.0,
          rse: 0.04,
        ).isNaN,
        isTrue,
      );
    });

    test('zero lambdaMain in inhomogeneous layer returns NaN', () {
      expect(
        ThermalEngine.uValueCombined(
          layers: [
            const InhomogeneousLayerSpec(
              thicknessMm: 140.0,
              lambdaMain: 0.0,
              studWidthMm: 38.0,
              studClearGapMm: 562.0,
            ),
          ],
          rsi: 0.13,
          rse: 0.04,
        ).isNaN,
        isTrue,
      );
    });
  });
}
