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

## ADR-003 — Partial shared walls: only the overlapping segment counts

**What.**
When a smaller room is drawn adjacent to a larger room and only *part* of one
of the larger room's walls forms the shared boundary, a new `WallSegment` is
created for the **overlap portion only**. The larger room's original wall is
split into up to three segments: the part before the overlap (exterior), the
overlap (interior), and the part after the overlap (exterior). The smaller room
gets a single mirror segment covering only the shared portion.

**Why.**
Heat demand must use the actual shared area, not the full length of the
original wall. Using the full wall would over-count the interior area and
under-count the exterior area for the larger room, corrupting both rooms'
`Q_T` figures. Splitting at the exact overlap endpoints is the only geometrically
correct approach.

**Rule.**
When `addRoomFromDetection` detects that a new room's detected wall is a
*sub-segment* of an existing room's wall (both endpoints of the new wall lie on
the existing wall but do not coincide with its endpoints), the implementation
must:
1. Split the original wall at the two intersection points, producing up to three
   segments and replacing the original in state.
2. Mark only the middle (overlapping) segment as `interior` on both sides.
3. Store the mirror of the middle segment for the new room.
4. Leave the flanking segments as `exterior` on the original room's side.

> **Status:** The current implementation handles only the **exact-match** case
> (shared wall endpoints coincide). Partial overlap is **not yet implemented**.
> Until it is, the room detection algorithm requires that the user draw the
> shared wall at exactly the same start/end points as the existing wall.
> A `ValidationResult` with `WarningSeverity.warning` should be raised if the
> detected wall for a new room is a strict sub-segment of an existing room's
> wall, prompting the user to re-draw to the exact endpoints.
