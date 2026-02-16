import 'dart:math' show log, pow;

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

  /// Specific heat output per unit floor area (W/m²) — EN 1264.
  ///
  /// q = B × a_B × a_T × a_U × a_D × ΔT^n
  ///
  /// APPROXIMATION: Correction factors use simplified curve fits from
  /// [EN1264Tables]. Replace with full digitised tables for production accuracy.
  ///
  /// // TODO(HVAC): Replace approximation factors with full EN 1264 tables.
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

  /// Estimated mean surface temperature (°C).
  ///
  /// T_surface ≈ T_room + q / α_total
  ///
  /// [alphaTotal] ≈ 10.8 W/(m²·K) combines convective and radiative heat
  /// transfer at the floor surface (EN 1264-2 simplified model).
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
