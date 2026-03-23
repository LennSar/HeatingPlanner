import '../../core/constants/thermal_defaults.dart';
import '../../data/models/enums.dart';

/// Thermal calculation engine — EN ISO 6946 / EN 12831.
///
/// All functions are pure static. Returns [double.nan] for invalid inputs;
/// never throws.
class ThermalEngine {
  ThermalEngine._(); // coverage:ignore-line

  /// U-value (thermal transmittance) of a composite wall assembly.
  ///
  /// EN ISO 6946: U = 1 / (R_si + Σ(d_i/λ_i) + R_se)
  ///
  /// [layerThicknessesMm] and [layerLambdas] must have equal length ≥ 1.
  /// Thicknesses in mm, lambdas in W/(m·K), surface resistances in m²·K/W.
  /// Returns U in W/(m²·K).
  static double uValue({
    required List<double> layerThicknessesMm,
    required List<double> layerLambdas,
    required double rsi,
    required double rse,
  }) {
    final r = totalResistance(
      layerThicknessesMm: layerThicknessesMm,
      layerLambdas: layerLambdas,
      rsi: rsi,
      rse: rse,
    );
    if (r.isNaN || r <= 0) return double.nan;
    return 1.0 / r;
  }

  /// Total thermal resistance of the assembly R_total (m²·K/W).
  ///
  /// R_total = R_si + Σ(d_i/λ_i) + R_se
  static double totalResistance({
    required List<double> layerThicknessesMm,
    required List<double> layerLambdas,
    required double rsi,
    required double rse,
  }) {
    if (layerThicknessesMm.isEmpty) return double.nan;
    if (layerThicknessesMm.length != layerLambdas.length) return double.nan;
    if (rsi <= 0 || rse <= 0) return double.nan;
    var r = rsi + rse;
    for (var i = 0; i < layerThicknessesMm.length; i++) {
      final d = layerThicknessesMm[i] / 1000.0; // mm → m
      final lambda = layerLambdas[i];
      if (d <= 0 || lambda <= 0) return double.nan;
      r += d / lambda;
    }
    return r;
  }

  /// Temperature at each layer interface through the wall.
  ///
  /// Returns a list of (n + 2) values:
  ///   [0]       interior surface temperature (after R_si)
  ///   [1]..[n]  temperature after each of the n layers
  ///   [n + 1]   exterior surface temperature (= T_outdoor, after R_se)
  ///
  /// Returns an empty list if inputs are invalid.
  static List<double> temperatureProfile({
    required List<double> layerThicknessesMm,
    required List<double> layerLambdas,
    required double rsi,
    required double rse,
    required double tIndoorC,
    required double tOutdoorC,
  }) {
    final rTotal = totalResistance(
      layerThicknessesMm: layerThicknessesMm,
      layerLambdas: layerLambdas,
      rsi: rsi,
      rse: rse,
    );
    if (rTotal.isNaN || rTotal <= 0) return [];

    final n = layerThicknessesMm.length;
    final temps = List<double>.filled(n + 2, 0.0);
    final deltaT = tIndoorC - tOutdoorC;

    // [0]: interior surface (after R_si)
    temps[0] = tIndoorC - deltaT * rsi / rTotal;

    // [1..n]: after each layer
    for (var i = 0; i < n; i++) {
      final rLayer = layerThicknessesMm[i] / 1000.0 / layerLambdas[i];
      temps[i + 1] = temps[i] - deltaT * rLayer / rTotal;
    }

    // [n+1]: exterior surface (after R_se = T_outdoor)
    temps[n + 1] = tOutdoorC;
    return temps;
  }

  /// Transmission heat loss through a single building element (W).
  ///
  /// Q = U × A × f × (T_i − T_e)
  ///
  /// [correctionF] is dimensionless (1.0 for exterior elements).
  /// Returns 0.0 when [correctionF] == 0 (no loss between same-temp spaces).
  static double transmissionLoss({
    required double uValue,
    required double areaM2,
    required double correctionF,
    required double tIndoorC,
    required double tOutdoorC,
  }) {
    if (uValue.isNaN || uValue <= 0) return double.nan;
    if (areaM2 <= 0) return double.nan;
    if (correctionF == 0) return 0.0;
    return uValue * areaM2 * correctionF * (tIndoorC - tOutdoorC);
  }

  /// Net wall area after subtracting openings (m²).
  ///
  /// A_net = wallLengthMm × wallHeightMm / 1e6 − Σ(opening areas in m²)
  static double netWallAreaM2({
    required double wallLengthMm,
    required double wallHeightMm,
    required List<({int widthMm, int heightMm})> openings,
  }) {
    if (wallLengthMm <= 0 || wallHeightMm <= 0) return double.nan;
    var gross = wallLengthMm * wallHeightMm / 1e6;
    for (final o in openings) {
      gross -= o.widthMm * o.heightMm / 1e6;
    }
    return gross < 0 ? 0.0 : gross;
  }

  /// Temperature correction factor for floor or ceiling boundary
  /// conditions (EN 12831 §6.3.3).
  ///
  /// | [BoundaryCondition] | Factor |
  /// |---------------------|--------|
  /// | exterior            | 1.0 (direct outdoor contact) |
  /// | ground              | [groundCorrectionFactorDefault] = 0.6 |
  /// | unheatedSpace       | (T_room − T_adjacent)/(T_room − T_outdoor) |
  /// | interior            | (T_room − T_adjacent)/(T_room − T_outdoor) |
  ///
  /// [tAdjacentC] is required for [BoundaryCondition.unheatedSpace] and
  /// [BoundaryCondition.interior]; callers must resolve null to the
  /// appropriate project-level default before calling. Returns
  /// [double.nan] when [tAdjacentC] is null for those conditions, or
  /// when T_room == T_outdoor (division by zero).
  static double boundaryCorrectionFactor({
    required BoundaryCondition condition,
    required double tRoomC,
    required double tOutdoorC,
    double? tAdjacentC,
  }) {
    switch (condition) {
      case BoundaryCondition.exterior:
        return 1.0;
      case BoundaryCondition.ground:
        return groundCorrectionFactorDefault;
      case BoundaryCondition.unheatedSpace:
      case BoundaryCondition.interior:
        if (tAdjacentC == null) return double.nan;
        return interiorCorrectionFactor(
          tThisRoomC: tRoomC,
          tAdjacentRoomC: tAdjacentC,
          tOutdoorC: tOutdoorC,
        );
    }
  }

  /// Temperature correction factor for interior walls.
  ///
  /// f = (T_this − T_adjacent) / (T_this − T_outdoor)
  ///
  /// Returns 0.0 if both rooms are at the same temperature.
  /// Returns [double.nan] if T_this == T_outdoor (division by zero).
  static double interiorCorrectionFactor({
    required double tThisRoomC,
    required double tAdjacentRoomC,
    required double tOutdoorC,
  }) {
    if (tThisRoomC == tAdjacentRoomC) return 0.0;
    final denominator = tThisRoomC - tOutdoorC;
    if (denominator == 0) return double.nan;
    return (tThisRoomC - tAdjacentRoomC) / denominator;
  }

  /// Ventilation heat loss (W).
  ///
  /// Q_V = V × n × ρ_air × c_air × (T_i − T_e) / 3600
  ///
  /// The /3600 converts J/h to W (watts = J/s).
  static double ventilationLoss({
    required double roomVolumeM3,
    required double airChangeRate, // 1/h
    required double tIndoorC,
    required double tOutdoorC,
    double rhoAir = 1.2,
    double cAir = 1005.0,
  }) {
    if (roomVolumeM3 <= 0 || airChangeRate <= 0) return double.nan;
    return roomVolumeM3 *
        airChangeRate *
        rhoAir *
        cAir *
        (tIndoorC - tOutdoorC) /
        3600.0;
  }

  /// Room volume from floor area and ceiling height (m³).
  static double roomVolumeM3({
    required double floorAreaM2,
    required double ceilingHeightMm,
  }) {
    if (floorAreaM2 <= 0 || ceilingHeightMm <= 0) return double.nan;
    return floorAreaM2 * ceilingHeightMm / 1000.0;
  }
}
