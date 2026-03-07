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
