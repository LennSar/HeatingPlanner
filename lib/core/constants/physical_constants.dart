/// Physical constants used throughout the heating calculations.
///
/// All values are at standard conditions unless otherwise noted.
library;

/// Air density at standard conditions [kg/m³]
const double rhoAir = 1.2;

/// Specific heat capacity of air at constant pressure [J/(kg·K)]
const double cAir = 1005.0;

/// Water density at 40 °C [kg/m³]
const double rhoWater = 992.2;

/// Specific heat capacity of water [J/(kg·K)]
const double cWater = 4186.0;

/// Dynamic viscosity of water at 40 °C [Pa·s]
const double muWater = 0.000653;

/// Kinematic viscosity of water at 40 °C [m²/s]
const double nuWater = 6.58e-7;

/// Stefan-Boltzmann constant [W/(m²·K⁴)]
const double sigma = 5.67e-8;

/// Gravitational acceleration [m/s²]
const double g = 9.81;
