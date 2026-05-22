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
    - When a wall is selected, a small lock/pin glyph is drawn on the
      anchored face (inner face for `innerFace`, outer face for `outerFace`).
      For `centerline` (and therefore every shared wall) no glyph is drawn —
      centerline is the implicit default.

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

