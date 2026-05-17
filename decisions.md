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
