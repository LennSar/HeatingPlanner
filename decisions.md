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
