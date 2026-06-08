# Architecture Decisions

Short records of non-obvious choices. Each entry covers **What** was decided,
**Why** that option was chosen, and the **Rule** future code must respect.

---

## ADR-001 — Shared walls use two WallSegments, not one

**What.**
When two rooms share a wall, each room gets its own `WallSegment` at the same
geometric position. The room-1 copy keeps `roomId = room1` and gains
`wallType = interior, adjacentRoomId = room2`. A mirror copy (start/end
swapped) is created with `roomId = room2, wallType = interior,
adjacentRoomId = room1`.

**Why.**
The provider `wallSegmentsProvider(roomId)` queries strictly by `roomId`. A
single shared segment would be invisible to one of the two rooms, breaking wall
counts and heat-demand calculations. Approach A (one segment referencing both
rooms via `roomId + adjacentRoomId`) was rejected because it would require
every consumer to handle the "I am the secondary room" case.

**Rule.**
Every room must be able to find all its boundary walls by filtering
`wallSegmentsProvider(roomId)` alone. Never rely on `adjacentRoomId` to
discover that a wall belongs to a room — use it only to look up the *neighbour*
room's temperature. A shared wall therefore always exists in the database twice:
once per room.

---

## ADR-002 — Interior wall heat demand uses the correction-factor formula

**What.**
For a wall with `wallType = interior`, heat demand is calculated as:

```
Q = U × A × f × (T_this − T_outdoor)
  where f = (T_this − T_adjacent) / (T_this − T_outdoor)
         = ThermalEngine.interiorCorrectionFactor(...)
```

`T_adjacent` is read from the `Room` whose `id` equals `adjacentRoomId`.
When both rooms are at the same temperature `f = 0` and `Q = 0`.
When the adjacent room is warmer than this room, `f` is negative — the wall
contributes a heat *gain* that reduces the room's total heating demand.

**Why.**
EN 12831 §6.3.3 defines this correction factor for walls between conditioned
spaces. It correctly scales the demand between 0 (identical temperatures) and
1 (adjacent space at outdoor temperature), and goes negative when the neighbour
is warmer, which is physically correct.

**Rule.**
`roomHeatDemandProvider` must resolve `adjacentRoomId` to the neighbouring
`Room` before calling `ThermalEngine.transmissionLoss`. Passing `correctionF =
1.0` for interior walls is a bug. Passing `correctionF = 0.0` when
`adjacentRoomId` is null (wall not yet linked) is acceptable as a safe default
that over-estimates demand.

---

## ADR-003 — Partial shared walls: split at wall-commit time

**What.**
When the user ends a new wall segment on the interior of an existing
room-assigned wall, `EditorStateNotifier.commitWallWithSplit` splits that host
wall at the junction point **immediately**, before room detection runs. The host
wall is replaced by two segments (`before` and `after`) that share the junction
point as an endpoint. The new wall is then added, and room detection sees the
fully-split graph.

`addRoomFromDetection` is unchanged: it handles only exact-match shared walls
(ADR-001) — no sub-segment detection is needed there because the split already
occurred at draw time.

**Why.**
Room detection (`RoomDetection.detectClosedRoom`) performs a DFS on wall
endpoints. If wall `d` runs from corner `jcd` to corner `A`, a new wall whose
endpoint lands at interior point `J` on `d` would leave the DFS with no node
at `J` to traverse — the cycle cannot be found. Splitting `d` into `d1` and
`d2` at `J` creates the missing graph node so the DFS can close the cycle
through `J`.

Splitting inside `addRoomFromDetection` (the first implementation) was
incorrect because the detection itself requires the split to have already
happened — a circular dependency.

**Rule.**
1. `WallDrawTool` always calls `callbacks.commitWallWithSplit(wall)` (never
   the plain `commitWall`).
2. `EditorStateNotifier.commitWallWithSplit` scans all walls for any
   room-assigned (`roomId` non-empty) wall whose interior strictly contains
   either endpoint of the new wall (using `GeometryEngine.isPointOnSegment`
   and `GeometryEngine.parameterAlongSegment` with `t ∈ (ε, 1−ε)`).
3. Only one split per endpoint (the first matching host wall wins); at most two
   splits per new wall (one per endpoint).
4. Unassigned walls (`roomId` empty) are never split — they have no room
   graph ownership yet.
5. Flanking segments inherit all properties of the host wall
   (`wallType`, `constructionId`, `adjacentRoomId`, `orientation`).
6. All mutations (removals + insertions + new wall addition) happen in a single
   `state = state.copyWith(walls: ...)` call so no intermediate state is
   observable.

A wall drawn across the open side can land on a second assigned wall, splitting
it too, so both endpoints are checked independently. A single host wall can
accumulate many junction nodes across successive room additions because each
split piece remains individually splittable.

> **Status:** Implemented in `EditorStateNotifier.commitWallWithSplit` and
> `SnapService` (wall-interior snap, 150 mm threshold, grid-aligned where
> possible). Cursor feedback via `SnapType.wallPoint` shown in
> `WallDrawTool.getInteractionData`.

---

## ADR-004 — Heating zone colour is a priority-ordered state machine

**What.**
A heating zone's display colour is determined by evaluating conditions in strict
priority order: (1) unconnected → red hatched, (2) no demand data → grey,
(3) output < 90% demand → red solid, (4) output 90–99% → yellow,
(5) output ≥ 100% → green. The first matching condition wins.

**Why.**
Multiple conditions can be true simultaneously (e.g. a zone could be unconnected
*and* have insufficient output). Without a defined priority, different code paths
could assign conflicting colours. The "unconnected" state takes highest priority
because it represents a structural incompleteness that makes output values
meaningless. The "no demand data" state is second because the adequacy comparison
cannot be evaluated without it, but the zone's own heat output can still be
displayed.

**Rule.**
Zone colour evaluation must follow the priority chain exactly. Never evaluate
output-vs-demand when the zone is unconnected or demand data is missing. The
Frontend Developer implements the colour mapping; the Architect defines the
provider that returns the zone's state enum; the HVAC agent has no role here —
this is a UI state concern, not a thermal calculation.

---

## ADR-006 — Heating zones may span adjacent rooms through doorways

**What.**
A heating zone polygon is allowed to extend from its primary room into an
adjacent room, provided the rooms share a wall that contains a door. The zone
retains a single `roomId` (the primary room) but its polygon vertices may lie
inside the adjacent room.

Heat output attribution is split by area proportion: the zone's total output
(EN 1264) is calculated twice, once per room, using each room's own target
temperature for ΔT. The output attributed to each room equals
`specificOutput(T_room_i) × areaInRoom_i`. The demand-vs-output comparison in
each room's heat balance uses only the portion attributed to that room.

**Why.**
In practice, tubes sometimes run through doorways between adjacent rooms to
achieve optimal zone sizes or to serve open-plan areas. EN 1264 does not
address this case — it assumes one zone = one room temperature. When both rooms
share the same target temperature, area-proportional splitting is physically
accurate because ΔT is uniform. When temperatures differ, the split is an
approximation (the true output distribution depends on tube path and flow
direction), but it is the same approach used by commercial design tools.

**Rule.**
1. Polygon validation relaxes from "all vertices inside primary room" to "all
   vertices inside primary room OR inside a room that shares a door-connected
   wall with the primary room."
2. The zone's `roomId` remains a single FK to the primary room (the room where
   drawing started). The data model does not change.
3. `zoneHeatOutputProvider` must compute output per room portion separately,
   using each room's target temperature.
4. When a zone spans rooms with different target temperatures, a validation
   result with `WarningSeverity.warning` is emitted: "Zone crosses rooms with
   different target temperatures — output estimate is approximate. Consider
   separate zones for accurate room-by-room control."
5. When both rooms share the same target temperature, no warning is emitted.

---

## ADR-008 — Three supply pipe insulation variants with distinct calculation models

**What.**
A `HeatingCircuit`'s supply and return runs (the stretch from the distributor
to the heating zone and back) can be configured in one of three modes via
`supplyPipeInsulationType`:

| Enum value | Meaning | Heat output to transit room |
|---|---|---|
| `none` | Uninsulated in screed | 100 % — full BVF model |
| `corrugatedConduit` | Corrugated PE conduit (Wellrohr) in screed | ~25–30 % residual — BVF model × reduction factor |
| `insulationLayer` | Routed inside the insulation layer beneath the screed (e.g. Kermi x-net connect principle) | 0 % — no heat output to transit room |

**Why.**
The three variants have fundamentally different thermal behaviours and cannot
share a single formula:
- `none` and `corrugatedConduit` both embed the pipe in the screed and
  therefore contribute to the heat balance of any room the pipe traverses.
  The BVF information sheet (2014) provides the calculation basis: a
  corrugated conduit creates a ~2 mm still-air gap that reduces surface
  temperature from ~50 °C to ~35 °C, yielding roughly 70–75 % reduction in
  heat output compared to an uninsulated pipe; a simultaneous-use factor of
  0.5 is applied on top.
- `insulationLayer` keeps the pipe entirely below the screed, so it emits
  zero heat to the transit room's floor surface. This eliminates uncontrolled
  room heating and enables GEG §63 single-room control in corridor/transit
  areas. The routing is geometrically unrestricted (diagonal paths are
  valid and preferred to minimise length).

The corrugated-conduit reduction factors are confirmed by thermal testing
(BVF, 2014). The insulation-layer model is the basis of proprietary systems
such as Kermi x-net connect but can be applied to any manufacturer's
equivalent solution.

**Rule.**
1. `supplyPipeInsulationType` is a required field on `HeatingCircuit`. No
   default is assumed; the user must make an explicit choice.
2. `HydraulicEngine.supplyPipeHeatOutput` accepts the insulation type and
   returns the heat contribution (W) of the supply/return runs to the rooms
   they traverse. For `insulationLayer` it always returns 0.0.
3. `HydraulicEngine.supplyPipeTubeLength` calculates differently per type:
   for `insulationLayer`, the shortest straight-line (Euclidean) path through
   the floor plan is used; for the other two types, the user-drawn polyline
   length is used as-is.
4. Validation emits `WarningSeverity.warning` when the supply/return polyline
   of a circuit with `supplyPipeInsulationType != insulationLayer` geometrically
   intersects or overlaps any `HeatingZone` polygon on the same floor. Reason:
   uninsulated/corrugated pipes beneath a heating zone surface cause unintended
   additional heat output on that zone's area that is not accounted for in the
   EN 1264 zone calculation.
5. The 1/3 rule (BVF): the total length of supply + return runs must not
   exceed one third of the heating circuit length of the transit room's own
   heating circuit. If no heating circuit exists in the transit room, the
   validation is skipped. Violation → `WarningSeverity.warning`.
6. Routing in the insulation layer across another room's heating zone
   (type `insulationLayer`) is geometrically allowed and carries no warning —
   the pipe is thermally decoupled from the screed above.

---

## ADR-007 — Pump head is a calculated output, not a user input

**What.**
The `pumpHeadPa` field on the Distributor model is a calculated value, not
user-entered. It equals the pressure loss of the highest-loss circuit connected
to the distributor. An optional `pumpCapacityPa` field allows the user to enter
an existing pump's rated capacity for validation purposes.

**Why.**
The correct workflow is: design zones and circuits → calculate pressure loss per
circuit → the worst-case circuit determines the minimum pump head → select or
validate a pump against that requirement. Requiring the user to enter pump head
before circuits exist inverts this dependency and produces meaningless values.

**Rule.**
1. `pumpHeadPa` is computed by the hydraulic balancing provider as
   `max(pressureLossPa)` across all circuits on the distributor. It is read-only
   in the UI.
2. `pumpCapacityPa` is optional and user-editable. When provided, the system
   emits a warning if `pumpCapacityPa < pumpHeadPa` ("Selected pump may be
   undersized for this system").
3. The distributor properties panel shows `pumpHeadPa` as a read-only computed
   field (displayed after circuits are connected) and `pumpCapacityPa` as an
   optional input field.

---

## ADR-009 — Rect-mode corner snap and shared-wall deduplication

**What.**
When the user draws a second room in rectangle mode (Ctrl+drag) near an existing
room corner, the drag start and/or end point snaps to that corner. When the
resulting rectangle shares a full edge with an existing wall, a single shared wall
is created (ADR-001 pattern) instead of two overlapping wall segments.

**Why.**
Without snapping, the user must land the cursor pixel-perfectly on an existing
corner to avoid a small gap or overlap between rooms. Without deduplication, Ctrl+drag
next to an existing room produces two coincident wall segments (one per room),
breaking heat-loss calculations and rendering artefacts.

**Rules.**

1. **Corner snap in rect mode** — When `WallDrawTool._rectMode` is active, both the
   drag-start point (from `onDragStart`) and the drag-end point (from `onDragUpdate`
   / `onDragEnd`) are passed through `SnapService.snapRectCorner` *after* normal
   grid snap. The snap radius is `2 × gridSpacingMm`.

   ```
   SnapService.snapRectCorner(Point2D point, List<WallSegment> walls, double gridSpacingMm)
     → Point2D
   ```

   The method iterates all existing wall segment endpoints; if any endpoint lies
   within the snap radius, it returns that endpoint instead of `point`. If multiple
   endpoints qualify, the nearest one wins. If none qualifies, returns `point`
   unchanged.

2. **Edge-match detection** — After the four rect edges are finalised (at
   `onDragEnd`), before committing any wall segment, check each of the four edges
   against all existing `WallSegment` records. An edge *matches* an existing wall
   when **both** of the following hold:
   - The edge's start and end points are each within **50 mm** of the existing
     wall's start/end or end/start (direction-agnostic).
   - The existing wall belongs to a different room than the one being created.

3. **Commit behaviour for matched edges** — For each matched edge:
   - Do **not** insert a new `WallSegment` for the new room's side.
   - Promote the existing `WallSegment` to `wallType = WallType.interior`
     (if not already interior).
   - Set `adjacentRoomId` on the existing segment to the new room's ID.
   - Insert the ADR-001 mirror copy: a second `WallSegment` with swapped
     `startPoint`/`endPoint`, `roomId = newRoom`, `adjacentRoomId = existingRoom`,
     and `wallType = WallType.interior`.

4. **Non-adjacent behaviour** — When no edge matches, the four wall segments are
   committed exactly as before (grid-snapped corners, ADR-003 split logic applies
   at intersections). No change to the existing rect-mode commit flow.

5. **Undo** — All insertions and updates for a single rect-mode drag are grouped
   into one `UndoRedoService` batch so that a single Ctrl+Z reverts the entire
   room creation (shared walls, mirror copies, and room entity).

**Scope.**
Applies only to `WallDrawTool` in rect mode. Single-wall draw mode is unaffected.

---

## ADR-010 — Rect-mode dimension-matching snap

**What.**
When the user Ctrl+drags a second room and the grid-snapped drag-end's y (or x)
coordinate is within **100 mm** of a wall endpoint that shares the x (or y)
coordinate of the snapped drag-start, that axis is overridden to match — ensuring
the new room has the same height (or width) as the adjacent room's shared wall.

**Why.**
After the drag-start snaps to an existing corner (ADR-009 Rule 1), the drag-end
has no wall endpoint nearby, so `snapRectCorner` cannot help. Grid snap may land
on the wrong line: e.g., y = 2050 grid-snaps to 2100 with a 100 mm grid, making
the new room 100 mm taller than the adjacent one. A dimension-matching snap infers
the intended size from the wall already anchored at the drag-start corner.

**Rules.**

1. **Axis candidates** — From the snapped drag-start `S`, collect all wall
   endpoints `E` where:
   - `|E.x − S.x| ≤ 1 mm` (same x-column) → `E.y` is a y-snap candidate
   - `|E.y − S.y| ≤ 1 mm` (same y-row)    → `E.x` is an x-snap candidate

2. **Snap condition** — For each y-snap candidate `cy`: if
   `|dragEnd.y − cy| ≤ 100 mm`, set `dragEnd.y = cy` (prefer nearest). Apply
   the same logic to x-snap candidates independently.

3. **Order of operations** in `WallDrawTool.onDragEnd`:
   a. `SnapService.snap` (grid + endpoint snap)
   b. `_ortho` constraint
   c. `SnapService.snapRectCorner` (ADR-009 Rule 1)
   d. `SnapService.snapRectDimension` ← new — applied last

4. **New method** — `SnapService.snapRectDimension(Point2D dragStart, Point2D dragEnd, List<WallSegment> walls) → Point2D`. Pure static function; no state, no I/O.

5. **Threshold** — 100 mm. Intentionally narrower than the ADR-009 corner-snap
   radius (200 mm) to avoid snapping when rooms are intentionally different sizes.

**Scope.**
`WallDrawTool` rect mode, `onDragEnd` only. Not applied to `onDragUpdate` (ghost
preview uses raw cursor for performance). Single-wall draw mode is unaffected.

**Verification.**
WDT-12 in `test/widget/tools/wall_draw_tool_test.dart`.

---

## ADR-011 — Shared-wall mirror synchronization via `mirrorId`

**What.**
`WallSegment` gains a nullable `String? mirrorId` that points to the other wall
in an ADR-001 mirror pair. `addRoomFromDetection` sets `mirrorId` on both walls
when it creates the pair. `EditorStateNotifier.updateWall` detects a non-null
`mirrorId`, finds the partner wall by ID, and writes both walls in a single
`state.copyWith` call.

**Why.**
Without explicit linkage the user must edit both halves of a shared wall
independently — changing construction material or moving a vertex requires two
identical operations. A coordinate-heuristic search (find wall with reversed
endpoints) would work for current data but is fragile under float drift and
non-self-documenting. An explicit FK is O(1), survives any geometry
manipulation, and makes the pairing visible in the data model and Drift schema.

**Rules.**

1. `mirrorId` is `String?`, default `null`. Exterior and unassigned walls carry
   `null`. Only walls created by `addRoomFromDetection` carry a non-null value.

2. Drift `wall_segments` table: add nullable TEXT column `mirror_id` with
   `REFERENCES wall_segments(id) ON DELETE SET NULL`. Increment schema version;
   migration adds the column with `DEFAULT NULL`.

3. `addRoomFromDetection` sets `mirrorId` cross-referencing both walls after
   creating the mirror copy: `original.mirrorId = mirror.id` and
   `mirror.mirrorId = original.id`. No other call-site sets `mirrorId`.

4. `EditorStateNotifier.updateWall` — when `wall.mirrorId` is non-null, find
   the partner by ID and write a single atomic `state.copyWith`. Fields that
   sync:
   - `constructionId` — same physical material on both sides (covers both
     re-assignment of a different construction ID and creation of a new
     `WallConstruction` record by the editor; edits to the layers of an already-
     shared construction propagate automatically via the shared FK without
     needing `updateWall`)
   - `startPoint` / `endPoint` — reversed for the mirror (same geometry,
     opposite direction)
   - `wallType` — always both interior

   Fields that do **not** sync: `id`, `roomId`, `adjacentRoomId`, `mirrorId`,
   `orientation` (auto-recalculated from new geometry by `_withOrientation`).
   Both walls are persisted to the DAO in the same call.

5. `destroyRoom` cascade on `roomId` deletes the room's walls; the remaining
   partner's `mirrorId` becomes `null` via `ON DELETE SET NULL` — no
   application code needed.

6. `.hsp` format: `mirrorId` is included automatically once `build_runner`
   regenerates `WallSegment.toJson`/`fromJson`. No manual exporter change
   required.

---

## ADR-012 — Ctrl+endpoint-handle drag reshapes a rectangular room

**What.**
When a user drags an endpoint handle (corner) of a wall whose room is a
strictly rectangular room — exactly 4 wall segments, all axis-aligned
(horizontal or vertical), all interior angles 90° — and holds **Ctrl**, the
room is reshaped as a rectangle defined by:
- the diagonally opposite corner (fixed anchor), and
- the cursor position (the new location of the dragged corner).

All four corners of the room are repositioned in a single atomic update so the
room remains an axis-aligned rectangle. **Shift** held during endpoint handle
drag is an explicit no-op. **Modifier keys never apply to mid-handle drag.**

This mirrors the semantics of `WallDrawTool`'s rect mode (Ctrl-drag during
wall drawing): the user thinks of the room as a rectangle defined by two
diagonal corners, and resizing one corner reshapes all four walls together.

**Why.**
Without this feature, reshaping a rectangular room to a different size
requires four separate endpoint drags (one per corner) and careful
coordination to keep edges axis-aligned. Ctrl-drag for reshape is the natural
inverse of Ctrl-drag for creation.

Shift is deliberately a no-op because a corner is shared by two walls and the
system cannot decide which wall should keep its angle versus which should
rotate to follow the cursor. Silently picking one would be surprising; falling
back to default behaviour matches the principle of least astonishment.

Non-rectangular rooms (L-shapes, polygons with > 4 walls, walls not
axis-aligned) fall back to default endpoint-drag behaviour when Ctrl is held.
A "rectangle reshape" has no well-defined meaning on those shapes, and
attempting one would either silently rectangularise the room (destructive) or
require complex per-wall heuristics (fragile).

**Rules.**

1. **Rectangle eligibility check.** Before applying Ctrl-reshape, the
   `SelectTool` evaluates the dragged wall's `Room`:
   - `wallSegmentsProvider(roomId)` returns **exactly 4** segments;
   - every segment is axis-aligned within a 1 mm tolerance
     (`|startPoint.x − endPoint.x| < 1 mm` OR
     `|startPoint.y − endPoint.y| < 1 mm`);
   - the 4 segments form a closed loop with 4 distinct corners and
     90° interior angles (perpendicular adjacent edges).

   If any check fails, Ctrl has **no effect** — the drag proceeds with
   default endpoint-drag behaviour.

2. **Diagonal-corner identification.** From the 4 corners, the dragged
   corner `C_drag` is the endpoint being moved. The fixed anchor `D` is the
   corner whose x **and** y both differ from `C_drag`. The two adjacent
   corners share exactly one coordinate with `C_drag`.

3. **New corner positions.** Let `C_new` be the snapped cursor position.
   The four new corners are:
   - dragged corner → `C_new`
   - diagonal corner → `D` (unchanged)
   - the corner sharing `C_drag`'s x-axis → `(C_new.x, D.y)`
   - the corner sharing `C_drag`'s y-axis → `(D.x, C_new.y)`

4. **Snap pipeline for `C_new`.** Apply the same order used by rect-mode
   draw at `onDragEnd` (see ADR-009 / ADR-010):
   a. `SnapService.snap` (grid + endpoint snap)
   b. `SnapService.snapRectCorner(C_new, walls, gridSpacingMm)` — snap to
      other rooms' corners within `2 × gridSpacingMm`. Walls of the room
      being reshaped are excluded from the candidate list (snapping a
      corner onto its own diagonal would collapse the room).
   c. `SnapService.snapRectDimension(D, C_new, walls)` — match adjacent
      rooms' dimensions within 100 mm. Same exclusion: the room being
      reshaped is omitted from the candidate list.

5. **Wall updates.** Each of the 4 walls is updated via
   `EditorStateNotifier.updateWall` so that ADR-011 mirror synchronization
   propagates changes to any shared-wall partners automatically. All four
   `updateWall` calls happen in a single `state.copyWith(walls: ...)`
   transaction grouped into one `UndoRedoService` batch so a single Ctrl+Z
   reverts the entire reshape.

6. **Minimum dimension validation.** If the reshape would produce any wall
   shorter than 100 mm (either rectangle width or height < 100 mm), the
   commit at `onDragEnd` is **rejected**: revert all four walls to their
   pre-drag positions and show a transient toast: *"Room too small (min
   100×100 mm)"*. During `onDragUpdate` (live preview), the ghost may
   shrink below 100 mm — the rejection only fires on release.

7. **Modifier-key tracking in `SelectTool`.** `SelectTool` tracks `_ctrlHeld`
   in the same pattern `WallDrawTool` uses (see Frontend agent §4.4):
   listen to key-down and key-up events for `LogicalKeyboardKey.controlLeft`
   / `controlRight` / `metaLeft` / `metaRight` (Cmd on macOS maps via
   Flutter's `Shortcuts` infra to the same logical Ctrl). The flag is
   sampled at `onDragStart` to decide which drag mode to enter; toggling
   Ctrl mid-drag does **not** switch modes (avoids jarring shape jumps).
   This matches the WallDrawTool rect-mode convention.

8. **Cursor.** When `_ctrlHeld` is true and hovering over an endpoint
   handle of a rectangle-eligible room, the cursor changes to the same
   rectangle-crosshair used by rect-mode draw, signalling the alternate
   behaviour. On non-eligible rooms the cursor stays as the default
   endpoint-drag cursor (bidirectional arrow) — visual feedback that Ctrl
   will not apply.

9. **Shift and Alt during endpoint drag.** Shift is a documented no-op
   (UI/UX §5.6.1). Alt is reserved for future free-placement semantics; the
   initial implementation may leave it unhandled.

**Scope.**
Applies only to `SelectTool` endpoint handle drag. Mid-handle drag, wall
selection, multi-select, and marquee select are unaffected. Wall *drawing*
modifier keys (ADR-009 / ADR-010) are unchanged.

---

## ADR-013 — Heating Zone tool gains the desktop modifier vocabulary

**What.**
The Heating Zone tool (`ZoneDrawTool`), previously click-to-place polygon
only, gains the same Shift / Ctrl / Alt desktop modifier vocabulary that
`WallDrawTool` already exposes (UI/UX §5.3, agent-ui-ux.md §8):

| Modifier | Flag            | Effect on the zone tool |
|----------|-----------------|-------------------------|
| **Shift** | `orthoSnap`     | Constrain the ghost edge from the previous vertex (polygon mode) or the rect drag endpoint to 0°/90°. |
| **Ctrl**  | `rectMode`      | Drag corner-to-corner to commit a four-vertex rectangular zone in one gesture. |
| **Alt**   | `freePlacement` | Disable grid snap for the current vertex/corner; use the raw world coordinate. |

**Why.**
Rooms are overwhelmingly rectangular, so drawing a zone vertex-by-vertex is
tedious and error-prone where a single Ctrl-drag suffices. Keeping the
modifier vocabulary identical to wall drawing means one mental model for the
whole canvas. The shared behaviour is factored into a `ModifierDrawTool`
mixin so the flag-tracking and ortho/grid-snap logic exist once, not copied
into each tool (mirrors the wall/room rect-mode of ADR-009/010/012).

Zone rectangles deliberately do **not** reuse the wall rect-mode corner/
dimension snapping. `SnapService.snapRectCorner` and `snapRectDimension`
exist to deduplicate shared *walls* and match adjacent *room* dimensions
(ADR-009/010) — neither concept applies to a zone polygon, which carries no
wall-graph ownership and no shared-edge promotion. Forcing a zone corner
onto an unrelated room corner would silently distort the heated area.

**Rules.**

1. **Shared modifier tracking.** `ZoneDrawTool` mixes in `ModifierDrawTool`
   and is fed by the existing `wallModifiersProvider` listener in
   `FloorPlanCanvas` — the same path that already drives `WallDrawTool` and
   `SelectTool`. No tool re-implements flag tracking or the ortho helper.

2. **Shift — ortho.** With ≥ 1 committed vertex, the ghost edge from the
   last vertex constrains to H or V via `ModifierDrawTool.applyOrtho`
   (axis closest to the cursor wins). In rect mode the drag endpoint is
   ortho-constrained relative to the drag-start corner. Same algorithm as
   wall drawing.

3. **Alt — free placement.** The current vertex/corner skips grid snap and
   uses the raw world coordinate. Zones never snap to wall endpoints or
   interiors, so the non-Alt path is pure grid snap
   (`SnapService.snapToGrid`), never `SnapService.snap`.

4. **Rect-mode snap pipeline excludes corner/dimension snap.** In rect mode
   both the drag-start (`onPointerDown`) and drag-end (`onDragEnd`) corners
   pass through grid snap (Alt-aware) then ortho **only**.
   `SnapService.snapRectCorner` and `SnapService.snapRectDimension` are
   **not** applied (unlike ADR-009 Rule 1 / ADR-010 for walls).

5. **Commit path is shared.** Both the polygon close (click-near-first /
   double-click) and the rectangle drag-end commit through one
   `_commitZone(polygon, primaryRoom)` helper that builds the `HeatingZone`
   with the spec defaults (tubeSpacing 150 mm, meander, border 100 mm,
   floor heating) and calls `EditorCallbacks.commitZone`. The rectangle is
   a 4-vertex polygon `[tl, tr, br, bl]`. Minimum side length is 100 mm
   (mirrors `WallDrawTool`'s wall-length minimum); a smaller drag is
   discarded with a toast.

6. **Vertex-in-room validation still applies to rect corners.** §5.3 /
   ADR-006 validation is enforced for every rectangle corner exactly as
   for polygon vertices: the primary room is the room containing the
   drag-start corner; all four corners must lie inside the primary room
   **or** a door-connected adjacent room (`_isValidPosition` over
   `_validRooms()`). A rectangle that fails validation, has no primary
   room, or is too small is rejected with a toast and committed nothing.

7. **Ctrl + corner drag reshapes an existing rectangular zone
   (`SelectTool`).** This is the editing counterpart of Rule 5, and the
   zone analogue of ADR-012's room reshape: with a floor zone selected,
   Ctrl-dragging one of its vertex handles reshapes the zone as a
   rectangle — the diagonally-opposite corner is the fixed anchor, the
   dragged corner follows the cursor, and the two adjacent corners
   reposition so the zone stays an axis-aligned rectangle.

   - **Eligibility.** `SelectTool.rectangleZoneCorners` — the polygon
     has exactly 4 vertices forming an axis-aligned rectangle (2 distinct
     x, 2 distinct y within 1 mm). Non-rectangular zones fall back to
     normal single-vertex drag when Ctrl is held.
   - **Ctrl sampling.** `_ctrlHeld` is re-synced from the live hardware
     key state at drag-start and held for the whole drag (mirrors
     ADR-012 Rule 7). The corner/anchor identification reuses ADR-012's
     `identifyRectCornersAroundDrag`.
   - **Snap pipeline.** Pure grid snap only (Alt-aware), exactly as the
     existing single-vertex zone drag and Rule 4 above —
     **no** `snapRectCorner` / `snapRectDimension` / wall-endpoint snap,
     unlike ADR-012's room reshape.
   - **Ghost / commit.** No state mutates during the drag; a
     `RectDrawData` ghost (the same painter as Ctrl-drawing a new zone)
     previews from anchor to raw cursor. On release the snapped
     rectangle is committed via a single `_MoveZoneCommand`
     ("Resize zone") so one Ctrl+Z reverts it.
   - **Validation.** Min 100×100 mm and the ADR-006 vertex-in-room rule
     (`_isZonePointValid`) apply to all four new corners; failure
     rejects with a toast and mutates nothing.
   - **Cursor.** Hovering a corner of a rectangle-eligible selected zone
     while Ctrl is held swaps to the rect-crosshair (same affordance as
     ADR-012 Rule 8; `shouldUseRectCrosshair`).

**Scope.**
Applies to `ZoneDrawTool` (Rules 1–6) and `SelectTool` floor-zone vertex
drag (Rule 7). Wall-zone placement (`WallZonePlaceTool`), polygon-only
behaviour when no modifier is held, non-rectangular zone vertex drag, and
the wall/room rect modes (ADR-009/010/012) are unchanged.

**Verification.**
`flutter analyze` clean; ZDT-1…ZDT-4, WDT-1…WDT-12 and the existing
SelectTool ST / ST-RR suites pass after the `ModifierDrawTool` extraction
and the zone-reshape addition.

---

## ADR-014 — Zone creation is undoable via one shared `_CreateZoneCommand`

**What.**
Every heating-zone *creation* — floor zones from `ZoneDrawTool`
(polygon close, Ctrl-drag rectangle, and the ADR-013 Ctrl+Shift+click
"fill room as one zone" gesture) and wall zones from
`WallZonePlaceTool` — is wrapped in a single `_CreateZoneCommand`
pushed onto `UndoRedoService`. `ZoneDrawTool` and `WallZonePlaceTool`
gain the `undoRedo` constructor dependency that
`WallDrawTool` / `SelectTool` already have. The command's `execute`
adds the zone via `EditorCallbacks.commitZone`; `undo` removes it via
`EditorCallbacks.removeZone(zone.id)`; `redo` re-adds the identical
zone object (same `id`). The command wraps the shared
`_commitZone(polygon, parentRoom)` helper (ADR-013 rule 5), so all
floor-zone gestures produce exactly **one** undo entry regardless of
how the polygon was drawn.

**Why.**
Zone delete and move/reshape were already undoable
(`_DeleteZoneCommand` / `_MoveZoneCommand` in `SelectTool`), but
creation bypassed `UndoRedoService` — `commitZone` mutated editor
state and persisted to the DAO without pushing a command, so Ctrl+Z
could not revert a freshly drawn or filled zone. agent-frontend.md §7
already requires zone drawing to be undoable; this closes the gap.
Wrapping the single shared `_commitZone` path (not each gesture)
guarantees the ADR-013 "one commit path" promise also means "one undo
entry" — fill-room, polygon, and rectangle behave identically under
undo. A freshly created zone has no circuit (`circuitId == null`), so
`removeZone(id)` is a complete inverse; no circuit-detachment
bookkeeping is needed at creation time.

**Rule.**
1. `ZoneDrawTool` and `WallZonePlaceTool` take an `undoRedo`
   (`UndoRedoService`) constructor argument, wired in the
   `FloorPlanCanvas` tool init exactly as the other tools are.
2. The shared `_commitZone` helper and `WallZonePlaceTool`'s zone
   commit route through `undoRedo.execute(_CreateZoneCommand(...))`.
   No zone-creation path calls `commitZone` outside a command.
3. `_CreateZoneCommand`: `execute` → `callbacks.commitZone(zone)`;
   `undo` → `callbacks.removeZone(zone.id)`; the zone object is
   captured so redo restores the identical record. Label via the
   localized `EditorCallbacks.l10n` convention used by the other
   commands.
4. Exactly one command per committed zone. The ADR-013 fill-room
   no-op cases (outside any room; room already has a zone) commit
   nothing and push no command.
5. `_DeleteZoneCommand` / `_MoveZoneCommand` are unchanged; this ADR
   only adds the missing creation command and the tool dependency.

**Scope.**
`ZoneDrawTool`, `WallZonePlaceTool`, and the `FloorPlanCanvas` tool
wiring. `SelectTool` zone delete/move/reshape and all non-zone tools
are unaffected.

**Verification.**
`flutter analyze` clean; new ZDT-5 (create → undo removes the zone)
and ZDT-6 (redo re-adds it) in
`test/widget/tools/zone_draw_tool_test.dart` covering polygon,
rectangle, and fill-room; existing ZDT-1…ZDT-4 still pass.

---

## ADR-015 — Properties-panel resize of a rectangular room (top-left anchored)

**What.**
A rectangle-eligible room (ADR-012 Rule 1 eligibility) shows editable
**Width** and **Height** fields in the room properties panel
(UI/UX §7.2.2), in **centimetres**. Editing a value resizes the room as an
axis-aligned rectangle with the **top-left corner (min-x, min-y) as the fixed
anchor**: changing Width moves the two right-side corners' x; changing Height
moves the two bottom-side corners' y. The four walls are repositioned in one
atomic update reusing the ADR-012 reshape path
(`EditorStateNotifier.updateWall`, ADR-011 mirror sync), grouped into one
`UndoRedoService` command ("Resize room").

**Why.**
ADR-012's corner-drag reshape anchors the corner diagonally opposite the
grabbed one. A panel field has no grabbed corner, so a fixed, deterministic
anchor is required. Top-left (min-x, min-y) is chosen because it is
deterministic, matches reading order, and keeps the room's origin stable
across successive single-dimension edits. Center-anchoring was rejected
because it moves all four edges on every commit, making repeated edits
visually unstable. Typed values are honoured exactly (no grid snap): grid
snap exists to forgive imprecise pointer input, but a typed dimension is
already precise, and snapping 451 cm → 450 cm would silently contradict the
user.

**Rule.**
1. Eligibility = ADR-012 Rule 1 exactly (4 wall segments, all axis-aligned
   within 1 mm, 4 distinct corners, 90° interior angles). For non-eligible
   rooms the Dimensions group is not rendered.
2. `Width = maxX − minX`, `Height = maxY − minY` of the room's corners
   (mm). Displayed as cm = mm / 10; input parsed cm → mm = round(cm × 10).
3. On commit (field submit or focus loss) the four corners become
   `(minX, minY)`, `(minX+W, minY)`, `(minX+W, minY+H)`, `(minX, minY+H)`,
   where the edited extent changes and the other keeps its current value.
4. The four walls update atomically via the existing ADR-012 reshape path
   (`EditorStateNotifier.updateWall` per wall in a single `state.copyWith`,
   ADR-011 mirror sync for shared walls), pushed as one `UndoRedoService`
   command labelled "Resize room" so one Ctrl+Z reverts it.
5. Minimum 100 mm / 10 cm per dimension (ADR-012 Rule 6). A value < 10 cm or
   non-numeric is rejected: the field reverts to the current value and a
   transient toast "Room too small (min 10×10 cm)" is shown; nothing mutates.
6. No grid snap on the typed value — the parsed mm extent is used verbatim
   (contrast ADR-012 corner drag, which snaps the cursor).

**Scope.**
Properties-panel Width/Height fields only. ADR-012 corner-drag reshape,
non-rectangular rooms, and all other panels are unchanged.

**Verification.**
`flutter analyze` clean; widget test: rectangular room shows the fields;
editing Width resizes with top-left fixed; < 10 cm rejected with field
revert + toast; non-rectangular room hides the group; one Ctrl+Z reverts a
resize.

---

## ADR-016 — Move entire room by interior drag; shared walls regenerated on drop

**What.**
In `SelectTool`, pressing inside a room's polygon interior (not on a wall or
a wall handle) and dragging translates the **entire room** rigidly. A press
without drag still only selects (existing §5.6 behaviour). During the drag
the room is treated as fully standalone: every one of its wall segments —
including its own copies of any currently-shared/interior walls — translates
by the grid-snapped delta; the room's `HeatingZone` polygons translate by the
same delta; windows/doors follow their host walls automatically. Adjacent
rooms do **not** move (ADR-011 mirror sync is bypassed for this operation).

On drop (`onDragEnd`) the moved room's walls are reconciled against all other
rooms' walls using the **existing room-draw shared-wall pipeline** — the same
edge-match, promote-to-interior, ADR-001 mirror copy, ADR-003 host-wall split,
and ADR-011 `mirrorId` linkage used when a room is drawn onto an existing one.
The post-drop graph is **identical to deleting the moved room and redrawing
it at the destination** via the normal draw + reconciliation flow.

**Why.**
The user's mental model is "pick the room up and drop it somewhere else."
Keeping neighbours fixed during the drag (vs. dragging them along) is
predictable and avoids cascading multi-room moves. Regenerating shared walls
on drop — rather than trying to preserve mirror links through the move —
reuses one already-proven code path (ADR-001/003/009/010/011) instead of a
second, parallel "move-aware" sync, and guarantees the move can never produce
a graph the draw flow could not. Defining correctness as "same as redraw"
makes the behaviour testable by equivalence.

**Rule.**
1. **Trigger.** `SelectTool`: pointer-down whose world point is inside a
   room polygon (point-in-polygon) and *not* within a wall hit-band or a
   selected wall's handle hit radius. Drag beyond the standard click/drag
   threshold → move; release within threshold → select only (unchanged).
2. **During drag.** Compute `delta = snappedCursor − dragStart`
   (grid-snapped, Alt disables snap, consistent with other tools). Translate
   every `WallSegment` with `roomId == movedRoom`, the room's `polygon`, and
   every `HeatingZone` with `roomId == movedRoom` by `delta`. No mirror sync:
   partner walls of other rooms are untouched. A ghost preview shows the
   translating room each frame.
3. **On drop — detach.** Any wall of the moved room that was `interior`
   with a `mirrorId`: clear `mirrorId`/`adjacentRoomId` on both it and its
   former partner, revert both to `exterior`. The former partner's geometry
   is unchanged (the neighbour stays put).
4. **On drop — reconcile.** Re-commit the moved room's walls through the
   existing shared-wall reconciliation used by room drawing: corner snap
   (ADR-009 Rule 1, 2×grid) and dimension snap (ADR-010) on the translated
   corners; edge-match against other rooms' walls (50 mm both endpoints,
   ADR-009 Rule 2); promote + ADR-001 mirror copy + ADR-011 `mirrorId`
   (ADR-009 Rule 3); host-wall split where a moved endpoint lands mid-wall
   (ADR-003). The `Room` entity identity is preserved — room detection is
   **not** re-run; only geometry and shared-wall links change.
5. **Atomicity / undo.** All translations, detaches, splits, promotions,
   mirror-copy insertions and zone moves for one drag are one
   `state.copyWith` and one `UndoRedoService` command "Move room"; a single
   Ctrl+Z reverts the entire move including regenerated/severed shared walls.
6. **Equivalence (acceptance).** For any destination, the resulting wall/
   room/zone graph must equal the graph produced by deleting the moved room
   and drawing an identical room at that destination.

**Scope.**
`SelectTool` room-interior drag only. Wall-handle drags (§5.6.1), ADR-012/
015 rectangle reshape, zone move/reshape, and marquee select are unchanged.

**Verification.**
`flutter analyze` clean; widget tests: standalone room moves and zones
follow; move next to another room regenerates a shared wall equal to the
redraw result; moving a shared room away detaches and reverts both walls to
exterior; one Ctrl+Z reverts a move (including shared-wall regeneration);
a click without drag still only selects.

---

## ADR-017 — Walls carry thickness; geometry is centerline-anchored; annotations are inner clear

**What.**
`WallSegment` becomes a physical thickness-bearing element rather than a
zero-width line. Two new fields:

| Field | Type | Meaning |
|-------|------|---------|
| `thicknessMm` | `double` | Total wall thickness in mm. Stored on the wall (denormalized) so geometry can be re-anchored when the value changes. |
| `anchorMode`  | `WallAnchorMode` enum (`centerline` / `innerFace` / `outerFace`) | Which face stays fixed when `thicknessMm` changes. |

`startPoint` / `endPoint` are reinterpreted as the wall **centerline**.
`Room.polygon` is the centerline polygon. The inner clear polygon (the
*Lichtmaß* polygon used by EN 12831) and the outer envelope are **derived** by
offsetting the centerline polygon by ±½t per edge, with the corners mitered
along the angle bisector. Neither derived polygon is persisted.

`Project` gains three thickness defaults:

| Field | Default |
|-------|---------|
| `defaultExteriorWallThicknessMm`  | 240 |
| `defaultInteriorWallThicknessMm`  | 120 |
| `defaultPartitionWallThicknessMm` | 100 |

A wall's `thicknessMm` source-of-truth:
1. If `constructionId != null` → `sum(MaterialLayer.thicknessMm)` of that
   construction. Updated whenever the construction's layers change.
2. Else → `Project.default<WallType>WallThicknessMm` for the wall's
   `wallType`. Updated whenever the project default changes.

All canvas dimension annotations (room width/height labels, wall length
labels, properties-panel Width/Height fields per ADR-015) show **inner clear**
values, per EN 12831 simplified method. There is no inner/outer toggle in
project settings — outer envelope is a derived quantity used for rendering
the wall body and for export, never as an input dimension.

**Why.**
EN 12831 simplified method defines room area, room volume, and wall heat-loss
area in terms of inner clear dimensions (*Lichtmaß*) — the German/Austrian
heat-load convention. Pinning the displayed dimension to inner clear means
the input the planner types matches the input the calculation consumes; no
mode flag, no risk that toggling a display setting moves any wall.

Centerline storage is the only representation in which an ADR-001 shared-wall
pair can share a single, unambiguous geometric anchor that both rooms agree on.
Storing inner-face geometry would force one of the two rooms to "own" the wall
and would break ADR-001's symmetry guarantee.

Per-wall anchor mode gives predictable thickness-change behaviour:
- Exterior wall (one room): default `innerFace` — thickening pushes the outer
  envelope outward; the planned room dimension is preserved (matches the
  new-build / regulatory planning workflow).
- Shared interior wall (two rooms, ADR-001 mirror pair): **forced to**
  `centerline` — both adjoining rooms each lose ½Δt of inner space
  symmetrically. `innerFace` and `outerFace` are undefined for shared walls
  (whose "inner"?), so the dropdown is disabled for these walls.
- Standalone partition wall (single room, interior type, no mirror): default
  `centerline`; user may override.

Storing `thicknessMm` (rather than always re-deriving it) is necessary so the
re-anchor step has a defined Δt = new − old when construction layers or the
project default change. It is denormalised against `constructionId` and
maintained by the same code path that mutates either source.

**Rule.**

1. **Storage.** `WallSegment` adds `thicknessMm` (non-null `double`) and
   `anchorMode` (non-null `WallAnchorMode`, default per Rule 2). Drift table
   `wall_segments` adds `thickness_mm REAL NOT NULL DEFAULT 0` and
   `anchor_mode INTEGER NOT NULL DEFAULT 0`. **No migration is provided** —
   this is a dev-stage change; existing project DBs may be discarded.

2. **Default `anchorMode` on creation.**
   - `WallType.exterior` → `innerFace`
   - `WallType.interior` → `centerline`
   - `WallType.partition` → `centerline`

3. **`anchorMode` constraint for shared walls.** Whenever
   `WallSegment.mirrorId != null`, `anchorMode` is **forced** to `centerline`
   on both partners. The wall properties dropdown for that field is disabled
   on shared walls and shows the explanatory tooltip
   *"Shared interior walls always pivot on the centerline."*

4. **Derived geometry.** Two new providers:
   - `roomInnerPolygonProvider(roomId)` — returns the inner clear polygon,
     computed by offsetting `Room.polygon` by `−½t` per edge using each
     wall's `thicknessMm`, with corners mitered along the angle bisector.
   - `roomOuterPolygonProvider(roomId)` — analogous, offset `+½t`.

   Both rebuild when any of the room's walls or their `thicknessMm` change.
   Neither polygon is persisted.

5. **Inner polygon is authoritative for area / volume / wall-area.**
   - `roomAreaM2Provider(roomId)` and `roomVolumeM3Provider(roomId)` use the
     inner polygon (replaces the current use of `Room.polygon` directly).
   - Each wall's net heat-loss area in `roomHeatDemandProvider` uses its
     **inner edge length** (the edge of the inner polygon that corresponds
     to that wall) × `Floor.heightMm`, minus opening areas as before.
   - Per-wall inner edge lengths come from a new helper
     `GeometryEngine.roomFaceEdges(walls, side: inner|outer)` returning a
     `Map<wallId, edgeLengthMm>`.

6. **Thickness change → centerline re-anchor.** When `thicknessMm` updates
   on a wall (cascade from construction-layer edit, construction (re)assign,
   construction clear, or project-default change for unassigned walls of
   that type), the wall's centerline is repositioned by `Δt = new − old`:

   - `centerline` → no shift; both faces move outward by ½Δt each.
   - `innerFace`  → centerline shifts **outward** (away from the room
     interior) along the wall's outward normal by ½Δt; inner face stays put.
   - `outerFace`  → centerline shifts **inward** by ½Δt; outer face stays put.

   "Outward" is determined by `Room.polygon` winding order. For shared walls
   (`anchorMode = centerline`, forced) the centerline never shifts and ADR-011
   mirror sync keeps both copies in lockstep.

7. **ADR-011 mirror sync extension.** Fields that sync between mirror partners
   are extended to include `thicknessMm` and `anchorMode`. Both partners
   always carry identical values for these two fields (and `anchorMode` is
   always `centerline` for shared walls per Rule 3).

8. **Shared-wall promotion: non-default config wins.** When an existing wall
   is promoted to interior (ADR-003 wall-commit split, ADR-009 Rule 3
   rect-mode edge match, ADR-016 room-move reconciliation), the shared
   wall's `thicknessMm` and `constructionId` are resolved as:

   a. Both sides default (each side has `constructionId == null` AND
      `thicknessMm == projectDefault[wallType]`) → use
      `projectDefault[interior]`, `constructionId = null`,
      `anchorMode = centerline`.
   b. Exactly one side non-default → adopt that side's `thicknessMm`,
      `constructionId`, and set `anchorMode = centerline`.
   c. Both sides non-default and equal (`constructionId` matches and
      thicknesses match) → preserve.
   d. Both sides non-default and different → adopt the **existing** (not the
      newly drawn / just moved) wall's `thicknessMm` and `constructionId`,
      and emit a `WarningSeverity.warning` validation result:
      *"Shared wall construction conflict — adopted [name] from [room]; review."*

   In all cases the shared pair is `anchorMode = centerline` (Rule 3).

9. **Project default change.** When the user edits any
   `default<WallType>WallThicknessMm` in settings, every wall with
   `constructionId == null` AND matching `wallType` has its `thicknessMm`
   updated and its centerline re-anchored per Rule 6. Walls with an explicit
   `constructionId` are unaffected (their thickness is sourced from the
   construction).

10. **Visual / UX.**
    - `WallPainter` renders each wall as a filled rectangle of
      `thicknessMm × wallLength` along the centerline, with corners mitered
      along the angle bisector at every junction.
    - `AnnotationPainter` labels each wall with its **inner edge length**
      (not centerline length).
    - The properties-panel Width/Height fields (ADR-015) are interpreted as
      **inner clear** dimensions; back-computing the four centerline corners
      uses the wall thicknesses on each side.
    - ~~When a wall is selected, a small lock/pin glyph is drawn on the
      anchored face (inner face for `innerFace`, outer face for `outerFace`).
      For `centerline` (and therefore every shared wall) no glyph is drawn —
      centerline is the implicit default.~~ **Superseded (UX):** the
      anchored-face pin glyph was removed at user request — it read as a
      pressable "button" and cluttered the selected wall. `WallPainter` no
      longer renders it (the `selectedWallId` / `pinFill` / `pinStroke` /
      `worldToScreen` parameters were dropped). The anchor mode still drives
      the thickness re-anchor math (Rule 6); it just has no on-canvas glyph.

11. **No backwards compatibility.** Migration of pre-ADR-017 project data is
    out of scope. The expectation is that development databases are
    recreated. `.hsp` files exported before this ADR cannot be imported.

**Scope.**
Replaces the prior zero-thickness wall model. Affects `WallSegment` and
`Project` schemas; the wall painter; annotation painter; wall draw / select
tools; the construction editor (thickness-change cascade); the settings
screen (defaults); heat-demand and area providers; ADR-011 mirror sync
fields; and the shared-wall promotion paths in ADR-003 / ADR-009 / ADR-016.
Other ADRs (004, 006, 007, 008, 012, 013, 014, 015) are unchanged in intent;
ADR-015 input semantics remain "inner clear" — that is now the only mode.

**Verification.**
Defined per implementation prompt. Acceptance criteria include: drawing a
4×5 m exterior-walled room shows the inner annotation as 4000×5000 mm with
the outer envelope at 4240×5480 mm (for a 240 mm wall thickness), and
increasing the wall thickness to 300 mm leaves the inner annotation
unchanged while the outer envelope grows to 4300×5600 mm; assigning a
construction to one room's exterior wall, then drawing an adjacent room
against it, produces a shared wall that inherits that construction
(promotion rule 8b).

---

## ADR-018 — Splitting a rectangular heating zone in two equal halves

**What.**
A `HeatingZone` whose polygon is a 4-vertex axis-aligned rectangle (eligibility
via `SelectTool.rectangleZoneCorners`, ADR-013 Rule 7) can be split into two
equally-sized rectangular child zones via two entry points:

1. **Zone tool (`ZoneDrawTool`) — double-click on an existing zone.** Splits
   along the perpendicular bisector of the **longer side** of the parent
   rectangle (ties — `W == H` within 1 mm — split vertically, i.e. bisect X).
   Disambiguation against the existing polygon-close double-click (UI/UX §5.3
   step 4, ADR-013 Rule 5): if the in-progress polygon buffer holds **≥ 1**
   committed vertex, the double-click still closes the polygon; only when the
   buffer is empty does the double-click route to the zone-under-cursor
   actions.

2. **Select tool (`SelectTool`) — right-click on an existing zone.** Opens a
   context menu with *Delete*, *Split vertically*, *Split horizontally*. The
   two split items render **disabled** on non-rectangular zones with the
   tooltip *"Splitting is only available for rectangular zones."*

The Zone tool double-click is also extended so that a double-click on **empty
room interior** triggers the existing fill-room path (the same code path as
`Ctrl+Shift+click`, ADR-014). Double-click on a non-rectangular zone shows a
transient toast *"Splitting is only available for rectangular zones."* and
mutates nothing.

**Why.**
Planners frequently lay out one rectangle covering a room, see it render red
(output < demand, ADR-004), and need two zones — each with its own circuit —
to double the available tube length and heat output. Manual re-draw of two
half-rectangles is fiddly at the shared boundary (snap tolerances can leave a
hairline gap or overlap) and forces re-typing every zone setting. A
one-gesture split guarantees the two halves are mathematically equal, share
the boundary exactly, and inherit every parent setting verbatim.

Two entry points serve two distinct mental states:
- The **double-click** path is the in-flow shortcut. "Smart default" =
  longest-axis bisection produces children whose aspect ratio is closer to 1:1
  than the parent's, which gives the BVF tube-routing simpler meanders.
  Shorter-axis splitting would yield two narrow strips, rarely useful.
- The **right-click** path is deliberative — open menu, choose direction —
  matching the Select-tool convention of right-click context menus on existing
  elements (cf. wall-handle right-click disconnect, UI/UX §5.6.1) and the
  user's mental model "I'm inspecting and editing".

Routing the right-click menu through Select tool (not Zone tool) reflects the
architectural split already in place: Zone tool owns *creation* gestures
(polygon, rect drag, fill-room); Select tool owns *mutations* on existing
zones (move, resize per ADR-013 Rule 7, delete). The double-click in Zone
tool is the deliberate exception — a fast "act on what I see" shortcut tied
to the tool's purpose, with the disambiguation rule making both behaviours
unambiguous without a modifier key.

The split coordinate is **not** grid-snapped: snap would silently break the
equal-area guarantee that defines the gesture. The user wants two halves, not
two near-halves that happen to land on the grid.

**Rule.**

1. **Eligibility.** A zone is splittable iff `SelectTool.rectangleZoneCorners`
   returns non-null on its polygon (4 vertices, axis-aligned within 1 mm, 2
   distinct x and 2 distinct y per ADR-013 Rule 7). Wall zones
   (`zoneType = wall`) are never splittable; the right-click menu items remain
   hidden (not just disabled) for wall zones.

2. **Split geometry.** Let the parent rectangle have inner corners
   `tl = (minX, minY)`, `tr = (maxX, minY)`, `br = (maxX, maxY)`,
   `bl = (minX, maxY)`, width `W = maxX − minX`, height `H = maxY − minY`,
   midpoints `mx = (minX + maxX) / 2`, `my = (minY + maxY) / 2`.
   - *Vertical split:* child A `[tl, (mx, minY), (mx, maxY), bl]`,
     child B `[(mx, minY), tr, br, (mx, maxY)]`.
   - *Horizontal split:* child A `[tl, tr, (maxX, my), (minX, my)]`,
     child B `[(minX, my), (maxX, my), br, bl]`.
   - No grid snap on the midpoint.

3. **Direction selection.**
   - Zone tool double-click → split the longer dimension (`W ≥ H` →
     vertical; `H > W` → horizontal; equal within 1 mm → vertical).
   - Select tool context menu → user picks explicitly.

4. **Minimum-size guard.** The bisected dimension of each child must be
   ≥ 100 mm (ADR-013 Rule 5). If `W / 2 < 100 mm` (vertical) or
   `H / 2 < 100 mm` (horizontal), the split is rejected with a transient
   toast *"Zone too small to split (each half must be ≥ 100 mm)."* Nothing
   mutates.

5. **Inherited fields.** Both children copy every settings field from the
   parent verbatim: `tubeSpacingMm`, `tubeType`, `flooringMaterialId`,
   `layoutPattern`, `borderMm`, `zoneType`, `roomId`. Each child receives a
   fresh UUID `id`.

6. **Circuit ownership.** If `parent.circuitId == null`, both children also
   have `circuitId == null`. Otherwise:
   - Look up the parent's `HeatingCircuit`. Find the *zone-end* of its
     supply/return polyline — the polyline endpoint that lies inside the
     parent zone polygon (point-in-polygon).
   - The child whose polygon contains that endpoint inherits the parent's
     `circuitId`. The circuit's recorded zone reference (`HeatingCircuit`'s
     zone FK) is updated to that child's id.
   - The other child has `circuitId = null` and therefore renders as
     **unconnected** (red-hatched, ADR-004 state 1).
   - Edge case: if neither child's point-in-polygon contains the endpoint
     (e.g. float drift), the **first** child (child A in Rule 2 — left for
     vertical, top for horizontal) keeps the circuit.

7. **Atomic commit / undo.** All mutations for one split — remove parent
   zone, insert both children, update circuit zone-FK — happen in a single
   `state.copyWith(...)` and are wrapped in one `_SplitZoneCommand`. The
   command lives alongside `_CreateZoneCommand` / `_MoveZoneCommand` /
   `_DeleteZoneCommand` (Frontend agent §7.1).
   - `execute`: delete parent, insert both children, reassign circuit
     zone-FK to the inheriting child.
   - `undo`: delete both children, re-insert the captured parent (same `id`,
     same fields), restore circuit's zone-FK to the parent.
   - `redo`: replay `execute` (children captured with their original ids so
     re-insertion is identical).
   - Both `ZoneDrawTool` and `SelectTool` push the command via their
     existing `undoRedo` dependency (already injected per ADR-014). One
     Ctrl+Z reverts the entire split.

8. **Hover preview (Zone tool only).** When `ZoneDrawTool` is active, its
   polygon buffer is empty, and the raw cursor world-point lies inside an
   existing **rectangular** zone, the interaction layer draws a dashed line
   along the perpendicular bisector of the **longer side** of that zone
   (the line a double-click would cut along), in `selectionHighlight`
   colour at 50 % opacity, 2 px stroke, dash 6 / gap 4 (world units scaled
   for screen). Non-rectangular zones show no preview. The preview is
   purely visual — it does not affect commit semantics.

9. **Context menu items (Select tool).** A right-click on a heating zone
   (any zone type) shows *Delete* (existing implicit gesture, now explicit
   in the menu). For floor zones only, two additional items render below
   *Delete*: *Split vertically* and *Split horizontally*. Both are
   **disabled** when the right-clicked zone is non-rectangular, with the
   tooltip *"Splitting is only available for rectangular zones."*
   On macOS, `Ctrl+click` produces the same menu (standard Cocoa pattern,
   already used by ADR-009 wall-handle disconnect).

10. **Tablet equivalence.**
    - Zone tool double-tap behaves identically to desktop double-click
      (same disambiguation rule on the polygon buffer).
    - Select tool long-press (500 ms per UI/UX §8) opens the same context
      menu as desktop right-click.

11. **No mutation of fill-room semantics.** The existing `Ctrl+Shift+click`
    fill-room path (ADR-014) is unchanged. Double-click on empty room
    interior is an **additional** entry point routing through the same
    `_CreateZoneCommand` and the same fill-room geometry (the room's inner
    polygon per ADR-017).

**Scope.**
`ZoneDrawTool` (Rule 1 double-click + Rule 8 hover preview + Rule 11 empty-
room double-click), `SelectTool` (Rule 1 right-click context menu), and a
new `_SplitZoneCommand` shared by both tools (Rule 7). Wall zones, non-
rectangular zones, the polygon-close double-click during active drawing,
the wall/room rect modes (ADR-009 / ADR-010 / ADR-012), and
`_CreateZoneCommand` / `_MoveZoneCommand` / `_DeleteZoneCommand` are
unchanged.

**Verification.**
`flutter analyze` clean. New tests:
- `test/widget/tools/zone_draw_tool_test.dart`:
  - ZDT-7: double-click on rectangular zone (W > H) splits vertically; the
    two children share an exact midpoint edge; both inherit parent settings.
  - ZDT-8: double-click on a non-rectangular zone (5+ vertices or non-axis-
    aligned) emits the splittability toast and mutates nothing.
  - ZDT-9: double-click on empty room interior creates a zone equivalent to
    the existing `Ctrl+Shift+click` fill-room path (same polygon, single
    undo entry).
  - ZDT-10: hover preview renders dashed bisector on rectangular zones,
    no preview on non-rectangular zones.
- `test/widget/tools/select_tool_test.dart`:
  - ST-S1: right-click on a rectangular zone shows enabled split items.
  - ST-S2: right-click on a non-rectangular zone shows disabled split items
    with the explanatory tooltip.
  - ST-S3: *Split vertically* on a zone with a connected circuit leaves the
    `circuitId` on whichever child contains the pipe terminus; the other
    child renders unconnected.
  - ST-S4: split rejected with toast when either half would be < 100 mm;
    nothing mutates.
  - ST-S5: Ctrl+Z after split restores the parent zone with its original
    `circuitId` and circuit zone-FK.

---

## ADR-019 — Deleting a room cascades to its walls, zones, openings; mirror partners revert to exterior

**What.**
Deleting a `Room` (Select-tool Delete on a selected room, or Ctrl/⌘+Delete /
Backspace when a room is selected) removes the room entity *and* every
child element keyed by `roomId`: all of its `WallSegment`s, all of its
`HeatingZone`s, and every `WindowElement` / `Door` hosted on those walls.
For each removed wall whose `mirrorId != null`, the surviving partner is
reverted in place: `wallType` becomes `exterior`, `mirrorId` /
`adjacentRoomId` are cleared, `anchorMode` is set to `innerFace`
(ADR-017 Rule 2 default for exterior walls), while `thicknessMm` and
`constructionId` are preserved verbatim (the partner's physical wall is
unchanged — only its sharing relationship is severed).

The whole cascade — child removal, partner revert, room removal — is one
atomic `state.copyWith` and one `UndoRedoService` "Delete room" command;
a single Ctrl+Z restores the room, every deleted child, and every
mirror link to its pre-delete state.

**Why.**
Until ADR-019 the delete path called `clearRoomIdOnWalls` and left walls
in memory with an empty `roomId`. These orphans rendered nowhere (the
wall painter only mitres room-assigned walls into corners) yet still
participated in snap candidates, room-detection BFS, and validation,
which led to drifting state and confusing repeats of "Restore room"
attempts. Cascading the delete matches the intuitive mental model
("delete the room, take its walls with it") and gives the snapshot-
based undo a clean inverse: replace the post-delete state with the
pre-delete state and DAO writes follow.

Partner revert is required because ADR-017 Rule 3 forces shared walls
to `centerline`. Once the partner is alone it is conceptually a fresh
exterior wall and must follow Rule 2 (`innerFace`); leaving it at
`centerline` would mean the next thickness change would push the
neighbour's inner clear dimension inward, contradicting the planning-
workflow promise that the planner's typed dimension is what's kept.
The partner's `thicknessMm` and `constructionId` are preserved because
those are physical properties — the wall is the same wall, just no
longer shared.

**Rule.**

1. **Cascade scope.** On `destroyRoom(roomId)`:
   - Every wall with `roomId == roomId` is removed.
   - Every zone with `roomId == roomId` is removed.
   - Every window / door whose `wallSegmentId` references a removed
     wall is removed.
   - The room entity itself is removed.

2. **Mirror revert.** For each removed wall with `mirrorId != null`,
   locate the partner by id in the remaining walls (the partner's
   `roomId` is the neighbour and therefore not in the delete set) and
   update it in-place to:
   - `wallType = WallType.exterior`
   - `mirrorId = null`
   - `adjacentRoomId = null`
   - `anchorMode = WallAnchorMode.innerFace`
   - `thicknessMm` and `constructionId` unchanged.

3. **Atomicity.** All of the above happens in a single `state.copyWith`
   so the wall painter, room detection, and validation only ever see the
   pre- or post-delete graph — never an intermediate state with the
   room gone but its walls still present.

4. **Undo.** The delete command snapshots the pre-delete (walls, rooms,
   zones, windows, doors) and post-delete tuples; `execute` replaces with
   the post-delete tuple, `undo` replaces with the pre-delete tuple. A
   single Ctrl+Z restores the room and every cascaded child, with
   mirror links intact on both partners. DAO writes follow the same
   eventual-sync pattern as `_MoveRoomCommand` (ADR-016 Rule 5).

5. **Heating circuits.** Circuits referencing a removed zone via
   `zoneId` are left with a dangling reference; this is the existing
   behaviour and is out of scope for ADR-019. Validation already flags
   unconnected circuits via `ADR-004`'s zone-state machine. A future
   ADR may extend the cascade to also remove orphan circuits.

**Scope.**
Affects `EditorStateNotifier.destroyRoom`-equivalent path,
`EditorCallbacks.destroyRoom` / `restoreRoom`, and
`SelectTool._DeleteRoomCommand`. Wall deletion (ADR-001 mirror-pair
deletion) and zone / opening deletion in isolation are unchanged.

**Verification.**
`flutter analyze` clean; new widget tests:
- `test/widget/tools/delete_room_test.dart`:
  - DR-1: deleting a standalone room removes the room, all its walls,
    and all its zones; nothing else changes.
  - DR-2: deleting a room with a shared wall removes the deleted
    room's wall, leaves the neighbour's partner as a standalone
    `exterior` wall with cleared `mirrorId` / `adjacentRoomId`,
    `anchorMode = innerFace`, and unchanged `thicknessMm` /
    `constructionId`.
  - DR-3: a single Ctrl+Z after either case restores the room, every
    deleted child, and the mirror link on both partners.


## ADR-020 — Project default wall material; every new wall carries a single-layer auto-default construction

**What.**
`Project` gains three new material-id fields:

| Field | Default |
|-------|---------|
| `defaultExteriorMaterialId`   | `mat-016` (Vertical coring brick) |
| `defaultInteriorMaterialId`   | `mat-016` |
| `defaultPartitionMaterialId`  | `mat-016` |

`WallConstruction` gains a boolean `isAutoDefault` (default `false`),
orthogonal to the existing `isPreset` flag but mutually exclusive
(`isAutoDefault = true` implies `isPreset = false`).

Every code path that creates a `WallSegment` — room-draw polygon tool,
rect-mode, ADR-003 host-wall split, ADR-009 Rule 3 promotion, ADR-016
reconciliation re-creation — also spawns a fresh `WallConstruction`
with `isAutoDefault = true, isPreset = false` and exactly one
`MaterialLayer` whose `materialId` equals the project default for the
wall's `wallType` and whose `thicknessMm` equals the matching project
default. The wall's `constructionId` is linked to that new
construction; the wall's `thicknessMm` equals the layer sum (ADR-017
Rule 1 case 1). Rule 1 case 2 (the bare-thickness project-default
fallback) remains as a safety net for any wall that might still have
`constructionId == null`.

The wall construction editor flips `isAutoDefault` to `false` on any
layer-affecting mutation (add layer, remove layer, change material,
change thickness). The "Load preset" path replaces
`WallSegment.constructionId` with a fresh non-auto-default copy of the
preset; the orphaned auto-default construction is deleted in the same
save transaction. A no-op edit (open then close without changes)
leaves the flag alone. The editor enforces a minimum of one layer per
construction.

Project Settings exposes three new material dropdowns next to the
existing thickness fields. Changing any default cascades to every
auto-default construction layer of the corresponding `wallType` and is
recorded as a single `UndoRedoService` "Update project defaults"
command.

**Why.**
Before ADR-020 the wall properties panel's construction section was
empty for un-assigned walls. Walls already adopted the project default
*thickness* (ADR-017 Rule 1 case 2), so the inner-clear annotation and
heat-demand calculations were correct, but the construction-editor
field was visually empty, which was inconsistent with the rest of the
panel. Auto-spawning a construction at draw time gives every wall a
real layer stack with sensible material defaults, matching the user
mental model of "a wall always has a build-up." Marking these
constructions with `isAutoDefault = true` lets us cascade Project
Settings changes without disturbing user-customised assemblies, and
gives the editor a clear signal for the "this construction was never
edited" UI state.

The single source-of-truth for material lookups is the catalog stream
(`materialEntriesProvider`); the auto-default construction's layer
copies thermal conductivity / density / specific heat from the catalog
at spawn time so U-value calculations are consistent with the
non-auto-default path.

**Rule.**

1. **Project model — three new material fields.** Add
   `defaultExteriorMaterialId`, `defaultInteriorMaterialId`,
   `defaultPartitionMaterialId` to the `Project` freezed model and to
   the `projects` Drift table. All three initial defaults are
   `mat-016` (Vertical coring brick).

2. **Construction model — `isAutoDefault` flag.** Add
   `isAutoDefault: bool` (default `false`) to the `WallConstruction`
   freezed model and to the `wall_constructions` Drift table.
   Orthogonal to `isPreset`; `isAutoDefault = true` implies
   `isPreset = false`.

3. **Wall creation always generates a construction.** Every code path
   that creates a `WallSegment` also creates a fresh `WallConstruction`
   with `isAutoDefault = true, isPreset = false` and one
   `MaterialLayer` whose `materialId = project.default<WallType>MaterialId`
   and `thicknessMm = project.default<WallType>WallThicknessMm`. The
   wall's `constructionId` is linked to that new construction; its
   `thicknessMm` equals the layer sum. Rule 1 case 2 stays as a
   safety net only.

4. **Edit clears auto-default.** Any mutation through the construction
   editor that changes the construction's contents sets
   `isAutoDefault = false` on save. A no-op edit (open + close without
   changes) leaves the flag alone. Loading a preset replaces
   `WallSegment.constructionId` with a fresh non-auto-default instance
   copied from the preset; the orphaned auto-default construction is
   deleted in the same transaction.

5. **Construction editor must require at least one layer.** Removing
   the last layer is disallowed; the UI surfaces a localised toast
   instead.

6. **Project default material change → cascade.** When the user changes
   any `default<WallType>MaterialId` in Project Settings, every
   `WallSegment` whose `wallType` matches AND whose construction has
   `isAutoDefault = true` has its single layer's `materialId` (and
   thermal conductivity / density / specific heat copied from the new
   `MaterialEntry`) updated. Walls with `isAutoDefault = false` are
   untouched.

7. **Project default thickness change → cascade (reinterprets ADR-017
   Rule 9).** Same predicate: walls of matching `wallType` whose
   construction has `isAutoDefault = true` get their single layer
   `thicknessMm` updated and the wall is re-anchored per ADR-017
   Rule 6. ADR-017 Rule 9 is effectively replaced by this rule — its
   safety-net behaviour is retained for any `constructionId == null`
   wall that might still exist.

8. **Shared-wall promotion (ADR-017 Rule 8) — auto-default
   propagation.** Cases a–d unchanged in outcome. The surviving shared
   wall's `isAutoDefault` follows whichever side was adopted:
    - 8a → `true` (both sides auto-default; mirror copies share a
      single new auto-default construction; the prior auto-default
      constructions are orphaned and deleted in the same transaction);
    - 8b/c → adopted side's `isAutoDefault` value;
    - 8d → existing wall's `isAutoDefault` value.

   ADR-001 mirror partners share `constructionId` (single construction
   row) per existing behaviour. A wall with `constructionId == null`
   is treated as auto-default for the purposes of this rule (legacy
   safety-net path).

9. **UI — Project Settings screen.** Add three dropdowns ("Default
   exterior material", "Default interior material", "Default partition
   material") next to the existing default-thickness fields, populated
   from `materialEntriesProvider`. Each material change commits via
   `_ChangeDefaultMaterialCommand`; each thickness change commits via
   the existing `_ChangeDefaultWallThicknessCommand` (now extended to
   snapshot constructions / layers too). Both commands are labelled
   "Update project defaults" in the undo stack.

10. **UI — wall properties panel.** Every wall now carries a real
    construction, so the placeholder "(project default)" suffix on the
    thickness display is removed. The "Add construction" / "Edit
    construction" button label conditional is kept only as a safety
    net for the legacy `constructionId == null` branch.

11. **L10n.** Add German + English strings for the three new dropdown
    labels (`defaultExteriorMaterial`, `defaultInteriorMaterial`,
    `defaultPartitionMaterial`), the section heading
    (`defaultWallMaterials`), the descriptive tooltip
    (`defaultWallMaterialsDesc`: *"Changes here update walls you have
    not customised individually"*), and the Rule 5 toast
    (`layerStackRequiresOneLayer`: *"A construction must have at
    least one layer."*).

**Scope.**
Affects `Project` and `WallConstruction` schemas; the project settings
dialog; the wall construction editor; the wall properties panel;
`EditorStateNotifier`'s wall-creation paths
(`addWall`, `commitWallWithSplit`, `addRoomFromDetection`); and the
shared-wall promotion logic. Does not change ADR-001 (shared walls
remain two `WallSegment`s sharing a single `WallConstruction`),
ADR-016, or ADR-017 semantics. The in-flight `isPreset` work is
orthogonal and is preserved.

**Verification.**
Defined per implementation prompt. Acceptance criteria include:
- Drawing a 4×5 m room shows four walls, each with a non-null
  `constructionId` pointing at a single-layer auto-default
  construction whose `materialId` and `thicknessMm` match the project
  defaults for `WallType.exterior`.
- Changing `defaultExteriorMaterialId` in Project Settings updates
  only the auto-default exterior walls' single-layer material;
  user-edited (`isAutoDefault == false`) walls and walls of other
  `wallType`s remain untouched. Ctrl+Z reverts both the project field
  and the cascaded layer rows in one step.
- Changing `defaultExteriorWallThicknessMm` updates the auto-default
  exterior layers' thickness and re-anchors the owning walls per
  ADR-017 Rule 6.
- Editing any layer in the construction editor flips
  `isAutoDefault` to `false` on save.
- Loading a preset over an auto-default construction yields a fresh
  non-auto-default copy on the wall and orphan-deletes the original
  auto-default row.
- Shared-wall promotion under Rule 8a yields a wall with
  `isAutoDefault = true`; Rule 8b yields a wall whose `isAutoDefault`
  matches the adopted side.

## ADR-021 — Custom material library is a user-pickable JSON file mirrored into the in-app DB

**What.**
Custom materials live in a single JSON file at a user-chosen path
stored in `AppPreferences.customMaterialLibraryPath`. On launch and on
every change to that path the app runs a *sync pass* that re-seeds the
`material_entries` table from the file. Every add / edit / delete from
the UI writes through to both SQLite (the source of truth for queries
and `materialsProvider`) and the JSON file (the source of truth for
sharing the library between users / installs). Built-in materials
seeded from `assets/materials.json` remain `isBuiltIn = true` and are
read-only.

**Why.**
- The user picked an explicit shareable file (Dropbox / network share /
  USB) over both an OS app-data folder and an in-`.hsp` bundle. A
  user-pickable path lets one team share one file without hard-coding a
  per-OS location.
- The picker dropdown already groups by category and feeds off
  `materialsProvider`. Mirroring custom entries into the same table
  keeps the picker uniform — no two-pass UI logic, no special-casing
  search and grouping.
- JSON is human-readable, easy to diff, and matches the existing
  `assets/materials.json` shape, so the same `MaterialEntry.toJson`
  serialisation is reused.
- `MaterialEntry.isBuiltIn` already exists in the model (architect §5.3)
  exactly for this distinction; no schema change to that table.

**Rule.**

1. **AppPreferences field.** `AppPreferences` gains
   `customMaterialLibraryPath: String?`. `null` means "use the default
   location" (Rule 14) — **not** "no library". A non-null value is an
   explicit user override (e.g. a Dropbox path). Persisted alongside
   `gridSpacingMm` / `lastOpenedProjectId` per existing preferences
   pattern.

2. **File schema.** JSON, UTF-8:

   ```json
   {
     "version": "1.1",
     "materials": [
       {
         "id": "uuid-v4",
         "name": "...",
         "categoryPath": ["Insulation boards", "Wood fibre"],
         "manufacturer": "...",
         "lambdaDefault": 0.035,
         "densityDefault": 50,
         "specificHeatDefault": 1030,
         "source": ""
       }
     ]
   }
   ```

   Field names match `MaterialEntry.toJson()` exactly. `isBuiltIn` is
   not stored in the file; on read it is forced to `false`.

   **Versioning.**
   - `"version": "1.1"` (current) — `categoryPath` is the taxonomy
     field per ADR-022.
   - `"version": "1.0"` (legacy) — entries carry `category` and
     `subcategory` strings. Readers migrate on load:
     `categoryPath = [category, subcategory]`. The first subsequent
     write rewrites the file at `"1.1"`.
   - Unknown higher-version files: read what we can, warn the user,
     per the same forward-compat rule used for `.hsp` (architect
     §7.4).

3. **Identifier.** Each entry's `id` is a UUID v4 generated at add time
   in the dialog. It is the stable identifier across the JSON file and
   the SQLite row — never regenerate it on sync.

4. **Sync pass.** On app launch and on every change to
   `customMaterialLibraryPath`:
   1. Resolve the *effective path*: the stored value if non-null,
      otherwise the default path from Rule 14.
   2. Delete all rows in `material_entries` where `isBuiltIn = false`.
   3. Ensure the effective path's file exists per Rule 14 (create the
      empty skeleton if missing).
   4. If the file exists and parses: insert each entry into
      `material_entries` with `isBuiltIn = false`, preserving its
      `id`.
   5. If the file is unreadable or malformed: keep step 2's empty
      custom set, surface a toast ("Custom material library could
      not be loaded — check the path in Settings"), do **not** clear
      `customMaterialLibraryPath` automatically (the user fixes it
      from Settings).

5. **CRUD write-through.** Add / edit / delete operations from the UI
   route through `CustomMaterialLibraryService.create` /
   `.update` / `.delete`. Each operation:
   1. Mutates the SQLite row.
   2. Rewrites the **entire JSON file** from the current set of
      `isBuiltIn = false` rows (simple full-file write — atomic via
      write-temp-then-rename per platform conventions; no append, no
      partial diff).
   3. If the file write throws, rolls the SQLite change back and
      surfaces an error toast. The two stores must stay in sync.

   The full-file-rewrite approach is intentional: the file is small,
   diffing is cheap, and it guarantees the file always reflects the
   complete current library — no chance of partial writes leaving
   stale entries behind.

6. **Concurrent edits across users.** Last-write-wins; no locking.
   Settings exposes a "Reload from file" button that re-runs the sync
   pass on demand. There is no background watcher or auto-reload in
   v1 — users who share a file accept the trade-off that two
   simultaneous edits can overwrite each other.

7. **Delete blocked while referenced.** Before deleting a custom
   material, query for any `MaterialLayer.materialId == thisId`. If
   the count is > 0, abort the delete and show a dialog listing the
   affected constructions:

   ```
   "Custom Hempcrete" is used in 3 layers:
     - Exterior Wall South
     - Living Room Floor
     - Bathroom Ceiling
   Remove or reassign those layers first, then try again.
   ```

   No FK-orphan path in v1. Rationale: keeps the data model unchanged
   (no nullable FK migration) and avoids silently breaking
   constructions a user may not be looking at right now.

8. **Editing preserves captured values.** Changing a custom material's
   `lambdaDefault` / `densityDefault` / `specificHeatDefault` updates
   the `MaterialEntry` row only. Existing `MaterialLayer` rows that
   reference the material keep their captured
   `thermalConductivity` / `density` / `specificHeat` values
   unchanged — this is the existing layer-override behaviour
   (architect §5.3). The construction editor's per-layer overrides
   continue to work the same way for both built-in and custom
   materials.

9. **Renaming is unrestricted.** A custom material's `name`,
   `category`, `subcategory`, `manufacturer`, and `source` can change
   freely. The picker shows the new name immediately because
   `materialsProvider` is a stream off `material_entries`.

10. **`.hsp` export not bundled in v1.** The library is the sharing
    channel; `.hsp` is the per-project envelope. The architect's
    `customMaterials` slot in `.hsp` (architect §7.4) stays reserved
    but unpopulated. Rationale: bundling custom materials inside a
    `.hsp` would create three sources of truth (file, DB, .hsp) and
    require conflict resolution on import. Revisit only if users
    explicitly ask for self-contained project bundles. **Note for
    import path:** when a `.hsp` from a different installation
    references `materialId`s that don't resolve in the current DB
    (e.g. that user's custom materials are not in this user's
    library), the imported `MaterialLayer` rows keep their captured
    `thermalConductivity` / `density` / `specificHeat` values
    (architect §5.3) — the missing material reference is logged as a
    soft `ValidationResult` with severity `info` ("Layer references a
    material not in your library") rather than blocking the import.

11. **Free-form taxonomy.** Category and subcategory are arbitrary
    strings on a custom entry — a custom material may invent new
    values. The picker derives the visible taxonomy from
    `SELECT DISTINCT category, subcategory FROM material_entries`,
    union of built-in and custom. No validation against the built-in
    list — the user explicitly asked to be able to create new
    categories.

12. **Provider contract.** Two new providers are added:
    - `customMaterialLibraryPathProvider` — `StateProvider<String?>`
      backed by `AppPreferences`. Writes invalidate
      `customMaterialsProvider` and trigger a sync pass.
    - `customMaterialsProvider` — `StreamProvider<List<MaterialEntry>>`
      over `material_entries WHERE isBuiltIn = false`. Used by the
      Manage Custom Materials screen; the wall construction editor
      keeps using the union-view `materialsProvider`.

13. **Service contract.** `CustomMaterialLibraryService` lives in the
    repository layer
    (`lib/repositories/custom_material_library_service.dart`) and is
    the **only** code path that mutates `material_entries` rows where
    `isBuiltIn = false`. Surface:

    | Method | Behaviour |
    |--------|-----------|
    | `Stream<List<MaterialEntry>> watchCustom()` | Mirrors `customMaterialsProvider` |
    | `Future<String> resolvedLibraryPath()` | Effective path = stored value or Rule 14 default |
    | `Future<void> setLibraryPath(String? path)` | Updates `AppPreferences` (null = revert to default) and runs the sync pass (Rule 4) |
    | `Future<void> reloadFromFile()` | Re-runs the sync pass with the current effective path |
    | `Future<MaterialEntry> create(MaterialEntry entry)` | UUID v4 id; write-through per Rule 5 |
    | `Future<void> update(MaterialEntry entry)` | Write-through per Rule 5 |
    | `Future<DeleteResult> delete(String id)` | Returns `DeleteResult.blocked(usages)` or `DeleteResult.ok()` per Rule 7 |

    All mutating methods always operate against the effective path
    (Rule 14) — there is no "library not configured" state, so the
    previously specified `LibraryNotConfiguredException` is removed.

14. **Default library file.** When
    `AppPreferences.customMaterialLibraryPath == null` the service
    uses
    `<applicationDocumentsDirectory>/HeatingPlanner/custom_materials.matlib.json`
    as the effective path. `applicationDocumentsDirectory` comes from
    the existing `path_provider` dependency. The service:
    1. Creates the parent `HeatingPlanner/` directory if missing.
    2. Creates the file with `{"version":"1.0","materials":[]}` if
       missing.
    3. Treats writes to the default file identically to writes to a
       user-picked path (Rule 5).
    The default file is **always** available — the picker's "+ New
    custom material…" affordance is therefore never disabled on the
    grounds of "no library configured". Previous spec text in
    `agent-ui-ux.md §5.7.1 items 2 and 3` describing a disabled state
    is superseded by this rule.

    "Clear" in the Settings UI does not unset a configured library
    into a no-library state; it **resets** an explicit user-picked
    path back to the default (`setLibraryPath(null)`). The default
    file remains on disk; its content is not touched by Clear. See
    `agent-ui-ux.md §5.7.3` and `§9.2` for the renamed control.

**Scope.**
Affects `AppPreferences`; adds `CustomMaterialLibraryService` and two
new providers; adds the Manage Custom Materials screen, the Add/Edit
Custom Material dialog, the Settings "Custom material library" section,
and the picker affordances per `agent-ui-ux.md §5.7.1`. Does **not**
change the `MaterialEntry` model, the `material_entries` table schema,
the `.hsp` envelope, or any calculation engine. The built-in seed path
from `assets/materials.json` is untouched and continues to run on first
launch when the table is empty.

**Verification.**
Defined per implementation prompt. Acceptance criteria include:
- Picking a fresh JSON file path in Settings creates the file (if
  absent) with `{"version":"1.0","materials":[]}` and immediately
  enables the picker's "+ New custom material…" affordance.
- Adding a material via the dialog writes a new row to
  `material_entries` with `isBuiltIn = false` and appends an entry
  with the same `id` to the JSON file; the entry appears in the
  picker dropdown grouped under its chosen category/subcategory
  within one repaint.
- Pointing the path at a pre-populated JSON file on launch loads all
  its entries; pointing it at a different file clears the previous
  custom set and loads the new one (Rule 4).
- Deleting a custom material referenced by any `MaterialLayer` is
  rejected with the per-construction usage list (Rule 7); after the
  user removes the references, the delete succeeds and both the
  SQLite row and the file entry are gone.
- Editing a custom material's λ from 0.045 → 0.040 updates the
  `MaterialEntry` but leaves every existing `MaterialLayer.thermalConductivity`
  that captured the old value untouched (Rule 8).
- A malformed JSON file does not crash the app; the toast is shown
  and the picker behaves as if no library is configured (Rule 4.3).
- `materialsProvider` continues to emit the union of built-in +
  custom; the wall construction editor's dropdown sees both with no
  changes to its existing grouping logic.

## ADR-022 — Material taxonomy is an arbitrary-depth path

**What.**
Replace `MaterialEntry.category` (String) + `MaterialEntry.subcategory`
(String) with a single `categoryPath: List<String>` of length ≥ 1.
Built-in and custom materials both carry the path. The material
picker dropdown and the Manage Custom Materials screen group by full
path. A custom material may be anchored under any existing node
(including root) and extended with any number of new subcategory
segments.

**Why.**
- The 2-level taxonomy was a compromise fitted to the DIN tables that
  seeded the built-in library. Custom users want richer hierarchies
  ("Insulation boards › custom insulations › funky new materials →
  …").
- A single ordered list is simpler than two strings plus an implicit
  parent-child rule; it also models "(root)" naturally as the empty
  prefix.
- Storing as a JSON array in a TEXT column reuses the existing
  pattern for `polygon` / `supplyRoutePath` (architect §7.1).
- The picker's existing grouping logic generalises cleanly: instead
  of grouping by 2-tuple, group by N-tuple, render as a breadcrumb.

**Rule.**

1. **Model.** `MaterialEntry.categoryPath: List<String>`, non-empty,
   each segment trimmed to 1–100 characters, no `/` characters
   (reserved for breadcrumb display).

2. **Drift schema.** `material_entries` drops the `category` and
   `subcategory` TEXT columns and gains `category_path TEXT NOT
   NULL` containing the JSON-encoded list. Schema version bumps; the
   migration:
   - Reads the existing `(category, subcategory)` for every row.
   - Writes `category_path = json([category, subcategory])` —
     preserving order outside → inside.
   - Drops the two old columns.

3. **Built-in seed migration.** `assets/materials.json` is
   regenerated by the HVAC agent so that every entry exposes
   `categoryPath: [category, subcategory]` and drops the two scalar
   fields. The re-seed on next launch (when `material_entries` is
   empty or the seed-version preference advances) loads the new
   shape directly. No semantic change to the built-in taxonomy — the
   tree shape is identical, just expressed differently.

4. **Custom-library file format.** ADR-021 Rule 2 is amended (see
   ADR-021): the file's `version` bumps to `"1.1"` and entries
   carry `categoryPath` instead of `category`/`subcategory`. Readers
   are tolerant of legacy `"1.0"` files and migrate on load
   (`categoryPath = [category, subcategory]`); the first write
   rewrites the file at `"1.1"`.

5. **Picker tree.** The wall construction editor's material dropdown
   displays an **inline-disclosure tree** built from every
   `MaterialEntry.categoryPath`, not a flat list of breadcrumb
   headers. Each unique path prefix is a node; a node may contain
   sub-nodes (deeper prefixes) and/or materials (entries whose
   `categoryPath` equals this node's path). All nodes are collapsed
   by default. Tap a node row to toggle. When the search field is
   non-empty, the tree is hidden and a flat filtered list of
   materials with breadcrumb subtitles is shown (UI/UX §5.7.1
   items 4–5). Alphabetic ordering — sub-nodes before materials
   within each parent. The prior "built-in categories first" hint
   from `agent-hvac.md` §7.1 is retired (no longer meaningful when
   arbitrary user-defined branches can interleave).

6. **Custom Material dialog — path builder** (replaces the two-toggle
   "Category" + "Subcategory" section in UI/UX §5.7.2):
   - **Start under** — a single dropdown listing **every distinct
     prefix** of every existing `categoryPath` in `material_entries`
     (length 1 through length N for each entry), rendered as
     breadcrumbs, plus the special **"(root)"** option pinned to
     the top. Selecting "(root)" anchors at top-level (empty
     prefix). Including intermediate prefixes means a material can
     be placed at any node in the tree — e.g. directly under
     `"Concrete & Screed"` without picking one of its existing
     subcategories.
   - **Typed extensions** — below the start picker, a vertical
     stack of editable text fields, one per appended segment. Each
     row has a "✕" that removes that segment **and every segment
     below it**.
   - **+ Add subcategory** — button below the last typed segment
     (or directly below the start picker when no segments are
     typed). Tapping appends a new empty editable row and focuses
     it.
   - **Save** computes `categoryPath = startPath + typedSegments`.
     `startPath = []` when the user selected "(root)".

7. **Edit mode.** Pre-fills "Start under" with the material's
   current `categoryPath[:-1]` (all but the last segment, or
   "(root)" when length is 1) and shows the last segment as a
   single typed field. The user can freely rename, delete, or
   extend from there. Renaming does not migrate other materials
   that share the old name — paths are per-material strings, not
   shared nodes.

8. **Validation.** Each typed segment is trimmed on Save. Empty,
   `>100` chars, or containing `/` blocks Save with an inline error.
   Duplicate-of-existing-sibling is allowed: if the user types a
   segment whose name matches an existing child of the chosen
   parent, the new material simply joins that existing bucket — no
   warning, no merge dialog, no special handling. The picker's
   group-by-path query collapses them naturally.

9. **Manage Custom Materials screen.** Group rows by full
   `categoryPath` rendered as a breadcrumb (mirrors picker grouping
   in UI/UX §5.7.3). Empty state copy unchanged.

10. **`MaterialLayer.materialId` unaffected.** Paths can change
    without touching layer rows; the FK is `id`-based, not
    path-based.

11. **`.hsp` import resilience (forward note).** When a future
    revision re-enables `customMaterials` bundling in `.hsp` per
    ADR-021 Rule 10, the import path must treat `categoryPath` as
    authoritative and not attempt to re-derive a 2-level shape.

**Scope.**
Affects the `MaterialEntry` freezed model and JSON serialisation,
the `material_entries` Drift table (schema migration), the
`assets/materials.json` seed file, the `CustomMaterialLibraryService`
read path (legacy `"1.0"` migration), the material picker dropdown
grouping, the Custom Material dialog UX, and the Manage Custom
Materials screen. Does not change any calculation engine, any
`MaterialLayer` row, the `.hsp` envelope, or the built-in
taxonomy's content.

**Verification.**
Acceptance criteria include:
- After migration, every built-in row's `categoryPath` matches its
  pre-migration `[category, subcategory]` tuple exactly.
- The picker dropdown displays the identical visual grouping as
  before for built-in materials, now driven by `categoryPath`
  instead of the two scalar fields.
- Adding a custom material with `Start under = Insulation boards`
  and typed segments `["custom insulations", "funky new materials"]`
  → name "flux compensating plates" results in a `MaterialEntry`
  with `categoryPath = ["Insulation boards", "custom insulations",
  "funky new materials"]` and appears in the picker under that
  breadcrumb.
- Editing the same material's "funky new materials" segment to
  "fun old materials" updates only that row's `categoryPath` and
  shifts its picker grouping accordingly; other materials are
  untouched.
- Selecting "(root)" + typing "Brand New Branch" creates a
  top-level group containing the new material.
- A legacy `"1.0"` custom-library file loads correctly via the
  ADR-022 Rule 4 migration and is rewritten at `"1.1"` on the
  next add/edit/delete.

---

## ADR-023 — Drag/slider DB writes are debounced to the interaction boundary

**What.**
The editor-state mutators (`EditorStateNotifier.updateWall` /
`updateRoom` / `updateZone` / `updateWindow` / `updateDoor` /
`updateDistributor`) each do two things: update the in-memory `state`
**and** issue an immediate `unawaited(upsert…(dao, …))` to SQLite plus
`markProjectDirty()`. Every one of those mutators now has a **transient
twin** — `updateWallTransient`, `updateRoomTransient`, etc. — that
updates `state` (and, for walls, the ADR-011 mirror partner) but performs
**no** DAO write and does **not** mark the project dirty.

Continuous interactions call the transient twin on every frame/tick; the
**single** persisting call happens only when the interaction commits:

- **Canvas drags (`SelectTool`).** Every per-frame `_apply*` path
  (`_applyMidDrag`, `_applyEndpointDrag`, `_adjustConnectedWalls`,
  `_adjustConnectedWallAtEndpoint`, `_updateRoomPolygon`, `_applyZoneDrag`,
  `_applyWallZoneUpdate`, `_applyOpeningUpdate`, `_applyDistributorDrag`)
  and every drag-revert path (`_revertDrag`, the `cancel()` reverts, the
  invalid-zone-drag revert in `_commitZoneDrag`) call the **transient**
  twins. The commit at `onDragEnd` already re-applies the final value
  through the undo command's `execute()` (e.g. `_MoveWallCommand` →
  persisting `updateWall`/`updateRoom`), so the database is written once
  per changed element.
- **Property-panel sliders.** `onChanged` calls the transient twin;
  `onChangeEnd` performs the single persist. Room (`room_properties`),
  zone (`heating_zone_properties` — spacing/height/border) and distributor
  (`distributor_properties` — supply/return temp) sliders follow this.
  The distributor sliders previously persisted every tick with no undo
  entry and gained an `onChangeStart`/`onChangeEnd` commit that writes once.
- **Project-settings sliders.** `ProjectSettingsNotifier` gained transient
  setters (`setDesignOutdoorTempCTransient`, `setDefaultIndoorTempCTransient`,
  `setUnheatedSpaceTempCTransient`, `setFloorHeightMmTransient`); the
  temperature sliders call them on `onChanged` and the persisting setter on
  `onChangeEnd`. The room-height slider also cascades to wall-zone heights:
  the dialog snapshots the "auto" wall-zone ids (those matching the floor
  height) at `onChangeStart` and drives `EditorStateNotifier`'s
  `setWallZoneHeightsForIds(ids, h, persist: …)` — `persist: false` per
  tick, `persist: true` once on release.

**Why.**
A single wall mid-drag frame fans out into several mutator calls
(`_adjustConnectedWalls` + `_updateRoomPolygon`), so the prior code issued
several synchronous SQLite writes **per pointer-move frame**; a slider did
the same per tick. The canvas must read in-memory `state` synchronously
every frame, so the state update has to stay live — but the durable write
only needs the committed value. (The 3 s debounce in
`SaveStateNotifier.markDirty` only governs the `.hsp` export, not the
per-row SQLite writes.) Splitting "update state" from "persist" lets the
hot path skip I/O entirely while keeping exactly one write — and exactly
one undo entry — per interaction. Reverts use the transient twin because a
transient drag never touched the database; the pre-drag values are still
the persisted ones.

**Rule.**
1. Any new continuous interaction (drag, slider, scrub) MUST call the
   `*Transient` mutator on the per-frame/per-tick path and the persisting
   mutator exactly once at the commit boundary (`onDragEnd` /
   `onChangeEnd`), normally via the undo command's `execute()`.
2. The transient twins are the **only** mutators that may run on a hot
   path. They never call a DAO and never `markProjectDirty()`. Persisting
   mutators are unchanged: state + one upsert + `markProjectDirty()`.
3. `updateWallTransient` replicates the ADR-011 mirror-partner sync
   in-memory so a shared wall stays consistent mid-drag; it just omits the
   two DAO writes.
4. Tools reach the transient twins through `EditorCallbacks`
   (`updateWallTransient` …); the canvas widget forwards them to the
   notifier. Every `EditorCallbacks` implementer (including test stubs)
   must provide them — test stubs may delegate the transient method to its
   persisting counterpart.

**Scope.**
`EditorStateNotifier`, `ProjectSettingsNotifier`, `EditorCallbacks` +
`FloorPlanCanvas`, `SelectTool` drag paths, and the room / heating-zone /
distributor / project-settings slider panels. Undo/redo, mirror sync
(ADR-011), and the persisting mutators' contracts are unchanged.

**Verification.**
`flutter analyze` clean. `test/unit/providers/transient_persistence_test.dart`:
for each entity, N transient calls issue 0 upserts and one persisting call
issues exactly 1 (plus the `setWallZoneHeightsForIds` persist flag).
`test/widget/tools/select_tool_test.dart` "Debounced persistence": a
five-frame mid-handle wall drag issues 0 wall/room upserts during the drag
and, on drop, persists the room once and each moved wall at most once.

## ADR-024 — Zone-colour recompute is debounced to the interaction boundary

**What.**
`zoneColorStatesProvider` (the ADR-004 `Map<zoneId, ZoneColorState>` the
canvas paints) was a plain `Provider` that `ref.watch`ed
`editorStateProvider` **and**, per zone, `roomHeatDemandProvider(roomId)`
and `zoneHeatOutputProvider(zoneId)`. It is now a debounced
`NotifierProvider` (`ZoneColorStatesNotifier`). The notifier `ref.watch`es
**only the cheap trigger signals** — `editorStateProvider`,
`designOutdoorTempCProvider`, `defaultIndoorTempCProvider`,
`unheatedSpaceTempCProvider`, `floorHeightMmProvider` — and `ref.read`s (never
watches) the heavy demand / output providers inside its compute. The first
build computes synchronously (correct colours at rest / on load); every
subsequent trigger cancels and restarts a trailing
`zoneColorDebounceDuration` (100 ms) timer and returns the **previous** map
instance (so listeners are not notified) until the timer fires with the
settled value.

**Why.**
The colour result is expensive: each zone runs the full EN 12831 heat-load
graph (`roomHeatDemandProvider`) plus `zoneHeatOutputProvider`. Per ADR-023 a
continuous interaction mutates in-memory state every frame/tick — a zone drag
mutates `editorStateProvider`; a project-settings temperature slider mutates
`designOutdoorTempCProvider`, which invalidates **every** room's demand per
tick. Because the old provider *watched* the heavy providers, every tick
re-ran the whole graph for all rooms and rebuilt the canvas — many times per
second — even though only the settled value affects the colours. By watching
only the cheap triggers and *reading* the heavy providers post-debounce,
nothing subscribes to them during the burst, so they are not eagerly
recomputed each tick; they are evaluated **once**, lazily, when the timer
fires (O(1) per burst instead of O(N)). Geometry still renders live every
frame: the canvas watches `editorStateProvider` directly for wall / room /
zone outlines and only depends on this notifier for fill colour.

**Rule.**
1. The debounce lives in the UI-provider notifier, **not** in the calculation
   engines or the demand / output providers — those stay pure and unchanged.
2. The notifier must watch the complete set of cheap trigger signals so no
   legitimate at-rest change is missed; all building geometry is mirrored in
   `editorStateProvider` and the thermal settings are the only other source.
   It must **not** watch the heavy demand / output providers, or the O(N)
   burst returns.
3. The committed (final) value of any drag/slider is the last state change, so
   the surviving timer recomputes against it — colours are never left stale
   once the interaction settles. There is no separate explicit flush.
4. The debounce only fires while `zoneColorStatesProvider` has an active
   listener (eager rebuild); the canvas always `ref.watch`es it, so this holds
   in production. Tests must `listen` (not merely `read`) to exercise it.

**User-visible effect.**
Zone *outlines* still drag live. Zone *fill colour* holds its last-settled
value during an active drag / slider sweep and snaps to the correct final
value ~100 ms after the user stops. The final colour always matches the
non-debounced result.

**Scope.**
`zoneColorStatesProvider` only. ADR-004 priority order, ADR-023 transient
persistence, and the demand / output providers' contracts are unchanged.

**Verification.**
`flutter analyze` clean.
`test/unit/providers/zone_color_state_debounce_test.dart`: a 10-tick outdoor-
temperature burst evaluates the (instrumented) demand provider exactly once
for the whole burst (O(1), not O(N)); the colour map holds its pre-burst value
mid-burst; and after the debounce the map equals the colour computed directly
from the final demand / output values.

