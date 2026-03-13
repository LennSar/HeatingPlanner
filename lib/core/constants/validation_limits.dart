/// Min/max bounds used by the validation service for every numeric field.
library;

// ── Temperature ─────────────────────────────────────────────────────────────
const double minOutdoorTempC = -50.0;
const double maxOutdoorTempC = 10.0;
const double minIndoorTempC = 15.0;
const double maxIndoorTempC = 30.0;
const double minSupplyTempC = 20.0;
const double maxSupplyTempC = 55.0;

// ── Geometry ─────────────────────────────────────────────────────────────────
const int minWallLengthMm = 100;
const int minRoomHeightMm = 2000;
const int maxRoomHeightMm = 6000;
const int minOpeningWidthMm = 300;
const int maxOpeningWidthMm = 5000;
const int minOpeningHeightMm = 300;
const int maxOpeningHeightMm = 3000;
const int maxSillHeightMm = 2500;

// ── Materials ────────────────────────────────────────────────────────────────
const double minLambda = 0.01;
const double maxLambda = 50.0;
const double minThicknessMm = 1.0;
const double maxThicknessMm = 1000.0;
const double minDensity = 1.0;
const double maxDensity = 10000.0;
const double minSpecificHeat = 100.0;
const double maxSpecificHeat = 5000.0;

// ── U-values ─────────────────────────────────────────────────────────────────
const double minUValue = 0.5;
const double maxUValue = 6.0;

// ── Heating system ───────────────────────────────────────────────────────────
const int minTubeSpacingMm = 50;
const int maxTubeSpacingMm = 400;
const double minTubeOuterDiamMm = 8.0;
const double maxTubeOuterDiamMm = 32.0;
const int minBorderDistanceMm = 50;
const int maxBorderDistanceMm = 300;

/// Minimum height of a wall heating zone (mm).
const int minWallZoneHeightMm = 300;

// ── Hydraulic ─────────────────────────────────────────────────────────────────
/// Upper noise threshold — flow above this generates a warning.
const double maxFlowVelocityMs = 0.5;

/// Lower turbulence threshold — flow below this generates a warning.
const double minFlowVelocityMs = 0.2;

/// Maximum circuit length for outer diameter > 14 mm [m]
const double maxTubeLength16mm = 120.0;

/// Maximum circuit length for outer diameter ≤ 14 mm [m]
const double maxTubeLength12mm = 90.0;

// ── Air change ───────────────────────────────────────────────────────────────
const double minAirChangeRate = 0.1;
const double maxAirChangeRate = 5.0;

// ── Surface temperature limits (EN 1264) ─────────────────────────────────────
const double maxSurfaceTempOccupiedFloor = 29.0;
const double maxSurfaceTempPeripheralFloor = 35.0;
const double maxSurfaceTempBathroomFloor = 33.0;
const double maxSurfaceTempWall = 40.0;
