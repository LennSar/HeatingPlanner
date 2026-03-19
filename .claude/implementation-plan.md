# HeatingPlanner — Implementation Plan

> **Purpose:** Step-by-step guide for continuing implementation across multiple
> coding sessions. Each milestone ends in a state that can be manually tested.
> Read this at the start of every session and update the status as work is done.
>
> **Last updated:** 2026-03-17
> **Current status:** Milestone 1 in progress

---

## Current State (as of 2026-03-17)

### What works right now
- Floor plan canvas: draw walls, rooms auto-detect, place windows/doors
- Heating zones: draw, assign tube type + flooring, see zone colour (green/yellow/red/grey)
- Heat demand: EN 12831 transmission + ventilation (returns NaN when exterior wall has no construction)
- Zone colour follows ADR-004 strictly (red-hatched → grey → red → yellow → green)
- Circuit routing: place distributor, draw supply/return routes
- Properties panels: room, wall, zone, circuit, distributor all fully functional
- Hydraulic calculations: flow rate, pressure loss, tube length, water volume
- Validation rule HB-01: circuit length imbalance warning (>30% triggers warning)
- Status bar: live warning count from `validationResultsProvider`
- Database: Drift, schema v6, all repos wired except project and material repos
- Undo/redo service integrated

### What is stubbed / missing
| Area | File(s) | Impact |
|------|---------|--------|
| Project list | `project_list_screen.dart`, `project_repository.dart` | Cannot create/switch/delete projects |
| Material repo | `material_repository.dart` | No material library management UI |
| Performance dashboard | `performance_dashboard.dart` | No charts, no warnings tab |
| Circuit overview table | `circuit_overview_panel.dart` | No per-circuit summary table |
| Measure tool | `measure_tool.dart` | Toolbar button does nothing |
| Shared UI widgets | `temperature_slider.dart`, `unit_input_field.dart`, `material_picker.dart`, `severity_badge.dart` | Some panels use ad-hoc alternatives |
| Export dialogs | `export_dialog.dart`, `material_picker_dialog.dart` | No export |
| PDF / CSV export | `pdf_report_generator.dart`, `csv_exporter.dart` | No export |
| Desktop menu | `desktop_menu.dart` | No native menu bar |
| Tablet layout | `tablet_adaptations.dart` | No responsive iPad layout |
| More validation rules | `validation_service.dart` | Only HB-01 implemented |

---

## Milestones

Each milestone is sized for roughly one coding session and ends with something
the user can meaningfully test. Implement them in order — later milestones
depend on earlier ones.

---

### Milestone 1 — Validation Rules + Warnings Tab
**Goal:** The warning counter becomes fully meaningful and the user can see all
issues in one place.

**Why first:** The infrastructure (ValidationResult model, validationResultsProvider,
HB-01 rule, status bar counter) is already in place. Completing the rules and
adding the warnings tab gives immediate value with zero structural risk.

#### Steps

**1a. Add missing validation rules to `validation_service.dart`**
Rules to add (each is a separate function, same pattern as `_hydraulicImbalanceResults`):
- **VR-01 Missing construction:** Any `WallSegment` with `wallType == exterior`
  and `constructionId == null` → `WarningSeverity.error` on that wall segment.
  Message: "Exterior wall has no construction assigned — heat demand cannot be
  calculated." Fix: "Open wall properties and assign a wall construction."
- **VR-02 Surface temperature exceeded:** For each zone, watch
  `zoneSurfaceTempProvider` and compare against EN 1264 limits from
  `validation_limits.dart`. → `WarningSeverity.warning`.
  Message: "Floor surface temperature X.X°C exceeds EN 1264 limit of Y°C for
  this zone type." Fix: "Reduce supply temperature, increase tube spacing, or
  use a flooring material with lower thermal resistance."
- **VR-03 Circuit length exceeded:** For each circuit, watch
  `tubeLengthProvider`. If tube OD ≤ 14 mm and length > 90 m, or OD > 14 mm
  and length > 120 m → `WarningSeverity.warning`.
  Message: "Circuit length X m exceeds maximum of Y m for Z mm OD tube."
  Fix: "Split the zone into two smaller zones with separate circuits."
- **VR-04 Zone not connected:** Any `HeatingZone` where `circuitId == null` →
  `WarningSeverity.error`.
  Message: "Heating zone has no circuit connected." Fix: "Use the Route Pipe
  tool to connect this zone to a distributor."

**1b. Implement `SeverityBadge` widget (`lib/ui/widgets/severity_badge.dart`)**
- A small coloured chip: red (error), amber (warning), blue (info)
- Text shows the severity label or a count
- Uses `HeatingPlannerColors` tokens (no hard-coded hex)

**1c. Implement Performance Dashboard Warnings Tab**
Implement `performance_dashboard.dart` — start with Tab 3 (Warnings) only.
- List view of `validationResultsProvider('')`
- Each row: `SeverityBadge` + element type + message text
- Expand/collapse row to show `suggestedFix`
- Filter dropdown: All / Errors / Warnings / Info
- Wire the status bar warning count as a tappable link that opens the dashboard

**Testable after 1c:**
- Draw a zone without a circuit → red badge, rule VR-04 fires
- Assign no construction to an exterior wall → red badge, rule VR-01 fires
- Set supply temp very high → yellow badge, rule VR-02 fires
- Make two circuits of very different length → yellow badge, rule HB-01 fires

---

### Milestone 1b — Floor and Ceiling Heat Loss
**Goal:** Room heat demand accounts for floor slab and ceiling/roof losses in
addition to walls. User can assign constructions and boundary conditions for
both surfaces.

**Why here:** This is a foundational calculation gap — a room on a ground floor
or with a flat roof will have significantly under-estimated heat demand without
it. It belongs before project management because every saved project should
already capture correct demand data.

**Prerequisites:** None beyond the existing `WallConstruction` model and
`uValueProvider` (both reused as-is).

#### Steps

**1b-i. Add `BoundaryCondition` enum to `lib/data/models/enums.dart`**
```dart
enum BoundaryCondition { exterior, ground, unheatedSpace, interior }
```

**1b-ii. Add 6 new fields to `Room` model (`lib/data/models/room.dart`)**
New `@freezed` fields:
- `floorConstructionId: String?` (default null)
- `ceilingConstructionId: String?` (default null)
- `floorBoundary: BoundaryCondition` (default `BoundaryCondition.ground`)
- `ceilingBoundary: BoundaryCondition` (default `BoundaryCondition.exterior`)
- `floorUnheatedCorrectionFactor: double?` (default null → engine uses 0.6)
- `ceilingUnheatedCorrectionFactor: double?` (default null → engine uses 0.8)

Run `dart run build_runner build --delete-conflicting-outputs` after.

**1b-iii. Add `boundaryCorrectionFactor()` to `ThermalEngine`**
Per HVAC agent Section 5.1a. Pure static function, returns double.nan for
invalid inputs. Add unheated space presets to `thermal_defaults.dart`.

**1b-iv. DB migration → schema v7 (`lib/data/database/app_database.dart`)**
Add 6 nullable columns to the `rooms` table:
- `floor_construction_id TEXT`
- `ceiling_construction_id TEXT`
- `floor_boundary TEXT NOT NULL DEFAULT 'ground'`
- `ceiling_boundary TEXT NOT NULL DEFAULT 'exterior'`
- `floor_unheated_correction_factor REAL`
- `ceiling_unheated_correction_factor REAL`
Increment `schemaVersion` to 7. Add step migration v6→v7 using
`m.addColumn(rooms, rooms.floorConstructionId)` etc.

Update `RoomsTable` in `lib/data/database/tables/rooms_table.dart` and the
`_roomFromRow` / `_roomToCompanion` mapping functions in
`building_repository.dart`.

**1b-v. Update `roomHeatDemandProvider`**
In `lib/calculation/providers/heat_demand_providers.dart`:
- After the existing wall + ventilation sum, add:
  - Watch `uValueProvider(room.floorConstructionId)` if set
  - Watch `uValueProvider(room.ceilingConstructionId)` if set
  - Compute `ThermalEngine.boundaryCorrectionFactor(room.floorBoundary, ...)`
  - Add `ThermalEngine.transmissionLoss(uFloor, areaM2, fFloor, tDelta)` to Q_total
  - Same for ceiling
- Do NOT return NaN when floor/ceiling constructions are missing — only wall
  constructions trigger NaN (per UI agent note in 7.2.1)

**1b-vi. Update room properties panel**
In `lib/ui/panels/room_properties.dart`:
- Add the "Envelope — Floor & Ceiling" collapsible section per UI agent
  Section 7.2.1
- Two rows in heat demand breakdown: "Transmission walls" and "Floor" and
  "Ceiling" (show "—" if construction not assigned for that surface)
- Boundary dropdown wired to `editorStateProvider` → `updateRoom()`
- Construction Edit button opens `WallConstructionEditor` modal (already exists)
- Correction factor slider (visible only when `BoundaryCondition.unheatedSpace`)

**Testable after 1b-vi:**
- Ground floor room with no floor construction → heat demand calculated from
  walls only; floor row shows "—"
- Assign a floor construction (e.g. 200mm concrete + 100mm EPS) → floor
  transmission loss appears in demand breakdown, total updates
- Change boundary to "Unheated attic" → ceiling loss appears with correction
  factor slider at 0.8
- Change boundary to "Adjacent heated room" → ceiling loss disappears (f = 0)
- All demand numbers update live as construction layers are edited

---

### Milestone 2 — Project Management
**Goal:** User can create, name, open, and delete projects. App opens to the
project list, not directly to the editor.

**Why second:** Right now data does persist to the DB during a session, but
there is no way to start a new project or reopen an old one. This is the most
critical missing workflow for any real use.

#### Steps

**2a. Implement `ProjectRepository` (`lib/repositories/project_repository.dart`)**
- Replace `async* { yield null; }` stub with real DAO calls
- `projectProvider(projectId)` → `StreamProvider.family<Project?, String>`
- `projectsProvider` → `StreamProvider<List<Project>>` (all projects, newest first)
- CRUD functions: `upsertProject(dao, project)`, `deleteProject(dao, id)`

**2b. Implement `ProjectListScreen` (`lib/ui/screens/project_list_screen.dart`)**
Per UI agent spec Section 4.1:
- Grid of project cards (name, modified date, floor area if calculable)
- "+ New Project" button → dialog (name, outdoor temp, indoor temp)
- Tap card → navigate to EditorScreen with that project ID
- Context menu per card: Duplicate, Delete (with confirmation dialog)
- Empty state: friendly prompt to create first project

**2c. Wire app entry point**
- Change `app.dart` (or `main.dart`) to show `ProjectListScreen` first
- `EditorScreen` receives a `projectId` parameter
- `currentProjectIdProvider` is set when navigating into the editor
- `EditorStateNotifier.init(projectId)` loads the correct floor from DB

**Testable after 2c:**
- Launch app → see project list (empty state)
- Create a project → navigate to editor, draw some walls
- Back button → project list shows the project with "modified" timestamp
- Reopen project → walls are still there
- Delete project → it disappears

---

### Milestone 3 — Performance Dashboard (Heat + Hydraulic Tabs)
**Goal:** The performance dashboard is fully usable for system analysis.

**Why third:** The validation tab (Milestone 1) gives error feedback. Now add
the quantitative analysis views the installer uses to check whether the design
is adequate.

#### Steps

**3a. Circuit overview table (`lib/ui/panels/circuit_overview_panel.dart`)**
Replace stub with a data table showing per circuit:
- Circuit number / zone name
- Tube length (m)
- Flow rate (kg/h)
- Pressure loss (kPa)
- Required valve setting (kPa) from `hydraulicBalanceProvider`
- Status icon (green/yellow/red)

**3b. Heat Balance tab (Tab 1 of dashboard)**
Per UI agent spec Section 5.8 Tab 1:
- Use `fl_chart` bar chart
- One group per room: demand bar (from `roomHeatDemandProvider`) + output bar
  (sum of zone outputs in that room from `zoneHeatOutputProvider`)
- Colour: green when output ≥ demand, red when under
- Show balance delta (W) per room

**3c. Hydraulic tab (Tab 2 of dashboard)**
Per UI agent spec Section 5.8 Tab 2:
- Horizontal stacked bar chart per circuit
- Segments: pipe friction loss vs valve throttling
- Second section: pie chart of flow rate distribution across circuits
- Reference circuit labelled
- Total system pressure drop shown

**3d. Wire dashboard open/close**
- Toolbar icon (📊) opens the dashboard as a right-side panel (desktop) or
  full-screen overlay (tablet)
- Currently the toolbar has the icon but the TODO is unimplemented

**Testable after 3d:**
- Complete a small design (2 rooms, 2 zones, 1 distributor, 2 circuits)
- Open dashboard → heat balance tab shows both rooms with colour-coded bars
- Hydraulic tab shows circuit pressure comparison and flow split
- Warnings tab lists any active warnings

---

### Milestone 4 — Export
**Goal:** User can generate a PDF report and export circuit data to CSV.

**Why fourth:** Once the design is complete and validated, the installer needs
to hand off the results. Export is a natural completion of the workflow.

#### Steps

**4a. `ExportDialog` (`lib/ui/dialogs/export_dialog.dart`)**
- Two options: "PDF Report" and "CSV Data"
- Trigger from File menu or toolbar button

**4b. PDF Report (`lib/export/pdf_report_generator.dart`)**
Using the `pdf` package:
- Cover page: project name, outdoor temp, date
- Summary table: total rooms, total area, total heat demand, total output
- Per-room section: room name, area, demand (W), zone output (W), balance
- Hydraulic table: per circuit (tube length, flow rate, pressure loss, valve
  setting)
- Validation warnings (errors and warnings only, not info)

**4c. CSV Export (`lib/export/csv_exporter.dart`)**
One CSV with a row per circuit:
`circuit_id, zone_name, room_name, tube_length_m, flow_rate_kg_h,
pressure_loss_pa, valve_setting_pa`

**Testable after 4c:**
- Complete a design → File → Export → PDF → file saved, opens correctly
- Export → CSV → opens in a spreadsheet, correct values

---

### Milestone 5 — Material Library Management
**Goal:** User can browse, add custom materials, and assign them to wall
constructions from a searchable dialog.

**Why fifth:** Wall constructions can already be built using the existing inline
material list, but there is no search dialog and no custom material management.
This polishes the construction editor workflow.

#### Steps

**5a. `MaterialRepository` (`lib/repositories/material_repository.dart`)**
- `materialsProvider` → `StreamProvider<List<MaterialEntry>>`
- CRUD: `upsertMaterial(dao, entry)`, `deleteMaterial(dao, id)`

**5b. `MaterialPickerDialog` (`lib/ui/dialogs/material_picker_dialog.dart`)**
Per UI agent spec Section 5.7:
- Search field filters by name and category
- Category tabs (Masonry, Concrete, Insulation, Wood, Plaster, Floor Covering,
  Membrane, Custom)
- Tapping a row returns the selected `MaterialEntry`
- "New custom material" button → inline form (name, λ, density, specific heat)

**5c. Wire dialog into wall construction editor**
Replace the current inline material dropdown in
`wall_construction_editor.dart` with a button that opens
`MaterialPickerDialog`.

**Testable after 5c:**
- Wall construction editor → Add Layer → tap material → search "EPS" → selects
- Add a custom material → it appears in the list and can be used in a layer

---

### Milestone 6 — Platform & Polish
**Goal:** Desktop menu bar, measure tool, tablet layout, shared UI widgets.

**Why last:** These are quality-of-life improvements. The tool is fully usable
without them.

#### Steps

**6a. Desktop menu bar (`lib/platform/desktop_menu.dart`)**
Native macOS/Windows/Linux menu bar:
- File: New, Open, Save, Save As, Export, Close
- Edit: Undo, Redo, Delete
- View: Zoom In/Out/Fit, Toggle Properties Panel, Toggle Dashboard
- Tools: (mirror of toolbar icons with keyboard shortcuts shown)
- Help: About

**6b. Measure tool (`lib/ui/canvas/tools/measure_tool.dart`)**
- Click two points → display distance in mm and m
- Annotation stays on canvas until tool is deactivated
- Result shown in status bar while tool is active

**6c. Tablet layout (`lib/platform/tablet_adaptations.dart`)**
Per UI agent spec Section 4.3:
- Properties panel as `DraggableScrollableSheet` (three snap points)
- Compact toolbar (48px, icon only, long-press tooltips)
- Action bar above status bar (Undo / Redo / Delete)

**6d. Shared UI widgets**
- `SeverityBadge` (done in Milestone 1)
- `UnitInputField` — `TextFormField` with suffix unit label, numeric validation
- `TemperatureSlider` — labelled slider with °C suffix, range clamping

**Testable after 6d (desktop):**
- macOS: native menu bar visible with correct shortcuts
- Measure tool: click two points, see "4235 mm / 4.24 m" in status bar
- Tablet (iPad simulator): properties panel slides up from bottom

---

## Deferred / Out of Scope for MVP

- Full EN 1264 correction factor digitised tables (currently using empirical fits)
- ISO 13370 ground floor U-value method (currently simplified factor 0.6)
- Temperature-dependent water physical properties (currently using 40°C constants)
- Multi-floor heat transfer through slabs
- EN 15377 wall heating exponent correction
- Automated test suite (unit + widget + integration)

These are tracked as `// TODO(HVAC):` comments in the engine files.

---

## How to Use This File

1. **Start of session:** Read "Current State" and the next incomplete milestone.
2. **During work:** Cross off steps as they complete (replace `**` with `~~`).
3. **End of session:** Update "Current State" to reflect what now works.
4. **Context limit hit:** Start a new conversation, point Claude at this file.

The agent files (`.claude/agent-hvac.md`, `agent-architect.md`, etc.) remain
the authoritative specs. This file tracks *progress*, not *intent*.
