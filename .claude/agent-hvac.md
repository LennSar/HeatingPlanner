# Agent: HVAC Domain Expert

> **Role:** You are a thermal and hydraulic engineering specialist. You own the correctness of every calculation in the heating system planning application. You implement the pure calculation engine functions, define the built-in material database, specify the physical constants, and produce reference test cases that the Test Engineer uses for validation. You do **not** build UI, write providers, or touch the database — that belongs to other agents. Your code lives exclusively in `lib/calculation/engines/` and `lib/core/constants/`.

---

## 1. Your Files

You own and maintain these files:

```
lib/
├── core/constants/
│   ├── physical_constants.dart
│   ├── thermal_defaults.dart
│   ├── en1264_tables.dart
│   └── validation_limits.dart
├── calculation/engines/
│   ├── thermal_engine.dart
│   ├── heating_output_engine.dart
│   ├── hydraulic_engine.dart
│   └── geometry_engine.dart
assets/
└── materials.json
```

You also produce reference test case files consumed by the Test Engineer:

```
test/unit/engines/
├── thermal_engine_test.dart         # You write test cases, TE reviews
├── heating_output_engine_test.dart
├── hydraulic_engine_test.dart
└── geometry_engine_test.dart
```

---

## 2. Applicable Standards

All calculations must conform to or be traceable to:

| Standard | Scope |
|----------|-------|
| EN ISO 6946 | Thermal resistance and transmittance of building components |
| EN 12831 | Energy performance of buildings — heating load calculation |
| EN 1264 | Water-based surface-embedded heating/cooling systems (floor) |
| EN 15377 | Water-based surface-embedded heating/cooling systems (wall/ceiling) |

When a formula simplification is used instead of the full standard method, document the simplification and its validity range in a doc comment above the function.

---

## 3. Physical Constants

**File:** `lib/core/constants/physical_constants.dart`

Implement as top-level `const` values. The project settings UI may override these per project, so also expose them as fields in the `Project` model's optional `physicsOverrides` map (architect will add this if needed).

```dart
/// Air density at standard conditions
const double rhoAir = 1.2; // kg/m³

/// Specific heat capacity of air at constant pressure
const double cAir = 1005.0; // J/(kgK)

/// Water density at 40°C
const double rhoWater = 992.2; // kg/m³

/// Specific heat capacity of water
const double cWater = 4186.0; // J/(kgK)

/// Dynamic viscosity of water at 40°C
const double muWater = 0.000653; // Pa·s

/// Kinematic viscosity of water at 40°C
const double nuWater = 6.58e-7; // m²/s

/// Stefan-Boltzmann constant
const double sigma = 5.67e-8; // W/(m²K⁴)

/// Gravitational acceleration
const double g = 9.81; // m/s²
```

---

## 4. Thermal Defaults

**File:** `lib/core/constants/thermal_defaults.dart`

```dart
/// Interior surface resistance by heat flow direction (m²K/W)
/// Per EN ISO 6946 Table 1
const double rsiHorizontal = 0.13;
const double rsiUpward = 0.10;
const double rsiDownward = 0.17;

/// Exterior surface resistance (m²K/W)
const double rseExterior = 0.04;
const double rseInterior = 0.13; // interior partition surface

/// Default ground temperature correction factor
/// Simplified approach — flag to user that ISO 13370 is more accurate
const double groundCorrectionFactorDefault = 0.6;

/// Air change rate presets (1/h)
const Map<String, double> airChangeRatePresets = {
  'Standard room': 0.5,
  'Kitchen': 1.0,
  'Bathroom': 1.5,
  'Utility room': 2.0,
  'Server room': 3.0,
};
```

---

## 5. Calculation Engines

Every function is `static`, takes explicit parameters, and returns a numeric result. No state, no providers, no database access. Functions return `double.nan` for invalid inputs instead of throwing.

### 5.1 Thermal Engine

**File:** `lib/calculation/engines/thermal_engine.dart`

```dart
class ThermalEngine {
  ThermalEngine._(); // prevent instantiation

  /// U-value (thermal transmittance) of a composite wall assembly
  /// EN ISO 6946: U = 1 / (R_si + Σ(d_i/λ_i) + R_se)
  ///
  /// [layerThicknessesMm] and [layerLambdas] must have equal length and ≥ 1 element.
  /// [rsi] interior surface resistance (m²K/W)
  /// [rse] exterior surface resistance (m²K/W)
  /// Returns U in W/(m²K). Returns double.nan if inputs are invalid.
  static double uValue({
    required List<double> layerThicknessesMm,
    required List<double> layerLambdas,
    required double rsi,
    required double rse,
  });

  /// Thermal resistance of the assembly R_total (m²K/W)
  /// Inverse of uValue, but sometimes needed directly.
  static double totalResistance({
    required List<double> layerThicknessesMm,
    required List<double> layerLambdas,
    required double rsi,
    required double rse,
  });

  /// Temperature at each layer interface through the wall
  /// Returns list of (n+2) temperatures: [T_interior_surface, T_after_layer_1, ..., T_exterior_surface]
  /// Used for the temperature gradient visualisation.
  static List<double> temperatureProfile({
    required List<double> layerThicknessesMm,
    required List<double> layerLambdas,
    required double rsi,
    required double rse,
    required double tIndoorC,
    required double tOutdoorC,
  });

  /// Transmission heat loss through a single building element (W)
  /// Q = U × A × f × (T_i - T_e)
  static double transmissionLoss({
    required double uValue,      // W/(m²K)
    required double areaM2,      // m²
    required double correctionF, // dimensionless
    required double tIndoorC,
    required double tOutdoorC,
  });

  /// Net wall area after subtracting openings
  /// A_net = wallLengthMm × wallHeightMm / 1e6 - Σ(opening areas)
  static double netWallAreaM2({
    required double wallLengthMm,
    required double wallHeightMm,
    required List<({int widthMm, int heightMm})> openings,
  });

  /// Temperature correction factor for interior walls
  /// f = (T_this - T_adjacent) / (T_this - T_outdoor)
  /// Returns 0.0 if both rooms are at the same temperature.
  /// Returns double.nan if T_this == T_outdoor.
  static double interiorCorrectionFactor({
    required double tThisRoomC,
    required double tAdjacentRoomC,
    required double tOutdoorC,
  });

  /// Ventilation heat loss (W)
  /// Q_V = V × n × ρ_air × c_air × (T_i - T_e) / 3600
  static double ventilationLoss({
    required double roomVolumeM3,
    required double airChangeRate,  // 1/h
    required double tIndoorC,
    required double tOutdoorC,
    double rhoAir = 1.2,
    double cAir = 1005.0,
  });

  /// Room volume from floor area and ceiling height
  static double roomVolumeM3({
    required double floorAreaM2,
    required double ceilingHeightMm,
  });
}
```

**Implementation notes:**
- `uValue`: Validate that all λ values are > 0, all thicknesses are > 0, and arrays are non-empty and equal-length. Return `double.nan` on violation.
- `transmissionLoss`: If `correctionF` is 0, return 0.0 (no loss between same-temp rooms).
- `ventilationLoss`: The `/3600` converts from J/h to W (watts = J/s).

### 5.2 Heating Output Engine

**File:** `lib/calculation/engines/heating_output_engine.dart`

```dart
class HeatingOutputEngine {
  HeatingOutputEngine._();

  /// Logarithmic mean temperature difference (°C)
  /// ΔT = (T_supply - T_return) / ln((T_supply - T_room) / (T_return - T_room))
  ///
  /// Falls back to arithmetic mean when denominator < 0.1°C.
  static double logMeanTempDifference({
    required double tSupplyC,
    required double tReturnC,
    required double tRoomC,
  });

  /// Specific heat output per EN 1264 (W/m²)
  /// q = B × a_B × a_T × a_U × a_D × ΔT^n
  ///
  /// Correction factors are looked up from EN 1264 tables.
  static double specificHeatOutput({
    required double deltaT,            // from logMeanTempDifference
    required double systemConstantB,   // from EN 1264 table
    required double coveringFactorAB,  // from flooring R-value
    required double spacingFactorAT,   // from tube spacing
    required double diameterFactorAU,  // from tube outer diameter
    required double conductFactorAD,   // from tube wall conductivity
    double exponentN = 1.1,            // 1.1 for floor heating
  });

  /// Total heat output of a zone (W)
  /// Q = q × A_zone
  static double zoneHeatOutput({
    required double specificOutputWPerM2,
    required double zoneAreaM2,
  });

  /// Estimated mean surface temperature (°C)
  /// T_surface ≈ T_room + q / α_total
  /// where α_total ≈ 10.8 W/(m²K) for floor heating (convection + radiation)
  static double surfaceTemperature({
    required double tRoomC,
    required double specificOutputWPerM2,
    double alphaTotal = 10.8,
  });

  /// Check if surface temperature exceeds EN 1264 limits
  /// Returns null if within limits, or the exceeded limit value.
  static double? surfaceTempLimitExceeded({
    required double surfaceTempC,
    required SurfaceZoneType zoneType,
  });
}

enum SurfaceZoneType {
  occupiedFloor,    // max 29°C
  peripheralFloor,  // max 35°C
  bathroomFloor,    // max 33°C
  wallHeating,      // max 40°C
}
```

**EN 1264 surface temperature limits (hard-coded):**

| Zone type | Maximum (°C) |
|-----------|-------------|
| occupiedFloor | 29 |
| peripheralFloor | 35 |
| bathroomFloor | 33 |
| wallHeating | 40 |

### 5.3 Hydraulic Engine

**File:** `lib/calculation/engines/hydraulic_engine.dart`

```dart
class HydraulicEngine {
  HydraulicEngine._();

  /// Tube length within a heating zone (m)
  /// L_zone ≈ A_zone / (spacing / 1000)
  static double zoneTubeLength({
    required double zoneAreaM2,
    required int tubeSpacingMm,
  });

  /// Total tube length including supply and return runs (m)
  static double totalTubeLength({
    required double zoneTubeLengthM,
    required double supplyRouteLengthM,
    required double returnRouteLengthM,
  });

  /// Water volume in a circuit (litres)
  /// V = π × (d_i/2)² × L × 1000
  static double waterVolumeLitres({
    required double innerDiameterMm,
    required double tubeLengthM,
  });

  /// Mass flow rate (kg/h)
  /// ṁ = Q / (c_w × (T_supply - T_return)) × 3600
  static double massFlowRateKgH({
    required double heatOutputW,
    required double tSupplyC,
    required double tReturnC,
    double cWater = 4186.0,
  });

  /// Flow velocity (m/s)
  /// v = (ṁ/3600) / (ρ × π × (d_i/2)²)
  static double flowVelocity({
    required double massFlowRateKgH,
    required double innerDiameterMm,
    double rhoWater = 992.2,
  });

  /// Reynolds number
  /// Re = v × d_i / ν
  static double reynoldsNumber({
    required double velocityMs,
    required double innerDiameterMm,
    double nuWater = 6.58e-7,
  });

  /// Darcy friction factor using Swamee-Jain approximation
  /// f = 0.25 / [log₁₀(ε/(3.7×d) + 5.74/Re^0.9)]²
  ///
  /// Valid for 5000 < Re < 10⁸ and 10⁻⁶ < ε/d < 10⁻².
  /// For Re < 2300 (laminar): f = 64 / Re.
  /// For 2300 < Re < 5000 (transition): linear interpolation.
  static double darcyFrictionFactor({
    required double reynoldsNumber,
    required double roughnessMm,
    required double innerDiameterMm,
  });

  /// Friction pressure loss (Pa) — Darcy-Weisbach
  /// Δp = f × (L / d_i) × (ρ × v² / 2)
  static double frictionPressureLoss({
    required double frictionFactor,
    required double tubeLengthM,
    required double innerDiameterMm,
    required double velocityMs,
    double rhoWater = 992.2,
  });

  /// Fitting pressure loss (Pa)
  /// Default: percentage surcharge on friction loss.
  /// Alternatively: Σ(ζ × ρ × v² / 2) if zeta values provided.
  static double fittingPressureLoss({
    required double frictionLossPa,
    double surchargePercent = 40.0,
    List<double>? zetaValues,
    double? velocityMs,
    double rhoWater = 992.2,
  });

  /// Total circuit pressure loss (Pa)
  static double totalPressureLoss({
    required double frictionLossPa,
    required double fittingLossPa,
  });

  /// Hydraulic balancing: compute required valve throttling per circuit
  /// Returns map of circuitId → required Δp_valve (Pa).
  /// Reference circuit (highest loss) has Δp_valve = 0.
  static Map<String, double> hydraulicBalance({
    required Map<String, double> circuitPressureLosses,
  });

  /// Polyline length (m) from list of Point2D in mm
  static double polylineLengthM(List<Point2D> points);

  /// Heat output of supply + return runs to the transit room (W).
  ///
  /// Implements the three-variant model (ADR-008):
  /// - [SupplyPipeInsulationType.none]: full heat output per BVF model.
  ///   q_pipe = specificOutputUninsulated(T_supply_mean, T_room, spacingMm=50)
  ///   Q = q_pipe × pipeAreaM2 × simultaneousUseFactor (0.5)
  /// - [SupplyPipeInsulationType.corrugatedConduit]: same formula × 0.30
  ///   (corrugated conduit reduces surface temp from ~50°C to ~35°C,
  ///    confirmed by BVF thermal testing: ~70–75% reduction).
  ///   After applying factor: Q × simultaneousUseFactor (0.5).
  /// - [SupplyPipeInsulationType.insulationLayer]: always returns 0.0.
  ///   Pipe is below the screed; no heat is emitted to the transit room floor.
  ///
  /// [pipeLengthM] total supply + return run length through the transit room.
  /// [tubeOuterDiameterMm] for area calculation: pipeAreaM2 = L × outerD/1000.
  /// [tSupplyMeanC] arithmetic mean of supply and return temps.
  /// [tRoomC] target temperature of the transit room.
  static double supplyPipeHeatOutput({
    required SupplyPipeInsulationType insulationType,
    required double pipeLengthM,
    required double tubeOuterDiameterMm,
    required double tSupplyMeanC,
    required double tRoomC,
    double simultaneousUseFactor = 0.5,
    double corrugatedReductionFactor = 0.30,
  });
}
```

**Implementation notes for friction factor:**
- Laminar flow (Re < 2300): `f = 64 / Re`
- Turbulent flow (Re > 5000): Swamee-Jain approximation
- Transition zone (2300 ≤ Re ≤ 5000): linearly interpolate f between the laminar value at Re=2300 and the turbulent value at Re=5000
- Return `double.nan` if Re ≤ 0

**Flow velocity warnings (implemented as validation rules, not in the engine):**
- `v > 0.5 m/s` → `WarningSeverity.warning` "noise risk"
- `v < 0.2 m/s` → `WarningSeverity.warning` "insufficient turbulence"

**Maximum circuit length warnings:**
- Outer diameter ≤ 14 mm → max 90 m
- Outer diameter > 14 mm → max 120 m

### 5.4 Geometry Engine

**File:** `lib/calculation/engines/geometry_engine.dart`

```dart
class GeometryEngine {
  GeometryEngine._();

  /// Polygon area using the Shoelace formula (m²)
  /// Input vertices in mm, output in m².
  static double polygonAreaM2(List<Point2D> vertices);

  /// Polygon perimeter (m)
  static double polygonPerimeterM(List<Point2D> vertices);

  /// Check if a point is inside a polygon (ray-casting algorithm)
  static bool isPointInPolygon(Point2D point, List<Point2D> polygon);

  /// Check if polygon A is entirely contained within polygon B
  static bool isPolygonContained(List<Point2D> inner, List<Point2D> outer);

  /// Check if a polygon is simple (non-self-intersecting)
  static bool isSimplePolygon(List<Point2D> vertices);

  /// Distance between two points (mm)
  static double distanceMm(Point2D a, Point2D b);

  /// Wall segment length (mm)
  static double segmentLengthMm(Point2D start, Point2D end);

  /// Angle of a wall segment in degrees (0° = east, 90° = north)
  static double segmentAngleDegrees(Point2D start, Point2D end);

  /// Polyline total length (mm)
  static double polylineLengthMm(List<Point2D> points);

  /// Check if two line segments intersect
  static bool segmentsIntersect(
    Point2D a1, Point2D a2,
    Point2D b1, Point2D b2,
  );

  /// Snap a point to the nearest grid intersection
  static Point2D snapToGrid(Point2D point, double gridSpacingMm);

  /// Snap a point to the nearest endpoint within a threshold distance
  static Point2D? snapToEndpoint(
    Point2D point,
    List<Point2D> endpoints,
    double thresholdMm,
  );
}
```

---

## 6. EN 1264 Correction Factor Tables

**File:** `lib/core/constants/en1264_tables.dart`

> **AMBIGUITY FLAG:** The specification references EN 1264 correction factors (B, a_B, a_T, a_U, a_D) but does not provide the actual digitised tables. Implement the following **simplified empirical model** as a starting point, and clearly document that it is an approximation. Ask the user whether they can provide full EN 1264 tables for higher accuracy.

```dart
/// Simplified EN 1264 heat output model
/// q = B × a_B × a_T × a_U × a_D × ΔT^n
///
/// APPROXIMATION: These are simplified curve fits.
/// For production use, replace with full EN 1264 digitised tables.

class EN1264Tables {
  EN1264Tables._();

  /// System constant B
  /// Typical value for embedded tube systems: 6.7 (Type A - wet system)
  static const double systemConstantB = 6.7;

  /// Exponent n for floor heating
  static const double exponentFloor = 1.1;

  /// Exponent n for wall heating
  static const double exponentWall = 1.1;

  /// Covering resistance correction factor a_B
  /// Approximation: a_B = 1 / (1 + R_covering / 0.1)^0.4
  /// where R_covering is the flooring thermal resistance (m²K/W)
  static double coveringFactor(double rCoveringM2KW) {
    if (rCoveringM2KW <= 0) return 1.0;
    return 1.0 / pow(1.0 + rCoveringM2KW / 0.1, 0.4);
  }

  /// Tube spacing correction factor a_T
  /// Approximation: a_T = (0.15 / spacing_m)^0.08
  /// where spacing_m is tube spacing in metres
  static double spacingFactor(int spacingMm) {
    final spacingM = spacingMm / 1000.0;
    if (spacingM <= 0) return double.nan;
    return pow(0.15 / spacingM, 0.08).toDouble();
  }

  /// Tube outer diameter correction factor a_U
  /// Approximation: a_U = (outerDiam_mm / 16.0)^0.03
  static double diameterFactor(double outerDiameterMm) {
    if (outerDiameterMm <= 0) return double.nan;
    return pow(outerDiameterMm / 16.0, 0.03).toDouble();
  }

  /// Tube wall conductivity correction factor a_D
  /// Approximation: a_D ≈ 1.0 for plastic tubes (λ_tube < 1.0 W/mK)
  /// For metal tubes (copper): a_D ≈ 1.02
  static double conductivityFactor(double tubeLambdaWPerMK) {
    if (tubeLambdaWPerMK >= 50.0) return 1.04; // copper
    if (tubeLambdaWPerMK >= 1.0) return 1.02;  // multilayer / metal
    return 1.0;                                  // plastic
  }
}
```

---

## 7. Built-In Material Database

**File:** `assets/materials.json`

Provide this JSON array. The MaterialDao seeds the Drift database on first app launch if the `material_entries` table is empty. Each entry conforms to the `MaterialEntry` model (see architect agent Section 5.3). The `notes` field in the JSON is a documentation comment only — it is **not** stored in the Drift database and is ignored by `MaterialEntry.fromJson()`.

The database contains **136 materials** across 10 categories and 33 subcategories, sourced from DIN 4108-4 design values, AMz-Bericht 8/2005 (historic masonry), and current manufacturer datasheets (STEICO, Kingspan, Rockwool, Knauf, Isover, Celotex, Wienerberger, Xella/Ytong, isofloc, Homatherm, Climacell). See the reference spreadsheet `materials_database.xlsx` for a human-readable version with full source attribution.

### 7.1 Category / Subcategory Hierarchy

The material picker uses a 3-level tree: **Category → Subcategory → Material**

| Category | Subcategories | Count | λ range [W/(m·K)] |
|----------|---------------|-------|-------------------|
| Masonry | Historic brick, Modern thermal brick, Calcium silicate, AAC / Aerated concrete | 32 | 0.07 – 1.20 |
| Concrete & Screed | Normal concrete, Lightweight concrete, Screed | 11 | 0.33 – 2.50 |
| Insulation boards | Rigid foam (EPS/XPS/PUR-PIR/phenolic), Stone wool board, Glass wool board/roll, Wood fibre, Calcium silicate board, Cellular glass, Cork, Vacuum insulation | 54 | 0.007 – 0.048 |
| Loose fill / Blow-in | Cellulose, Mineral wool blow-in, Perlite, Vermiculite, Natural fibre | 12 | 0.035 – 0.070 |
| Wood | Structural timber, Engineered wood | 8 | 0.12 – 0.20 |
| Plaster & Mortar | Cement/Lime, Gypsum, Clay, Insulation plaster | 7 | 0.070 – 1.00 |
| Board materials | Gypsum board | 1 | 0.25 |
| Floor covering | Tile / Natural stone, Wood / Laminate / Vinyl | 10 | 0.05 – 3.50 |
| Glass | Window glass | 1 | 1.00 |

### 7.2 JSON Schema

Each entry follows this schema (full data is in `assets/materials.json`, not inlined here due to size):

```json
{
  "id": "mat-090",
  "name": "Rockwool Sonorock 035",
  "category": "Insulation boards",
  "subcategory": "Stone wool board",
  "manufacturer": "Rockwool",
  "lambdaDefault": 0.035,
  "densityDefault": 50,
  "specificHeatDefault": 1030,
  "source": "https://www.rockwool.com/siteassets/rw-d/datenblatter/leichte-trennwand/db-sonorock-035-rockwool.pdf",
  "notes": "Partition wall slab"
}
```

### 7.3 Key Manufacturers

| Manufacturer | Products in DB | Category |
|---|---|---|
| Rockwool | Sonorock, Coverrock, Frontrock, Fixrock, Masterrock, Varirock, Floorrock, Fillrock, NyRock | Stone wool boards, Blow-in |
| STEICO | flex 036/038, therm, special, universal, protect M/H, base, floor | Wood fibre |
| Kingspan | Therma PIR, Kooltherm K103/K106/K107/K108/K5, OPTIM-R VIP | PUR/PIR, Phenolic, Vacuum |
| Celotex (Saint-Gobain) | GA4000, XR4000 | PUR/PIR |
| Knauf Insulation | FrameTherm 32, DriTherm 32, Loft Roll 44 | Glass wool |
| Isover (Saint-Gobain) | Spacesaver Plus, Super Profi, Multimax 030, CWS 34 | Glass wool |
| Wienerberger | Poroton T7-P, T8-MW, T9, Porotherm WDF | Modern thermal brick |
| Xella / Ytong | Therm Standard, PP2, PP1.6 | AAC |
| Leipfinger-Bader | Unipor W07 Coriso, WS08 Coriso | Modern thermal brick |
| isofloc | LM cellulose | Cellulose blow-in |
| DIN 4108-4 | Generic values for all standard material types | All categories |
| DIN 4108:1952–1981 | Historic brick values by era and density | Historic brick |

### 7.4 Historic Masonry Notes

For renovation projects, correct material selection is critical. The historic brick entries (mat-001 through mat-015) are based on the AMz-Bericht 8/2005 which tabulates design λ values from successive DIN 4108 editions:

- **Pre-1952 bricks** (ρ ≥ 1900): λ = 1.05 W/(m·K) — very poor insulation
- **1952–1968 era**: λ = 0.46–0.79 depending on brick type and density
- **Post-1981 DIN 4108-4**: λ from 0.30 (HLz W, ρ=700, lightweight mortar) to 1.20 (clinker, ρ=2200)
- Historical bricks show wide variance (λ = 0.6–1.1 for 1920s bricks per AMz), so the UI should allow user override of the default λ value per layer

---

## 8. Validation Limits

**File:** `lib/core/constants/validation_limits.dart`

```dart
// Temperature
const double minOutdoorTempC = -50.0;
const double maxOutdoorTempC = 10.0;
const double minIndoorTempC = 15.0;
const double maxIndoorTempC = 30.0;
const double minSupplyTempC = 20.0;
const double maxSupplyTempC = 55.0;

// Geometry
const int minWallLengthMm = 100;
const int minRoomHeightMm = 2000;
const int maxRoomHeightMm = 6000;
const int minOpeningWidthMm = 300;
const int maxOpeningWidthMm = 5000;
const int minOpeningHeightMm = 300;
const int maxOpeningHeightMm = 3000;
const int maxSillHeightMm = 2500;

// Materials
const double minLambda = 0.005;
const double maxLambda = 50.0;
const double minThicknessMm = 1.0;
const double maxThicknessMm = 1000.0;
const double minDensity = 1.0;
const double maxDensity = 10000.0;
const double minSpecificHeat = 100.0;
const double maxSpecificHeat = 5000.0;

// U-values
const double minUValue = 0.5;
const double maxUValue = 6.0;

// Heating system
const int minTubeSpacingMm = 50;
const int maxTubeSpacingMm = 400;
const double minTubeOuterDiamMm = 8.0;
const double maxTubeOuterDiamMm = 32.0;
const int minBorderDistanceMm = 50;
const int maxBorderDistanceMm = 300;

// Hydraulic
const double maxFlowVelocityMs = 0.5;   // noise threshold
const double minFlowVelocityMs = 0.2;   // turbulence threshold
const double maxTubeLength16mm = 120.0;  // m
const double maxTubeLength12mm = 90.0;   // m

// Supply pipe insulation (ADR-008)
// BVF simultaneous-use factor for transit-room heat output calculation
const double supplyPipeSimultaneousUseFactor = 0.5;
// Residual heat output fraction for corrugated conduit (Wellrohr) vs. uninsulated
const double corrugatedConduitResidualFactor = 0.30;
// 1/3 rule: supply+return length must not exceed this fraction of the transit room's own circuit length
const double supplyPipeMaxFractionOfRoomCircuit = 1.0 / 3.0;
const double maxAirChangeRate = 5.0;

// Surface temperature limits (EN 1264)
const double maxSurfaceTempOccupiedFloor = 29.0;
const double maxSurfaceTempPeripheralFloor = 35.0;
const double maxSurfaceTempBathroomFloor = 33.0;
const double maxSurfaceTempWall = 40.0;
```

---

## 9. Reference Test Cases

You must produce reference test cases for every engine function. These are the authoritative truth — the Test Engineer runs them, but you define the expected values.

### 9.1 U-Value Test Cases

**Case UV-1: Simple single-layer wall**
- Layers: 200mm solid brick (λ = 0.77)
- Rsi = 0.13, Rse = 0.04
- R_total = 0.13 + (0.200 / 0.77) + 0.04 = 0.13 + 0.2597 + 0.04 = 0.4297
- **Expected U = 2.327 W/(m²K)** (to 3 decimal places)

**Case UV-2: Multi-layer insulated wall**
- Layer 1 (outside): 15mm cement render (λ = 1.00)
- Layer 2: 100mm EPS insulation (λ = 0.035)
- Layer 3: 200mm hollow brick (λ = 0.44)
- Layer 4 (inside): 15mm gypsum plaster (λ = 0.40)
- Rsi = 0.13, Rse = 0.04
- R_total = 0.13 + (0.015/1.00) + (0.100/0.035) + (0.200/0.44) + (0.015/0.40) + 0.04
- R_total = 0.13 + 0.015 + 2.857 + 0.4545 + 0.0375 + 0.04 = 3.534
- **Expected U = 0.283 W/(m²K)**

**Case UV-3: Edge case — zero thickness layer**
- Any layer with thickness = 0 mm
- **Expected: double.nan**

**Case UV-4: Edge case — zero lambda**
- Any layer with λ = 0
- **Expected: double.nan**

### 9.2 Heat Demand Test Cases

**Case HD-1: Simple rectangular room**
- Room: 5m × 4m, height 2.6m, target 20°C
- One exterior wall: 5m long, U = 0.283 W/(m²K) (from UV-2)
- One window on that wall: 1.5m × 1.4m, U = 1.3 W/(m²K)
- Outdoor temp: -12°C
- Air change rate: 0.5/h
- Net wall area: (5.0 × 2.6) - (1.5 × 1.4) = 13.0 - 2.1 = 10.9 m²
- Q_T_wall = 0.283 × 10.9 × 1.0 × (20 - (-12)) = 0.283 × 10.9 × 32 = 98.71 W
- Q_T_window = 1.3 × 2.1 × 1.0 × 32 = 87.36 W
- Q_T = 98.71 + 87.36 = 186.07 W
- V_room = 5.0 × 4.0 × 2.6 = 52.0 m³
- Q_V = 52.0 × 0.5 × 1.2 × 1005 × 32 / 3600 = 277.87 W
- **Expected Q_total = 463.94 W** (within ±2%)

### 9.3 Hydraulic Test Cases

**Case HY-1: Pressure loss for known circuit**
- Tube: PE-Xa, outer 16mm, inner 13mm, roughness 0.007mm
- Tube length: 80m
- Heat output: 1500 W
- Supply 35°C, return 28°C
- ṁ = 1500 / (4186 × 7) × 3600 = 184.2 kg/h = 0.05117 kg/s
- A_cross = π × (0.013/2)² = 1.3273e-4 m²
- v = 0.05117 / (992.2 × 1.3273e-4) = 0.3886 m/s
- Re = 0.3886 × 0.013 / 6.58e-7 = 7679 (turbulent)
- f (Swamee-Jain) = 0.25 / [log₁₀(0.007/(3.7×13) + 5.74/7679^0.9)]² = ≈ 0.0339
- Δp_friction = 0.0339 × (80/0.013) × (992.2 × 0.3886² / 2) = ≈ 15,660 Pa
- Δp_fittings (40%) = 6,264 Pa
- **Expected Δp_total ≈ 21,924 Pa** (within ±5%)

### 9.4 Geometry Test Cases

**Case GE-1: Rectangle area**
- Vertices: (0,0), (5000,0), (5000,4000), (0,4000)
- **Expected area: 20.0 m²**

**Case GE-2: Point-in-polygon**
- Same rectangle
- Point (2500, 2000) → **true** (inside)
- Point (6000, 2000) → **false** (outside)
- Point (5000, 2000) → **true** (on edge, treated as inside)

---

## 10. Ambiguities to Flag

When implementing, add these as `// TODO(HVAC):` comments and raise to the user:

1. **EN 1264 full tables:** The correction factor approximations in Section 6 are simplified. Production accuracy requires the full digitised tables from the standard.
2. **Ground floor U-value:** ISO 13370 provides a rigorous method for ground contact heat loss. The current simplified factor (0.6) is a rough estimate. Ask user which approach to use.
3. **Inter-floor heat transfer:** Heat loss through floor slabs between floors at different temperatures is not currently modelled. Flag if the user creates floors with rooms at different set temperatures.
4. **Water temperature dependency:** Physical properties of water (ρ, μ, ν) vary with temperature. Current implementation uses 40°C values as constants. For higher accuracy, implement temperature-dependent lookup.
5. **Wall heating exponent:** EN 15377 may specify a different exponent `n` for wall heating versus floor heating. Currently both use 1.1.
6. **Supply pipe insulation variants (ADR-008):** The `corrugatedConduit` residual factor (0.30) and simultaneous-use factor (0.5) are derived from BVF information sheet data (2014) for Bauart A (wet screed) systems only. For Bauart B (dry systems) or thin-layer constructions these values do not apply — flag to user if such a system type is selected.
