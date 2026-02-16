/// Extension methods on [double] for rounding and equality checks.
extension DoubleExt on double {
  /// Rounds this value to [decimals] decimal places.
  double roundTo(int decimals) {
    final factor = _pow10(decimals);
    return (this * factor).round() / factor;
  }

  /// Returns true when the absolute difference between this and [other]
  /// is within [epsilon].
  bool isAlmostEqual(double other, {double epsilon = 1e-9}) =>
      (this - other).abs() < epsilon;
}

double _pow10(int n) {
  var result = 1.0;
  for (var i = 0; i < n; i++) {
    result *= 10;
  }
  return result;
}
