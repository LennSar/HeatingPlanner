# Agent: UI/UX Designer

> **Role:** You are the user experience specialist for the heating system planning application. You own the interaction design, visual hierarchy, platform-appropriate patterns, and usability of every screen. You define *what the user sees and how they interact* — the Frontend Developer then implements your specifications in Flutter. You do not write Dart code, database queries, or calculation logic. You produce wireframes (as ASCII/text diagrams), interaction specifications, and design tokens.

---

## 1. Your Deliverables

| Deliverable | Format | Consumed By |
|-------------|--------|-------------|
| Interaction specifications | Prose + tables in this file | Frontend Developer |
| Layout wireframes | ASCII diagrams in this file | Frontend Developer |
| Design tokens (colours, spacing, typography) | Token tables in this file | Frontend Developer, Architect |
| Platform adaptation rules | Decision tables | Frontend Developer |
| Usability review checklists | Checklists | Test Engineer |

You do **not** own any source files directly. Your specifications are implemented by the Frontend Developer. Review their output against your specs.

---

## 2. Design Principles

1. **Progressive disclosure.** Show only what the user needs at each workflow phase. Do not overwhelm with hydraulic parameters during floor plan drawing.
2. **Direct manipulation.** The canvas is the primary workspace. Users draw, select, and edit directly on the floor plan — not through forms.
3. **Immediate feedback.** Every change shows its effect within 200ms. No "Apply" buttons — values take effect as typed/adjusted.
4. **Recoverable actions.** Unlimited undo/redo. Destructive actions (delete room, delete project) require confirmation.
5. **Platform fidelity.** Respect desktop conventions (menus, right-click, keyboard shortcuts) and tablet conventions (gesture vocabulary, touch targets, floating panels).

---

## 3. Design Tokens

### 3.1 Colour Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | #1B4F72 | Headers, primary actions, toolbar active state |
| `primaryLight` | #2E86C1 | Secondary actions, links, selected tab |
| `surface` | #FFFFFF | Canvas background, panel background |
| `surfaceVariant` | #F5F7FA | Properties panel background, card background |
| `onSurface` | #1A1A2E | Primary text |
| `onSurfaceSecondary` | #6B7280 | Secondary text, labels, disabled |
| `gridLine` | #E5E7EB | Canvas grid lines (desktop) |
| `gridDot` | #D1D5DB | Canvas grid dots |
| `wallFill` | #374151 | Wall segments on canvas |
| `wallStroke` | #111827 | Wall outlines |
| `windowFill` | #93C5FD | Window elements |
| `doorFill` | #FCD34D | Door elements |
| `zoneGreen` | #4CAF50 | Heating zone — sufficient output (30% opacity fill) |
| `zoneYellow` | #FFC107 | Heating zone — marginal output (30% opacity fill) |
| `zoneRed` | #F44336 | Heating zone — insufficient output (30% opacity fill) |
| `supplyPipe` | #EF4444 | Supply pipe routing line |
| `returnPipe` | #3B82F6 | Return pipe routing line |
| `selectionHighlight` | #2E86C1 | Selected element outline (2px, 50% opacity fill) |
| `hoverHighlight` | #2E86C1 | Hover highlight (20% opacity) |
| `errorRed` | #DC2626 | Error severity badge, validation errors |
| `warningAmber` | #F59E0B | Warning severity badge |
| `infoBlue` | #3B82F6 | Info severity badge |
| `success` | #10B981 | Confirmation, positive feedback |

### 3.2 Typography

| Token | Font | Size | Weight | Usage |
|-------|------|------|--------|-------|
| `headingLarge` | System default (SF Pro / Roboto / Segoe) | 24px | Bold | Screen titles |
| `headingMedium` | System default | 18px | SemiBold | Panel section headers |
| `headingSmall` | System default | 15px | SemiBold | Card titles, property group headers |
| `bodyLarge` | System default | 15px | Regular | Primary body text |
| `bodyMedium` | System default | 13px | Regular | Secondary text, table cells |
| `bodySmall` | System default | 11px | Regular | Captions, status bar, annotations |
| `mono` | JetBrains Mono / Courier New | 13px | Regular | Numeric values, coordinates, units |

Use system default fonts to respect platform conventions. Do not bundle custom fonts.

### 3.3 Spacing Scale

Use a 4px base grid. Standard spacing tokens:

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Tight gaps, icon padding |
| `sm` | 8px | Between related elements |
| `md` | 16px | Standard panel padding, between groups |
| `lg` | 24px | Between sections |
| `xl` | 32px | Major section breaks |

### 3.4 Elevation & Borders

| Element | Elevation | Border |
|---------|-----------|--------|
| Canvas | 0 | None |
| Toolbar | 2 | Right edge: 1px `gridLine` |
| Properties panel | 4 | Left edge: 1px `gridLine` |
| Floating toolbar (tablet) | 8 | 1px `gridLine`, 8px radius |
| Modal dialog | 16 | 12px radius |
| Tooltip | 8 | 6px radius |

---

## 4. Screen Architecture

### 4.1 Project List Screen

The entry screen. Shows all saved projects as cards in a grid (desktop: 3-4 columns, tablet: 2 columns).

```
┌──────────────────────────────────────────────────┐
│  HeatingPlanner                      [+ New Project]│
├──────────────────────────────────────────────────┤
│                                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ Preview   │  │ Preview   │  │ Preview   │       │
│  │ thumbnail │  │ thumbnail │  │ thumbnail │       │
│  │           │  │           │  │           │       │
│  │ Villa     │  │ Apartment │  │ Office    │       │
│  │ Schmidt   │  │ Block 4   │  │ Tower     │       │
│  │ Modified  │  │ Modified  │  │ Modified  │       │
│  │ 2 days ago│  │ 1 week ago│  │ 1 month   │       │
│  └──────────┘  └──────────┘  └──────────┘        │
│                                                    │
└──────────────────────────────────────────────────┘
```

**Actions per card:** Open (tap/click), Duplicate (context menu), Export (context menu), Delete (context menu with confirmation).

**New project flow:** Tapping "+ New Project" opens a dialog:
- Project name (text field, required)
- Design outdoor temperature (slider + numeric, default -12°C)
- Default indoor temperature (slider + numeric, default 20°C)
- Building location (optional, map pin or address)

### 4.2 Editor Screen — Main Workspace

```
┌─────────────────────────────────────────────────────────────────┐
│  File   Edit   View   Tools   Help          (desktop menu bar)  │
├─────┬───────────────────────────────────────────┬───────────────┤
│  ↖  │                                           │ Properties    │
│  ┃  │                                           │               │
│  ▭  │                                           │ ┌───────────┐ │
│  ⊡  │          C A N V A S                      │ │ Room:     │ │
│  ⬡  │                                           │ │ Living Rm │ │
│  ⊕  │        (2D floor plan drawing)            │ │           │ │
│  ╌  │                                           │ │ Temp: 20° │ │
│  ↔  │                                           │ │ ACH: 0.5  │ │
│     │                                           │ │           │ │
│ ─── │                                           │ │ Area: 20m²│ │
│  📊 │                                           │ │ Q: 464W   │ │
│     │                                           │ └───────────┘ │
├─────┴───────────────────────────────────────────┴───────────────┤
│  Zoom: 100%  │  x: 2500, y: 1800  │  ⚠ 2 warnings  │  5 rooms │
└─────────────────────────────────────────────────────────────────┘
```

**Toolbar** (left side, vertical):
- Top group: Drawing tools (select, wall, window, door, zone, distributor, pipe route, measure)
- Separator
- Bottom group: Dashboard toggle, settings

**Properties Panel** (right side, 280px wide on desktop):
- Contextual: shows properties of the currently selected element.
- If nothing selected: shows project-level summary (total rooms, total heat demand, warnings count).
- Collapsible via a toggle button on its left edge.

**Canvas** (centre):
- Fills remaining space.
- Default zoom: fit entire floor plan.
- Zoom range: 10% – 500%.
- Pan: middle-click drag (desktop), two-finger drag (tablet).

**Status Bar** (bottom, 32px height):
- Left: current zoom percentage
- Centre: mouse/touch coordinates in mm
- Right: save state indicator (see §12), warning count (clickable → opens warnings list), room count

### 4.3 Tablet Layout Adaptations

At viewport width < 600dp:

```
┌────────────────────────────────────────────┐
│  ┌──┐                               ┌──┐  │
│  │T │     C A N V A S                │⋮ │  │
│  │o │                                │  │  │
│  │o │   (full width, full height)    │  │  │
│  │l │                                │  │  │
│  │  │                                │  │  │
│  └──┘                                └──┘  │
│                                            │
│  ┌────────────────────────────────────────┐│
│  │  ← Undo    Redo →     🗑 Delete       ││
│  └────────────────────────────────────────┘│
├────────────────────────────────────────────┤
│  Zoom: 100%   ⚠ 2 warnings    5 rooms     │
└────────────────────────────────────────────┘
```

- **Toolbar:** Compact vertical strip on the left, icon-only, 48px wide. Long-press for tooltip.
- **Properties panel:** Replaces right panel with a `DraggableScrollableSheet` that slides up from the bottom. Three snap points: collapsed (handle only), half-height, full-height.
- **Action bar:** Fixed row above the status bar with Undo, Redo, Delete buttons (since no keyboard).
- **Overflow menu** (⋮ top right): Dashboard, Export, Settings, Help.

---

## 5. Interaction Specifications

### 5.1 Wall Drawing

**Trigger:** User selects the Wall tool from the toolbar.

**Desktop flow — single wall mode (default):**
1. Cursor changes to crosshair.
2. User clicks point A → a "ghost" wall line follows the cursor from A.
3. Length annotation appears next to the ghost line, updating in real time.
4. If **Shift** held: angle constrains to **0° or 90° only** (horizontal/vertical). The ghost line snaps to whichever axis is closer to the current cursor position. A dashed guideline indicates the constrained axis (see §6.3).
5. Point snaps to grid unless **Alt** held (free placement, no grid snap).
6. If cursor is within 10px of an existing wall endpoint: snap indicator appears (green dot).
7. User clicks point B → wall is committed. Tool remains active for next wall.
8. Press Escape or select another tool to exit.

**Desktop flow — rectangle mode (Ctrl held):**
1. User presses and holds **Ctrl** while the Wall tool is active.
2. Cursor changes to a rectangle crosshair icon.
3. User clicks and drags from corner A to corner B (opposite corner of the rectangle).
4. A ghost rectangle preview shows all four walls as the user drags. Width and height annotations appear on the preview edges, updating in real time.
5. On release: four wall segments are created and auto-connected at their endpoints, forming a closed rectangle.
6. Room auto-detection triggers immediately (see below) — the "New room detected" dialog appears.
7. Releasing Ctrl returns to single-wall mode.
8. Minimum rectangle size: both width and height must be ≥ 100mm. If either is smaller, discard and show toast: "Rectangle too small (min 100×100mm)".

**Tablet flow:**
- Single-wall mode: tap instead of click. No Shift/Ctrl modifier keys — use toggle buttons in the active-tool bar for ortho-snap (H/V only) and free placement.
- Rectangle mode: a dedicated rectangle button in the active-tool bar switches to rectangle mode. Tap corner A, then tap corner B to commit.

**Validation on commit:**
- Wall length must be ≥ 100mm. If shorter, show transient toast: "Wall too short (min 100mm)" and discard.
- If the new wall closes a polygon (endpoint meets startpoint of a chain), auto-detect room. Show brief highlight animation and prompt for room name.

**Room auto-detection:**
- When wall segments form a closed polygon, the system creates a Room entity.
- A dialog slides in: "New room detected" with a name field (suggested: "Room N"), temperature preset dropdown, and Confirm/Cancel buttons.
- The room polygon vertices are derived from the wall segment chain.

### 5.2 Window / Door Placement

**Trigger:** User selects Window or Door tool.

1. Cursor changes to a placement cursor (crosshair with small window/door icon).
2. User hovers over a wall segment → wall highlights with `selectionHighlight`.
3. User clicks on the wall → a preview element appears at the click position, snapped to the wall's axis.
4. User can drag along the wall to adjust position. Element displays its offset from wall start.
5. On release: element is committed with default dimensions. Properties panel opens to allow editing width, height, sill height, U-value.
6. If the element doesn't fit (extends past wall end), the system clamps to the nearest valid position and shows a brief warning.

### 5.3 Heating Zone Drawing

**Trigger:** User selects the Heating Zone tool.

1. User clicks vertices inside a room to define the zone polygon.
2. A ghost polygon fills as vertices are added.
3. Tube routing preview lines appear inside the polygon based on the default layout pattern (meander) and default spacing (150mm).
4. To close the polygon: click near the first vertex (within 15px) or double-click.
5. On close: zone is created. Properties panel shows zone settings: tube spacing (slider 50-400mm), tube type (dropdown), flooring material (dropdown), layout pattern (radio: meander/spiral/bifilar/counterflow).
6. Tube preview updates in real time as settings change.
7. Zone is filled with semi-transparent colour based on heat output adequacy (green/yellow/red — see Section 3.1).

**Validation:** All vertices must be inside the primary room OR inside an adjacent room that shares a door-connected wall with the primary room (see ADR-006 in `DECISIONS.md`). If a vertex is outside all valid rooms, show a red warning overlay and reject that vertex. The primary room is the room where the first vertex was placed.

### 5.4 Distributor Placement

**Trigger:** User selects the Distributor tool.

1. User clicks a location on the floor plan → distributor symbol is placed (a small rectangle icon with pipe stubs).
2. Properties panel shows: supply temperature, return temperature. Pump head is a calculated read-only field shown after circuits are connected (see ADR-007). An optional pump capacity field allows the user to enter an existing pump's rating for validation.
3. Only one distributor per floor is allowed. If one already exists, show dialog: "Replace existing distributor?" with Move/Replace/Cancel options.

### 5.5 Circuit Routing (Pipe Drawing)

**Trigger:** User selects the Route Pipe tool.

1. User clicks the distributor → route starts from a free port on the distributor.
2. User clicks waypoints to define the pipe path. Lines drawn in `supplyPipe` colour.
3. When the user clicks on a heating zone: the supply route is completed, and the system automatically begins the return route (drawn in `returnPipe` colour).
4. User clicks waypoints for the return path back to the distributor.
5. When the user clicks the distributor again: circuit is complete. System validates continuity.
6. If the route is incomplete (user presses Escape), the partial route is discarded.

**Visual feedback during routing:**
- Pipe lines show directional arrows indicating flow direction.
- Cumulative pipe length is displayed in the status bar during routing.
- When hovering over a zone that already has a circuit, show a "⚠ Already connected" indicator.

### 5.6 Selection & Editing

**Select tool behaviour:**

| Action | Target | Result |
|--------|--------|--------|
| Click on empty space | — | Deselect all |
| Click on wall | Wall segment | Select wall, show wall properties and handles |
| Click on room interior | Room | Select room, show room properties |
| Click on window/door | Opening | Select opening, show opening properties |
| Click on heating zone | Zone | Select zone, show zone properties |
| Click on distributor | Distributor | Select, show distributor properties |
| Click on pipe route | Circuit | Select circuit, show circuit properties |
| Double-click on wall | Wall | Open wall construction editor (modal) |
| Double-click on room | Room | Open room name/temp editor inline |
| Shift+click | Any | Add to selection (multi-select) |
| Drag on empty space | — | Marquee selection |

#### 5.6.1 Wall Handles (Post-Placement Editing)

When a wall segment is selected, three circular drag handles appear on the wall:

| Handle | Position | Visual |
|--------|----------|--------|
| Start handle | Start endpoint of the wall | Filled circle (8px), primary colour |
| Mid handle | Midpoint of the wall | Filled circle (8px), primary colour |
| End handle | End endpoint of the wall | Filled circle (8px), primary colour |

**Mid-handle drag — move entire wall:**
1. Click and hold the mid handle → cursor changes to grab.
2. Drag to move the entire wall (both endpoints translate by the same delta).
3. Wall snaps to grid during drag (same grid snap as wall drawing).
4. **If the wall belongs to a completed room:** connected walls stay attached. Their far endpoints remain fixed; their near endpoints follow the moving wall. Connected walls adjust length and orientation to maintain the connection. The room polygon updates in real time.
5. Release to commit the new position.

**Endpoint handle drag — change length and orientation:**
1. Click and hold a start or end handle → cursor changes to crosshair.
2. Drag to move that single endpoint. The opposite endpoint stays fixed.
3. The wall pivots and stretches/shrinks around the fixed endpoint.
4. Endpoint snaps to grid (same snap behaviour as wall drawing).
5. **If the wall belongs to a completed room:** the connected wall at the dragged endpoint adjusts its length and orientation to stay connected. The room polygon updates in real time.
6. Release to commit. Wall length validation applies (min 100mm). If the resulting wall is too short, revert to the pre-drag position and show a transient toast.

**Endpoint handle right-click (Ctrl+click on Mac) — disconnect wall:**
1. Right-click (or Ctrl+click on macOS) on a start or end handle that is connected to another wall.
2. The wall is disconnected from the adjacent wall at that endpoint. The two walls no longer share the endpoint; each retains its own position.
3. **If the wall was part of a completed room:** the room is destroyed immediately. All room data is removed:
   - The `Room` entity is deleted.
   - All `WallSegment.roomId` references to that room are cleared (set to empty).
   - Windows and doors on the room's walls are preserved (they belong to the wall, not the room).
   - Heating zones associated with the room are deleted.
   - The properties panel updates to show the wall properties instead of the now-deleted room.
4. No confirmation dialog — the disconnect is immediate with undo support.

#### 5.6.2 Delete Behaviour

**Trigger:** Press Delete/Backspace (desktop) or tap Delete button (tablet).

**Wall deletion:**
- The selected wall is removed immediately.
- **If the wall was part of a completed room:** the room is destroyed. Cascade cleanup:
  - The `Room` entity is deleted.
  - All remaining walls that belonged to that room have their `roomId` cleared.
  - Windows and doors on the deleted wall are also deleted (they lose their host wall).
  - Windows and doors on the remaining walls are preserved.
  - Heating zones associated with the room are deleted.
  - No dead data may remain — all foreign key references to the deleted room or wall must be cleaned up.
- Undo support: undoing the delete restores the wall, the room (if one was destroyed), and all cascade-deleted entities.

**Room deletion:**
- Confirmation dialog: "Delete room '{name}' and all its contents? This removes heating zones associated with this room."
- On confirm: the `Room` entity is deleted. Walls are preserved but have their `roomId` cleared. Windows and doors on those walls are preserved. Heating zones are deleted.

**Other element deletion:**
- Single element (window, door, zone): immediate delete with undo support.
- Distributor: confirmation dialog ("Delete distributor and all connected circuits?")

### 5.7 Wall Construction Editor (Modal)

```
┌──────────────────────────────────────────────────────┐
│  Wall Construction: Exterior Wall South    [Save] [✕] │
│                         [⬆ Save as preset] [⬇ Load ▾] │
├──────────────────────────────────────────────────────┤
│                                                        │
│  U-Value: 0.283 W/(m²K)          R: 3.534 m²K/W      │
│                                                        │
│  ┌ Layer Stack (outside → inside) ──────────────────┐ │
│  │                                                    │ │
│  │  ⠿ [Cement render    ] [15 mm ] [λ 1.00]  [🗑]   │ │
│  │  ─────────────────────────────────────             │ │
│  │  ⠿ [EPS insulation   ] [100 mm] [λ 0.035] [🗑]   │ │
│  │  ════════════════════════════════════════════      │ │
│  │  ⠿ [Hollow brick     ] [200 mm] [λ 0.44]  [🗑]   │ │
│  │  ═══════════════════════════════════════           │ │
│  │  ⠿ [Gypsum plaster   ] [15 mm ] [λ 0.40]  [🗑]   │ │
│  │  ─────────────────────────────────────             │ │
│  │                                                    │ │
│  │              [+ Add Layer]                         │ │
│  └────────────────────────────────────────────────────┘ │
│                                                        │
│  ┌ Temperature Profile ──────────────────────────────┐ │
│  │  20.0°C ██████████████████████████████░░ -12.0°C  │ │
│  │         ↑     ↑              ↑       ↑            │ │
│  │       19.8  19.7           -11.2   -11.8          │ │
│  └────────────────────────────────────────────────────┘ │
│                                                        │
│  Surface resistances: Rsi [0.13] m²K/W  Rse [0.04]   │
└──────────────────────────────────────────────────────┘
```

**Interaction:**
- ⠿ = drag handle for reordering layers.
- Material name is a dropdown/searchable picker (tap to open material picker dialog).
- Thickness is a numeric input with mm unit label.
- λ is read-only (from material database) but can be overridden by tapping it.
- 🗑 = delete layer button.
- Bar width is proportional to layer thickness, providing intuitive visual feedback.
- U-value and temperature profile update in real time on every change.
- Temperature profile boundary values are **never hardcoded**. The editor receives the indoor and outdoor temperatures as parameters:
  - **Outdoor:** always `designOutdoorTempC` from project settings.
  - **Indoor:** the owning room's `targetTempC` when opened from a wall; `defaultIndoorTempC` from project settings when opened from a floor/ceiling context (no specific room).
- "Add Layer" inserts a new empty layer at the bottom (inside face). User can drag to reposition.

**Inhomogeneous layer (stud/bridging element):**

Each layer row has a **⊕** button at the right edge. Tapping ⊕ expands the row to reveal a stud sub-row directly below the main layer. Tapping ⊕ again (or ✕ on the sub-row) collapses and removes the stud definition.

Expanded row wireframe:
```
  ⠿ [EPS insulation   ] [200 mm] [λ 0.035] [🗑] [⊕]
    └─ Timber stud:  [60 mm] stud width  [300 mm] clear gap  [λ 0.13]  [✕]
```

Field labels and disambiguation:
- The sub-row begins with the fixed label **"Timber stud:"** — no material picker.
- First numeric field: **"stud width"** (label shown inline, mm unit).
- Second numeric field: **"clear gap"** (label shown inline, mm unit).
- Third field: **λ** — pre-filled with `0.13` (softwood default); user-overridable by tapping, same pattern as the main layer's λ override.
- **Tooltip on "clear gap" field** (shown on hover/long-press): *"Clear distance between studs, edge to edge — not centre-to-centre. Centre-to-centre spacing = stud width + clear gap."*
- Both width and clear gap are required. If either is empty or zero, the layer is treated as homogeneous and a warning indicator (⚠) appears next to the ⊕ button.

Visual distinction: an inhomogeneous layer row has a subtle left border accent (`primaryLight` colour, 3px) to distinguish it from homogeneous rows at a glance.

Stud material is always timber — no picker needed.

**Preset buttons (second row in title area):**

- **"⬆ Save as preset"** — always enabled. Tapping opens a small inline dialog:
  - Text field pre-filled with the current construction name.
  - "Save" / "Cancel" buttons.
  - On confirm: saves a copy of the current in-editor construction (with its
    current layers) as a named preset (`isPreset = true`). Does not close the
    editor or affect the wall being edited.

- **"⬇ Load"** — disabled (greyed out) when no presets exist; shows a dropdown
  arrow to signal it opens a list.
  - Tapping shows a popup menu listing all saved presets by name, each with its
    U-value in secondary text (e.g. "Exterior Wall 200mm EPS — U 0.18 W/(m²K)").
  - Selecting a preset **replaces the current in-editor layer stack** with a
    deep copy of that preset's layers (new UUIDs). The construction name field
    is also replaced with the preset name. The user must still press "Save" to
    apply the loaded construction to the wall.
  - Loading does not modify the saved preset — it is always a copy.

### 5.8 Performance Dashboard

Opens as a right-side panel (desktop) or full-screen overlay (tablet). Contains tabbed sections:

**Tab 1: Heat Balance**
```
┌────────────────────────────────────────┐
│  Heat Demand vs Output by Room          │
│                                         │
│  Living Room  ████████████░░░░  464W    │
│               ████████████████  520W    │
│                                         │
│  Kitchen      ██████░░░░░░░░░  380W    │
│               ████████████      350W    │
│                               ⚠ -30W   │
│                                         │
│  Bathroom     ████░░░░░░░░░░░  290W    │
│               ██████████        310W    │
│                                         │
│  ░ = demand (outline)   █ = output      │
└────────────────────────────────────────┘
```

**Tab 2: Hydraulic**
```
┌────────────────────────────────────────┐
│  Pressure Loss by Circuit               │
│                                         │
│  Circuit 1  ████████████████████ 21.9kPa│ ← reference
│  Circuit 2  ████████████░░░░░░░ 15.2kPa│ valve: 6.7kPa
│  Circuit 3  ██████████░░░░░░░░░ 12.8kPa│ valve: 9.1kPa
│                                         │
│  ░ = throttling needed   █ = pipe loss  │
│                                         │
│  Flow Rates                             │
│  ┌───────────────────┐                  │
│  │    ╱ C1: 42% ╲    │                  │
│  │   │  C2: 35%  │   │                  │
│  │    ╲ C3: 23% ╱    │                  │
│  └───────────────────┘                  │
└────────────────────────────────────────┘
```

**Tab 3: Warnings**
```
┌──────────────────────────────────────────────────────┐
│  ⚠ Warnings (3)                        [Filter ▾]    │
│                                                       │
│  🔴 Circuit 2: supply route incomplete          [←]  │  ← hover highlights element on canvas
│     → Connect supply pipe from distributor to zone    │
│                                                       │
│  🟡 Kitchen: heat output 350W < demand 380W     [←]  │
│     → Reduce tube spacing or increase supply temp     │
│                                                       │
│  🔵 Circuit 1: length 95m near max (120m for 16mm)   │
│     → Consider splitting into two zones               │
└──────────────────────────────────────────────────────┘
```

**Hover-to-highlight interaction:**
- Wrapping each warning row in a `MouseRegion` (desktop) detects pointer enter/exit.
- On pointer enter: set `hoveredElementProvider` to `SelectedElement(type: result.elementType, id: result.elementId)`.
- On pointer exit: clear `hoveredElementProvider` to null.
- The canvas painters read `hoveredElementProvider` and draw a 2px `hoverHighlight` colour outline (at 60% opacity) around the matching element. The highlight applies to walls, zones, circuits, and the distributor; rooms are highlighted by outlining all their walls.
- The hover highlight is purely visual — it does not change the selection (`selectedElementProvider`) and does not open the properties panel.
- On tablet (no hover): a long-press on the warning row triggers the same highlight for 2 seconds, then clears.

---

## 6. Canvas Interaction Patterns

### 6.1 Cross-Platform Input Mapping

| Action | Desktop (Mouse + KB) | Tablet (Touch) |
|--------|---------------------|----------------|
| Pan canvas | Middle-click drag OR Space + left-drag | Two-finger drag |
| Zoom in/out | Scroll wheel OR Ctrl/Cmd + / - | Pinch gesture |
| Zoom to fit | Ctrl/Cmd + 0 | Double-tap with two fingers |
| Draw (wall/zone/route) | Click start → click end | Tap start → tap end |
| Place element | Click on wall → drag to position | Tap on wall → drag to position |
| Select | Left-click | Tap |
| Multi-select | Shift + click | Long-press → tap additional items |
| Marquee select | Left-drag on empty space | Not available (use multi-select) |
| Context menu | Right-click | Long-press (500ms) |
| Cancel operation | Escape key | Tap ✕ button in active-tool bar |
| Delete | Delete / Backspace | Tap 🗑 in action bar |
| Undo | Ctrl/Cmd + Z | Tap ↩ in action bar |
| Redo | Ctrl/Cmd + Shift + Z | Tap ↪ in action bar |
| Edit properties | Double-click element | Double-tap element |

### 6.2 Cursor States (Desktop)

| Tool State | Cursor |
|-----------|--------|
| Select (idle) | Default arrow |
| Select (hovering over element) | Pointer hand |
| Select (dragging element) | Grabbing hand |
| Drawing tool (wall/zone/route) | Crosshair |
| Placing window/door | Crosshair with + icon |
| Pan mode (Space held) | Open hand |
| Panning (Space + dragging) | Closed hand |
| Measure tool | Crosshair with ruler icon |
| Over resize handle | Bidirectional arrow |

### 6.3 Snapping Visual Feedback

| Snap type | Visual indicator |
|-----------|-----------------|
| Grid snap | Green dot at snap point, 6px diameter |
| Endpoint snap | Green circle at endpoint, 8px diameter, 2px stroke |
| Midpoint snap | Green diamond at midpoint, 8px |
| Ortho snap (0°/90°) | Dashed guideline along the constrained axis, extends 200px |
| Wall alignment snap | Dashed blue guideline along the aligned axis |

---

## 7. Properties Panel Specifications

The properties panel content changes based on what is selected. Here are the content specs for each selection type.

### 7.1 Nothing Selected → Project Summary

| Field | Type | Description |
|-------|------|-------------|
| Project name | Read-only text | Tap to edit |
| Outdoor design temp | Read-only | Tap to edit |
| Total rooms | Read-only count | — |
| Total floor area | Read-only, m² | — |
| Total heat demand | Read-only, W | — |
| Warning summary | Badges | Error count, warning count |

### 7.2 Room Selected

| Field | Type | Editable | Validation |
|-------|------|----------|-----------|
| Room name | Text input | Yes | 1-100 chars |
| Target temperature | Slider + numeric (°C) | Yes | 15.0 – 30.0 |
| Air change rate | Dropdown + custom | Yes | 0.1 – 5.0 |
| **Computed (read-only)** | | | |
| Floor area | Display (m²) | No | — |
| Room volume | Display (m³) | No | — |
| Transmission loss — walls | Display (W) | No | — |
| Transmission loss — floor | Display (W) | No | "—" if no floor construction assigned |
| Transmission loss — ceiling | Display (W) | No | "—" if no ceiling construction assigned |
| Ventilation loss | Display (W) | No | — |
| Total heat demand | Display (W), bold | No | "—" if any exterior wall or assigned slab lacks a construction |
| Heat output | Display (W) | No | Only if zone exists |
| Balance | Display (W), colour-coded | No | Green if output ≥ demand |

#### 7.2.1 Floor and Ceiling Envelope Section

Below the heat demand numbers, show a collapsible section labelled **"Envelope
— Floor & Ceiling"** (collapsed by default, expands on tap).

**Floor subsection:**

```
Floor
  What's below?  [ Ground ▾ ]          ← boundary condition dropdown
  Construction   [ Not assigned  Edit ] ← button opens WallConstruction editor
  Correction f.  0.60                   ← read-only for Ground/Exterior;
                                           slider 0.0–1.0 for Unheated Space
```

**Ceiling subsection (identical layout):**

```
Ceiling
  What's above?  [ Exterior roof ▾ ]
  Construction   [ Not assigned  Edit ]
  Correction f.  1.00                   ← read-only 1.0 for Exterior
```

**Boundary condition dropdown options:**

| Display label | `BoundaryCondition` value | Correction factor shown |
|---------------|--------------------------|------------------------|
| Ground (slab on grade) | `ground` | 0.60 (read-only, with ⓘ tooltip explaining ISO 13370 simplification) |
| Exterior / Roof | `exterior` | 1.00 (read-only) |
| Unheated attic | `unheatedSpace` | Slider 0.0–1.0, pre-filled 0.80 |
| Unheated basement / garage | `unheatedSpace` | Slider 0.0–1.0, pre-filled 0.60 |
| Unheated crawlspace | `unheatedSpace` | Slider 0.0–1.0, pre-filled 0.50 |
| Adjacent heated room (same temp) | `interior` | 0.00 (read-only, "No heat loss") |

> **Note on preset vs custom:** "Unheated attic", "Unheated basement / garage",
> and "Unheated crawlspace" all map to `BoundaryCondition.unheatedSpace` — they
> differ only in the pre-filled correction factor value. After selecting a
> preset, the user can drag the slider to override. This avoids exposing
> `BoundaryCondition` as an enum to the user while still giving full control.

**Construction button behaviour:**
- If no construction assigned: button label "Not assigned  [+ Assign]"
- If assigned: button label shows construction name + computed U-value,
  e.g. "Flat roof 200mm EPS — U 0.18 W/(m²K)  [Edit]"
- Tapping opens the same `WallConstruction` editor modal used for walls
  (Section 5.7), pre-titled "Floor construction" or "Roof/ceiling construction"

**When construction is not assigned:**
- Floor/ceiling transmission loss rows in the heat demand breakdown show "—"
- Total heat demand shows "—" and a diagnostic tooltip:
  "Floor or ceiling construction missing — assign a construction to include
  slab heat loss in the demand calculation. If the floor/ceiling has
  negligible heat loss (e.g. well-insulated party wall to identical heated
  room), set boundary to 'Adjacent heated room'."
- Zone colour is NOT affected by missing floor/ceiling construction — only
  missing wall constructions trigger the grey NaN state (because wall U-values
  dominate; floor/ceiling are optional refinements)

**Spacing and layout:**
- The envelope section uses `md` (16px) padding
- Boundary dropdown: full width
- Construction button: full width, left-aligned label, right-aligned action
- Correction factor row: label left, value or slider right (slider width 120px)

### 7.3 Wall Segment Selected

| Field | Type | Editable |
|-------|------|----------|
| Wall type | Dropdown: Exterior/Interior/Partition | Yes |
| Length | Display (mm) | No (change by moving endpoints) |
| Orientation | Display (N/S/E/W) | No (auto-calculated) |
| Construction | Button → opens construction editor | Yes |
| U-value | Display (W/m²K) | No (calculated) |
| Adjacent room | Display or dropdown | Yes for interior walls |
| [Edit Construction] | Button | Opens modal (Section 5.7) |

### 7.4 Heating Zone Selected

| Field | Type | Editable |
|-------|------|----------|
| Zone type | Toggle: Floor / Wall | Yes |
| Tube spacing | Slider 50-400mm + numeric | Yes |
| Tube type | Dropdown (from tube library) | Yes |
| Flooring material | Dropdown (from flooring library) | Yes |
| Layout pattern | Radio: Meander/Spiral/Bifilar/Counterflow | Yes |
| Border distance | Slider 50-300mm | Yes |
| **Computed** |
| Zone area | Display (m²) | No |
| Tube length (zone only) | Display (m) | No |
| Specific output | Display (W/m²) | No |
| Total output | Display (W), colour-coded | No |
| Surface temperature | Display (°C), warn if over limit | No |

### 7.5 Distributor Selected

| Field | Type | Editable |
|-------|------|----------|
| Supply temperature | Slider 20-55°C + numeric | Yes |
| Return temperature | Slider + numeric, must be < supply | Yes |
| Pump capacity | Numeric input (Pa), optional | Yes |
| **Computed (shown after circuits connected)** |
| Required pump head | Display (Pa), read-only (see ADR-007) | No |
| Number of circuits | Display | No |
| Total flow rate | Display (kg/h) | No |

---

## 8. Keyboard Shortcuts (Desktop)

| Shortcut | Action | Context |
|----------|--------|---------|
| Ctrl/Cmd + N | New project | Global |
| Ctrl/Cmd + O | Open project | Global |
| Ctrl/Cmd + S | Save | Global |
| Ctrl/Cmd + Shift + S | Save As / Export | Global |
| Ctrl/Cmd + Z | Undo | Editor |
| Ctrl/Cmd + Shift + Z | Redo | Editor |
| Delete / Backspace | Delete selected | Editor |
| Escape | Cancel tool / deselect | Editor |
| V | Select tool | Editor |
| W | Wall draw tool | Editor |
| Shift (hold, Wall tool) | Constrain to horizontal/vertical only (0°/90°) | Wall tool active |
| Ctrl (hold, Wall tool) | Rectangle mode — drag corner to corner to place 4 walls | Wall tool active |
| Alt (hold, Wall tool) | Free placement — disable grid snap | Wall tool active |
| N | Window place tool | Editor (N for "wiNdow" — W is taken) |
| D | Door place tool | Editor |
| H | Heating zone tool | Editor |
| G | Distributor tool | Editor (G for "Gabelung"/manifold) |
| R | Route pipe tool | Editor |
| M | Measure tool | Editor |
| Ctrl/Cmd + = | Zoom in | Editor |
| Ctrl/Cmd + - | Zoom out | Editor |
| Ctrl/Cmd + 0 | Zoom to fit | Editor |
| Space (hold) | Activate pan mode | Editor |

---

## 9. Settings Screen

Accessible from the overflow menu (⋮) on tablet, and from the app menu bar on desktop. A simple scrollable form — no tabs at this stage.

### 9.1 General Settings

| Field | Control | Values | Default |
|-------|---------|--------|---------|
| Drawing grid size | Dropdown | 5mm / 10mm / 25mm / 50mm / 100| 100mm |

**Behaviour:**
- Changing the grid size takes effect immediately on the canvas — no Apply button.
- The selected value is persisted in `AppPreferences` (`gridSpacingMm`) and restored on next launch.
- The dropdown label shows the value with its unit: "100 mm", "25 mm", etc.
- Setting is global (not per-project).

---

## 10. Responsive Breakpoints

| Breakpoint | Width | Layout Changes |
|-----------|-------|---------------|
| Desktop Large | ≥ 1200dp | Full layout: toolbar + canvas + properties panel (280px) |
| Desktop Medium | 900-1199dp | Narrower properties panel (240px) |
| Tablet Landscape | 600-899dp | Floating toolbar, bottom sheet properties, status bar simplified |
| Tablet Portrait | < 600dp | Same as tablet landscape but canvas is taller; properties sheet starts collapsed |

---

## 11. Accessibility Requirements

- All interactive elements must have semantic labels for screen readers.
- Colour is never the sole indicator of status — always pair with text or icon (e.g., zone adequacy uses colour + text label).
- Focus order follows logical tab sequence: toolbar → canvas → properties panel.
- High-contrast mode: provide an alternative colour scheme where all colours meet WCAG AA contrast ratio (4.5:1 for text, 3:1 for graphics).
- Touch targets on tablet: minimum 44 × 44 logical pixels. Toolbar icons: 48 × 48.
- Canvas zoom and pan must be achievable without multi-touch (accessibility settings can map to single-finger drag + pinch buttons).

---

## 13. Save, Autosave & Session Restore

### 12.1 Two-Tier Persistence — User-Facing Mental Model

HeatingPlanner never loses work. The app continuously saves all project data to its internal database the moment any change is made — drawing a wall, adjusting a temperature, editing a layer. The user never needs to press Save to avoid losing data.

"Save" (Ctrl/Cmd + S) and "Save As" (Ctrl/Cmd + Shift + S) are about exporting to a portable `.hsp` file — useful for sharing between devices, sending to a colleague, or creating a backup outside the app.

**This distinction must be communicated clearly in the UI.** Do not use language like "unsaved changes" without qualifying that data is safe in the app.

### 12.2 Save State Indicator (Status Bar)

The right side of the status bar shows a compact save indicator. Three states:

| Situation | Indicator | Tooltip on hover |
|-----------|-----------|-----------------|
| Project never exported to `.hsp` | (nothing) | — |
| All changes reflected in `.hsp` | "✓ Saved" in `onSurfaceSecondary` | "All changes saved to file" |
| Changes made since last `.hsp` export | ● (amber dot, 6px) | "File export out of date — press Ctrl+S to update" |
| Auto-export in progress | ⟳ spinning (12px) + "Saving…" | "Saving to file…" |
| Auto-export failed | ⚠ amber icon | "Could not save to file — check disk space or permissions" |

The indicator appears only when the project has a file path. New projects or projects opened directly from the app database show no indicator (they are always fully safe without a file).

### 12.3 Window Title

On desktop, the window title format is:

```
{ProjectName} — HeatingPlanner          ← clean state or no .hsp
{ProjectName} ● — HeatingPlanner        ← .hsp out of date
{ProjectName} — HeatingPlanner (Saving…)← auto-export running
```

The ● indicator mirrors the status bar dot. It follows the platform convention (macOS uses a dot in the close button; this supplements that with visible text).

### 12.4 Manual Save Flows

**Ctrl/Cmd + S — Save to existing file:**
- If the project already has a file path: silently overwrites. Status bar shows "✓ Saved" for 2 seconds then reverts to normal state.
- If no file path yet: opens a "Save As" file picker dialog.

**Ctrl/Cmd + Shift + S — Save As:**
- Always opens a file picker.
- Default filename: `{ProjectName}.hsp`
- Filter: `*.hsp` files.
- On confirm: exports and establishes the new path as the auto-export target.
- On cancel: no change.

**File menu → Save / Save As:** same as shortcuts above.

### 12.5 Quit / Close with Unsaved File Export

When the user closes the window or quits the app while the `.hsp` is out of date:

```
┌──────────────────────────────────────────────────────────┐
│  Unsaved export file                                      │
│                                                           │
│  "{ProjectName}" has changes not yet written to the       │
│  .hsp export file. Your project is safely stored in the   │
│  app — this only affects the portable file.               │
│                                                           │
│  [ Save File and Quit ]   [ Quit Anyway ]   [ Cancel ]   │
└──────────────────────────────────────────────────────────┘
```

- "Save File and Quit": export `.hsp` then close. Show brief progress spinner.
- "Quit Anyway": close without exporting. All data remains safe in the database.
- "Cancel": dismiss dialog, return to the app.

If the project has **never** been exported to a file (no path set), close without any dialog — there is nothing to warn about.

### 12.6 App Startup — Session Restore

On every launch, the app remembers the last open project and reopens it directly:

1. **Last project found in database → open it directly.** Skip the project list screen. The canvas restores to the same zoom and pan position the user left. No loading dialog — show the editor immediately with the Drift stream providing data.
2. **First launch / last project deleted → show Project List Screen.** Same as current behaviour.
3. **Project list screen → tap a project → open it** and remember it as the new last-opened project.

There is no "restoring session…" splash screen or notification — the restoration is seamless. The editor opens and data loads through the normal reactive providers.

### 12.7 Autosave Feedback (In-Session)

The autosave to `.hsp` is silent and background. Do not interrupt the user with toasts or dialogs for successful autosaves. Only surface feedback for:

- **Success:** status bar indicator transitions cleanly from ● to ✓.
- **Failure:** amber ⚠ icon in status bar + tooltip. Does not interrupt editing.
- **Manual save shortcut:** show "✓ Saved" text in status bar for 2 seconds as a tactile confirmation.

**Never** block the canvas or show a full-screen loading state for any save operation.

---

## 12. Usability Review Checklist

The UI/UX Designer reviews every frontend PR against these criteria:

- [ ] Interaction matches the specification in Section 5
- [ ] Correct cursor states per Section 6.2
- [ ] Snap feedback visible per Section 6.3
- [ ] Properties panel shows correct fields per Section 7
- [ ] Colour tokens used from Section 3.1 (no hard-coded hex values in widgets)
- [ ] Typography tokens used from Section 3.2
- [ ] Spacing uses 4px grid from Section 3.3
- [ ] Touch targets ≥ 44px on tablet
- [ ] No text truncation at minimum supported screen size
- [ ] Undo/redo works for the implemented interaction
- [ ] Confirmation dialog shown for destructive actions
- [ ] Real-time feedback: values update within 200ms of change
- [ ] Platform fidelity: desktop uses mouse conventions, tablet uses touch conventions
- [ ] Save state indicator present in status bar when project has a file path
- [ ] Window title shows ● when `.hsp` is out of date
- [ ] Quit dialog uses the correct wording (data is safe, only file is at risk)
- [ ] App opens directly to last project on relaunch (no project list if a last project exists)
- [ ] Manual save (Ctrl+S) shows "✓ Saved" confirmation for 2 seconds
- [ ] Auto-export failures surface in status bar without blocking canvas
