/// Default surface resistance values and thermal presets.
///
/// Per EN ISO 6946 Table 1 and EN 12831.
library;

/// Interior surface resistance — horizontal heat flow (walls) [m²·K/W]
const double rsiHorizontal = 0.13;

/// Interior surface resistance — upward heat flow (floor heating) [m²·K/W]
const double rsiUpward = 0.10;

/// Interior surface resistance — downward heat flow (ceiling) [m²·K/W]
const double rsiDownward = 0.17;

/// Exterior surface resistance — external environment [m²·K/W]
const double rseExterior = 0.04;

/// Interior surface resistance used on the warm side of interior partitions [m²·K/W]
const double rseInterior = 0.13;

/// Default ground temperature correction factor.
///
/// Simplified approach — ISO 13370 is more accurate for ground contact floors.
/// // TODO(HVAC): Flag to user that ISO 13370 gives higher accuracy.
const double groundCorrectionFactorDefault = 0.6;

/// Air change rate presets (1/h) keyed by room type.
const Map<String, double> airChangeRatePresets = {
  'Standard room': 0.5,
  'Kitchen': 1.0,
  'Bathroom': 1.5,
  'Utility room': 2.0,
  'Server room': 3.0,
};
