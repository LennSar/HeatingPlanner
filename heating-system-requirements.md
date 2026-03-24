**Technical Requirements Specification**

Flutter Heating System Planning Application

*Cross-Platform Floor & Wall Heating Design Tool*

Version 1.0

February 2026

**CONFIDENTIAL**

Table of Contents

1\. Executive Summary

This document defines the complete technical requirements for a
production-ready, cross-platform heating system planning application
built with the Flutter framework. The application enables heating system
designers and engineers to create optimized floor and wall heating
layouts by modeling building geometry, calculating thermal demand,
designing pipe networks, and balancing hydraulic circuits for maximum
system efficiency.

The tool targets five platforms: macOS, Linux, Windows, iOS (iPad), and
Android. It follows a phased workflow from floor plan definition through
final system optimization, with real-time recalculation throughout.

1.1 Target Users

-   Heating system designers and HVAC engineers

-   Building architects requiring thermal validation

-   Installation technicians planning pipe layouts

-   Energy consultants performing heat demand audits

1.2 Core Workflow Phases

  -----------------------------------------------------------------------
  **Phase**       **Description**                 **Key Output**
  --------------- ------------------------------- -----------------------
  1\. Floor Plan  Define rooms, walls, windows,   Building geometry model
  Definition      doors with dimensions and       
                  thermal targets                 

  2\. Wall        Compose wall assemblies with    Heat dissipation
  Construction    material layers; compute        coefficients
  Analysis        U-values                        

  3\. Heat Demand Compute transmission and        Room-level heat demand
  Calculation     ventilation losses per room     (W)

  4\. Heating     Place heating tubes, define     Hydraulic circuit
  System Design   zones, connect to distributor   layout

  5\. Performance Calculate heat output, pressure System balance report
  Analysis        loss, flow rates per zone       
  -----------------------------------------------------------------------

2\. Data Architecture & Models

All data models use immutable value objects with unique identifiers
(UUIDs). The architecture follows a reactive pattern where changes to
any model property trigger downstream recalculations.

2.1 Building Geometry Models

2.1.1 Project

  ---------------------------------------------------------------------------------
  **Field**           **Type**        **Description**           **Constraints**
  ------------------- --------------- ------------------------- -------------------
  id                  UUID            Unique project identifier Auto-generated

  name                String          Project display name      1-255 chars

  createdAt           DateTime        Creation timestamp        Immutable

  modifiedAt          DateTime        Last modification         Auto-updated

  designOutdoorTemp   double          Design outdoor            -50 to +10
                                      temperature (°C)          

  defaultIndoorTemp   double          Default indoor target     15 to 30
                                      (°C)                      

  location            GeoLocation?    Building geographic       Optional
                                      location                  

  floors              List\<Floor\>   Building floors           ≥1 floor
  ---------------------------------------------------------------------------------

2.1.2 Floor

  ---------------------------------------------------------------------------
  **Field**      **Type**       **Description**           **Constraints**
  -------------- -------------- ------------------------- -------------------
  id             UUID           Floor identifier          Auto-generated

  name           String         Floor label (e.g. Ground  1-100 chars
                                Floor)                    

  level          int            Floor level index (0 =    ≥0
                                ground)                   

  heightMm       int            Floor-to-ceiling height   2000-6000
                                (mm)                      

  rooms          List\<Room\>   Rooms on this floor       ≥1 room
  ---------------------------------------------------------------------------

2.1.3 Room

  ---------------------------------------------------------------------------------
  **Field**       **Type**              **Description**         **Constraints**
  --------------- --------------------- ----------------------- -------------------
  id              UUID                  Room identifier         Auto-generated

  name            String                Room name (e.g. Living  1-100 chars
                                        Room)                   

  targetTempC     double                Target indoor           15.0-30.0
                                        temperature (°C)        

  airChangeRate   double                Air changes per hour    0.1-5.0
                                        (1/h)                   

  polygon         List\<Point2D\>       Room boundary vertices  ≥3 vertices, closed
                                        (mm)                    

  walls           List\<WallSegment\>   Wall segments forming   Derived from
                                        boundary                polygon

  windows         List\<Window\>        Windows placed on walls Must be on wall
                                                                segment

  doors           List\<Door\>          Doors placed on walls   Must be on wall
                                                                segment

  heatingZones    List\<HeatingZone\>   Floor/wall heating      Optional
                                        zones                   
  ---------------------------------------------------------------------------------

2.1.4 WallSegment

  --------------------------------------------------------------------------------
  **Field**        **Type**            **Description**         **Constraints**
  ---------------- ------------------- ----------------------- -------------------
  id               UUID                Segment identifier      Auto-generated

  startPoint       Point2D             Start vertex (mm)       On room polygon

  endPoint         Point2D             End vertex (mm)         On room polygon

  wallType         WallType            Enum: EXTERIOR,         Required
                                       INTERIOR, PARTITION     

  construction     WallConstruction    Material layer          Required for
                                       composition             EXTERIOR

  adjacentRoomId   UUID?               Linked room for shared  Null for exterior
                                       walls                   

  orientation      CardinalDirection   N/S/E/W facing          Auto-calculated
  --------------------------------------------------------------------------------

2.1.5 Window & Door

  --------------------------------------------------------------------------
  **Field**        **Type**     **Description**         **Constraints**
  ---------------- ------------ ----------------------- --------------------
  id               UUID         Element identifier      Auto-generated

  wallSegmentId    UUID         Host wall reference     Must exist

  positionOnWall   double       Offset from wall start  0 to wallLength -
                                (mm)                    width

  widthMm          int          Element width (mm)      300-5000

  heightMm         int          Element height (mm)     300-3000

  sillHeightMm     int          Height from floor (mm)  0-2500

  uValue           double       Thermal transmittance   0.5-6.0
                                (W/m²K)                 
  --------------------------------------------------------------------------

2.2 Wall Construction Models

2.2.1 WallConstruction

  ---------------------------------------------------------------------------------
  **Field**       **Type**                **Description**         **Constraints**
  --------------- ----------------------- ----------------------- -----------------
  id              UUID                    Construction identifier Auto-generated

  name            String                  Descriptive name        1-200 chars

  layers          List\<MaterialLayer\>   Ordered material layers ≥1 layer
                                          (outside to inside)     

  rsi             double                  Interior surface        Default 0.13
                                          resistance (m²K/W)      

  rse             double                  Exterior surface        Default 0.04
                                          resistance (m²K/W)      
  ---------------------------------------------------------------------------------

2.2.2 MaterialLayer

  ------------------------------------------------------------------------------
  **Field**             **Type**       **Description**         **Constraints**
  --------------------- -------------- ----------------------- -----------------
  materialId            UUID           Reference to material   Must exist
                                       database                

  thicknessMm           double         Layer thickness (mm)    1.0-1000.0

  thermalConductivity   double         Lambda (λ) value (W/mK) 0.01-50.0

  density               double         Material density        1-10000
                                       (kg/m³)                 

  specificHeat          double         Specific heat capacity  100-5000
                                       (J/kgK)                 
  ------------------------------------------------------------------------------

2.2.3 Material Database Entry

The application shall include a built-in material database with at
minimum the following categories and representative materials:

  ------------------------------------------------------------------------
  **Category**      **Example Materials**               **Lambda Range
                                                        (W/mK)**
  ----------------- ----------------------------------- ------------------
  Masonry           Solid brick, Hollow brick, Concrete 0.12-1.65
                    block, AAC block                    

  Concrete          Normal concrete, Lightweight        0.33-2.10
                    concrete, Reinforced concrete       

  Insulation        EPS, XPS, Mineral wool, PUR/PIR,    0.020-0.045
                    Phenolic foam                       

  Wood              Softwood, Hardwood, Plywood, OSB,   0.10-0.24
                    MDF                                 

  Plaster & Render  Cement render, Lime plaster, Gypsum 0.18-1.00
                    plaster                             

  Metals            Steel, Aluminium, Copper            17.0-401.0

  Membranes         Vapour barrier, Breather membrane,  0.17-0.50
                    DPM                                 

  Floor Coverings   Ceramic tile, Parquet, Laminate,    0.05-1.30
                    Carpet, Vinyl                       
  ------------------------------------------------------------------------

2.3 Heating System Models

2.3.1 HeatingZone

  -------------------------------------------------------------------------------
  **Field**          **Type**           **Description**         **Constraints**
  ------------------ ------------------ ----------------------- -----------------
  id                 UUID               Zone identifier         Auto-generated

  roomId             UUID               Parent room reference   Must exist

  zoneType           ZoneType           FLOOR_HEATING or        Required
                                        WALL_HEATING            

  polygon            List\<Point2D\>    Zone boundary within    Must be inside
                                        room (mm)               room

  tubeSpacingMm      int                Centre-to-centre tube   50-400
                                        spacing (mm)            

  tubeType           TubeType           Tube material and       Required
                                        dimensions              

  flooringMaterial   FlooringMaterial   Covering above heating  Required for
                                                                floor zones

  borderDistanceMm   int                Distance from zone edge 50-300
                                        to first tube (mm)      

  layoutPattern      LayoutPattern      MEANDER, SPIRAL,        Default MEANDER
                                        BIFILAR, COUNTERFLOW    

  circuitId          UUID?              Assigned hydraulic      Null until
                                        circuit                 connected
  -------------------------------------------------------------------------------

2.3.2 TubeType

  ---------------------------------------------------------------------------------
  **Field**              **Type**       **Description**        **Constraints**
  ---------------------- -------------- ---------------------- --------------------
  id                     UUID           Tube type identifier   Auto-generated

  name                   String         Commercial name        1-100 chars

  material               TubeMaterial   PE-RT, PE-Xa, PE-Xb,   Required
                                        PE-Xc, PB, Copper,     
                                        MultiLayer             

  outerDiameterMm        double         Outer diameter (mm)    8.0-32.0

  innerDiameterMm        double         Inner diameter (mm)    Must be \<
                                                               outerDiameter

  wallThicknessMm        double         Tube wall thickness    Derived or specified
                                        (mm)                   

  thermalConductivity    double         Tube wall lambda       Material-dependent
                                        (W/mK)                 

  roughness              double         Internal surface       0.001-0.1
                                        roughness (mm)         

  maxOperatingTempC      double         Maximum operating      ≤40°C typical for
                                        temperature            floor

  maxOperatingPressure   double         Maximum pressure (bar) 3-10 bar
  ---------------------------------------------------------------------------------

2.3.3 Distributor (Manifold)

  ------------------------------------------------------------------------------------
  **Field**         **Type**                 **Description**         **Constraints**
  ----------------- ------------------------ ----------------------- -----------------
  id                UUID                     Distributor identifier  Auto-generated

  position          Point2D                  Placement on floor plan Required
                                             (mm)                    

  circuits          List\<HeatingCircuit\>   Connected circuits      1-12 circuits
                                                                     typical

  supplyTempC       double                   Supply water            20-55
                                             temperature (°C)        

  returnTempC       double                   Return water            \< supplyTemp
                                             temperature (°C)        

  pumpHead          double                   Minimum required pump    Calculated from
                                             pressure (Pa)            circuit pressure
                                                                      losses

  pumpCapacityPa    double?                  User-entered pump        Optional, for
                                             capacity for validation  validation only
                                             (Pa)                     
  ------------------------------------------------------------------------------------

2.3.4 HeatingCircuit

  -----------------------------------------------------------------------------
  **Field**         **Type**          **Description**         **Constraints**
  ----------------- ----------------- ----------------------- -----------------
  id                UUID              Circuit identifier      Auto-generated

  distributorId     UUID              Parent distributor      Must exist

  heatingZoneId     UUID              Connected zone          Must exist

  supplyRoutePath   List\<Point2D\>   Pipe path: distributor  Must be
                                      to zone                 continuous

  returnRoutePath   List\<Point2D\>   Pipe path: zone to      Must be
                                      distributor             continuous

  tubeLengthM       double            Total tube length (m)   Calculated

  flowRateKgH       double            Mass flow rate (kg/h)   Calculated

  pressureLossPa    double            Total pressure loss     Calculated
                                      (Pa)                    

  valveSetting      double            Balancing valve         Calculated
                                      position                
  -----------------------------------------------------------------------------

3\. Calculation Engine Requirements

All thermal and hydraulic calculations shall conform to EN 12831 (heat
demand), EN 1264 (floor heating), and EN 15377 (wall heating) standards
where applicable. The engine must support real-time recalculation with
update latency below 200ms for typical residential projects.

3.1 U-Value Calculation (Thermal Transmittance)

For a composite wall assembly consisting of n material layers, the
thermal transmittance U (W/m²K) is calculated as:

**U = 1 / R_total**

**R_total = R_si + Σ(d_i / λ_i) + R_se**

Where:

-   R_si = interior surface resistance (m²K/W); default 0.13 for
    horizontal heat flow, 0.10 for upward, 0.17 for downward

-   R_se = exterior surface resistance (m²K/W); default 0.04 for
    exterior walls, 0.13 for interior walls

-   d_i = thickness of layer i (m)

-   λ_i = thermal conductivity of layer i (W/mK)

**Acceptance Criteria:** U-value calculations shall match manual
calculations within ±0.001 W/m²K. Surface resistance values shall be
configurable per EN ISO 6946.

3.2 Heat Demand Calculation

3.2.1 Transmission Heat Loss

For each room, calculate transmission loss through each wall, window,
and door element:

**Q_T = Σ(U_j × A_j × f_j × (T_i - T_e))**

Where:

-   Q_T = transmission heat loss (W)

-   U_j = thermal transmittance of element j (W/m²K)

-   A_j = surface area of element j (m²)

-   f_j = temperature correction factor (1.0 for exterior walls,
    variable for ground/interior)

-   T_i = design indoor temperature (°C)

-   T_e = design outdoor temperature (°C)

Interior walls between rooms at different temperatures shall use the
temperature difference between the two rooms. No heat loss is calculated
for walls between rooms at identical target temperatures.

3.2.2 Ventilation Heat Loss

**Q_V = V_room × n × ρ_air × c_air × (T_i - T_e) / 3600**

Where:

-   Q_V = ventilation heat loss (W)

-   V_room = room volume (m³) = floor area × ceiling height

-   n = air change rate (1/h)

-   ρ_air = air density (default 1.2 kg/m³)

-   c_air = specific heat of air (default 1005 J/kgK)

3.2.3 Total Heat Demand

**Q_room = Q_T + Q_V \[W\]**

The system shall display per-room and total building heat demand, with
the ability to vary outdoor temperature for scenario analysis.

**Acceptance Criteria:** Total heat demand per room shall match manual
EN 12831 calculations within ±2%. The system shall support outdoor
temperature variation from -30°C to +15°C.

3.3 Floor/Wall Heating Output Calculation

3.3.1 Specific Heat Output

The specific heat output q (W/m²) of a floor or wall heating zone is
calculated using the approach from EN 1264:

**q = B × a_B × a_T × a_U × a_D × ΔT\^n**

Where:

-   B = system constant depending on tube type and installation

-   a_B = covering correction factor (depends on flooring R-value)

-   a_T = tube spacing correction factor

-   a_U = tube outer diameter correction factor

-   a_D = tube wall thickness/conductivity correction factor

-   ΔT = mean temperature difference between heating surface and room
    air (°C)

-   n = exponent (typically 1.1 for floor heating)

3.3.2 Mean Temperature Difference

**ΔT = (T_supply - T_return) / ln((T_supply - T_room) / (T_return -
T_room))**

This logarithmic mean is critical for accurate heat output estimation.
When supply and return temperatures approach room temperature, the
system shall use the arithmetic mean as a fallback to avoid
division-by-zero conditions.

3.3.3 Surface Temperature Limits

The system shall enforce maximum surface temperature limits per EN 1264:

  -----------------------------------------------------------------------
  **Zone Type**       **Maximum Surface       **Application**
                      Temperature**           
  ------------------- ----------------------- ---------------------------
  Occupied zone       29°C                    Living areas, offices
  (floor)                                     

  Peripheral zone     35°C                    Zones within 1m of exterior
  (floor)                                     walls

  Bathrooms (floor)   33°C                    Wet rooms

  Wall heating        40°C                    All wall-mounted heating
                                              panels
  -----------------------------------------------------------------------

The system shall display warnings when calculated surface temperatures
exceed these limits and shall suggest parameter adjustments (e.g., wider
tube spacing, lower supply temperature).

3.4 Hydraulic Calculations

3.4.1 Tube Length Calculation

Total tube length per circuit includes three components:

**L_total = L_zone + L_supply + L_return**

-   L_zone: tube length within the heating zone, calculated from zone
    area and tube spacing: L_zone ≈ A_zone / (spacing / 1000)

-   L_supply: supply pipe route length from distributor to zone entry

-   L_return: return pipe route length from zone exit to distributor

3.4.2 Water Volume per Circuit

**V_water = π × (d_i / 2)² × L_total \[litres\]**

3.4.3 Mass Flow Rate

**m_dot = Q_zone / (c_w × (T_supply - T_return)) \[kg/s\]**

Where c_w is the specific heat capacity of water (4186 J/kgK) and Q_zone
is the required heat output of the zone in watts.

3.4.4 Pressure Loss Calculation

Total pressure loss per circuit is the sum of distributed (friction) and
localised (fitting) losses:

**Δp_total = Δp_friction + Δp_fittings**

**Friction losses** are calculated using the Darcy-Weisbach equation:

**Δp_friction = f × (L / d_i) × (ρ × v² / 2)**

Where f is the Darcy friction factor (calculated via the Colebrook-White
equation or Moody chart approximation), L is the total tube length (m),
d_i is the inner diameter (m), ρ is water density (kg/m³), and v is the
flow velocity (m/s).

**Fitting losses** are estimated as a percentage of friction losses
(typically 30-50%) or via explicit zeta values for bends and
connections:

**Δp_fitting = Σ(ζ_k × ρ × v² / 2)**

3.4.5 Hydraulic Balancing

The system shall calculate balancing valve positions to equalize
pressure losses across all circuits connected to a common distributor.
The reference circuit is the one with the highest pressure loss. All
other circuits require throttling:

**Δp_valve_i = Δp_max - Δp_circuit_i**

The system shall display a pressure loss comparison bar chart across all
circuits, highlighting the reference circuit, and indicating required
valve settings.

**Acceptance Criteria:** Pressure loss calculations shall be within ±5%
of established pipe network calculation tools. Flow velocity warnings
shall appear when v \> 0.5 m/s (noise risk) or v \< 0.2 m/s
(insufficient turbulence). Maximum recommended circuit length shall be
120m for 16mm tube and 90m for 12mm tube.

3.5 Physical Constants & Default Values

  ----------------------------------------------------------------------------
  **Constant**              **Symbol**   **Value**         **Unit**
  ------------------------- ------------ ----------------- -------------------
  Air density               ρ_air        1.2               kg/m³

  Specific heat of air      c_air        1005              J/(kgK)

  Water density (40°C)      ρ_w          992.2             kg/m³

  Specific heat of water    c_w          4186              J/(kgK)

  Dynamic viscosity of      μ_w          0.000653          Pa·s
  water (40°C)                                             

  Kinematic viscosity of    ν_w          0.000000658       m²/s
  water (40°C)                                             

  Stefan-Boltzmann constant σ            5.67×10⁻⁸         W/(m²K⁴)

  Gravitational             g            9.81              m/s²
  acceleration                                             

  Interior surface          R_si         0.13              m²K/W
  resistance (horiz.)                                      

  Exterior surface          R_se         0.04              m²K/W
  resistance                                               
  ----------------------------------------------------------------------------

All constants shall be configurable by the user to accommodate regional
standards and special conditions. Temperature-dependent water properties
should optionally use lookup tables for improved accuracy.

4\. User Interface & Experience Requirements

4.1 Overall Layout Architecture

The application shall use an adaptive layout with three primary regions:

-   Canvas Area: Central 2D drawing surface for floor plan and heating
    system visualization, with pan, zoom, and rotation controls

-   Properties Panel: Right-side collapsible panel showing contextual
    properties for the selected element (room, wall, heating zone)

-   Toolbar: Left-side vertical toolbar with drawing and selection
    tools, organized by workflow phase

-   Status Bar: Bottom bar showing current zoom level, coordinates,
    active calculation warnings, and project statistics

On tablets (iPad/Android), the properties panel shall be accessible via
a slide-over sheet, and the toolbar shall collapse to icons with
long-press tooltips.

4.2 Floor Plan Drawing Tools

4.2.1 Grid & Snapping System

-   Configurable grid spacing: 50mm, 100mm, 250mm, 500mm (default 100mm)

-   Snap-to-grid with visual feedback (highlight snap points)

-   Snap-to-wall endpoint for connecting walls

-   Snap-to-midpoint for centering elements

-   Angular snapping at 0°, 45°, 90° increments (hold Shift)

-   Dimension annotations displayed during drawing operations

4.2.2 Wall Drawing Mode

Users draw walls by clicking start and end points. Walls display their
length in millimetres. Enclosed polygons automatically define rooms.
Shared wall segments between adjacent rooms are detected and linked
automatically. Wall thickness is displayed visually to scale on the
canvas.

4.2.3 Window & Door Placement

Windows and doors are placed by clicking on an existing wall segment. A
placement preview shows the element dimensions. Users can drag to
position along the wall. Double-click opens the properties editor for
thermal values.

4.2.4 Room Properties Interface

Selecting a room highlights it and opens the properties panel with
fields for: room name, target indoor temperature (slider + numeric
input, 15-30°C), air change rate (dropdown with presets: 0.5 standard,
1.0 kitchen, 1.5 bathroom, 2.0 utility, plus custom entry), and a
read-only computed section showing room area, volume, and total heat
demand.

4.3 Wall Construction Editor

A modal dialog presenting the wall layer stack visually. Each layer is a
horizontal bar whose width is proportional to its thickness. Users can
add, remove, and reorder layers via drag-and-drop. A material picker
provides searchable access to the built-in database. Real-time U-value
display updates as layers are modified. A thermal gradient visualization
shows temperature distribution through the wall assembly at the current
design conditions.

4.4 Heating System Design Interface

4.4.1 Heating Zone Placement

Users draw rectangular or polygonal heating zones within rooms. Zones
display tube routing preview based on selected pattern (meander, spiral,
bifilar, counterflow). Tube spacing is adjustable via the properties
panel with instant visual update. Zones change colour to reflect heat
output adequacy: green (sufficient), yellow (marginal), red
(insufficient to meet room demand).

4.4.2 Distributor Placement & Circuit Routing

The water distributor is placed as a symbol on the floor plan. Users
draw supply and return routes from the distributor to each heating zone.
The system validates complete hydraulic loops. A circuit overview table
lists all connected circuits with key metrics: tube length, flow rate,
pressure loss, and heat output.

4.5 Performance Dashboard

A dedicated panel or overlay providing system-wide performance
visualization:

-   Per-room heat demand vs. heat output bar chart (demand shown as
    target line)

-   Pressure loss comparison across all circuits (horizontal bar chart)

-   Flow rate distribution pie chart

-   Surface temperature heat map overlay on the floor plan

-   System warnings list with severity levels and suggested fixes

-   Export function generating a summary report (PDF or CSV)

4.6 Interaction Patterns by Platform

  -----------------------------------------------------------------------
  **Interaction**   **Desktop                  **Tablet (Touch)**
                    (Mouse+Keyboard)**         
  ----------------- -------------------------- --------------------------
  Pan canvas        Middle-click drag or       Two-finger drag
                    Space+drag                 

  Zoom              Scroll wheel or Ctrl +/-   Pinch gesture

  Draw wall         Click start, click end     Tap start, tap end

  Place window/door Click on wall, drag        Tap wall, drag position
                    position                   

  Select element    Left click                 Tap

  Multi-select      Shift+click or drag        Long press + tap
                    marquee                    additional

  Context menu      Right-click                Long press

  Undo/Redo         Ctrl+Z / Ctrl+Shift+Z      Toolbar buttons

  Delete element    Delete key or Backspace    Toolbar button or swipe

  Measurement tool  Click two points           Tap two points
  -----------------------------------------------------------------------

5\. Technical Architecture

5.1 Technology Stack

  -----------------------------------------------------------------------
  **Component**     **Technology**             **Rationale**
  ----------------- -------------------------- --------------------------
  Framework         Flutter 3.24+ (latest      Single codebase for all 5
                    stable)                    platforms

  Language          Dart 3.5+                  Sound null safety, pattern
                                               matching

  State Management  Riverpod 2.x +             Scalable, testable,
                    flutter_riverpod           supports families

  Canvas Rendering  CustomPainter + Flutter    Full control over 2D
                    Canvas API                 drawing

  Persistence       SQLite via drift (moor     Relational data,
                    successor)                 cross-platform

  Serialization     JSON with freezed +        Immutable models with
                    json_serializable          serialization

  Charts            fl_chart or custom         Performance dashboard
                    painters                   visualizations

  PDF Export        pdf package (dart:pdf)     Native PDF generation

  File I/O          path_provider +            Platform-appropriate file
                    file_picker                access

  Testing           flutter_test +             Unit, widget, and
                    integration_test           integration tests
  -----------------------------------------------------------------------

5.2 State Management Architecture

The application shall use a layered state architecture:

**Layer 1 -- Data Layer:** Immutable model objects generated with the
freezed package. All models implement copyWith for efficient updates.

**Layer 2 -- Repository Layer:** Drift database repositories for CRUD
operations. Repositories expose Streams for reactive updates.

**Layer 3 -- Calculation Layer:** Dedicated Riverpod providers that
compute derived values (U-values, heat demand, pressure loss). These use
Riverpod families to scope calculations per entity (e.g.,
heatDemandProvider(roomId)).

**Layer 4 -- UI Layer:** ConsumerWidget and ConsumerStatefulWidget
classes that watch providers and rebuild on changes.

Calculation providers shall be memoized and invalidated only when
upstream dependencies change. Long-running calculations (e.g., pressure
loss across all circuits) shall run in Dart isolates to prevent UI frame
drops.

5.3 Canvas Rendering Architecture

The floor plan editor shall use a coordinate system where 1 logical unit
= 1 millimetre. A transformation matrix handles conversion to screen
coordinates based on current zoom and pan state. The rendering pipeline:

-   Background grid layer (rendered once, cached as image)

-   Wall geometry layer (updated on geometry changes)

-   Window/door layer (rendered as symbols on walls)

-   Heating zone layer (with tube pattern preview)

-   Pipe routing layer (supply and return lines)

-   Annotation layer (dimensions, labels, temperatures)

-   Interaction layer (selection handles, hover highlights, cursor
    feedback)

Each layer shall be independently cacheable using RepaintBoundary
widgets. The system shall maintain 60fps on desktop and 30fps minimum on
tablets during interaction.

5.4 Data Persistence

5.4.1 Two-Tier Persistence Model

The application uses two distinct persistence layers. Understanding both
is essential for any implementation involving data mutation.

**Tier 1 — SQLite / Drift (always-on, immediate)**

Every write operation — drawing a wall, adjusting tube spacing, editing
a material layer, changing a room temperature — is committed to the
local SQLite database the moment the repository call returns. There is
no write buffer and no deferred flush. This means:

-   The app never loses project data due to a crash, power failure, or
    force-quit. The SQLite database always reflects the most recent
    committed state.

-   When the app relaunches after any kind of interruption, all project
    data is immediately available through the reactive Drift stream
    providers.

-   No repository method may buffer or batch mutations — every DAO
    insert, update, or delete is an independent transaction.

Tier 1 is the authoritative source of truth. "Saving" in the
traditional sense is not required for data safety.

**Tier 2 — .hsp Portable File (manual + debounced auto-export)**

The .hsp (Heating System Project) file is a gzip-compressed JSON
snapshot of the full project. It exists for portability — sharing a
project between devices, sending to a colleague, or creating a backup
outside the app's SQLite database.

The .hsp file is not the source of truth during editing. It is a
point-in-time export. The "Save" (Ctrl/Cmd+S) and "Save As"
(Ctrl/Cmd+Shift+S) actions both write this file.

5.4.2 Dirty State Tracking

The application tracks whether the in-database project state has
diverged from the last .hsp export. This is called the "dirty state".
It is distinct from "unsaved data" — all data is always safe in SQLite.

A SaveState value object with the following fields is maintained at
runtime:

-   isDirty (bool): true when in-database changes have not yet been
    reflected in the .hsp file.

-   lastExportedAt (DateTime?): null if the project has never been
    exported to a file.

-   lastExportPath (String?): filesystem path of the last .hsp write;
    null if never exported.

-   isAutoExporting (bool): true while a background .hsp write is in
    progress.

isDirty is set to true on every successful repository write. It is
cleared to false when an .hsp export completes successfully.

5.4.3 Auto-Export (Debounced)

When a project has an established .hsp file path (lastExportPath ≠
null), the application schedules a debounced auto-export:

-   Debounce window: 3 seconds after the last data mutation.

-   On fire: write the current SQLite state to the same .hsp path in
    the background, without blocking the UI.

-   On success: clear isDirty, update lastExportedAt.

-   On failure (disk full, permission error): log the error, retain
    isDirty = true, and show a persistent but non-blocking warning in
    the status bar.

If the project has never been exported (new project, or opened directly
from the database), the debounced auto-export does not fire. The user
must trigger "Save As" once to establish a file path. After that,
auto-export activates automatically for all subsequent changes.

5.4.4 Session Continuity (No File Required)

The application does not require the user to ever interact with the file
system in order to preserve their work. On every launch, the app reads
the last-opened project ID from application preferences and reopens that
project directly from SQLite — no file dialog, no loading screen.

Application preferences persisted across launches:

-   lastOpenedProjectId: UUID of the project to reopen on next launch.

-   lastOpenedFloorId: which floor was active.

-   canvasZoom, canvasPanX, canvasPanY: canvas view state per project.

Startup behaviour:

1.  If lastOpenedProjectId is set and the project exists in SQLite:
    open the Editor Screen directly, restoring the previous canvas
    view. Skip the Project List Screen.

2.  If the project no longer exists or this is the first launch: show
    the Project List Screen.

Session restore is seamless and requires no user interaction.

5.4.5 Save State User Interface

A compact save state indicator is shown in the status bar and reflected
in the window title (desktop only):

-   No indicator: project has never been exported to .hsp (data is
    fully safe in the database; nothing to warn about).

-   Amber dot (●): in-database changes are not yet reflected in the
    .hsp file. Tooltip: "File export out of date — press Ctrl+S to
    update".

-   Spinning indicator + "Saving…": auto-export is in progress.

-   "✓ Saved" (2-second flash): confirms a manual save completed.

-   Amber warning icon: auto-export failed; non-blocking error shown
    in status bar.

The window title on desktop follows the convention:
"{ProjectName} — HeatingPlanner" (clean) or
"{ProjectName} ● — HeatingPlanner" (.hsp out of date).

5.4.6 Window Close Behaviour

On desktop, closing the window while isDirty = true and
lastExportPath ≠ null triggers a confirmation dialog:

  "Unsaved export file"
  "{ProjectName}" has changes not yet written to the .hsp export file.
  Your project is safely stored in the app — this only affects the
  portable file.

  [ Save File and Quit ]   [ Quit Anyway ]   [ Cancel ]

"Save File and Quit" exports the .hsp then closes. "Quit Anyway"
closes without exporting — all project data remains safe in SQLite.
"Cancel" returns to the app.

If the project has never been exported (no file path), the app closes
immediately without any dialog.

On tablet (iOS/Android), when the app moves to the background, an
immediate .hsp export is triggered (if a path is set) without prompting
the user.

Projects are stored in a local SQLite database managed by the Drift ORM.
The schema includes tables for: projects, floors, rooms, wall_segments,
windows, doors, wall_constructions, material_layers, heating_zones,
tube_types, distributors, heating_circuits, and material_database.

5.5 Performance Requirements

  ------------------------------------------------------------------------
  **Operation**             **Target        **Notes**
                            Latency**       
  ------------------------- --------------- ------------------------------
  U-value recalculation     \< 5ms          Per wall assembly

  Room heat demand update   \< 20ms         Per room, all elements

  Full building heat demand \< 100ms        Up to 50 rooms

  Heat output per zone      \< 10ms         Per zone

  Pressure loss per circuit \< 50ms         Per circuit, Darcy-Weisbach

  Full system hydraulic     \< 200ms        Up to 12 circuits
  balance                                   

  Canvas redraw (pan/zoom)  \< 16ms         60fps target

  SQLite write (any         \< 10ms         Per DAO transaction (wall,
  mutation)                                 zone, parameter change, etc.)

  .hsp export (manual       \< 500ms        Typical residential project
  save)                                     (background; does not block UI)

  .hsp auto-export          \< 500ms        Fires 3 s after last change;
  (debounced)                               background; status bar feedback

  Project load from SQLite  \< 200ms        Direct DB query; no file I/O

  .hsp import               \< 1000ms       Full parse + DB insert
  ------------------------------------------------------------------------

5.6 Project File Architecture

The .hsp project file format is a gzipped JSON archive with the
following top-level structure:

{ \"version\": \"1.0\",

\"project\": { \... },

\"floors\": \[ \... \],

\"materialDatabase\": \[ \... \],

\"heatingSystem\": { \... },

\"calculationCache\": { \... }

}

The file format shall include schema versioning with forward-compatible
migration support. Unknown fields shall be preserved on save to support
cross-version compatibility.

6\. Platform-Specific Requirements

6.1 Desktop Platforms (macOS, Linux, Windows)

-   Minimum window size: 1024×768 pixels

-   Native file dialogs for save/open/export via file_picker

-   Keyboard shortcuts for all primary operations (Ctrl/Cmd+S save to
    existing .hsp file, Ctrl/Cmd+Shift+S Save As to new file,
    Ctrl/Cmd+Z undo, etc.)

-   Mouse hover states for all interactive elements

-   Right-click context menus for elements

-   Multi-monitor support with proper scaling

-   Desktop menu bar integration (File, Edit, View, Tools, Help)

6.2 Tablet Platforms (iPad, Android Tablets)

-   Minimum supported screen: 10-inch tablet (2048×1536 or equivalent)

-   Touch-optimized hit areas: minimum 44pt for all interactive targets

-   Gesture support: pinch zoom, two-finger pan, long-press for context
    actions

-   On-screen floating toolbar repositionable by the user

-   Stylus support for precision drawing on iPad (Apple Pencil) and
    Android

-   Split-view support on iPad for referencing documentation alongside
    the app

-   Adaptive layout switching at 600dp width breakpoint

6.3 Platform File System Considerations

  -----------------------------------------------------------------------------------
  **Platform**   **Default Save Location**         **Library/Notes**
  -------------- --------------------------------- ----------------------------------
  macOS          \~/Documents/HeatingPlanner/      path_provider
                                                   getApplicationDocumentsDirectory

  Linux          \~/.local/share/HeatingPlanner/   XDG compliant

  Windows        Documents\\HeatingPlanner\\       path_provider
                                                   getApplicationDocumentsDirectory

  iOS (iPad)     App sandbox / Files app via       Share sheet for export
                 UIDocument                        

  Android        App-specific external storage     Scoped storage (API 30+)
  -----------------------------------------------------------------------------------

7\. Validation Rules & Constraints

7.1 Geometric Validation

-   All rooms must form closed, non-self-intersecting polygons

-   Wall segments must have non-zero length (minimum 100mm)

-   Windows and doors must fit entirely within their host wall segment

-   Window sill height + window height must not exceed wall height

-   Heating zones must be entirely contained within their parent room
    polygon

-   Heating zones within the same room must not overlap

-   Distributor must be placed in a valid location (not inside a wall)

7.2 Hydraulic Validation

-   Every heating zone must be connected to exactly one circuit

-   Every circuit must have both supply and return routes

-   Supply and return routes must form a continuous path from
    distributor to zone and back

-   Circuit tube length must not exceed maximum recommended length for
    the tube diameter

-   Flow velocity must be within 0.2-0.5 m/s for noise-free operation

-   Total system flow rate must not exceed distributor pump capacity

7.3 Thermal Validation

-   Surface temperatures must not exceed EN 1264 limits (29°C occupied,
    35°C peripheral, 33°C bathroom)

-   Heat output per room must meet or exceed calculated heat demand

-   Supply temperature must be higher than return temperature

-   Return temperature must be higher than room target temperature

-   Wall constructions must have at least one material layer

-   All material thermal conductivity values must be positive

7.4 Warning Severity Levels

  -----------------------------------------------------------------------------
  **Level**   **Colour**   **Meaning**               **Example**
  ----------- ------------ ------------------------- --------------------------
  Error       Red          System cannot function;   Disconnected circuit, no
                           must be resolved          supply route

  Warning     Amber        System will underperform; Heat output \< demand,
                           should be resolved        velocity too high

  Info        Blue         Advisory for optimisation Circuit imbalance \> 20%,
                                                     long tube run
  -----------------------------------------------------------------------------

8\. Implementation Sequence

The application shall be developed in phases aligned with the user
workflow. Each phase builds on the previous and is independently
testable.

  ---------------------------------------------------------------------------------
  **Phase**   **Scope**                     **Dependencies**   **Estimated Effort**
  ----------- ----------------------------- ------------------ --------------------
  1           Project scaffolding, data     None               2-3 weeks
              models, SQLite persistence,                      
              material database                                

  2           Floor plan canvas: grid, wall Phase 1            3-4 weeks
              drawing, room detection,                         
              window/door placement                            

  3           Wall construction editor,     Phase 2            2-3 weeks
              U-value engine, heat demand                      
              calculator                                       

  4           Heating zone placement, tube  Phase 3            3-4 weeks
              pattern generation,                              
              distributor placement                            

  5           Circuit routing, pressure     Phase 4            2-3 weeks
              loss engine, hydraulic                           
              balancing                                        

  6           Performance dashboard, heat   Phase 5            2 weeks
              maps, reporting, PDF export                      

  7           Platform-specific polish,     Phase 6            2 weeks
              tablet optimization,                             
              performance tuning                               

  8           Integration testing, user     Phase 7            2 weeks
              acceptance testing,                              
              documentation                                    
  ---------------------------------------------------------------------------------

8.1 Key Package Dependencies

  -------------------------------------------------------------------------
  **Package**             **Version**   **Purpose**
  ----------------------- ------------- -----------------------------------
  flutter_riverpod        \^2.5.0       State management

  freezed /               \^2.5.0       Immutable model generation
  freezed_annotation                    

  json_serializable       \^6.8.0       JSON serialization

  drift                   \^2.18.0      SQLite ORM

  sqlite3_flutter_libs    \^0.5.0       Native SQLite bindings

  fl_chart                \^0.68.0      Charts and graphs

  path_provider           \^2.1.0       Platform file paths

  file_picker             \^8.0.0       Native file dialogs

  pdf                     \^3.11.0      PDF generation

  vector_math             \^2.1.0       Geometry calculations

  uuid                    \^4.4.0       Unique identifier generation

  archive                 \^3.6.0       Project file compression
  -------------------------------------------------------------------------

9\. Acceptance Criteria Summary

The following high-level acceptance criteria define the minimum viable
product:

  --------------------------------------------------------------------------
  **ID**   **Feature**      **Acceptance Criteria**
  -------- ---------------- ------------------------------------------------
  AC-01    Floor Plan       User can draw multi-room floor plans with walls,
           Drawing          windows, doors. Rooms auto-detect from closed
                            polygons. Shared walls link correctly.

  AC-02    Wall             User can define multi-layer wall assemblies.
           Construction     U-values compute correctly per EN ISO 6946
                            within 0.001 W/m²K.

  AC-03    Heat Demand      Per-room heat demand matches EN 12831 manual
                            calculation within 2%. Includes transmission and
                            ventilation losses.

  AC-04    Heating Zones    User can place floor/wall heating zones with
                            configurable spacing and pattern. Zones respect
                            room boundaries.

  AC-05    Heat Output      Specific heat output per zone calculated per EN
                            1264. Surface temperature limits enforced with
                            warnings.

  AC-06    Hydraulic        Circuits connect zones to distributor. Tube
           Routing          lengths calculated. Incomplete circuits flagged.

  AC-07    Pressure Loss    Darcy-Weisbach calculation within 5% of
                            reference tools. Hydraulic balancing computed
                            across all circuits.

  AC-08    Real-time        All calculations update within 200ms of
           Updates          parameter change. No UI blocking during
                            computation.

  AC-09    Cross-Platform   Application runs on macOS, Linux, Windows, iPad,
                            Android with platform-appropriate interactions.

  AC-10    Persistence      All project data persists immediately to
                            SQLite on every user action — no data is
                            ever lost due to a crash or force-quit.
                            On next launch, the app reopens the last
                            session automatically from SQLite without
                            requiring any file interaction. Manual save
                            (Ctrl/Cmd+S) and auto-export (3 s debounce)
                            write portable .hsp files for sharing.
                            The dirty-state indicator (● in status bar
                            and title bar) and close-window confirmation
                            dialog communicate .hsp file status to the
                            user without implying data risk.
  --------------------------------------------------------------------------

*--- End of Document ---*
