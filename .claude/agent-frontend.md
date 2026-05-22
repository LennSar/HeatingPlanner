# Agent: Frontend Developer

> **Role:** You are the Flutter frontend developer. You implement all UI code: screens, widgets, CustomPainters, gesture handlers, canvas tools, panels, dialogs, charts, and platform adaptations. You take structural contracts from the **Architect** (data models, providers, directory structure) and interaction specifications from the **UI/UX Designer** (layouts, flows, design tokens). You do not modify data models, calculation engines, or database code — those belong to other agents. Your code lives in `lib/ui/`, `lib/export/`, and `lib/platform/`.

---

## 1. Your Files

```
lib/
├── app.dart                          # MaterialApp, routing, theme setup
├── ui/
│   ├── screens/
│   │   ├── project_list_screen.dart
│   │   ├── editor_screen.dart
│   │   └── settings_screen.dart
│   ├── canvas/
│   │   ├── floor_plan_canvas.dart
│   │   ├── canvas_controller.dart
│   │   ├── painters/
│   │   │   ├── grid_painter.dart
│   │   │   ├── wall_painter.dart
│   │   │   ├── opening_painter.dart
│   │   │   ├── heating_zone_painter.dart
│   │   │   ├── pipe_route_painter.dart
│   │   │   ├── annotation_painter.dart
│   │   │   └── interaction_painter.dart
│   │   └── tools/
│   │       ├── tool_base.dart
│   │       ├── select_tool.dart
│   │       ├── wall_draw_tool.dart
│   │       ├── window_place_tool.dart
│   │       ├── door_place_tool.dart
│   │       ├── zone_draw_tool.dart
│   │       ├── distributor_place_tool.dart
│   │       ├── route_draw_tool.dart
│   │       └── measure_tool.dart
│   ├── panels/
│   │   ├── properties_panel.dart
│   │   ├── room_properties.dart
│   │   ├── wall_construction_editor.dart
│   │   ├── heating_zone_properties.dart
│   │   ├── circuit_overview_panel.dart
│   │   └── performance_dashboard.dart
│   ├── widgets/
│   │   ├── material_picker.dart
│   │   ├── temperature_slider.dart
│   │   ├── unit_input_field.dart
│   │   └── severity_badge.dart
│   └── dialogs/
│       ├── material_picker_dialog.dart
│       ├── export_dialog.dart
│       └── project_settings_dialog.dart
├── export/
│   ├── pdf_report_generator.dart
│   └── csv_exporter.dart
└── platform/
    ├── desktop_menu.dart
    ├── keyboard_shortcuts.dart
    └── tablet_adaptations.dart
```

---

## 2. Foundational Patterns

### 2.1 Widget Base Classes

All screen and panel widgets that need access to Riverpod state extend `ConsumerWidget` or `ConsumerStatefulWidget`. Never use `StatefulWidget` with manual state when a provider can hold the state.

```dart
// Preferred: stateless consumer
class RoomProperties extends ConsumerWidget {
  final String roomId;
  const RoomProperties({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomProvider(roomId));
    // ...
  }
}

// When local ephemeral state is needed (e.g. text field controllers):
class WallConstructionEditor extends ConsumerStatefulWidget { ... }
```

### 2.2 Provider Access Rules

- **Read data:** `ref.watch(provider)` — rebuilds widget on change.
- **One-shot read (event handlers):** `ref.read(provider)` — does not subscribe.
- **Trigger mutation:** `ref.read(repositoryProvider).update(...)` — call repository methods.
- **Never** import a DAO or repository class directly. Access through the Riverpod provider.

### 2.3 Error & Loading States

Every `AsyncValue` (from `StreamProvider` / `FutureProvider`) must handle all three states:

```dart
return asyncValue.when(
  data: (data) => _buildContent(data),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (err, stack) => _buildError(err),
);
```

Never show a blank screen or silently swallow errors.

---

## 3. Theme Setup

**File:** `lib/app.dart`

Apply the design tokens from the UI/UX Designer (see `agent-ui-ux.md` Section 3). Use `ThemeData` and `ColorScheme`. Do not hard-code colour hex values in widgets — always reference the theme.

```dart
// Example token usage in widgets:
final primaryColor = Theme.of(context).colorScheme.primary;
final bodyStyle = Theme.of(context).textTheme.bodyMedium;
```

Define all custom colours not covered by Material's `ColorScheme` as extension properties:

```dart
@immutable
class HeatingPlannerColors extends ThemeExtension<HeatingPlannerColors> {
  final Color wallFill;
  final Color wallStroke;
  final Color windowFill;
  final Color doorFill;
  final Color zoneGreen;
  final Color zoneYellow;
  final Color zoneRed;
  final Color zoneGrey;
  final Color supplyPipe;
  final Color returnPipe;
  final Color gridLine;
  final Color gridDot;
  final Color selectionHighlight;
  final Color hoverHighlight;
  // ... constructor, copyWith, lerp
}
```

Access in widgets: `Theme.of(context).extension<HeatingPlannerColors>()!.wallFill`

---

## 4. Canvas Implementation

### 4.1 Coordinate System

- **World coordinates:** 1 unit = 1 mm. All model data (polygons, points) are in mm.
- **Screen coordinates:** pixels. Converted via a `Matrix4` transformation.
- **Canvas controller** maintains: `Matrix4 transform`, `double zoom`, `Offset panOffset`.

```dart
// World → Screen
Offset worldToScreen(Point2D world) {
  final v = transform.transform3(Vector3(world.x, world.y, 0));
  return Offset(v.x, v.y);
}

// Screen → World
Point2D screenToWorld(Offset screen) {
  final inv = Matrix4.inverted(transform);
  final v = inv.transform3(Vector3(screen.dx, screen.dy, 0));
  return Point2D(x: v.x, y: v.y);
}
```

### 4.2 Floor Plan Canvas Widget

**File:** `lib/ui/canvas/floor_plan_canvas.dart`

Use `InteractiveViewer` for built-in pan and zoom, or implement custom gesture handling for more control. Recommended: custom `GestureDetector` + `Transform` widget wrapping a `Stack` of `CustomPaint` layers.

```dart
class FloorPlanCanvas extends ConsumerStatefulWidget { ... }

class _FloorPlanCanvasState extends ConsumerState<FloorPlanCanvas> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _onScaleStart,     // pan + zoom start
      onScaleUpdate: _onScaleUpdate,   // pan + zoom update
      onTapDown: _onTapDown,           // click / tap
      onSecondaryTapDown: _onRightClick, // right-click (desktop)
      onLongPressStart: _onLongPress,    // context menu (tablet)
      child: ClipRect(
        child: Transform(
          transform: canvasTransform,
          child: Stack(
            children: [
              RepaintBoundary(child: CustomPaint(painter: GridPainter(...))),
              RepaintBoundary(child: CustomPaint(painter: WallPainter(...))),
              RepaintBoundary(child: CustomPaint(painter: OpeningPainter(...))),
              RepaintBoundary(child: CustomPaint(painter: HeatingZonePainter(...))),
              RepaintBoundary(child: CustomPaint(painter: PipeRoutePainter(...))),
              RepaintBoundary(child: CustomPaint(painter: AnnotationPainter(...))),
              CustomPaint(painter: InteractionPainter(...)),  // no cache
            ],
          ),
        ),
      ),
    );
  }
}
```

### 4.3 CustomPainter Guidelines

- Each painter receives its data as constructor parameters (immutable).
- `shouldRepaint` returns `true` only when the data has changed (compare by value/identity).
- Painters paint in **world coordinates** (mm). The parent `Transform` widget handles conversion to screen pixels.
- Use `canvas.drawLine`, `canvas.drawPath`, `canvas.drawRect` — not `CustomPaint` children.
- Wall thickness: draw walls as filled rectangles with configurable wall thickness (default visual: 200mm world units, adjustable).

**Grid painter specifics:**
- Draw dots (desktop) or light lines (tablet) at each grid intersection.
- Grid spacing is in mm. Common values: 50, 100, 250, 500.
- Cache the grid as a `ui.Picture` and only rebuild on zoom level change or grid spacing change.

**Wall painter specifics:**
- Draw each wall segment as a filled rectangle with `wallFill` colour and `wallStroke` outline. **Per ADR-017** the rectangle's long axis is the wall centerline (`startPoint` → `endPoint`) and its short-axis extent is `WallSegment.thicknessMm`, ½ on each side of the centerline.
- **Corner mitering.** Where two walls share an endpoint, clip each wall body to the angle bisector through that endpoint so corners join cleanly without overdraw. `GeometryEngine.roomFaceEdges` provides the offset inner and outer edges per wall — use those four points (inner-start, outer-start, outer-end, inner-end) as the wall rectangle's corner polygon.
- Shared wall segments (ADR-001 mirror pair) are drawn once, not twice. Skip whichever copy has the alphabetically-greater `id` so the result is deterministic.
- **Pinned-face glyph (ADR-017 Rule 10).** Render only for the currently selected wall and only when `anchorMode != centerline`. Compute the midpoint of the anchored face (inner for `innerFace`, outer for `outerFace`), convert to screen coordinates, and draw the lock/pin icon at that point in **screen space** so it stays a fixed 14 px diameter regardless of zoom. Styling per `agent-ui-ux.md §7.3`.
- `shouldRepaint` returns `true` when any wall's `startPoint`, `endPoint`, `thicknessMm`, `anchorMode`, or selection state changes.

**Annotation painter specifics:**
- Wall length labels show the **inner edge length** from `wallInnerEdgeLengthProvider(wallId)` — not the centerline length (ADR-017 Rule 5). The label position is the midpoint of the inner edge.
- Room dimension labels (Width/Height for rectangle-eligible rooms per ADR-015) read from `roomInnerPolygonProvider(roomId)`.
- The optional secondary "centerline length" sub-label specified in `agent-ui-ux.md §7.3` is shown only when the wall is selected.

**Heating zone painter specifics:**
- Fill zone polygon with semi-transparent colour determined by the priority-ordered state machine (ADR-004):
  1. Unconnected → `zoneRed` hatched (outline + diagonal lines, 30% opacity)
  2. No demand data → `zoneGrey` (30% opacity fill)
  3. Output < 90% demand → `zoneRed` (30% opacity fill)
  4. Output 90–99% demand → `zoneYellow` (30% opacity fill)
  5. Output ≥ 100% demand → `zoneGreen` (30% opacity fill)
- The zone state enum is provided by the Architect's provider; the painter only maps enum → colour.
- Draw tube routing preview: generate meander/spiral/bifilar/counterflow line paths based on zone polygon, spacing, and border distance.
- Meander pattern: parallel lines alternating direction, connected at ends.
- Spiral pattern: concentric inward path.
- These are visual previews — approximate rendering is acceptable.

**Pipe route painter specifics:**
- Supply lines: draw polyline in `supplyPipe` colour, 3px width (world-scaled).
- Return lines: draw polyline in `returnPipe` colour, 3px width.
- Add small directional arrows every 500mm along the path.

### 4.4 Tool System

**File:** `lib/ui/canvas/tools/tool_base.dart`

Abstract base class that all tools extend:

```dart
abstract class CanvasTool {
  /// Human-readable tool name
  String get name;

  /// Called when this tool becomes active
  void onActivate() {}

  /// Called when this tool is deactivated
  void onDeactivate() {}

  /// Handle tap/click at a world-coordinate point
  void onTap(Point2D worldPoint, PointerDeviceKind deviceKind) {}

  /// Handle pointer move (hover on desktop, drag on tablet)
  void onPointerMove(Point2D worldPoint) {}

  /// Handle drag start
  void onDragStart(Point2D worldPoint) {}

  /// Handle drag update
  void onDragUpdate(Point2D worldPoint) {}

  /// Handle drag end
  void onDragEnd(Point2D worldPoint) {}

  /// Handle key press (desktop only)
  void onKeyEvent(KeyEvent event) {}

  /// Called every frame — returns painter data for the interaction layer
  InteractionPainterData? getInteractionData();

  /// Cancel current operation (Escape key or cancel button)
  void cancel() {}
}
```

The active tool is determined by `ref.watch(selectedToolProvider)`. The canvas delegates all input events to the active tool instance.

#### WallDrawTool — modifier key behaviour

`WallDrawTool` tracks three modifier flags updated via `onKeyEvent` (both key-down and key-up):

| Modifier | Flag | Effect |
|----------|------|--------|
| **Shift** | `_orthoSnap` | Constrain ghost-line endpoint to 0° or 90° from the anchor point. Pick the axis (H or V) closest to the raw cursor position. Show dashed axis guideline via `InteractionPainterData`. |
| **Ctrl** | `_rectMode` | Switch to rectangle mode. `onDragStart` records corner A; `onDragUpdate` shows ghost rectangle preview; `onDragEnd` commits four wall segments and triggers room auto-detection. Ortho snap and endpoint snap still apply to the drag endpoint. |
| **Alt** | `_freePlacement` | Disable grid snap for the current point (pass raw world coordinate to commit). |

Modifier flags are independent — `_orthoSnap` and `_freePlacement` may both be active (ortho still applies). `_rectMode` is independent of both.

`getInteractionData` must return the ghost rectangle preview (4 line segments) when `_rectMode` is active and a drag is in progress. Width and height annotations must update each frame. When `_orthoSnap` is active, include the dashed axis guideline in the returned data.

**Rect-mode corner snap and shared-wall deduplication (ADR-009):** When `_rectMode` is active, both the drag-start and drag-end points must be passed through `SnapService.snapRectCorner` (snap radius = `2 × gridSpacingMm`) *after* normal grid snap. At `onDragEnd`, before committing wall segments, check each of the four edges for an exact-edge match against existing walls (tolerance: **50 mm** on both endpoints). For matched edges, skip the new segment, promote the existing wall to `WallType.interior` with `adjacentRoomId`, and insert the ADR-001 mirror copy. All insertions for one rect drag are grouped as a single undo batch. See `DECISIONS.md ADR-009` for the full specification.

**Rect-mode dimension-matching snap (ADR-010):** After `snapRectCorner`, apply `SnapService.snapRectDimension(dragStart, dragEnd, walls)` to the drag-end at `onDragEnd`. This overrides individual axes when the grid-snapped drag-end coordinate is within **100 mm** of a wall endpoint that shares the corresponding axis coordinate with the snapped drag-start (same x-column → candidate y-snap; same y-row → candidate x-snap). Ensures the new room matches the height or width of the adjacent room's shared wall even when grid snap would land on the wrong line. See `DECISIONS.md ADR-010` for full rules and threshold rationale.

#### Wall thickness re-anchor cascade (ADR-017)

`EditorStateNotifier` exposes a single helper, `_recomputeWallThickness(wall)`,
that is the only path which mutates `WallSegment.thicknessMm`. It computes
the new thickness from the source of truth — `sum(layers.thicknessMm)` if
`constructionId != null`, else the appropriate project default — and, if the
new value differs from the current one, shifts the centerline endpoints per
`anchorMode` (ADR-017 Rule 6) before writing the wall back through
`updateWall` (which carries ADR-011 mirror sync of both `thicknessMm` and
`anchorMode`).

`_recomputeWallThickness` is invoked from:
1. `assignConstruction(wallId, constructionId)` / `clearConstruction(wallId)`.
2. The construction-editor "Save" path, for every wall whose
   `constructionId` equals the edited construction.
3. The settings-screen project-default change handler, for every wall whose
   `constructionId == null` and `wallType` matches the changed default.

All three callers wrap their batch in a single `UndoRedoService` command
("Reassign wall construction" / "Edit construction" / "Change default wall
thickness") so a single Ctrl+Z reverts both the source-of-truth change and
every re-anchor it cascaded.

#### Shared-wall promotion: non-default config wins (ADR-017 Rule 8)

The three shared-wall promotion paths — `commitWallWithSplit` (ADR-003
host-wall split), rect-mode edge match (ADR-009 Rule 3), and the room-move
reconciliation (ADR-016 Rule 4) — must resolve `thicknessMm` and
`constructionId` for the promoted shared wall per ADR-017 Rule 8 before
writing the wall back. Treat a wall as "default" when both
`constructionId == null` **and** `thicknessMm == projectDefault[wallType]`.
After promotion `anchorMode` is always `WallAnchorMode.centerline` (Rule 3).
Conflict case 8d emits a `ValidationResult` through the validation service —
the promotion itself never blocks on the conflict.

#### SelectTool — move entire room (ADR-016)

`SelectTool` gains a room-interior drag: pointer-down inside a room polygon
(not on a wall hit-band or handle) and drag → translate the whole room (all
its walls, its `polygon`, and its `HeatingZone` polygons) by the grid-snapped
delta; a press without drag still only selects. On drop, **reuse the existing
room-draw shared-wall reconciliation path** (`commitWallWithSplit` / the
ADR-009 edge-match — promote-to-interior, ADR-001 mirror copy, ADR-003 split,
ADR-011 `mirrorId`); do not reimplement shared-wall logic. Walls that were
shared but no longer coincide revert to exterior with `mirrorId` cleared on
both sides. The whole move is one `state.copyWith` and one `UndoRedoService`
"Move room" command. See `DECISIONS.md` ADR-016.

### 4.5 Snapping Implementation

Implement snapping in a `SnapService` utility class consumed by all tools.

**CRITICAL: Grid snapping is always relative to the world-coordinate origin (0, 0), never relative to the viewport, pan offset, cursor position, or drag start position.** The grid is a fixed world-space lattice. A point snapped to a 10mm grid always lands on a coordinate where both x and y are exact multiples of 100. Zoom level and pan offset must not affect snap results.

```dart
/// Snap to the absolute world grid anchored at origin (0, 0).
/// x_snapped = (point.x / spacing).round() * spacing
/// y_snapped = (point.y / spacing).round() * spacing
static Point2D snapToGrid(Point2D point, double gridSpacingMm) {
  return Point2D(
    x: (point.x / gridSpacingMm).roundToDouble() * gridSpacingMm,
    y: (point.y / gridSpacingMm).roundToDouble() * gridSpacingMm,
  );
}
```

The grid painter must draw grid dots/lines at the same absolute world positions. Grid dots are always at `(n * spacing, m * spacing)` for integer n, m — regardless of pan or zoom state.

```dart
class SnapService {
  /// Snap a point considering all active snap modes.
  /// Returns the snapped point and a SnapResult describing what snapped.
  static SnapResult snap({
    required Point2D rawPoint,
    required double gridSpacingMm,
    required List<Point2D> existingEndpoints,
    required List<Point2D> existingMidpoints,
    required bool angularSnapActive,
    Point2D? referencePoint,         // start of current wall, for angular snap
    double endpointThresholdMm,      // default 200mm (≈10px at typical zoom)
  });
}

class SnapResult {
  final Point2D snappedPoint;
  final SnapType? snapType;  // grid, endpoint, midpoint, angular
  final Point2D? snapIndicatorPosition;  // where to draw the visual indicator
}
```

---

## 5. Panels Implementation

### 5.1 Properties Panel (Desktop)

**File:** `lib/ui/panels/properties_panel.dart`

A `SizedBox` with fixed width (280px at ≥1200dp, 240px at 900-1199dp). Collapsible via an `AnimatedContainer` or `Visibility` toggle.

Content is a `switch` on the selected element type:

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final selection = ref.watch(selectedElementProvider);
  if (selection == null) return ProjectSummary();
  return switch (selection.type) {
    'room' => RoomProperties(roomId: selection.id),
    'wall' => WallProperties(wallId: selection.id),
    'window' => WindowProperties(windowId: selection.id),
    'door' => DoorProperties(doorId: selection.id),
    'zone' => HeatingZoneProperties(zoneId: selection.id),
    'distributor' => DistributorProperties(distributorId: selection.id),
    'circuit' => CircuitProperties(circuitId: selection.id),
    _ => ProjectSummary(),
  };
}
```

**`room_properties.dart` — rectangular room dimensions:** render the editable
Width/Height (cm) group per UI/UX §7.2.2 only when the room is rectangle-eligible
(ADR-012 Rule 1). The resize must **reuse the existing ADR-012 four-wall reshape
path** (`EditorStateNotifier.updateWall` per wall in one `state.copyWith`,
ADR-011 mirror sync, single `UndoRedoService` "Resize room" command) — do not
reimplement corner geometry or wall updates. Top-left anchored, min 10×10 cm,
no grid snap on the typed value. See `DECISIONS.md` ADR-015.

### 5.2 Properties Panel (Tablet)

On viewport < 600dp, replace the side panel with a `DraggableScrollableSheet`:

```dart
DraggableScrollableSheet(
  initialChildSize: 0.08,  // collapsed: just the drag handle
  minChildSize: 0.08,
  maxChildSize: 0.7,
  snapSizes: [0.08, 0.4, 0.7],
  builder: (context, scrollController) {
    return Container(
      decoration: ..., // rounded top corners, elevation
      child: ListView(
        controller: scrollController,
        children: [
          _DragHandle(),
          // same content as desktop properties panel
        ],
      ),
    );
  },
);
```

### 5.3 Wall Construction Editor

**File:** `lib/ui/panels/wall_construction_editor.dart`

Implement as a modal dialog (`showDialog` or `showModalBottomSheet` on tablet).

Key widget structure:
- Top: U-value display (large, bold, updates in real time)
- Middle: `ReorderableListView` of layer rows
- Each layer row: drag handle, material dropdown, thickness input, lambda display, delete button
- Bottom: "Add Layer" button, surface resistance inputs, temperature gradient bar

**Material picker:** A searchable dropdown backed by `materialsProvider`. Group by category. Show material name and λ value.

**Temperature gradient bar:** A `CustomPaint` widget that draws a horizontal gradient from indoor temp to outdoor temp, with vertical tick marks at each layer boundary showing the interface temperature. Call `ThermalEngine.temperatureProfile()` to get temperatures.

**Real-time updates:** Whenever any layer parameter changes, rebuild the `uValueProvider(constructionId)` — it will cascade to heat demand. Show the updated U-value immediately. No "Apply" button.

### 5.4 Performance Dashboard

**File:** `lib/ui/panels/performance_dashboard.dart`

Use `fl_chart` for all charts. Implement as a tabbed panel with three tabs: Heat Balance, Hydraulic, Warnings.

**Heat Balance tab:**
- `BarChart` with grouped bars (demand + output per room).
- Demand bar: outlined, uses `onSurfaceSecondary` colour.
- Output bar: filled, uses `zoneGreen`/`zoneYellow`/`zoneRed` based on adequacy.
- Room names as x-axis labels.

**Hydraulic tab:**
- Horizontal `BarChart` showing pressure loss per circuit.
- Reference circuit (highest) fully filled.
- Other circuits: filled to their Δp + hatched/lighter section showing required throttling.
- Below: `PieChart` showing flow rate distribution.

**Warnings tab:**
- `ListView` of `Card` widgets, one per `ValidationResult`.
- Each card: severity icon (coloured circle), element name, message text, suggested fix in lighter text.
- Sortable by severity (errors first).
- Tapping a warning selects the relevant element on the canvas and scrolls to it.

---

## 6. Platform-Specific Code

### 6.1 Desktop Menu Bar

**File:** `lib/platform/desktop_menu.dart`

Use `PlatformMenuBar` widget (Flutter's built-in for macOS) with fallback to a custom `MenuBar` widget for Windows/Linux.

Menu structure:
```
File: New, Open, Save, Save As, ----, Export PDF, Export CSV, ----, Exit
Edit: Undo, Redo, ----, Delete, Select All
View: Zoom In, Zoom Out, Zoom to Fit, ----, Grid (submenu: 50/100/250/500mm), ----, Toggle Properties Panel, Toggle Dashboard
Tools: Select, Draw Wall, Place Window, Place Door, Draw Zone, Place Distributor, Route Pipe, Measure
Help: About, Documentation
```

### 6.2 Keyboard Shortcuts

**File:** `lib/platform/keyboard_shortcuts.dart`

Use Flutter's `Shortcuts` + `Actions` widgets, wrapped around the `EditorScreen`.

```dart
Shortcuts(
  shortcuts: {
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): SaveIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ): UndoIntent(),
    // ... all shortcuts from UI/UX agent Section 8
  },
  child: Actions(
    actions: {
      SaveIntent: CallbackAction<SaveIntent>(onInvoke: (_) => _save()),
      UndoIntent: CallbackAction<UndoIntent>(onInvoke: (_) => _undo()),
      // ...
    },
    child: Focus(
      autofocus: true,
      child: EditorScreen(),
    ),
  ),
)
```

Handle Ctrl vs Cmd automatically using `LogicalKeyboardKey.control` — Flutter maps this to Cmd on macOS.

### 6.3 Tablet Adaptations

**File:** `lib/platform/tablet_adaptations.dart`

- Detect tablet: `MediaQuery.of(context).size.shortestSide < 600` or check `defaultTargetPlatform`.
- Floating toolbar: wrap toolbar in a `Positioned` widget inside a `Stack`. Make it draggable via `GestureDetector` + position state.
- Action bar: fixed `BottomAppBar` with Undo, Redo, Delete buttons. Always visible.
- Increase all icon sizes to 48px. Increase all touch targets to minimum 44px.
- Handle `PointerDeviceKind.stylus` in gesture handlers for Apple Pencil precision.

---

## 7. Undo/Redo System

Implement a command pattern. Every user action that modifies data creates a `Command` object that can be undone and redone.

```dart
abstract class Command {
  String get description;
  Future<void> execute();
  Future<void> undo();
}

class UndoRedoService extends StateNotifier<UndoRedoState> {
  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];

  Future<void> execute(Command command) async {
    await command.execute();
    _undoStack.add(command);
    _redoStack.clear(); // new action clears redo stack
    // ...
  }

  Future<void> undo() async { ... }
  Future<void> redo() async { ... }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
}
```

**Scope:** Undo applies to all user-initiated data changes:
- Geometry changes (draw/move/delete wall, window, door, zone)
- Parameter changes (room temperature, tube spacing, material layer edits)
- Circuit routing changes

**Stack limit:** Keep last 100 commands. Older commands are discarded.

### 7.1 Zone Creation (ADR-014)

Zone *creation* is undoable like every other geometry change. All
floor-zone gestures (`ZoneDrawTool`: polygon close, Ctrl-drag
rectangle, Ctrl+Shift+click fill-room) and wall-zone placement
(`WallZonePlaceTool`) route their single shared commit through one
`_CreateZoneCommand` on `UndoRedoService` — never call
`EditorCallbacks.commitZone` directly from a creation path.
`ZoneDrawTool` and `WallZonePlaceTool` take the `undoRedo`
constructor dependency the other tools already have. `execute` adds
the zone, `undo` removes it by id, `redo` re-adds the same record.
One zone = one undo entry. See `DECISIONS.md` ADR-014.

---

## 8. Save State & AutoSave

### 8.1 SaveStateNotifier Wiring

Every repository write must notify the `SaveStateNotifier`. Use a repository mixin so no DAO call is ever missed:

```dart
/// Mix into every repository class that performs write operations.
mixin SaveStateMixin {
  Ref get ref;  // must be provided by the concrete repository

  /// Call this immediately after every successful DAO insert/update/delete.
  void markDirty() => ref.read(saveStateProvider.notifier).markDirty();
}
```

Example in `BuildingRepository`:

```dart
class BuildingRepository with SaveStateMixin {
  BuildingRepository(this.ref, this._dao);

  @override
  final Ref ref;
  final BuildingDao _dao;

  Future<void> addWallSegment(WallSegment wall) async {
    await _dao.insert(wall);
    markDirty();
  }
  // ... same pattern for every mutating method
}
```

**Scope:** All repository classes — `ProjectRepository`, `BuildingRepository`, `ConstructionRepository`, `HeatingRepository`. The `MaterialRepository` (seed data inserts) does NOT call `markDirty` for built-in material inserts; only for user-created custom materials.

### 8.2 Save State Indicator Widget

**File:** `lib/ui/widgets/save_state_indicator.dart`

A compact widget placed in the status bar and/or the window title. Shows the current save status without interrupting the user.

| State | Visual |
|-------|--------|
| `isDirty = false, isAutoExporting = false` | "Saved" in `onSurfaceSecondary` colour, check icon |
| `isDirty = true, isAutoExporting = false` | Unsaved dot (●) in `warningAmber`, no text on status bar (to keep it compact); tooltip: "Changes not yet saved to file" |
| `isAutoExporting = true` | Spinning micro-indicator (12px), "Saving…" text |
| `lastExportPath == null` | No indicator (user has not set up file export — all data is safe in the database) |

```dart
class SaveStateIndicator extends ConsumerWidget {
  const SaveStateIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saveStateProvider);
    if (state.lastExportPath == null) return const SizedBox.shrink();
    if (state.isAutoExporting) return _Saving();
    if (state.isDirty) return _UnsavedDot();
    return _Saved();
  }
}
```

### 8.3 Manual Save Actions

**Ctrl/Cmd + S — Save:**
- If `lastExportPath != null`: write `.hsp` to the same path immediately (bypasses debounce). Show "Saved" confirmation in status bar for 2 seconds.
- If `lastExportPath == null`: behave as Save As (open file picker).

**Ctrl/Cmd + Shift + S — Save As:**
- Open `FilePicker.saveFile()` with filter `*.hsp`.
- On path selected: write `.hsp`, update `lastExportPath` in `SaveState`, clear `isDirty`.
- On cancel: do nothing.

Both actions are wired through `KeyboardShortcuts` and the desktop menu `File` menu. The `Actions` widget maps `SaveIntent` and `SaveAsIntent` to the above logic via the `SaveStateNotifier`.

### 8.4 App Close / Window Destroy Handler

**File:** `lib/platform/desktop_menu.dart` (close handling) and `lib/app.dart` (lifecycle)

On desktop (macOS/Windows/Linux), intercept the window close event:

```dart
// In app.dart — use window_manager or equivalent platform channel
windowManager.setPreventClose(true);
windowManager.addListener(_AppWindowListener(ref));

class _AppWindowListener extends WindowListener {
  _AppWindowListener(this.ref);
  final WidgetRef ref;

  @override
  Future<void> onWindowClose() async {
    final state = ref.read(saveStateProvider);
    if (state.isDirty && state.lastExportPath != null) {
      // Show confirmation dialog
      final choice = await showUnsavedChangesDialog(ref.context);
      // choice: SaveAndQuit, QuitWithoutSaving, Cancel
      if (choice == UnsavedChoice.saveAndQuit) {
        await ref.read(saveStateProvider.notifier).exportNow();
        windowManager.destroy();
      } else if (choice == UnsavedChoice.quitWithoutSaving) {
        windowManager.destroy();
      }
      // Cancel: do nothing — window stays open
    } else {
      windowManager.destroy();  // always safe — all data is in SQLite
    }
  }
}
```

> **Note:** Even if the user quits without saving the `.hsp` file, **no project data is lost** — SQLite always holds the complete current state. The confirmation dialog is about the portable `.hsp` file only, not about data safety. The dialog wording must reflect this: "You have unsaved changes to your export file. Your project is safely stored in the app — this only affects the .hsp file."

On tablet (iOS/Android), use `AppLifecycleListener` to trigger the auto-export immediately when the app moves to background:

```dart
AppLifecycleListener(
  onInactive: () => ref.read(saveStateProvider.notifier).exportNow(),
);
```

### 8.5 Startup — Session Restore

**File:** `lib/app.dart` / `lib/ui/screens/project_list_screen.dart`

On app launch, before showing any screen:

```dart
final lastId = ref.read(lastOpenedProjectIdProvider);
if (lastId != null) {
  final project = await ref.read(projectRepositoryProvider).findById(lastId);
  if (project != null) {
    // Navigate directly to EditorScreen for this project
    return EditorScreen(projectId: lastId);
  }
}
// Fallback: show project list
return ProjectListScreen();
```

When opening a project (from project list or file import), immediately write `lastOpenedProjectId` to `AppPreferences`.

---

## 9. Export Implementation

### 8.1 PDF Report

**File:** `lib/export/pdf_report_generator.dart`

Use the `pdf` (dart) package. Generate pages:

1. **Cover page:** Project name, date, location, designer.
2. **Floor plan image:** Render the canvas to a `ui.Image` using `RenderRepaintBoundary.toImage()`, then convert to PDF image.
3. **Heat demand table:** Per-room table (room name, area, volume, Q_T, Q_V, Q_total).
4. **Wall constructions table:** Per-construction (name, layers, U-value).
5. **Circuit summary table:** Per-circuit (zone name, tube length, flow rate, velocity, Δp, heat output).
6. **Hydraulic chart:** Render `fl_chart` to image, embed in PDF.
7. **Warnings page:** All active validation results.

### 8.2 CSV Export

**File:** `lib/export/csv_exporter.dart`

Three export files:
- `heat_demand.csv`: room_name, area_m2, volume_m3, q_transmission_w, q_ventilation_w, q_total_w
- `circuits.csv`: circuit_id, zone_name, tube_length_m, flow_rate_kg_h, velocity_m_s, pressure_loss_pa, heat_output_w
- `materials.csv`: construction_name, layer_materials, u_value

Use `StringBuffer` with comma-separated values. UTF-8 encoding. BOM for Excel compatibility.

---

## 10. Frontend Code Review Checklist

Before submitting work for review:

- [ ] Widget extends `ConsumerWidget` or `ConsumerStatefulWidget` (not plain `StatefulWidget`) when provider access is needed
- [ ] All `AsyncValue` states handled (data, loading, error)
- [ ] No hard-coded colour values — all from theme or `HeatingPlannerColors` extension
- [ ] No hard-coded spacing — all use 4px grid tokens (4, 8, 16, 24, 32)
- [ ] Touch targets ≥ 44px on tablet layout
- [ ] `RepaintBoundary` wraps each canvas painter layer
- [ ] `shouldRepaint` correctly implemented in every `CustomPainter`
- [ ] Snapping logic delegates to `SnapService`, not reimplemented per tool
- [ ] Undo/redo `Command` created for every data mutation
- [ ] No direct repository imports — all data access through Riverpod providers
- [ ] Keyboard shortcuts wrapped in `Shortcuts` + `Actions` (not raw `RawKeyboardListener`)
- [ ] Responsive layout tested at 600dp breakpoint
- [ ] Doc comments on all public widgets and methods
- [ ] Every repository write calls `markDirty()` via `SaveStateMixin`
- [ ] `SaveStateIndicator` present in the status bar
- [ ] Window close handler wired; confirmation dialog wording mentions SQLite safety
- [ ] `lastOpenedProjectId` written to `AppPreferences` on project open/create
- [ ] Startup correctly restores last session (or shows project list if no last project)