/// EN 1264-2 characteristic-curve parameters for systems with pipes
/// embedded in the screed (types A and C), Annex A.
///
/// The heat flux density of such a system is
///
/// `q = B · a_B · a_T^m_T · a_U^m_U · a_D^m_D · Δθ_H`
///
/// This class holds the tabulated factors and the constants of that
/// equation; `HeatingOutputEngine.heatTransferCoefficientTypeA` combines
/// them (ADR-045).
///
/// Table values are interpolated linearly between the tabulated tube
/// spacings and covering resistances. Outside the tabulated range
/// (R_λ,B 0 … 0.15 m²K/W, T 0.05 … 0.375 m) the nearest table value is
/// used.
class EN1264Tables {
  EN1264Tables._(); // coverage:ignore-line

  /// System constant B₀ in W/(m²·K), valid for a pipe with thermal
  /// conductivity [referencePipeConductivityWPerMK] and wall thickness
  /// [referencePipeWallThicknessM].
  static const double systemConstantB = 6.7;

  /// Pipe thermal conductivity λ_R,0 the constant B₀ refers to, W/(m·K).
  static const double referencePipeConductivityWPerMK = 0.35;

  /// Pipe wall thickness s_R,0 the constant B₀ refers to, in metres.
  static const double referencePipeWallThicknessM = 0.002;

  /// Heat transfer coefficient at a heated floor surface, W/(m²·K).
  static const double alphaFloorWPerM2K = 10.8;

  /// Heat transfer coefficient at a heated wall surface, W/(m²·K)
  /// (EN 1264-5).
  static const double alphaWallWPerM2K = 8.0;

  /// Reference screed conductivity λ_u,0 in W/(m·K).
  static const double referenceScreedConductivityWPerMK = 1.0;

  /// Reference screed cover above the pipe s_u,0 in metres.
  static const double referenceScreedCoverM = 0.045;

  /// Screed conductivity λ_E assumed when the build-up is not modelled:
  /// cement screed, 1.2 W/(m·K).
  static const double defaultScreedConductivityWPerMK = 1.2;

  /// Screed cover above the pipe s_u assumed when the build-up is not
  /// modelled: 45 mm, the usual minimum for cement screed.
  static const double defaultScreedCoverMm = 45.0;

  /// Constant of the basic characteristic curve
  /// `q = 8.92 · (θ_F,m − θ_i)^1.1`, in W/(m²·K^1.1).
  static const double basicCharacteristicB = 8.92;

  /// Exponent of the basic characteristic curve.
  static const double basicCharacteristicExponent = 1.1;

  /// Largest covering resistance the tables cover, m²K/W.
  static const double maxTabulatedCoveringResistanceM2KPerW = 0.15;

  /// Largest tube spacing the tables cover, in metres.
  static const double maxTabulatedSpacingM = 0.375;

  /// Smallest tube spacing the tables cover, in metres.
  static const double minTabulatedSpacingM = 0.05;

  // Covering resistances R_λ,B of the table columns, m²K/W.
  static const List<double> _resistances = [0.0, 0.05, 0.10, 0.15];

  // Tube spacings T of the table rows, m.
  static const List<double> _spacings = [
    0.05,
    0.075,
    0.1,
    0.15,
    0.2,
    0.225,
    0.3,
    0.375,
  ];

  // Table A.1 — spacing factor a_T by R_λ,B.
  static const List<double> _aT = [1.23, 1.188, 1.156, 1.134];

  // Table A.2 — covering factor a_U by T (rows) and R_λ,B (columns).
  static const List<List<double>> _aU = [
    [1.069, 1.056, 1.043, 1.037],
    [1.066, 1.053, 1.041, 1.035],
    [1.063, 1.05, 1.039, 1.0335],
    [1.057, 1.046, 1.035, 1.0305],
    [1.051, 1.041, 1.0315, 1.0275],
    [1.048, 1.038, 1.0295, 1.026],
    [1.0395, 1.031, 1.024, 1.021],
    [1.03, 1.0221, 1.0181, 1.015],
  ];

  // Table A.3 — pipe diameter factor a_D by T (rows) and R_λ,B (columns).
  static const List<List<double>> _aD = [
    [1.013, 1.013, 1.012, 1.011],
    [1.021, 1.019, 1.016, 1.014],
    [1.029, 1.025, 1.022, 1.018],
    [1.04, 1.034, 1.029, 1.024],
    [1.046, 1.04, 1.035, 1.03],
    [1.049, 1.043, 1.038, 1.033],
    [1.053, 1.049, 1.044, 1.039],
    [1.056, 1.051, 1.046, 1.042],
  ];

  /// Floor covering factor
  /// `a_B = (1/α + s_u,0/λ_u,0) / (1/α + s_u,0/λ_E + R_λ,B)`.
  ///
  /// [coveringResistanceM2KPerW] is R_λ,B; negative values count as 0.
  /// Returns [double.nan] for a non-positive screed conductivity.
  static double coveringFactorAB({
    required double coveringResistanceM2KPerW,
    double screedConductivityWPerMK = defaultScreedConductivityWPerMK,
  }) {
    if (screedConductivityWPerMK <= 0) return double.nan;
    final r = coveringResistanceM2KPerW < 0 ? 0.0 : coveringResistanceM2KPerW;
    const surface = 1.0 / alphaFloorWPerM2K;
    return (surface +
            referenceScreedCoverM / referenceScreedConductivityWPerMK) /
        (surface + referenceScreedCoverM / screedConductivityWPerMK + r);
  }

  /// Spacing factor a_T (Table A.1) for a covering resistance.
  static double spacingFactorAT(double coveringResistanceM2KPerW) {
    final (i, t) = _locate(_resistances, coveringResistanceM2KPerW);
    return _aT[i] + t * (_aT[i + 1] - _aT[i]);
  }

  /// Covering factor a_U (Table A.2) for a tube spacing in metres and a
  /// covering resistance.
  static double coveringFactorAU(
    double spacingM,
    double coveringResistanceM2KPerW,
  ) => _bilinear(_aU, spacingM, coveringResistanceM2KPerW);

  /// Pipe diameter factor a_D (Table A.3) for a tube spacing in metres
  /// and a covering resistance.
  static double diameterFactorAD(
    double spacingM,
    double coveringResistanceM2KPerW,
  ) => _bilinear(_aD, spacingM, coveringResistanceM2KPerW);

  static double _bilinear(
    List<List<double>> table,
    double spacingM,
    double resistance,
  ) {
    final (row, u) = _locate(_spacings, spacingM);
    final (col, v) = _locate(_resistances, resistance);
    final low = table[row][col] + v * (table[row][col + 1] - table[row][col]);
    final high =
        table[row + 1][col] +
        v * (table[row + 1][col + 1] - table[row + 1][col]);
    return low + u * (high - low);
  }

  /// Index of the interval of [axis] containing [value] and the position
  /// inside it (0 … 1). Values outside the axis are clamped to its ends.
  static (int, double) _locate(List<double> axis, double value) {
    if (value.isNaN || value <= axis.first) return (0, 0.0);
    if (value >= axis.last) return (axis.length - 2, 1.0);
    var i = 0;
    while (value > axis[i + 1]) {
      i++;
    }
    return (i, (value - axis[i]) / (axis[i + 1] - axis[i]));
  }
}
