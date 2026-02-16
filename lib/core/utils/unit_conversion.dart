/// Unit conversion helpers.
abstract final class UnitConversion {
  /// Millimetres to metres.
  static double mmToM(double mm) => mm / 1000.0;

  /// Metres to millimetres.
  static double mToMm(double m) => m * 1000.0;

  /// Pascals to kilopascals.
  static double paToKpa(double pa) => pa / 1000.0;

  /// Kilopascals to Pascals.
  static double kpaToPa(double kpa) => kpa * 1000.0;

  /// Watts to kilowatts.
  static double wToKw(double w) => w / 1000.0;

  /// kg/h to kg/s.
  static double kgHToKgS(double kgH) => kgH / 3600.0;

  /// kg/s to kg/h.
  static double kgSToKgH(double kgS) => kgS * 3600.0;

  /// m²/h to m²/s.
  static double m3HToM3S(double m3H) => m3H / 3600.0;
}
