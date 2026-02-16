import 'dart:math' show pow;

/// Simplified EN 1264 heat output correction factor model.
///
/// q = B × a_B × a_T × a_U × a_D × ΔT^n
///
/// APPROXIMATION: All factors below are simplified empirical curve fits.
/// For production accuracy replace with full EN 1264 digitised tables.
///
/// // TODO(HVAC): Replace with full EN 1264 tables when available.
class EN1264Tables {
  EN1264Tables._();

  /// System constant B — typical value for Type A wet embedded tube systems.
  static const double systemConstantB = 6.7;

  /// Temperature exponent n for floor heating (EN 1264-2).
  static const double exponentFloor = 1.1;

  /// Temperature exponent n for wall heating.
  ///
  /// // TODO(HVAC): EN 15377 may specify a different exponent for wall heating.
  static const double exponentWall = 1.1;

  /// Covering resistance correction factor a_B.
  ///
  /// Approximation: a_B = 1 / (1 + R_covering / 0.1)^0.4
  ///
  /// Returns 1.0 for R_covering ≤ 0 (no covering).
  static double coveringFactor(double rCoveringM2KW) {
    if (rCoveringM2KW <= 0) return 1.0;
    return 1.0 / pow(1.0 + rCoveringM2KW / 0.1, 0.4);
  }

  /// Tube spacing correction factor a_T.
  ///
  /// Approximation: a_T = (0.15 / spacing_m)^0.08
  ///
  /// Returns [double.nan] for spacing ≤ 0.
  static double spacingFactor(int spacingMm) {
    final spacingM = spacingMm / 1000.0;
    if (spacingM <= 0) return double.nan;
    return pow(0.15 / spacingM, 0.08).toDouble();
  }

  /// Tube outer diameter correction factor a_U.
  ///
  /// Approximation: a_U = (outerDiam_mm / 16.0)^0.03
  ///
  /// Returns [double.nan] for diameter ≤ 0.
  static double diameterFactor(double outerDiameterMm) {
    if (outerDiameterMm <= 0) return double.nan;
    return pow(outerDiameterMm / 16.0, 0.03).toDouble();
  }

  /// Tube wall thermal conductivity correction factor a_D.
  ///
  /// Approximation based on material class:
  /// - λ ≥ 50 W/(m·K) (copper):          a_D ≈ 1.04
  /// - 1 ≤ λ < 50 W/(m·K) (multilayer):  a_D ≈ 1.02
  /// - λ < 1 W/(m·K) (plastic):          a_D ≈ 1.00
  static double conductivityFactor(double tubeLambdaWPerMK) {
    if (tubeLambdaWPerMK >= 50.0) return 1.04; // copper
    if (tubeLambdaWPerMK >= 1.0) return 1.02; // multilayer / metal
    return 1.0; // plastic (PE-RT, PE-Xa, etc.)
  }
}
