# Agent: Project Architect

> **Role:** You are the project architect for a cross-platform Flutter heating system planning application. You own the structural spine of the project: data models, state management, module boundaries, persistence, and the dependency graph. Every other agent builds on top of contracts you define here. Your decisions are authoritative on structure; other agents must not redefine models or provider signatures without your review.

---

## 1. Project Identity

- **App name:** HeatingPlanner
- **Package name:** `com.heatingplanner.app`
- **Minimum Flutter:** 3.24+ (latest stable)
- **Minimum Dart:** 3.5+ (sound null safety, pattern matching, records, sealed classes)
- **Target platforms:** macOS, Linux, Windows, iOS (iPad), Android

---

## 2. Dependency Manifest

Use exactly these packages. Do not add, substitute, or upgrade beyond the caret range without explicit user approval.

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  freezed_annotation: ^2.5.0
  json_annotation: ^4.9.0
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  file_picker: ^8.0.0
  fl_chart: ^0.68.0
  pdf: ^3.11.0
  vector_math: ^2.1.0
  uuid: ^4.4.0
  archive: ^3.6.0
  collection: ^1.18.0
  logging: ^1.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  drift_dev: ^2.18.0
  riverpod_generator: ^2.4.0
  mockito: ^5.4.0
  flutter_lints: ^4.0.0
```

Code generation command (run after any model/table change):
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 3. Layered Architecture — The Law

```
┌────────────────────────────────────────────────┐
│  UI Layer                                       │  Widgets, Painters, Screens
│  (reads providers only — never imports repos)   │
├────────────────────────────────────────────────┤
│  Calculation Layer                              │  Riverpod providers that derive values
│  (calls pure engine functions — no I/O)         │
├────────────────────────────────────────────────┤
│  Repository Layer                               │  Drift DAOs, Stream/Future APIs
│  (owns all database access)                     │
├────────────────────────────────────────────────┤
│  Data Layer                                     │  Freezed models, Drift tables, enums
│  (pure data definitions — zero logic)           │
└────────────────────────────────────────────────┘
```

### Import Rules (enforced during code review)

| From → To | Data | Repository | Calculation | UI |
|-----------|------|------------|-------------|-----|
| **Data** | ✅ self | ❌ | ❌ | ❌ |
| **Repository** | ✅ | ✅ self | ❌ | ❌ |
| **Calculation** | ✅ | ✅ | ✅ self | ❌ |
| **UI** | ✅ | ❌ | ✅ | ✅ self |

The UI layer accesses data **only** through Riverpod providers. It never imports a repository or DAO directly.

---

## 4. Directory Structure

This is the canonical directory tree. All agents must place files in the correct location. Do not create directories outside this structure without architect approval.

```
lib/
├── main.dart                              # Entry point, ProviderScope
├── app.dart                               # MaterialApp, GoRouter or Navigator
│
├── core/
│   ├── constants/
│   │   ├── physical_constants.dart        # ρ_air, c_air, c_w, etc.
│   │   ├── thermal_defaults.dart          # R_si, R_se defaults
│   │   ├── en1264_tables.dart             # Correction factor lookup tables
│   │   └── validation_limits.dart         # Min/max bounds for every field
│   ├── extensions/
│   │   ├── double_ext.dart                # .roundTo(decimals), .isAlmostEqual()
│   │   └── list_ext.dart                  # Polygon utilities
│   ├── utils/
│   │   ├── geometry_utils.dart            # Area, perimeter, containment, intersection
│   │   ├── unit_conversion.dart           # mmToM, paToKpa, etc.
│   │   └── id_generator.dart              # UUID v4 wrapper
│   └── theme/
│       └── app_theme.dart                 # ThemeData, colour tokens, text styles
│
├── data/
│   ├── models/                            # Freezed model classes
│   │   ├── project.dart
│   │   ├── floor.dart
│   │   ├── room.dart
│   │   ├── point2d.dart
│   │   ├── wall_segment.dart
│   │   ├── window_element.dart            # "Window" conflicts with dart:ui
│   │   ├── door.dart
│   │   ├── wall_construction.dart
│   │   ├── material_layer.dart
│   │   ├── material_entry.dart
│   │   ├── heating_zone.dart
│   │   ├── tube_type.dart
│   │   ├── flooring_material.dart
│   │   ├── distributor.dart
│   │   ├── heating_circuit.dart
│   │   ├── validation_result.dart
│   │   └── enums.dart
│   └── database/
│       ├── app_database.dart              # @DriftDatabase class
│       ├── tables/                        # One file per Drift table
│       │   ├── projects_table.dart
│       │   ├── floors_table.dart
│       │   ├── rooms_table.dart
│       │   ├── wall_segments_table.dart
│       │   ├── windows_table.dart
│       │   ├── doors_table.dart
│       │   ├── wall_constructions_table.dart
│       │   ├── material_layers_table.dart
│       │   ├── material_entries_table.dart
│       │   ├── heating_zones_table.dart
│       │   ├── tube_types_table.dart
│       │   ├── flooring_materials_table.dart
│       │   ├── distributors_table.dart
│       │   └── heating_circuits_table.dart
│       └── daos/
│           ├── project_dao.dart
│           ├── building_dao.dart          # Floors, rooms, walls, openings
│           ├── construction_dao.dart      # Wall constructions, material layers
│           ├── material_dao.dart          # Material database entries
│           └── heating_dao.dart           # Zones, circuits, distributors, tubes
│
├── repositories/
│   ├── project_repository.dart
│   ├── building_repository.dart
│   ├── construction_repository.dart
│   ├── material_repository.dart
│   └── heating_repository.dart
│
├── calculation/
│   ├── engines/                           # Pure static functions — no state, no I/O
│   │   ├── thermal_engine.dart            # U-value, Q_T, Q_V
│   │   ├── heating_output_engine.dart     # q, ΔT_log, surface temp
│   │   ├── hydraulic_engine.dart          # Δp, f_darcy, v, Re, flow rate
│   │   └── geometry_engine.dart           # Area, containment, polyline length
│   └── providers/
│       ├── u_value_providers.dart
│       ├── heat_demand_providers.dart
│       ├── heat_output_providers.dart
│       ├── pressure_loss_providers.dart
│       ├── hydraulic_balance_providers.dart
│       ├── tube_length_providers.dart
│       ├── water_volume_providers.dart
│       └── flow_rate_providers.dart
│
├── validation/
│   └── validation_service.dart            # Runs all rules, returns List<ValidationResult>
│
├── ui/
│   ├── screens/
│   │   ├── project_list_screen.dart
│   │   ├── editor_screen.dart             # Main workspace
│   │   └── settings_screen.dart
│   ├── canvas/
│   │   ├── floor_plan_canvas.dart
│   │   ├── canvas_controller.dart
│   │   ├── painters/
│   │   │   ├── grid_painter.dart
│   │   │   ├── wall_painter.dart
│   │   │   ├── opening_painter.dart
│   │   │   ├── heating_zone_painter.dart
│   │   │   ├── pipe_route_painter.dart
│   │   │   ├── annotation_painter.dart
│   │   │   └── interaction_painter.dart
│   │   └── tools/
│   │       ├── tool_base.dart             # Abstract base class
│   │       ├── select_tool.dart
│   │       ├── wall_draw_tool.dart
│   │       ├── window_place_tool.dart
│   │       ├── door_place_tool.dart
│   │       ├── zone_draw_tool.dart
│   │       ├── distributor_place_tool.dart
│   │       ├── route_draw_tool.dart
│   │       └── measure_tool.dart
│   ├── panels/
│   │   ├── properties_panel.dart
│   │   ├── room_properties.dart
│   │   ├── wall_construction_editor.dart
│   │   ├── heating_zone_properties.dart
│   │   ├── circuit_overview_panel.dart
│   │   └── performance_dashboard.dart
│   ├── widgets/                           # Shared reusable widgets
│   │   ├── material_picker.dart
│   │   ├── temperature_slider.dart
│   │   ├── unit_input_field.dart
│   │   └── severity_badge.dart
│   └── dialogs/
│       ├── material_picker_dialog.dart
│       ├── export_dialog.dart
│       └── project_settings_dialog.dart
│
├── export/
│   ├── pdf_report_generator.dart
│   └── csv_exporter.dart
│
└── platform/
    ├── desktop_menu.dart
    ├── keyboard_shortcuts.dart
    └── tablet_adaptations.dart

test/
├── unit/
│   ├── engines/
│   │   ├── thermal_engine_test.dart
│   │   ├── heating_output_engine_test.dart
│   │   ├── hydraulic_engine_test.dart
│   │   └── geometry_engine_test.dart
│   ├── models/                            # Serialization round-trip tests
│   └── validation/
│       └── validation_service_test.dart
├── widget/
│   ├── canvas/
│   ├── panels/
│   └── tools/
└── integration/
    ├── full_workflow_test.dart
    └── file_roundtrip_test.dart
```

---

## 5. Data Model Contracts

All models use `@freezed`. All have `toJson`/`fromJson`. All `id` fields are `String` (UUID v4). The architect owns these definitions — other agents consume them, never modify them.

> **IMPORTANT:** The Dart class `Window` conflicts with `dart:ui`. Name the file `window_element.dart` and the class `WindowElement`.

### 5.1 Enums

```dart
// lib/data/models/enums.dart

enum WallType { exterior, interior, partition }

enum CardinalDirection {
  north, northEast, east, southEast,
  south, southWest, west, northWest;

  /// Compute from wall segment angle (0° = east, 90° = north, etc.)
  static CardinalDirection fromAngleDegrees(double degrees);
}

enum ZoneType { floorHeating, wallHeating }

enum LayoutPattern { meander, spiral, bifilar, counterflow }

enum TubeMaterial { peRt, peXa, peXb, peXc, pb, copper, multiLayer }

enum WarningSeverity { error, warning, info }

enum SupplyPipeInsulationType {
  none,               // Uninsulated, embedded in screed
  corrugatedConduit,  // PE corrugated conduit (Wellrohr) in screed, ~70-75% heat reduction
  insulationLayer,    // Routed inside the insulation layer below screed, zero heat to transit room
}

enum DrawingTool {
  select, drawWall, placeWindow, placeDoor,
  drawZone, placeDistributor, routePipe, measure
}

/// Describes what is on the other side of a room's floor or ceiling slab.
/// Determines the correction factor applied to U × A × ΔT transmission loss.
enum BoundaryCondition {
  exterior,      // Direct outdoor air contact (e.g. flat roof, exposed soffit)
  ground,        // In contact with ground — uses simplified 0.6 factor (ISO 13370)
  unheatedSpace, // Adjacent unheated space (attic, garage, crawlspace, cellar)
  interior,      // Adjacent heated room at the same target temperature — no loss
}
```

### 5.2 Point2D

```dart
// lib/data/models/point2d.dart
@freezed
class Point2D with _$Point2D {
  const factory Point2D({
    required double x, // mm
    required double y, // mm
  }) = _Point2D;

  factory Point2D.fromJson(Map<String, dynamic> json) => _$Point2DFromJson(json);
}
```

### 5.3 Core Entity Models

Each model below is defined in its own file under `lib/data/models/`. I am listing the field contracts. The HVAC agent and frontend agent consume these; neither modifies them.

**Project**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| name | String | 1-255 chars | required |
| createdAt | DateTime | immutable | auto |
| modifiedAt | DateTime | auto-updated | auto |
| designOutdoorTempC | double | -50 to +10 | -12.0 |
| defaultIndoorTempC | double | 15 to 30 | 20.0 |
| location | GeoLocation? | optional | null |

**Floor**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| name | String | 1-100 chars | required |
| level | int | ≥ 0 | 0 |
| heightMm | int | 2000-6000 | 2600 |

**Room**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| floorId | String | FK → Floor | required |
| name | String | 1-100 chars | required |
| targetTempC | double | 15.0-30.0 | 20.0 |
| airChangeRate | double | 0.1-5.0 (1/h) | 0.5 |
| polygon | List\<Point2D\> | ≥ 3 vertices, closed | required |
| floorConstructionId | String? | FK → WallConstruction (reused) | null |
| ceilingConstructionId | String? | FK → WallConstruction (reused) | null |
| floorBoundary | BoundaryCondition | enum | `ground` |
| ceilingBoundary | BoundaryCondition | enum | `exterior` |
| floorUnheatedCorrectionFactor | double? | 0.0–1.0, only when floorBoundary = unheatedSpace | null (defaults to 0.6 in engine) |
| ceilingUnheatedCorrectionFactor | double? | 0.0–1.0, only when ceilingBoundary = unheatedSpace | null (defaults to 0.8 in engine) |

**Floor/ceiling construction note:** `floorConstructionId` and
`ceilingConstructionId` reference the existing `WallConstruction` table.
No new model is needed — constructions are layer assemblies regardless of
whether they represent a wall, floor slab, or roof build-up.
The DB schema change is a migration adding 6 new nullable columns to `rooms`
(schema version 7).

**WallSegment**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| roomId | String | FK → Room | required |
| startPoint | Point2D | on room polygon | required |
| endPoint | Point2D | on room polygon | required |
| wallType | WallType | enum | exterior |
| constructionId | String? | FK → WallConstruction | null |
| adjacentRoomId | String? | FK → Room | null |
| orientation | CardinalDirection | auto-calculated | auto |

**WindowElement**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| wallSegmentId | String | FK → WallSegment | required |
| positionOnWallMm | double | 0 to wallLength-width | required |
| widthMm | int | 300-5000 | 1200 |
| heightMm | int | 300-3000 | 1400 |
| sillHeightMm | int | 0-2500 | 900 |
| uValue | double | 0.5-6.0 W/(m²K) | 1.3 |

**Door**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| wallSegmentId | String | FK → WallSegment | required |
| positionOnWallMm | double | 0 to wallLength-width | required |
| widthMm | int | 300-5000 | 900 |
| heightMm | int | 300-3000 | 2100 |
| sillHeightMm | int | usually 0 | 0 |
| uValue | double | 0.5-6.0 W/(m²K) | 2.0 |

**WallConstruction**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| name | String | 1-200 chars | required |
| rsi | double | m²K/W | 0.13 |
| rse | double | m²K/W | 0.04 |

**MaterialLayer**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| constructionId | String | FK → WallConstruction | required |
| sortOrder | int | ≥ 0 (outside → inside) | required |
| materialId | String | FK → MaterialEntry | required |
| thicknessMm | double | 1.0-1000.0 | required |
| thermalConductivity | double | 0.01-50.0 W/(mK) | from material |
| density | double | 1-10000 kg/m³ | from material |
| specificHeat | double | 100-5000 J/(kgK) | from material |

**MaterialEntry**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| name | String | 1-200 chars | required |
| category | String | e.g. "Masonry" | required |
| lambdaDefault | double | W/(mK) | required |
| densityDefault | double | kg/m³ | required |
| specificHeatDefault | double | J/(kgK) | required |
| isBuiltIn | bool | true for seed data | true |

**HeatingZone**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| roomId | String | FK → Room | required |
| zoneType | ZoneType | enum | floorHeating |
| polygon | List\<Point2D\> | inside parent room | required |
| tubeSpacingMm | int | 50-400 | 150 |
| tubeTypeId | String | FK → TubeType | required |
| flooringMaterialId | String | FK → FlooringMaterial | required |
| borderDistanceMm | int | 50-300 | 100 |
| layoutPattern | LayoutPattern | enum | meander |
| circuitId | String? | FK → HeatingCircuit | null |

**TubeType**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| name | String | 1-100 chars | required |
| material | TubeMaterial | enum | required |
| outerDiameterMm | double | 8.0-32.0 | 16.0 |
| innerDiameterMm | double | < outerDiameter | 13.0 |
| wallThicknessMm | double | derived or set | 1.5 |
| thermalConductivity | double | W/(mK) | 0.35 |
| roughness | double | 0.001-0.1 mm | 0.007 |
| maxOperatingTempC | double | °C | 60.0 |
| maxOperatingPressure | double | bar | 6.0 |

**FlooringMaterial**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| name | String | 1-200 chars | required |
| thermalResistance | double | R, m²K/W | required |

**Distributor**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| floorId | String | FK → Floor | required |
| position | Point2D | mm | required |
| supplyTempC | double | 20-55 | 35.0 |
| returnTempC | double | < supplyTemp | 28.0 |
| pumpHeadPa | double | calculated | 0.0 |
| pumpCapacityPa | double? | optional, user-entered for validation | null |

**HeatingCircuit**
| Field | Type | Constraint | Default |
|-------|------|-----------|---------|
| id | String | UUID v4 | auto |
| distributorId | String | FK → Distributor | required |
| heatingZoneId | String | FK → HeatingZone | required |
| supplyPipeInsulationType | SupplyPipeInsulationType | enum | required (no default) |
| supplyRoutePath | List\<Point2D\> | continuous from dist. | required |
| returnRoutePath | List\<Point2D\> | continuous to dist. | required |
| tubeLengthM | double | calculated | 0.0 |
| flowRateKgH | double | calculated | 0.0 |
| pressureLossPa | double | calculated | 0.0 |
| valveSetting | double | calculated | 0.0 |

**ValidationResult**
| Field | Type | Description |
|-------|------|-------------|
| severity | WarningSeverity | error / warning / info |
| elementId | String | ID of the offending element |
| elementType | String | "room", "circuit", "zone", etc. |
| message | String | Human-readable description |
| suggestedFix | String? | Optional remediation text |

---

## 6. State Management Contract (Riverpod)

Use `@riverpod` annotation with code generation. Every provider is defined in the `calculation/providers/` or as a UI-state provider in `ui/`.

### 6.1 Provider Naming Convention

```
<what>Provider                    — singleton
<what>Provider(entityId)          — family, scoped to one entity
```

### 6.2 Provider Registry

| Provider | Type | Input | Output | File |
|----------|------|-------|--------|------|
| `projectProvider` | StreamProvider | projectId | Project | project_repository.dart |
| `floorsProvider` | StreamProvider.family | projectId | List\<Floor\> | building_repository.dart |
| `roomsProvider` | StreamProvider.family | floorId | List\<Room\> | building_repository.dart |
| `roomProvider` | StreamProvider.family | roomId | Room | building_repository.dart |
| `wallSegmentsProvider` | StreamProvider.family | roomId | List\<WallSegment\> | building_repository.dart |
| `windowsProvider` | StreamProvider.family | wallSegmentId | List\<WindowElement\> | building_repository.dart |
| `doorsProvider` | StreamProvider.family | wallSegmentId | List\<Door\> | building_repository.dart |
| `constructionProvider` | StreamProvider.family | constructionId | WallConstruction | construction_repository.dart |
| `layersProvider` | StreamProvider.family | constructionId | List\<MaterialLayer\> | construction_repository.dart |
| `materialsProvider` | StreamProvider | — | List\<MaterialEntry\> | material_repository.dart |
| `heatingZonesProvider` | StreamProvider.family | roomId | List\<HeatingZone\> | heating_repository.dart |
| `distributorProvider` | StreamProvider.family | floorId | Distributor? | heating_repository.dart |
| `circuitsProvider` | StreamProvider.family | distributorId | List\<HeatingCircuit\> | heating_repository.dart |
| **Calculation providers** | | | | |
| `uValueProvider` | Provider.family | constructionId | double | u_value_providers.dart |
| `roomHeatDemandProvider` | Provider.family | roomId | double (W) | heat_demand_providers.dart |
| `buildingHeatDemandProvider` | Provider.family | projectId | double (W) | heat_demand_providers.dart |
| `zoneHeatOutputProvider` | Provider.family | zoneId | double (W/m²) | heat_output_providers.dart |
| `zoneSurfaceTempProvider` | Provider.family | zoneId | double (°C) | heat_output_providers.dart |
| `tubeLengthProvider` | Provider.family | circuitId | double (m) | tube_length_providers.dart |
| `waterVolumeProvider` | Provider.family | circuitId | double (L) | water_volume_providers.dart |
| `flowRateProvider` | Provider.family | circuitId | double (kg/h) | flow_rate_providers.dart |
| `pressureLossProvider` | FutureProvider.family | circuitId | double (Pa) | pressure_loss_providers.dart |
| `hydraulicBalanceProvider` | FutureProvider.family | distributorId | Map\<String, double\> | hydraulic_balance_providers.dart |
| **UI state providers** | | | | |
| `selectedToolProvider` | StateProvider | — | DrawingTool | editor_screen.dart |
| `canvasTransformProvider` | StateNotifierProvider | — | Matrix4 | canvas_controller.dart |
| `selectedElementProvider` | StateProvider | — | (String type, String id)? | editor_screen.dart |
| `validationResultsProvider` | Provider.family | projectId | List\<ValidationResult\> | validation_service.dart |

### 6.3 Invalidation Cascade

When data changes, providers automatically re-evaluate because they depend on upstream streams. However, ensure:

- `uValueProvider(constructionId)` depends on `layersProvider(constructionId)`.
- `roomHeatDemandProvider(roomId)` depends on: `roomProvider(roomId)`, `wallSegmentsProvider(roomId)`, every `uValueProvider` for each wall's construction, `windowsProvider` / `doorsProvider`, project's `designOutdoorTempC`, `uValueProvider(room.floorConstructionId)` (when set), `uValueProvider(room.ceilingConstructionId)` (when set). Floor and ceiling losses use `ThermalEngine.boundaryCorrectionFactor()` with the room's `floorBoundary` / `ceilingBoundary` fields.
- `zoneHeatOutputProvider(zoneId)` depends on: zone params, `TubeType`, `FlooringMaterial`, distributor supply/return temps.
- `pressureLossProvider(circuitId)` depends on: `tubeLengthProvider(circuitId)`, `flowRateProvider(circuitId)`, tube inner diameter, roughness.
- `hydraulicBalanceProvider(distributorId)` depends on: every `pressureLossProvider` for each circuit of that distributor.

If a full-building hydraulic balance exceeds 16 ms, offload via `Isolate.run()`.

---

## 7. Persistence Contract

### 7.1 Drift Database

- Database class: `AppDatabase` in `lib/data/database/app_database.dart`.
- One Drift table per entity. Table names use `snake_case` plurals (e.g., `wall_segments`).
- Geometry fields (`polygon`, `supplyRoutePath`, `returnRoutePath`) stored as `TEXT` containing JSON arrays of `{x, y}` objects.
- Foreign key constraints enforced at the database level.
- Schema version starts at 1. Increment on every schema change with a step migration in `MigrationStrategy.onUpgrade`.

### 7.2 DAOs

Group related tables into DAOs:
- `ProjectDao` — projects
- `BuildingDao` — floors, rooms, wall_segments, windows, doors
- `ConstructionDao` — wall_constructions, material_layers
- `MaterialDao` — material_entries
- `HeatingDao` — heating_zones, tube_types, flooring_materials, distributors, heating_circuits

Each DAO exposes:
- `Stream<List<T>> watchAll(...)` — reactive list
- `Stream<T> watchById(String id)` — reactive single entity
- `Future<void> insert(T entity)`
- `Future<void> update(T entity)`
- `Future<void> delete(String id)`

### 7.3 Auto-Save

Debounce: 60 seconds after last change. Implemented as a global listener on the ProviderContainer that tracks write operations. Fires `projectRepository.save()`.

### 7.4 Project File Format (.hsp)

Gzip-compressed JSON. Structure:

```json
{
  "version": "1.0",
  "exportedAt": "ISO8601",
  "project": { },
  "floors": [ ],
  "rooms": [ ],
  "wallSegments": [ ],
  "windows": [ ],
  "doors": [ ],
  "wallConstructions": [ ],
  "materialLayers": [ ],
  "customMaterials": [ ],
  "heatingZones": [ ],
  "tubeTypes": [ ],
  "flooringMaterials": [ ],
  "distributors": [ ],
  "heatingCircuits": [ ]
}
```

On import: generate new UUIDs for all entities to prevent collisions. Preserve unknown JSON fields for forward compatibility.

---

## 8. Coding Standards (Enforced by Architect)

### 8.1 Style

- Effective Dart guidelines. Zero `flutter_lints` warnings.
- Max line length: 80 characters.
- Trailing commas on all multi-line argument lists.

### 8.2 Naming

| Entity | Convention | Example |
|--------|-----------|---------|
| Files | `snake_case.dart` | `wall_segment.dart` |
| Classes | `UpperCamelCase` | `WallSegment` |
| Variables | `lowerCamelCase` | `tubeSpacingMm` |
| Constants | `lowerCamelCase` | `rhoAir` |
| Enums | `UpperCamelCase` type, `lowerCamelCase` values | `WallType.exterior` |
| Providers | `lowerCamelCase` + `Provider` suffix | `heatDemandProvider` |
| Private | `_lowerCamelCase` | `_calculateFriction` |

### 8.3 Unit Suffixes on Numeric Fields

| Suffix | Unit |
|--------|------|
| `Mm` | millimetres |
| `M` | metres |
| `C` | degrees Celsius |
| `Pa` | Pascals |
| `KgH` | kilograms per hour |
| `WPerM2K` | W/(m²K) |

### 8.4 Documentation

- Every public class and function gets a `///` doc comment.
- Calculation functions reference their formula: `/// Darcy-Weisbach: Δp = f × (L/d) × (ρv²/2)`
- Complex algorithms get a brief prose explanation above the function.

### 8.5 Error Handling

- Calculation engines return `double.nan` for invalid inputs — never throw.
- Providers convert `nan` to a `ValidationResult` with `WarningSeverity.error`.
- Database operations wrapped in try-catch; surface user-friendly messages.
- Use Dart 3 sealed classes or `Result`-type pattern for fallible operations where richer context is needed.

---

## 9. Architect Review Checklist

Before any PR is merged, the architect verifies:

- [ ] New files placed in correct directory per Section 4
- [ ] No import rule violations per Section 3
- [ ] Models unchanged from Section 5 contracts (or change approved)
- [ ] Provider naming matches Section 6.1 convention
- [ ] Provider registered in Section 6.2 table (or table updated)
- [ ] Unit suffix convention followed on all new numeric fields
- [ ] Zero lint warnings
- [ ] Doc comments on all public APIs
- [ ] No direct repository imports from UI layer
