# HeatingPlanner — User Manual

A short guide to planning a floor or wall heating system end-to-end:
from drawing the first wall to reading the final hydraulic balance.

> Screenshots referenced as `docs/screenshots/<name>.png` are placeholders.
> Drop matching screenshots into that folder; the filenames already match
> what each section describes.

---

## 1. Getting Started

When the app opens, you land on the **Project List** — a grid of all your
saved projects.

![Project list screen](screenshots/01-project-list.png)

- **Open** an existing project by tapping its card.
- **+ New Project** opens a small dialog where you give the project a name,
  a design outdoor temperature (default −12 °C), and a default indoor
  temperature (20 °C). Confirm to enter the editor.
- **Right-click / long-press** a card for Duplicate, Export, or Delete.

The app remembers your last project and re-opens it directly on the next
launch, so you usually skip this screen after the first visit.

---

## 2. The Editor at a Glance

```
┌──────────────────────────────────────────────────────────────┐
│  File   Edit   View   Tools   Help          (menu bar)        │
├─────┬───────────────────────────────────────┬─────────────────┤
│  ↖  │                                         │ Properties      │
│  ▭  │                                         │                 │
│  ⊡  │                                         │ ┌─────────────┐ │
│  ⬡  │            C A N V A S                  │ │ (contextual)│ │
│  ⊕  │                                         │ │             │ │
│  ╌  │      (your floor plan goes here)        │ └─────────────┘ │
│ ─── │                                         │                 │
│  📊 │                                         │                 │
├─────┴───────────────────────────────────────┴─────────────────┤
│  Zoom: 100%  │  x: 2500, y: 1800  │  ⚠ 0  │ Saved │ 5 rooms │
└──────────────────────────────────────────────────────────────┘
   ↑                  ↑                ↑       ↑         ↑
 toolbar           canvas         warnings   save     room count
                                              state
```

![Editor overview](screenshots/02-editor-overview.png)

**Toolbar (left).** Vertical icon strip of drawing tools. Top to bottom:
Select • Wall • Window • Door • Heating Zone • Distributor • Route Pipe •
Measure. Below a separator: the Performance Dashboard toggle.

**Canvas (centre).** Your 2D floor plan. Pan with middle-mouse-drag (or
Space + left-drag); zoom with the scroll wheel or `Ctrl/Cmd +` / `−`. On
tablet: two-finger pan, pinch zoom.

**Properties Panel (right, 280 px).** Always shows whatever you have
selected. With nothing selected it shows a project summary (total area,
total heat demand, warning counts). Selecting a wall shows the wall;
selecting a room shows the room; and so on. Collapsible with the toggle on
its left edge.

**Status Bar (bottom).** Zoom percentage, cursor position in mm, warning
badge, save state, room count.

---

## 3. Drawing Rooms

Pick the **Wall tool** (`W`). The cursor becomes a crosshair.

![Wall tool — single wall](screenshots/03-wall-single.png)

### Single-wall mode (default)

1. Click point A → a ghost line follows the cursor with a live length label.
2. Click point B to commit. The tool stays active for the next wall.
3. Points snap to the grid (configurable in **Settings → Drawing grid
   size**, default 100 mm).
4. When walls close a loop, the **New room detected** dialog appears.
   Give the room a name and a temperature preset, confirm — the room is
   created.

### Modifier keys while drawing

| Hold | Effect |
|------|--------|
| **Shift** | Constrain to horizontal/vertical only — a dashed guideline shows the locked axis. |
| **Ctrl** | **Rectangle mode** — drag from corner to corner to place four walls at once. The room is detected immediately on release. |
| **Alt** | Free placement — disables grid snap for this point. |

![Rectangle mode preview](screenshots/04-wall-ctrl-rect.png)

Rectangle mode is the fastest way to lay out rectangular rooms; it also
auto-detects shared walls with neighbouring rooms and corner-snaps to
existing endpoints, so a second room placed next to the first lines up
exactly.

### Editing a room after drawing

Select a wall with the **Select tool** (`V`). Three handles appear:
**start • mid • end**.

![Wall handles](screenshots/05-wall-handles.png)

- **Drag the mid handle** to move the whole wall (connected walls follow).
- **Drag an endpoint handle** to move just that corner; the two walls
  meeting at the corner adjust their angles to stay connected.
- **Hold Ctrl while dragging an endpoint** of a rectangular room — the
  whole rectangle reshapes around the diagonally opposite corner.
  (Shift has no effect on corner drag, intentionally.)
- **Right-click an endpoint handle** to disconnect that corner. If the
  wall belonged to a closed room, the room is destroyed (undoable).

To delete a wall or room: select it and press **Delete**. Rooms ask for
confirmation; walls do not.

---

## 4. Adding Windows and Doors

Pick the **Window tool** (`N`) or **Door tool** (`D`). Hover over a wall —
the wall highlights.

![Window placement](screenshots/06-window-placement.png)

1. Click on the wall to place a preview at that position.
2. Drag along the wall to adjust position (offset from wall start is
   shown live).
3. Release to commit. The Properties Panel opens with width, height, sill
   height, and U-value fields.

If the element does not fit (extends past wall end), the system clamps it
to the nearest valid position. Defaults: window 1200 × 1400 mm, sill 900 mm;
door 900 × 2100 mm, sill 0.

---

## 5. Defining the Building Envelope

For accurate heat demand each wall, the floor, and the ceiling need a
**construction** — a stack of material layers with their λ values.

### Wall construction editor

Double-click a wall, or select it and press **Edit Construction** in the
Properties Panel.

![Wall construction editor](screenshots/07-wall-construction-editor.png)

```
┌──────────────────────────────────────────────────────┐
│  Wall: Exterior South                  [Save] [✕]    │
│              [⬆ Save as preset] [⬇ Load ▾]          │
├──────────────────────────────────────────────────────┤
│  U-Value: 0.283 W/(m²K)     R: 3.534 m²K/W           │
│                                                       │
│  Layer Stack (outside → inside)                       │
│  ⠿ [Cement render    ] [15 mm ] [λ 1.00]  [🗑]      │
│  ⠿ [EPS insulation   ] [100 mm] [λ 0.035] [🗑]      │
│  ⠿ [Hollow brick     ] [200 mm] [λ 0.44 ] [🗑]      │
│  ⠿ [Gypsum plaster   ] [15 mm ] [λ 0.40 ] [🗑]      │
│                                                       │
│              [+ Add Layer]                            │
│                                                       │
│  Temperature Profile                                  │
│  20.0°C ████████████████░░ -12.0°C                   │
│                                                       │
│  Rsi [0.13] m²K/W   Rse [0.04]                       │
└──────────────────────────────────────────────────────┘
```

- **Add Layer**, drag (⠿) to reorder, 🗑 to remove.
- **Material name** is a searchable dropdown — type to filter, grouped by
  category (Masonry, Insulation, etc.).
- **Thickness** and **λ** can be edited inline; the U-value, R-value, and
  temperature profile update in real time. No "Apply" button.
- **Inhomogeneous layers** (e.g. timber-stud insulation): tap **⊕** on a
  layer row to add a parallel stud sub-row with stud width and clear gap.
- **Save as preset / Load** lets you reuse common constructions across
  walls and projects.

### Floor and ceiling

With a room selected, expand **Envelope — Floor & Ceiling** in the
Properties Panel.

![Floor and ceiling section](screenshots/08-envelope-section.png)

For each surface you pick a **boundary condition** (Ground / Exterior roof
/ Unheated attic / Unheated basement / Unheated crawlspace / Adjacent
heated room) and assign a construction with the same editor as walls. The
**correction factor** is pre-filled by boundary type (Ground 0.60, Exterior
1.00, etc.) and adjustable for unheated spaces.

Until floor and ceiling constructions are assigned, the room's total heat
demand shows "—" with a tooltip explaining why.

---

## 6. Designing the Heating System

### 6.1 Drawing a heating zone

Pick the **Heating Zone tool** (`H`). Click vertices inside a room to
outline the zone, then click near the first vertex (or double-click) to
close it.

![Heating zone with tube preview](screenshots/09-heating-zone.png)

The zone fills with a colour that reflects its **adequacy**:

| Colour | Meaning |
|--------|---------|
| 🔴 hatched | Zone exists but is not connected to a distributor |
| ⚪ grey | Missing data — wall/floor/ceiling construction not yet set |
| 🔴 solid | Heat output below 90 % of demand |
| 🟡 yellow | Output 90–99 % of demand |
| 🟢 green | Output ≥ 100 % of demand |

The Properties Panel for the zone exposes the levers that change output:
**tube spacing** (50–400 mm), **tube type**, **flooring material**, **layout
pattern** (meander / spiral / bifilar / counterflow), **border distance**.
The preview lines inside the zone update live as you change these.

Zones may span into an adjacent room through a doorway when the two share a
door-connected wall — useful for open-plan areas.

### 6.2 Placing the distributor

Pick the **Distributor tool** (`G`). Click anywhere on the floor — one
distributor per floor is allowed.

![Distributor placed and selected](screenshots/10-distributor.png)

Set **supply temperature** (20–55 °C) and **return temperature** in the
Properties Panel. **Required pump head** is computed for you once circuits
are connected; an optional **pump capacity** field lets you record an
existing pump's rating and get a warning if it's undersized.

### 6.3 Routing pipes

Pick the **Route Pipe tool** (`R`).

![Pipe routing supply and return](screenshots/11-pipe-routing.png)

1. Click the distributor to start at a free port.
2. Click waypoints — the supply line is drawn in red.
3. Click a heating zone to finish the supply leg. The tool flips
   automatically to **return mode** (blue).
4. Click waypoints back to the distributor and click the distributor to
   close the circuit.

Cumulative pipe length is shown in the status bar during routing. Press
**Escape** to cancel a half-drawn route.

Each circuit lets you pick a **supply pipe insulation type**:

- **None** — uninsulated, embedded in screed; pipe contributes full heat
  to the transit room.
- **Corrugated conduit** — ~25–30 % residual heat to the transit room.
- **Insulation layer** — pipe runs in the insulation below the screed;
  zero heat to the transit room. The routing is geometrically free
  (diagonals are allowed and preferred).

---

## 7. Reading the Results

Toggle the **Performance Dashboard** with the chart icon at the bottom of
the toolbar (or from the View menu). Three tabs.

![Heat balance tab](screenshots/12-dashboard-heat.png)

**Heat Balance** — per-room demand vs output bar chart. Outlined bar =
demand, filled bar = output. The fill colour matches the zone-adequacy
scale (green / yellow / red). Any deficit is annotated.

![Hydraulic tab](screenshots/13-dashboard-hydraulic.png)

**Hydraulic** — pressure loss per circuit. The longest-loss circuit is the
**reference circuit** (fully filled); other circuits show the difference
they need to throttle away at the distributor valve. A pie below shows the
flow-rate distribution between circuits.

![Warnings tab](screenshots/14-dashboard-warnings.png)

**Warnings** — every validation issue in one list, sorted by severity
(errors first). Hovering over a warning highlights the offending element
on the canvas; clicking it selects the element so you can fix it in the
Properties Panel.

### What to look for

- All zones **green** in the heat-balance view — every room's demand is
  met.
- All zone colours **non-grey** — no rooms with missing constructions.
- **Warnings tab empty** of errors (yellow info-level warnings are
  usually fine).
- **Surface temperature** in each zone's properties below the limits
  (29 °C living spaces, 33 °C bathrooms, 35 °C border zones).
- **Pressure loss spread** in the hydraulic view not too wide — if one
  circuit is 5× another, consider splitting it.
- **Required pump head** smaller than your pump's capacity.

---

## 8. Saving, Exporting, and Sharing

Your project is **always safe in the app** — every change is written to
the internal database immediately. The save indicator on the status bar
only refers to the portable `.hsp` export file:

| Indicator | Meaning |
|-----------|---------|
| (nothing) | Project has no `.hsp` file yet. |
| ✓ Saved | `.hsp` file is up to date. |
| ● (amber dot) | `.hsp` is out of date — press `Ctrl/Cmd + S` to update. |
| ⟳ Saving… | Auto-export running. |
| ⚠ | Auto-export failed — check disk space / permissions. |

- **Ctrl/Cmd + S** — save to existing `.hsp` (or prompt for path the first
  time).
- **Ctrl/Cmd + Shift + S** — Save As to a new `.hsp` file.
- **File → Export** — PDF report (cover, floor-plan image, heat-demand
  table, wall constructions, circuit summary, hydraulic chart, warnings)
  or CSV (heat demand, circuits, materials).

Closing the window with an out-of-date `.hsp` prompts you with three
options: **Save File and Quit**, **Quit Anyway** (data is still safe in
the app), or **Cancel**.

---

## 9. Keyboard Shortcuts Cheat Sheet

| Shortcut | Action |
|----------|--------|
| `V` | Select tool |
| `W` | Wall tool |
| `N` | Window tool |
| `D` | Door tool |
| `H` | Heating zone tool |
| `G` | Distributor tool |
| `R` | Route pipe tool |
| `M` | Measure tool |
| `Shift` (Wall tool) | Constrain to 0° / 90° |
| `Ctrl` (Wall tool) | Rectangle mode |
| `Ctrl` (corner drag) | Rectangle reshape |
| `Alt` (Wall tool) | Free placement (no grid snap) |
| `Delete` | Delete selected |
| `Esc` | Cancel current tool action / deselect |
| `Ctrl/Cmd + Z` / `Shift+Z` | Undo / Redo |
| `Ctrl/Cmd + S` / `Shift+S` | Save / Save As |
| `Ctrl/Cmd + =` / `−` / `0` | Zoom in / out / fit |
| `Space + drag` | Pan canvas |

---

## 10. A Recommended Workflow

1. **Sketch the shell.** Wall tool → Ctrl-drag rectangles for each room.
   Adjust corners with Ctrl + endpoint drag if needed.
2. **Add openings.** Window and Door tools — place them on the right
   walls and tune sill height / U-value.
3. **Define constructions.** Pick one wall of each type (exterior, party,
   interior), assign its layer stack, save as preset, then apply the
   preset to similar walls. Do the same for floor and ceiling.
4. **Set room temperatures.** Select each room, adjust target temp and
   air-change rate.
5. **Draw heating zones.** One zone per room (or one zone spanning a few
   open-plan rooms). Choose layout pattern and tube spacing.
6. **Place the distributor.** Set supply / return temperatures (a typical
   starting point is 35 °C / 28 °C).
7. **Route the circuits.** Connect each zone back to the distributor.
   Pick the right insulation type per circuit.
8. **Open the dashboard.** Look for grey or red zones first — fix
   missing constructions and undersized zones. Then check pressure-loss
   spread on the Hydraulic tab. Resolve warnings.
9. **Export.** PDF report for documentation; CSV for downstream tools.

---

# Appendix A — How the Calculations Work

Every number in the dashboard comes from one of four pure calculation
engines. Nothing is fudged — the formulas below are exactly what the program
evaluates. All standards references are EN ISO 6946 (U-values), EN 12831
(heat load), EN 1264 (floor heating output), and the Darcy–Weisbach /
Swamee–Jain hydraulic model.

> **Units convention:** every stored number carries its unit in the field
> name (`Mm`, `M`, `C`, `Pa`, `KgH`, `WPerM2K`). The engines convert mm → m
> internally; you always enter geometry in mm.

## A.1 Physical constants

These are fixed values used throughout. Water properties are taken at 40 °C
(typical floor-heating mean temperature).

| Constant | Symbol | Value | Unit |
|----------|--------|-------|------|
| Air density | ρ_air | 1.2 | kg/m³ |
| Air specific heat | c_air | 1005 | J/(kg·K) |
| Water density (40 °C) | ρ_w | 992.2 | kg/m³ |
| Water specific heat | c_w | 4186 | J/(kg·K) |
| Water dynamic viscosity (40 °C) | μ_w | 6.53 × 10⁻⁴ | Pa·s |
| Water kinematic viscosity (40 °C) | ν_w | 6.58 × 10⁻⁷ | m²/s |
| Stefan–Boltzmann | σ | 5.67 × 10⁻⁸ | W/(m²·K⁴) |
| Gravity | g | 9.81 | m/s² |

**Surface resistances** (EN ISO 6946 Table 1), used in the U-value formula:

| Surface | Symbol | Value | Used for |
|---------|--------|-------|----------|
| Interior, horizontal heat flow | Rsi | 0.13 | walls |
| Interior, upward heat flow | Rsi | 0.10 | ceilings/floors heated from below |
| Interior, downward heat flow | Rsi | 0.17 | floors |
| Exterior | Rse | 0.04 | element facing outside air |
| Interior partition face | Rse | 0.13 | wall between two rooms |
| Ground correction factor | f | 0.60 | slab-on-grade (simplified — ISO 13370 is more exact) |

## A.2 Thermal resistance and U-value (the "R-value")

A wall is a stack of layers. Each layer's resistance is its thickness
divided by its thermal conductivity λ. The total resistance adds the inside
and outside surface resistances:

$$R_\text{total} = R_{si} + \sum_i \frac{d_i}{\lambda_i} + R_{se} \quad \left[\mathrm{m^2K/W}\right]$$

$$U = \frac{1}{R_\text{total}} \quad \left[\mathrm{W/(m^2K)}\right]$$

- `d_i` = layer thickness in **metres** (the editor's mm value ÷ 1000)
- `λ_i` = layer conductivity from the material database (W/(m·K))

**Worked example** (the editor's default exterior wall, case UV-2):

| Layer | d (mm) | λ | d/λ (m²K/W) |
|-------|--------|------|-------------|
| Cement render | 15 | 1.00 | 0.0150 |
| EPS insulation | 100 | 0.035 | 2.8571 |
| Hollow brick | 200 | 0.44 | 0.4545 |
| Gypsum plaster | 15 | 0.40 | 0.0375 |

$$
\begin{aligned}
R_\text{total} &= 0.13\,(R_{si}) + 0.0150 + 2.8571 + 0.4545 + 0.0375 + 0.04\,(R_{se}) \\
&= 3.534\ \mathrm{m^2K/W} \\
U &= \frac{1}{3.534} = 0.283\ \mathrm{W/(m^2K)}
\end{aligned}
$$

This is the U-value shown live at the top of the wall construction editor.
The **temperature profile** bar splits the indoor→outdoor temperature drop
in proportion to each layer's share of `R_total` — a layer with more
resistance "absorbs" more of the temperature gradient.

Lower U = better insulation = less heat demand. A modern exterior wall sits
around 0.15–0.30; an uninsulated 1950s brick wall can exceed 1.5.

## A.3 Heat demand per room (EN 12831)

Total demand = transmission loss through the envelope + ventilation loss.

**Transmission loss**, per wall / window / door / slab:

$$Q_T = U \cdot A \cdot f \cdot (T_\text{indoor} - T_\text{outdoor}) \quad [\mathrm{W}]$$

- `A` = net area (wall area minus the openings in it)
- `f` = correction factor:
  - **1.0** for elements facing outside air
  - **0.60** for slab-on-grade (ground)
  - **0.0** when the other side is a room at the same temperature
  - For an **interior wall** to a differently-heated room:
    $f = \dfrac{T_\text{this} - T_\text{adjacent}}{T_\text{this} - T_\text{outdoor}}$.
    If the neighbour is warmer, `f` goes negative — the wall is a heat
    *gain* and reduces this room's demand.

**Ventilation loss** (air exchanged with outside):

$$Q_V = \frac{V \cdot n \cdot \rho_\text{air} \cdot c_\text{air} \cdot (T_\text{indoor} - T_\text{outdoor})}{3600} \quad [\mathrm{W}]$$

- `V` = room volume (m³), `n` = air change rate (1/h, from the room's ACH
  preset: standard 0.5, kitchen 1.0, bathroom 1.5, …)
- The `/3600` converts J/h to W.

**Worked example** (case HD-1: 5 × 4 m room, h = 2.6 m, 20 °C indoor,
−12 °C outdoor, one 5 m exterior wall U = 0.283 with a 1.5 × 1.4 m window
U = 1.3, ACH 0.5):

$$
\begin{aligned}
A_\text{net} &= 5.0\times 2.6 - 1.5\times 1.4 = 10.9\ \mathrm{m^2} \\
Q_{T,\text{wall}} &= 0.283 \times 10.9 \times 1.0 \times 32 = 98.7\ \mathrm{W} \\
Q_{T,\text{window}} &= 1.3 \times 2.1 \times 1.0 \times 32 = 87.4\ \mathrm{W} \\
V_\text{room} &= 5 \times 4 \times 2.6 = 52\ \mathrm{m^3} \\
Q_V &= \frac{52 \times 0.5 \times 1.2 \times 1005 \times 32}{3600} = 277.9\ \mathrm{W} \\
Q_\text{total} &\approx 464\ \mathrm{W}
\end{aligned}
$$

That `Q_total` is the per-room demand bar in the Heat Balance dashboard tab.

## A.4 Heat output of a heating zone (EN 1264)

The driving temperature difference uses the **logarithmic mean**, because
the water cools as it travels the loop:

$$\Delta T = \frac{T_\text{supply} - T_\text{return}}{\ln\!\left(\dfrac{T_\text{supply} - T_\text{room}}{T_\text{return} - T_\text{room}}\right)}$$

(falls back to the arithmetic mean if the denominator is tiny.)

**Specific output** per square metre, then total:

$$q = B \cdot a_B \cdot a_T \cdot a_U \cdot a_D \cdot \Delta T^{\,n} \quad [\mathrm{W/m^2}]$$

$$Q_\text{zone} = q \times A_\text{zone} \quad [\mathrm{W}]$$

| Factor | Meaning | Driven by |
|--------|---------|-----------|
| B | system constant (≈ 6.7, wet screed) | construction type |
| a_B | covering factor | flooring thermal resistance R |
| a_T | spacing factor | tube spacing (closer = higher) |
| a_U | diameter factor | tube outer diameter |
| a_D | tube-wall conductivity factor | pipe material (plastic ≈ 1.0, copper ≈ 1.04) |
| n | exponent | 1.1 for floor heating |

> **Accuracy note:** the a_B / a_T / a_U / a_D factors are simplified
> curve-fits, not the full digitised EN 1264 tables. They are accurate
> enough for design comparison but treat absolute outputs as ±10 %.

**Surface temperature** (comfort/standards limit):

$$T_\text{surface} \approx T_\text{room} + \frac{q}{\alpha_\text{total}} \qquad (\alpha_\text{total} \approx 10.8\ \mathrm{W/(m^2K)})$$

Hard limits enforced as warnings: occupied floor **29 °C**, bathroom
**33 °C**, peripheral/border zone **35 °C**, wall heating **40 °C**.

## A.5 Hydraulics — flow rate and pressure loss

**Tube length in a zone** (meander approximation):

$$L_\text{zone} \approx \frac{A_\text{zone}}{\text{spacing}/1000} \quad [\mathrm{m}]$$

$$L_\text{total} = L_\text{zone} + L_\text{supply} + L_\text{return}$$

**Mass flow rate** — how much water the circuit needs to carry its heat:

$$\dot m = \frac{Q}{c_w \cdot (T_\text{supply} - T_\text{return})} \times 3600 \quad [\mathrm{kg/h}]$$

**Flow velocity** in the pipe:

$$v = \frac{\dot m / 3600}{\rho_w \cdot \pi \,(d_i/2)^2} \quad [\mathrm{m/s}]$$

**Reynolds number** (laminar vs turbulent):

$$Re = \frac{v \cdot d_i}{\nu_w}$$

**Darcy friction factor** $f$:

- **Laminar** ($Re < 2300$):  $f = \dfrac{64}{Re}$
- **Turbulent** ($Re > 5000$) — Swamee–Jain:

$$f = \frac{0.25}{\left[\log_{10}\!\left(\dfrac{\varepsilon}{3.7\,d} + \dfrac{5.74}{Re^{0.9}}\right)\right]^{2}}$$

- **Transition** ($2300 \le Re \le 5000$): linear interpolation between the
  laminar value at $Re = 2300$ and the turbulent value at $Re = 5000$

**Pressure loss** — Darcy–Weisbach, plus a fittings surcharge (default 40 %
of the friction loss for manifold connections, bends, valves):

$$\Delta p_\text{friction} = f \cdot \frac{L}{d_i} \cdot \frac{\rho_w \, v^2}{2} \quad [\mathrm{Pa}]$$

$$\Delta p_\text{total} = \Delta p_\text{friction} + \Delta p_\text{fittings}$$

**Worked example** (case HY-1: PE-Xa 16/13 mm, ε = 0.007 mm, L = 80 m,
Q = 1500 W, 35 → 28 °C):

$$
\begin{aligned}
\dot m &= \frac{1500}{4186 \times 7}\times 3600 = 184\ \mathrm{kg/h} \\
v &= \frac{184/3600}{992.2 \times \pi \times 0.0065^2} = 0.39\ \mathrm{m/s} \\
Re &= \frac{0.39 \times 0.013}{6.58\times10^{-7}} \approx 7700 \quad (\text{turbulent}) \\
f &\approx 0.034 \quad (\text{Swamee–Jain}) \\
\Delta p_\text{friction} &= 0.034 \times \frac{80}{0.013} \times \frac{992.2 \times 0.39^2}{2} \approx 15{,}700\ \mathrm{Pa} \\
\Delta p_\text{fittings} &\approx 6{,}300\ \mathrm{Pa} \quad (40\%) \\
\Delta p_\text{total} &\approx 22{,}000\ \mathrm{Pa} \approx 22\ \mathrm{kPa}
\end{aligned}
$$

**Hydraulic balance:** the circuit with the highest Δp is the *reference
circuit* — its valve stays fully open and it sets the required pump head.
Every other circuit must throttle away the difference at its manifold
valve: $\Delta p_{\text{valve},i} = \Delta p_\text{max} - \Delta p_i$. That throttling amount is what the
Hydraulic dashboard tab plots as the lighter bar segment.

---

# Appendix B — Optimisation Guide

The dashboard tells you *what* is wrong; this tells you *which knob* to
turn. Work in this order.

### 1. Make every zone green (output ≥ demand)

If a zone is red/yellow, raise output $q = B\cdot a_B\cdot a_T\cdot a_U\cdot a_D\cdot \Delta T^{\,n}$:

| Lever | Effect | Cost / trade-off |
|-------|--------|------------------|
| **Reduce tube spacing** (e.g. 150 → 100 mm) | Higher a_T, more output, more even floor | More pipe → higher Δp & cost |
| **Raise supply temperature** | Larger ΔT → strong output gain | Worse heat-pump COP; watch surface-temp limit |
| **Lower flooring resistance** | Higher a_B | Tile (R≈0.02) vs thick carpet (R≈0.15) is a huge difference |
| **Enlarge the zone** | More m² of emitting area | Needs floor space |
| **Reduce the demand instead** | Better wall U-value, better windows | Renovation cost, but permanent |

Lowering flooring R and reducing spacing are usually the cheapest wins.
Raising supply temperature is the last resort — it hurts efficiency and
pushes you toward the surface-temperature limits.

### 2. Respect the surface-temperature ceiling

If `T_surface` warns (29 °C occupied / 33 °C bath / 35 °C border), you
*cannot* simply keep raising supply temperature. Instead lower spacing and
lower supply temperature together: same output, lower, safer surface temp.
Border/edge zones may run hotter (35 °C) so concentrate high output near
external walls and windows.

### 3. Keep flow velocity in the 0.2 – 0.5 m/s band

- `v < 0.2 m/s` → warning "insufficient turbulence": flow may go laminar,
  heat transfer drops, air can't be flushed. Fix: shorter/fewer parallel
  loops, or smaller inner diameter.
- `v > 0.5 m/s` → warning "noise risk": audible flow. Fix: split the zone
  into more circuits, larger inner diameter, or lower spacing (lower flow
  per loop).

### 4. Watch circuit length limits

- Outer Ø ≤ 14 mm → keep loops **≤ 90 m**
- Outer Ø > 14 mm → keep loops **≤ 120 m**

Over the limit → split the zone into two circuits. Long loops also blow up
Δp (it scales with L), which forces a bigger pump.

### 5. Balance the manifold

Open the **Hydraulic** tab. Aim for circuits of *similar* Δp:

- A circuit far below the reference wastes most of its pressure as valve
  throttling — inefficient and noisy at the valve.
- If one circuit dominates (e.g. 5× the others), shorten it or split it so
  the reference Δp drops; the **required pump head** falls with it, letting
  you pick a smaller/cheaper pump (and check it against the optional *pump
  capacity* field — a warning fires if your pump is undersized).

### 6. Lower the supply temperature as the final pass

Once every zone is green with margin, try lowering the supply temperature a
few degrees and re-check. A lower supply temperature:

- improves a heat pump's COP substantially (roughly 2–3 % per °C),
- reduces surface-temperature risk,
- reduces standby/pipe losses.

Keep lowering until a zone just starts to go yellow, then step back one
notch. That is the efficient design point.

### Quick diagnostic map

| Symptom in dashboard | Most likely cause | First fix |
|----------------------|-------------------|-----------|
| Zone grey | Missing wall/floor/ceiling construction | Assign constructions |
| Zone red, hatched | Circuit not routed to distributor | Route the pipe |
| Zone red/yellow solid | Output < demand | Tighter spacing / lower flooring R |
| Surface-temp warning | Supply temp too high for spacing | Lower spacing + lower supply T |
| Velocity warning | Loop too long/short or wrong Ø | Split circuit / change tube |
| One huge pressure-loss bar | Over-long reference circuit | Split that zone |
| Pump-undersized warning | Required head > pump capacity | Reduce reference Δp or bigger pump |
