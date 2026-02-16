import 'dart:math' show pi, log, pow, sqrt;

import '../../data/models/point2d.dart';

/// Hydraulic calculation engine — Darcy-Weisbach / Swamee-Jain.
///
/// All functions are pure static. Returns [double.nan] for invalid inputs;
/// never throws.
///
/// // TODO(HVAC): Physical properties (ρ, μ, ν) use 40 °C constants.
/// // For higher accuracy implement temperature-dependent lookup tables.
class HydraulicEngine {
  HydraulicEngine._(); // coverage:ignore-line

  /// Tube length within a heating zone (m).
  ///
  /// L_zone ≈ A_zone / (spacing / 1000)
  static double zoneTubeLength({
    required double zoneAreaM2,
    required int tubeSpacingMm,
  }) {
    if (zoneAreaM2 <= 0 || tubeSpacingMm <= 0) return double.nan;
    return zoneAreaM2 / (tubeSpacingMm / 1000.0);
  }

  /// Total tube length including supply and return runs (m).
  static double totalTubeLength({
    required double zoneTubeLengthM,
    required double supplyRouteLengthM,
    required double returnRouteLengthM,
  }) {
    if (zoneTubeLengthM < 0 ||
        supplyRouteLengthM < 0 ||
        returnRouteLengthM < 0) {
      return double.nan;
    }
    return zoneTubeLengthM + supplyRouteLengthM + returnRouteLengthM;
  }

  /// Water volume in a circuit (litres).
  ///
  /// V = π × (d_i / 2)² × L × 1000
  static double waterVolumeLitres({
    required double innerDiameterMm,
    required double tubeLengthM,
  }) {
    if (innerDiameterMm <= 0 || tubeLengthM <= 0) return double.nan;
    final rM = (innerDiameterMm / 1000.0) / 2.0;
    return pi * rM * rM * tubeLengthM * 1000.0;
  }

  /// Mass flow rate (kg/h).
  ///
  /// ṁ = Q / (c_w × (T_supply − T_return)) × 3600
  static double massFlowRateKgH({
    required double heatOutputW,
    required double tSupplyC,
    required double tReturnC,
    double cWater = 4186.0,
  }) {
    final deltaT = tSupplyC - tReturnC;
    if (deltaT <= 0 || cWater <= 0) return double.nan;
    return heatOutputW / (cWater * deltaT) * 3600.0;
  }

  /// Flow velocity (m/s).
  ///
  /// v = (ṁ / 3600) / (ρ × π × (d_i / 2)²)
  static double flowVelocity({
    required double massFlowRateKgH,
    required double innerDiameterMm,
    double rhoWater = 992.2,
  }) {
    if (massFlowRateKgH <= 0 || innerDiameterMm <= 0 || rhoWater <= 0) {
      return double.nan;
    }
    final rM = (innerDiameterMm / 1000.0) / 2.0;
    final area = pi * rM * rM;
    return (massFlowRateKgH / 3600.0) / (rhoWater * area);
  }

  /// Reynolds number.
  ///
  /// Re = v × d_i / ν
  ///
  /// [innerDiameterMm] in mm, [nuWater] kinematic viscosity in m²/s.
  static double reynoldsNumber({
    required double velocityMs,
    required double innerDiameterMm,
    double nuWater = 6.58e-7,
  }) {
    if (innerDiameterMm <= 0 || nuWater <= 0) return double.nan;
    return velocityMs * (innerDiameterMm / 1000.0) / nuWater;
  }

  /// Darcy friction factor.
  ///
  /// - Laminar (Re < 2300):     f = 64 / Re
  /// - Turbulent (Re > 5000):   Swamee-Jain: f = 0.25 / [log₁₀(ε/(3.7×d) + 5.74/Re^0.9)]²
  /// - Transition (2300–5000):  linear interpolation between both boundary values.
  ///
  /// Returns [double.nan] if Re ≤ 0.
  static double darcyFrictionFactor({
    required double reynoldsNumber,
    required double roughnessMm,
    required double innerDiameterMm,
  }) {
    if (reynoldsNumber <= 0 || roughnessMm <= 0 || innerDiameterMm <= 0) {
      return double.nan;
    }
    if (reynoldsNumber < 2300) {
      return 64.0 / reynoldsNumber;
    }
    final fTurb5000 = _swameeJain(roughnessMm, innerDiameterMm, 5000.0);
    if (reynoldsNumber > 5000) {
      return _swameeJain(roughnessMm, innerDiameterMm, reynoldsNumber);
    }
    // Transition zone: linear interpolation
    const fLam2300 = 64.0 / 2300.0;
    final t = (reynoldsNumber - 2300.0) / (5000.0 - 2300.0);
    return fLam2300 + t * (fTurb5000 - fLam2300);
  }

  /// Friction pressure loss — Darcy-Weisbach (Pa).
  ///
  /// Δp = f × (L / d_i) × (ρ × v² / 2)
  static double frictionPressureLoss({
    required double frictionFactor,
    required double tubeLengthM,
    required double innerDiameterMm,
    required double velocityMs,
    double rhoWater = 992.2,
  }) {
    if (frictionFactor.isNaN || frictionFactor <= 0) return double.nan;
    if (tubeLengthM <= 0 || innerDiameterMm <= 0) return double.nan;
    final dM = innerDiameterMm / 1000.0;
    return frictionFactor *
        (tubeLengthM / dM) *
        (rhoWater * velocityMs * velocityMs / 2.0);
  }

  /// Fitting pressure loss (Pa).
  ///
  /// Default: [surchargePercent] applied to friction loss.
  /// If [zetaValues] are supplied, uses Σ(ζ × ρ × v² / 2) instead;
  /// [velocityMs] must be provided in that case.
  static double fittingPressureLoss({
    required double frictionLossPa,
    double surchargePercent = 40.0,
    List<double>? zetaValues,
    double? velocityMs,
    double rhoWater = 992.2,
  }) {
    if (zetaValues != null) {
      if (velocityMs == null) return double.nan;
      final dynPressure = rhoWater * velocityMs * velocityMs / 2.0;
      return zetaValues.fold(0.0, (sum, zeta) => sum + zeta * dynPressure);
    }
    if (frictionLossPa.isNaN || frictionLossPa < 0) return double.nan;
    return frictionLossPa * surchargePercent / 100.0;
  }

  /// Total circuit pressure loss (Pa).
  static double totalPressureLoss({
    required double frictionLossPa,
    required double fittingLossPa,
  }) {
    if (frictionLossPa.isNaN || fittingLossPa.isNaN) return double.nan;
    return frictionLossPa + fittingLossPa;
  }

  /// Hydraulic balancing — required valve throttling per circuit.
  ///
  /// The reference circuit (highest pressure loss) receives Δp_valve = 0.
  /// All other circuits receive Δp_valve = max − circuit loss.
  ///
  /// Returns an empty map if [circuitPressureLosses] is empty.
  static Map<String, double> hydraulicBalance({
    required Map<String, double> circuitPressureLosses,
  }) {
    if (circuitPressureLosses.isEmpty) return {};
    final maxLoss =
        circuitPressureLosses.values.reduce((a, b) => a > b ? a : b);
    return {
      for (final e in circuitPressureLosses.entries)
        e.key: maxLoss - e.value,
    };
  }

  /// Polyline length (m) from a list of [Point2D] coordinates in mm.
  static double polylineLengthM(List<Point2D> points) {
    if (points.length < 2) return double.nan;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final dx = points[i + 1].x - points[i].x;
      final dy = points[i + 1].y - points[i].y;
      total += sqrt(dx * dx + dy * dy);
    }
    return total / 1000.0; // mm → m
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Swamee-Jain turbulent friction factor approximation.
  ///
  /// f = 0.25 / [log₁₀(ε/(3.7×d) + 5.74/Re^0.9)]²
  static double _swameeJain(
    double roughnessMm,
    double innerDiameterMm,
    double re,
  ) {
    final term = roughnessMm / (3.7 * innerDiameterMm) + 5.74 / pow(re, 0.9);
    if (term <= 0) return double.nan;
    final logTerm = log(term) / log(10);
    return 0.25 / (logTerm * logTerm);
  }
}
