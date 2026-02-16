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
- Draw each wall segment as a filled rectangle with `wallFill` colour and `wallStroke` outline.
- Shared wall segments (between two rooms) are drawn once, not twice.
- Show dimension text (length in mm) alongside each wall, rotated to match wall angle.

**Heating zone painter specifics:**
- Fill zone polygon with semi-transparent colour (green/yellow/red per adequacy).
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

### 4.5 Snapping Implementation

Implement snapping in a `SnapService` utility class consumed by all tools:

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

---

## 8. Export Implementation

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

## 9. Frontend Code Review Checklist

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
