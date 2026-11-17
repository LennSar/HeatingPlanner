import 'dart:math' show log, pi, pow;

import '../../core/constants/en1264_tables.dart';

/// EN 1264 surface zone classification for surface temperature limits.
enum SurfaceZoneType {
  occupiedFloor, // max 29 °C
  peripheralFloor, // max 35 °C
  bathroomFloor, // max 33 °C
  wallHeating, // max 40 °C
}

/// Heating output calculation engine — EN 1264 / EN 15377.
///
/// All functions are pure static. Returns [double.nan] for invalid inputs;
/// never throws.
class HeatingOutputEngine {
  HeatingOutputEngine._(); // coverage:ignore-line

  /// Logarithmic mean temperature difference (°C).
  ///
  /// ΔT = (T_supply − T_return) / ln((T_supply − T_room) / (T_return − T_room))
  ///
  /// Falls back to arithmetic mean of the two temperature differences when
  /// the denominator (the log term) is < 0.1, avoiding division near zero.
  static double logMeanTempDifference({
    required double tSupplyC,
    required double tReturnC,
    required double tRoomC,
  }) {
    final dSup = tSupplyC - tRoomC;
    final dRet = tReturnC - tRoomC;
    if (dSup <= 0 || dRet <= 0) return double.nan;
    final denominator = log(dSup / dRet);
    if (denominator.abs() < 0.1) {
      // Arithmetic mean fallback
      return (dSup + dRet) / 2.0;
    }
    return (tSupplyC - tReturnC) / denominator;
  }

  /// Equivalent heat transmission coefficient K_H in W/(m²·K) of a
  /// floor heating system with pipes embedded in the screed (EN 1264-2
  /// types A and C), so that `q = K_H · Δθ_H`.
  ///
  /// `K_H = B · a_B · a_T^m_T · a_U^m_U · a_D^m_D` with
  /// - `m_T = 1 − T / 0.075`
  /// - `m_U = 100 · (0.045 − s_u)`
  /// - `m_D = 250 · (D − 0.020)`
  /// - B corrected for the pipe's conductivity and wall thickness:
  ///   `1/B = 1/B₀ + 1.1/π · Π(a_i^m_i) · T ·
  ///   [ln(D/(D−2s_R))/(2λ_R) − ln(D/(D−2s_R,0))/(2λ_R,0)]`
  ///
  /// The factors come from [EN1264Tables]. Validity as in the standard:
  /// spacing 0.05 … 0.375 m, pipe diameter 8 … 30 mm, screed cover
  /// ≥ 10 mm, covering resistance ≤ 0.15 m²K/W. Inputs outside are
  /// clamped to the nearest valid value for the factors, with two
  /// exceptions: a spacing above 0.375 m scales the result by 0.375 / T
  /// (EN 1264-2), and a_B always uses the actual covering resistance.
  ///
  /// Returns [double.nan] for non-positive geometry or conductivities.
  static double heatTransferCoefficientTypeA({
    required int tubeSpacingMm,
    required double tubeOuterDiameterMm,
    required double tubeWallThicknessMm,
    required double tubeConductivityWPerMK,
    required double coveringResistanceM2KPerW,
    double screedCoverMm = EN1264Tables.defaultScreedCoverMm,
    double screedConductivityWPerMK =
        EN1264Tables.defaultScreedConductivityWPerMK,
  }) {
    if (tubeSpacingMm <= 0 ||
        tubeOuterDiameterMm <= 0 ||
        tubeWallThicknessMm <= 0 ||
        tubeWallThicknessMm * 2 >= tubeOuterDiameterMm ||
        tubeConductivityWPerMK <= 0 ||
        screedCoverMm <= 0 ||
        screedConductivityWPerMK <= 0 ||
        coveringResistanceM2KPerW.isNaN) {
      return double.nan;
    }
    final r = coveringResistanceM2KPerW < 0 ? 0.0 : coveringResistanceM2KPerW;
    final actualSpacingM = tubeSpacingMm / 1000.0;
    final spacingM = actualSpacingM
        .clamp(
          EN1264Tables.minTabulatedSpacingM,
          EN1264Tables.maxTabulatedSpacingM,
        )
        .toDouble();
    final diameterM = (tubeOuterDiameterMm / 1000.0).clamp(0.008, 0.030);
    final screedCoverM = screedCoverMm / 1000.0 < 0.010
        ? 0.010
        : screedCoverMm / 1000.0;

    final aB = EN1264Tables.coveringFactorAB(
      coveringResistanceM2KPerW: r,
      screedConductivityWPerMK: screedConductivityWPerMK,
    );
    final aT = EN1264Tables.spacingFactorAT(r);
    final aU = EN1264Tables.coveringFactorAU(spacingM, r);
    final aD = EN1264Tables.diameterFactorAD(spacingM, r);

    final mT = 1.0 - spacingM / 0.075;
    final mU = 100.0 * (0.045 - screedCoverM);
    final mD = 250.0 * (diameterM - 0.020);
    final product = aB * pow(aT, mT) * pow(aU, mU) * pow(aD, mD);

    // Pipe other than the reference pipe (λ 0.35 W/(m·K), wall 2 mm).
    final outerM = tubeOuterDiameterMm / 1000.0;
    final wallM = tubeWallThicknessMm / 1000.0;
    const refWallM = EN1264Tables.referencePipeWallThicknessM;
    var b = EN1264Tables.systemConstantB;
    if (outerM > 2 * refWallM) {
      final pipeTerm =
          log(outerM / (outerM - 2 * wallM)) / (2 * tubeConductivityWPerMK) -
          log(outerM / (outerM - 2 * refWallM)) /
              (2 * EN1264Tables.referencePipeConductivityWPerMK);
      final inverseB =
          1.0 / EN1264Tables.systemConstantB +
          1.1 / pi * product * spacingM * pipeTerm;
      if (inverseB <= 0) return double.nan;
      b = 1.0 / inverseB;
    }

    final kH = b * product;
    return actualSpacingM > EN1264Tables.maxTabulatedSpacingM
        ? kH * EN1264Tables.maxTabulatedSpacingM / actualSpacingM
        : kH;
  }

  /// Equivalent heat transmission coefficient K_H in W/(m²·K) of a wall
  /// heating system with embedded pipes (EN 1264-5).
  ///
  /// EN 1264-5 converts the floor value: the surface resistance of a
  /// wall (1/8 instead of 1/10.8 m²K/W) is treated as an additional
  /// covering resistance ΔR_α on the line between the floor values
  /// without covering (K_H,0) and with R_λ,B = 0.15 m²K/W (K_H*):
  ///
  /// `K_H = K_H,0 / (1 + (ΔR_α + R_λ,B) / 0.15 · (K_H,0 / K_H* − 1))`
  ///
  /// Parameters as for [heatTransferCoefficientTypeA]; the screed values
  /// describe the plaster layer covering the pipes.
  static double heatTransferCoefficientWall({
    required int tubeSpacingMm,
    required double tubeOuterDiameterMm,
    required double tubeWallThicknessMm,
    required double tubeConductivityWPerMK,
    required double coveringResistanceM2KPerW,
    double screedCoverMm = EN1264Tables.defaultScreedCoverMm,
    double screedConductivityWPerMK =
        EN1264Tables.defaultScreedConductivityWPerMK,
  }) {
    if (coveringResistanceM2KPerW.isNaN) return double.nan;
    double floorValue(double resistance) => heatTransferCoefficientTypeA(
      tubeSpacingMm: tubeSpacingMm,
      tubeOuterDiameterMm: tubeOuterDiameterMm,
      tubeWallThicknessMm: tubeWallThicknessMm,
      tubeConductivityWPerMK: tubeConductivityWPerMK,
      coveringResistanceM2KPerW: resistance,
      screedCoverMm: screedCoverMm,
      screedConductivityWPerMK: screedConductivityWPerMK,
    );
    const rStar = EN1264Tables.maxTabulatedCoveringResistanceM2KPerW;
    final k0 = floorValue(0);
    final kStar = floorValue(rStar);
    if (k0.isNaN || kStar.isNaN || kStar <= 0) return double.nan;
    const deltaRAlpha =
        1.0 / EN1264Tables.alphaWallWPerM2K -
        1.0 / EN1264Tables.alphaFloorWPerM2K;
    final r = coveringResistanceM2KPerW < 0 ? 0.0 : coveringResistanceM2KPerW;
    return k0 / (1.0 + (deltaRAlpha + r) / rStar * (k0 / kStar - 1.0));
  }

  /// Heat flux density `q = K_H · Δθ_H` in W/m² (EN 1264-2).
  ///
  /// [heatTransferCoefficientWPerM2K] from
  /// [heatTransferCoefficientTypeA] or [heatTransferCoefficientWall],
  /// [deltaT] from [logMeanTempDifference].
  static double heatFluxDensity({
    required double heatTransferCoefficientWPerM2K,
    required double deltaT,
  }) {
    if (heatTransferCoefficientWPerM2K.isNaN ||
        heatTransferCoefficientWPerM2K <= 0) {
      return double.nan;
    }
    if (deltaT.isNaN || deltaT <= 0) return double.nan;
    return heatTransferCoefficientWPerM2K * deltaT;
  }

  /// Generic power-product form `q = B × a_B × a_T × a_U × a_D × ΔT^n`.
  ///
  /// Kept for callers that supply their own factors. The application
  /// itself calculates floor and wall heating with
  /// [heatTransferCoefficientTypeA] / [heatTransferCoefficientWall] and
  /// [heatFluxDensity] (ADR-045).
  static double specificHeatOutput({
    required double deltaT, // from logMeanTempDifference
    required double systemConstantB, // from EN 1264 table (e.g. 6.7)
    required double coveringFactorAB, // from flooring R-value
    required double spacingFactorAT, // from tube spacing
    required double diameterFactorAU, // from tube outer diameter
    required double conductFactorAD, // from tube wall conductivity
    double exponentN = 1.1, // 1.1 for floor heating
  }) {
    if (deltaT.isNaN || deltaT <= 0) return double.nan;
    if (systemConstantB <= 0) return double.nan;
    return systemConstantB *
        coveringFactorAB *
        spacingFactorAT *
        diameterFactorAU *
        conductFactorAD *
        pow(deltaT, exponentN);
  }

  /// Total heat output of a zone (W).
  ///
  /// Q = q × A_zone
  static double zoneHeatOutput({
    required double specificOutputWPerM2,
    required double zoneAreaM2,
  }) {
    if (specificOutputWPerM2.isNaN || specificOutputWPerM2 <= 0) {
      return double.nan;
    }
    if (zoneAreaM2 <= 0) return double.nan;
    return specificOutputWPerM2 * zoneAreaM2;
  }

  /// Mean floor surface temperature (°C) from the EN 1264-2 basic
  /// characteristic curve `q = 8.92 · (θ_F,m − θ_i)^1.1`:
  ///
  /// `θ_F,m = θ_i + (q / 8.92)^(1/1.1)`
  ///
  /// Returns [tRoomC] for a non-positive output and [double.nan] for a
  /// NaN input.
  static double floorSurfaceTemperature({
    required double tRoomC,
    required double specificOutputWPerM2,
  }) {
    if (specificOutputWPerM2.isNaN || tRoomC.isNaN) return double.nan;
    if (specificOutputWPerM2 <= 0) return tRoomC;
    return tRoomC +
        pow(
          specificOutputWPerM2 / EN1264Tables.basicCharacteristicB,
          1.0 / EN1264Tables.basicCharacteristicExponent,
        );
  }

  /// Mean surface temperature (°C) for a constant heat transfer
  /// coefficient: `T_surface = T_room + q / α_total`.
  ///
  /// Used for wall heating with α = 8 W/(m²·K) (EN 1264-5). For floors
  /// use [floorSurfaceTemperature]; the default [alphaTotal] of
  /// 10.8 W/(m²·K) is its linearisation.
  static double surfaceTemperature({
    required double tRoomC,
    required double specificOutputWPerM2,
    double alphaTotal = 10.8,
  }) {
    if (specificOutputWPerM2.isNaN || alphaTotal <= 0) return double.nan;
    return tRoomC + specificOutputWPerM2 / alphaTotal;
  }

  /// Check if surface temperature exceeds EN 1264 limits.
  ///
  /// Returns [null] if within limits, or the exceeded limit value (°C).
  static double? surfaceTempLimitExceeded({
    required double surfaceTempC,
    required SurfaceZoneType zoneType,
  }) {
    if (surfaceTempC.isNaN) return null;
    final limit = switch (zoneType) {
      SurfaceZoneType.occupiedFloor => 29.0,
      SurfaceZoneType.peripheralFloor => 35.0,
      SurfaceZoneType.bathroomFloor => 33.0,
      SurfaceZoneType.wallHeating => 40.0,
    };
    return surfaceTempC > limit ? limit : null;
  }
}
