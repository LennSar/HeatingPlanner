# HeatingPlanner Project Memory

## Architecture Patterns

- **EditorState** (lib/ui/providers/editor_state_provider.dart) is the in-memory canvas source of truth — walls, rooms, windows, doors, zones all live here. DB persistence is separate and not yet wired to canvas paint loop.
- **EditorCallbacks** (lib/ui/canvas/tools/editor_callbacks.dart) is the interface canvas tools use to mutate state. Implemented by `_FloorPlanCanvasState` via Riverpod.
- **InteractionData** (lib/ui/canvas/painters/interaction_data.dart) is a sealed class; each tool variant is its own subclass. The switch in InteractionPainter must be exhaustive — add a case when adding a new subclass.
- All tools inherit `CanvasTool` (tool_base.dart). They get `callbacks` + `onStateChanged`. No Riverpod access inside tools — use `callbacks.*` for reads and mutations.
- **_CanvasCompositePainter** in floor_plan_canvas.dart: 7 fixed layers in order: Grid → HeatingZone → Wall → Opening → PipeRoute → Annotation → Interaction.

## Seeded Default IDs (HeatingDao.seedDefaults)

- First tube type: `'10000000-0000-4000-8000-000000000001'` (PE-Xa 16×2)
- First flooring material: `'20000000-0000-4000-8000-000000000001'` (Ceramic tile)
- Used as hardcoded fallbacks in `_FloorPlanCanvasState.defaultTubeTypeId/defaultFlooringMaterialId`.

## Keyboard Shortcuts Already Registered

H → drawZone, W → drawWall, V → select, N → placeWindow, D → placeDoor, G → placeDistributor, R → routePipe, M → measure. Zone toolbar entry also already present in editor_screen.dart.

## Zone Tool (lib/ui/canvas/tools/zone_draw_tool.dart)

- Closes on click within `15.0 / callbacks.currentZoom` mm of first vertex, or double-tap (300 ms window detected manually via timestamps).
- Finds parent room via `GeometryEngine.isPointInPolygon` on first vertex; validates all vertices inside same room.
- On validation failure: sets `ZoneDrawData.hasValidationError = true`, keeps vertices, shows toast. Reset on next tap or Escape.

## Zone Painter (lib/ui/canvas/painters/heating_zone_painter.dart)

- ADR-004 state machine: currently all zones unconnected → red hatched style.
- Hatch: 45° diagonal lines, 200 mm spacing, clipped to polygon path.
- Meander preview: horizontal parallel lines spaced `tubeSpacingMm` apart, `borderDistanceMm` inset from bounding box, snake-connected. Clipped to polygon.
