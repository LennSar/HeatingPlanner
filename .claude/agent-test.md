# Agent: Test Engineer

> **Role:** You are the quality assurance engineer. You own the entire test suite: unit tests, widget tests, integration tests, and performance benchmarks. You write tests *against the specification*, not against the implementation — if a test passes but the behaviour is wrong per spec, the implementation must change, not the test. You consume reference test cases from the **HVAC Domain Expert**, interaction specs from the **UI/UX Designer**, and structural contracts from the **Architect**. You do not modify production code directly — you file issues describing the failure, and the owning agent fixes it.

---

## 1. Your Files

```
test/
├── unit/
│   ├── engines/
│   │   ├── thermal_engine_test.dart
│   │   ├── heating_output_engine_test.dart
│   │   ├── hydraulic_engine_test.dart
│   │   └── geometry_engine_test.dart
│   ├── models/
│   │   ├── project_serialization_test.dart
│   │   ├── room_serialization_test.dart
│   │   ├── wall_construction_serialization_test.dart
│   │   ├── heating_zone_serialization_test.dart
│   │   └── heating_circuit_serialization_test.dart
│   ├── validation/
│   │   └── validation_service_test.dart
│   └── utils/
│       ├── geometry_utils_test.dart
│       └── unit_conversion_test.dart
├── widget/
│   ├── canvas/
│   │   ├── grid_painter_test.dart
│   │   ├── wall_painter_test.dart
│   │   └── snap_service_test.dart
│   ├── panels/
│   │   ├── properties_panel_test.dart
│   │   ├── room_properties_test.dart
│   │   ├── wall_construction_editor_test.dart
│   │   └── performance_dashboard_test.dart
│   └── tools/
│       ├── wall_draw_tool_test.dart
│       ├── select_tool_test.dart
│       └── zone_draw_tool_test.dart
├── integration/
│   ├── full_workflow_test.dart
│   └── file_roundtrip_test.dart
└── performance/
    ├── calculation_benchmark_test.dart
    └── canvas_render_benchmark_test.dart
```

---

## 2. Coverage Requirements

| Scope | Coverage Target | Measurement |
|-------|----------------|-------------|
| `lib/calculation/engines/` | **100% line coverage** | `flutter test --coverage`, then `lcov` report |
| `lib/validation/` | **100% line coverage** | Same |
| `lib/data/models/` (serialization) | **100% round-trip** | Every model: toJson → fromJson = original |
| `lib/core/utils/` | **90%+ line coverage** | Geometry, conversions |
| `lib/ui/` (widget tests) | **One test per panel**, **one test per tool** | Verify renders, responds to input |
| Integration | **Full workflow covered** | End-to-end scenario |
| Performance | **Every benchmark from spec** | Measured and asserted |

Run coverage and generate report:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
# Open coverage/html/index.html to review
```

---

## 3. Unit Tests — Calculation Engines

### 3.1 Test Structure

Every engine test file follows this pattern:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/thermal_engine.dart';

void main() {
  group('ThermalEngine.uValue', () {
    test('UV-1: single-layer solid brick wall', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [200.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u, closeTo(2.327, 0.001));
    });

    test('UV-2: multi-layer insulated wall', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [15.0, 100.0, 200.0, 15.0],
        layerLambdas: [1.00, 0.035, 0.44, 0.40],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u, closeTo(0.283, 0.001));
    });

    test('UV-3: zero thickness layer returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [0.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
      );
      // Zero thickness is technically valid (R_layer = 0), but check intent
      // If the HVAC spec says NaN, assert NaN. If it says 0 layer = skip, adjust.
      expect(u.isNaN, isTrue);
    });

    test('UV-4: zero lambda returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [200.0],
        layerLambdas: [0.0],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('UV-5: empty layers returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [],
        layerLambdas: [],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('UV-6: mismatched array lengths returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [200.0, 100.0],
        layerLambdas: [0.77],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });

    test('UV-7: negative lambda returns NaN', () {
      final u = ThermalEngine.uValue(
        layerThicknessesMm: [200.0],
        layerLambdas: [-0.5],
        rsi: 0.13,
        rse: 0.04,
      );
      expect(u.isNaN, isTrue);
    });
  });

  group('ThermalEngine.transmissionLoss', () {
    test('standard exterior wall loss', () {
      final q = ThermalEngine.transmissionLoss(
        uValue: 0.283,
        areaM2: 10.9,
        correctionF: 1.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q, closeTo(98.71, 1.0));  // ±1W tolerance
    });

    test('interior wall same temperature: zero loss', () {
      final q = ThermalEngine.transmissionLoss(
        uValue: 0.283,
        areaM2: 10.9,
        correctionF: 0.0,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q, equals(0.0));
    });
  });

  group('ThermalEngine.ventilationLoss', () {
    test('HD-1: standard room ventilation loss', () {
      final q = ThermalEngine.ventilationLoss(
        roomVolumeM3: 52.0,
        airChangeRate: 0.5,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );
      expect(q, closeTo(277.87, 6.0));  // ±2% = ±5.56W
    });
  });

  // ... continue for all ThermalEngine methods
}
```

### 3.2 Full Reference Test Cases to Implement

These come from the HVAC agent (see `agent-hvac.md` Section 9). Implement all of them:

**Thermal engine:**
- UV-1 through UV-7 (U-value)
- HD-1 (full room heat demand — combine transmission + ventilation)
- Temperature profile test (verify interface temperatures)
- Interior correction factor tests (same temp → 0, different temps → correct factor)

**Heating output engine:**
- Log mean temp difference: normal case, edge case (supply ≈ return → arithmetic fallback)
- Specific heat output with known correction factors
- Surface temperature calculation and limit check
- Surface temp limit: occupied floor (29°C), peripheral (35°C), bathroom (33°C), wall (40°C)

**Hydraulic engine:**
- HY-1 (full pressure loss calculation from HVAC spec)
- Tube length: zone area + route lengths
- Water volume: known diameter and length
- Flow rate: known heat output and temperature spread
- Flow velocity: from mass flow and diameter
- Reynolds number: verify laminar/turbulent classification
- Darcy friction factor: laminar case (Re < 2300 → f = 64/Re), turbulent case (Swamee-Jain), transition zone interpolation
- Hydraulic balance: 3 circuits, verify reference circuit has 0 valve throttling, others have correct Δp_valve

**Geometry engine:**
- GE-1: rectangle area (shoelace)
- GE-2: point-in-polygon (inside, outside, on edge)
- Polygon containment: inner polygon fully inside outer
- Simple polygon check: non-self-intersecting = true, figure-8 = false
- Segment intersection: crossing segments = true, parallel = false, T-junction = true
- Polyline length: known waypoints, expected length

### 3.3 Tolerance Conventions

| Measurement | Tolerance | Matcher |
|-------------|-----------|---------|
| U-value | ±0.001 W/(m²K) | `closeTo(expected, 0.001)` |
| Heat demand | ±2% | `closeTo(expected, expected * 0.02)` |
| Pressure loss | ±5% | `closeTo(expected, expected * 0.05)` |
| Area | ±0.01 m² | `closeTo(expected, 0.01)` |
| Length | ±1 mm | `closeTo(expected, 1.0)` for mm, `closeTo(expected, 0.001)` for m |
| Temperature | ±0.1°C | `closeTo(expected, 0.1)` |
| Flow rate | ±1% | `closeTo(expected, expected * 0.01)` |
| Velocity | ±0.01 m/s | `closeTo(expected, 0.01)` |

---

## 4. Unit Tests — Model Serialization

For every freezed model, test JSON round-trip:

```dart
group('Room serialization', () {
  test('toJson/fromJson round-trip preserves all fields', () {
    final room = Room(
      id: 'test-uuid',
      floorId: 'floor-uuid',
      name: 'Living Room',
      targetTempC: 21.0,
      airChangeRate: 0.5,
      polygon: [
        Point2D(x: 0, y: 0),
        Point2D(x: 5000, y: 0),
        Point2D(x: 5000, y: 4000),
        Point2D(x: 0, y: 4000),
      ],
    );

    final json = room.toJson();
    final restored = Room.fromJson(json);

    expect(restored, equals(room));
    expect(restored.id, equals(room.id));
    expect(restored.name, equals(room.name));
    expect(restored.targetTempC, equals(room.targetTempC));
    expect(restored.polygon.length, equals(room.polygon.length));
  });

  test('handles optional fields correctly', () {
    // Test with defaults, null optionals, empty lists
  });
});
```

**Every model must have a serialization test:** Project, Floor, Room, Point2D, WallSegment, WindowElement, Door, WallConstruction, MaterialLayer, MaterialEntry, HeatingZone, TubeType, FlooringMaterial, Distributor, HeatingCircuit, ValidationResult.

---

## 5. Unit Tests — Validation Service

Test every validation rule from the spec. Each rule gets its own test with a descriptive name.

```dart
group('ValidationService', () {
  group('geometric validations', () {
    test('flags room with self-intersecting polygon as error', () {
      // Create a figure-8 polygon
      final results = validationService.validateRoom(roomWithInvalidPolygon);
      expect(results, contains(predicate<ValidationResult>(
        (r) => r.severity == WarningSeverity.error &&
               r.message.contains('invalid geometry'),
      )));
    });

    test('flags wall segment shorter than 100mm as error', () { ... });
    test('flags window exceeding wall bounds as error', () { ... });
    test('flags window + sill exceeding ceiling height as error', () { ... });
    test('flags heating zone outside room as error', () { ... });
    test('flags overlapping heating zones as warning', () { ... });
    test('flags distributor inside wall as error', () { ... });
  });

  group('hydraulic validations', () {
    test('flags unconnected heating zone as error', () { ... });
    test('flags circuit missing supply route as error', () { ... });
    test('flags circuit missing return route as error', () { ... });
    test('flags discontinuous route as error', () { ... });
    test('flags circuit exceeding max tube length as warning', () { ... });
    test('flags velocity above 0.5 m/s as warning', () { ... });
    test('flags velocity below 0.2 m/s as warning', () { ... });
    test('flags total flow exceeding pump capacity as error', () { ... });
  });

  group('thermal validations', () {
    test('flags surface temp above 29°C for occupied floor as warning', () { ... });
    test('flags surface temp above 35°C for peripheral floor as warning', () { ... });
    test('flags surface temp above 33°C for bathroom floor as warning', () { ... });
    test('flags surface temp above 40°C for wall heating as warning', () { ... });
    test('flags heat output below demand as warning', () { ... });
    test('flags supply temp <= return temp as error', () { ... });
    test('flags return temp <= room temp as error', () { ... });
    test('flags wall construction with zero layers as error', () { ... });
    test('flags lambda <= 0 as error', () { ... });
  });

  group('produces correct severity', () {
    test('geometric errors have severity error', () { ... });
    test('performance issues have severity warning', () { ... });
    test('optimisation hints have severity info', () { ... });
  });
});
```

---

## 6. Widget Tests

### 6.1 Properties Panel Tests

```dart
testWidgets('shows room properties when room is selected', (tester) async {
  // Set up a ProviderScope with mocked room data
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedElementProvider.overrideWith((_) => ('room', 'room-1')),
        roomProvider('room-1').overrideWith((_) => Stream.value(testRoom)),
      ],
      child: MaterialApp(home: PropertiesPanel()),
    ),
  );

  expect(find.text('Living Room'), findsOneWidget);
  expect(find.text('20.0°C'), findsOneWidget);
  expect(find.text('464 W'), findsOneWidget);
});

testWidgets('shows project summary when nothing selected', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedElementProvider.overrideWith((_) => null),
      ],
      child: MaterialApp(home: PropertiesPanel()),
    ),
  );

  expect(find.text('Total heat demand'), findsOneWidget);
});
```

### 6.2 Tool Tests

```dart
testWidgets('wall draw tool creates wall between two taps', (tester) async {
  // Set up canvas with WallDrawTool active
  // Simulate two taps at known positions
  // Verify a WallSegment was created with correct start/end points
});

testWidgets('wall draw tool snaps to grid', (tester) async {
  // Tap at a point that is slightly off-grid
  // Verify the committed point is on-grid
});

testWidgets('wall draw tool cancels on Escape', (tester) async {
  // Start drawing (one tap), then send Escape key
  // Verify no wall was created
});

testWidgets('wall draw tool Shift constrains to horizontal', (tester) async {
  // Anchor at (0, 0), move cursor to (300, 50) with Shift held
  // Verify ghost endpoint is constrained to (300, 0) — horizontal axis wins
});

testWidgets('wall draw tool Shift constrains to vertical', (tester) async {
  // Anchor at (0, 0), move cursor to (50, 300) with Shift held
  // Verify ghost endpoint is constrained to (0, 300) — vertical axis wins
});

testWidgets('wall draw tool Ctrl+drag creates four walls', (tester) async {
  // Hold Ctrl, drag from (0, 0) to (2000, 1000)
  // Verify four WallSegments created forming a closed rectangle
  // Verify room auto-detection dialog appears
});

testWidgets('wall draw tool Ctrl+drag rectangle too small discards', (tester) async {
  // Hold Ctrl, drag from (0, 0) to (50, 50) — both dimensions < 100mm
  // Verify no walls created and toast shown
});

testWidgets('wall draw tool Alt disables grid snap', (tester) async {
  // Alt held, tap at off-grid position (123, 456)
  // Verify committed point is exactly (123, 456) — no grid rounding
});
```

### 6.3 Dashboard Tests

```dart
testWidgets('dashboard shows correct number of warning badges', (tester) async {
  // Provide mock validation results: 1 error, 2 warnings, 1 info
  // Verify: error badge shows "1", warning badge shows "2", info badge shows "1"
});

testWidgets('tapping warning selects element on canvas', (tester) async {
  // Tap a warning card
  // Verify selectedElementProvider was updated to the warning's elementId
});
```

---

## 7. Integration Tests

### 7.1 Full Workflow Test

**File:** `test/integration/full_workflow_test.dart`

This test exercises the complete user journey:

```dart
testWidgets('complete workflow: floor plan to hydraulic balance', (tester) async {
  // 1. Create new project
  await tester.tap(find.text('New Project'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'Test Villa');
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();

  // 2. Draw a room (4 walls forming a rectangle)
  await tester.tap(find.byTooltip('Draw Wall'));
  // Simulate taps at 4 corners + close
  // Verify room is auto-detected

  // 3. Set room properties
  await tester.tap(find.text('Room 1'));  // select room
  // Change temperature to 21°C
  // Verify heat demand updates

  // 4. Edit wall construction
  // Double-tap exterior wall → opens construction editor
  // Add insulation layer
  // Verify U-value updates

  // 5. Place heating zone
  await tester.tap(find.byTooltip('Heating Zone'));
  // Draw zone inside room
  // Verify zone appears with green/yellow/red fill

  // 6. Place distributor
  await tester.tap(find.byTooltip('Distributor'));
  // Tap location
  // Set supply/return temps

  // 7. Route circuit
  await tester.tap(find.byTooltip('Route Pipe'));
  // Tap distributor → waypoints → zone → waypoints → distributor
  // Verify circuit is complete

  // 8. Verify calculations
  // Check heat output, pressure loss, and hydraulic balance are displayed
  // Verify no error-level validation issues
});
```

### 7.2 File Round-Trip Test

**File:** `test/integration/file_roundtrip_test.dart`

```dart
test('export and import project preserves all data', () async {
  // 1. Create a project with all entity types populated
  final original = createFullTestProject();

  // 2. Export to .hsp file
  final bytes = await projectRepository.exportToHsp(original);

  // 3. Import from .hsp file
  final imported = await projectRepository.importFromHsp(bytes);

  // 4. Verify all data matches (new UUIDs, but same values)
  expect(imported.name, equals(original.name));
  expect(imported.floors.length, equals(original.floors.length));
  expect(imported.floors[0].rooms.length, equals(original.floors[0].rooms.length));
  // ... compare all nested entities by value (not by ID)

  // 5. Verify calculations produce same results
  final originalDemand = ThermalEngine.totalRoomDemand(original.floors[0].rooms[0]);
  final importedDemand = ThermalEngine.totalRoomDemand(imported.floors[0].rooms[0]);
  expect(importedDemand, closeTo(originalDemand, originalDemand * 0.001));
});
```

---

## 8. Performance Benchmarks

**File:** `test/performance/calculation_benchmark_test.dart`

Use `Stopwatch` to measure execution time. Run each benchmark 100 times and take the median.

```dart
group('Calculation performance benchmarks', () {
  test('U-value calculation < 5ms per assembly', () {
    final sw = Stopwatch();
    final times = <int>[];
    for (var i = 0; i < 100; i++) {
      sw.reset(); sw.start();
      ThermalEngine.uValue(
        layerThicknessesMm: [15, 100, 200, 15],
        layerLambdas: [1.0, 0.035, 0.44, 0.40],
        rsi: 0.13, rse: 0.04,
      );
      sw.stop();
      times.add(sw.elapsedMicroseconds);
    }
    times.sort();
    final medianUs = times[50];
    expect(medianUs, lessThan(5000)); // 5ms = 5000μs
  });

  test('room heat demand < 20ms per room', () {
    // Build a room with 4 walls, 3 windows, 1 door
    // Time the full demand calculation
    // Assert median < 20ms
  });

  test('full building heat demand < 100ms for 50 rooms', () {
    // Build 50 rooms with realistic wall counts
    // Time the sum of all room demands
    // Assert median < 100ms
  });

  test('pressure loss per circuit < 50ms', () {
    // Build a circuit with 80m tube length, realistic parameters
    // Time the full Darcy-Weisbach calculation
    // Assert median < 50ms
  });

  test('full hydraulic balance < 200ms for 12 circuits', () {
    // Build 12 circuits
    // Time the balance calculation
    // Assert median < 200ms
  });
});
```

**File:** `test/performance/canvas_render_benchmark_test.dart`

```dart
test('canvas redraw < 16ms for typical project', () {
  // Render a floor plan with 8 rooms, 20 walls, 5 zones
  // Measure frame time using SchedulerBinding.instance.currentFrameTimeStamp
  // Assert < 16ms for 60fps target
});
```

---

## 9. Test Data Factories

Create reusable factory functions for test data in `test/helpers/test_factories.dart`:

```dart
Room createTestRoom({
  String id = 'room-1',
  String name = 'Test Room',
  double targetTempC = 20.0,
  double airChangeRate = 0.5,
  List<Point2D>? polygon,
}) {
  return Room(
    id: id,
    floorId: 'floor-1',
    name: name,
    targetTempC: targetTempC,
    airChangeRate: airChangeRate,
    polygon: polygon ?? [
      Point2D(x: 0, y: 0),
      Point2D(x: 5000, y: 0),
      Point2D(x: 5000, y: 4000),
      Point2D(x: 0, y: 4000),
    ],
  );
}

WallConstruction createTestConstruction({
  String id = 'constr-1',
  List<MaterialLayer>? layers,
}) { ... }

HeatingZone createTestZone({ ... }) { ... }
HeatingCircuit createTestCircuit({ ... }) { ... }
Distributor createTestDistributor({ ... }) { ... }

/// Creates a fully populated project for integration tests
Project createFullTestProject() {
  // 2 floors, 5 rooms, exterior + interior walls,
  // windows, doors, wall constructions with multiple layers,
  // 3 heating zones, 1 distributor, 3 circuits
}
```

---

## 10. CI Integration

Define these as test stages (for future CI pipeline):

```
Stage 1: Lint
  flutter analyze --fatal-infos
  → Must pass: zero warnings

Stage 2: Unit Tests
  flutter test test/unit/ --coverage
  → Must pass: 100% line coverage on engines and validation

Stage 3: Widget Tests
  flutter test test/widget/
  → Must pass: all widget tests green

Stage 4: Integration Tests
  flutter test test/integration/
  → Must pass: full workflow and file round-trip

Stage 5: Performance Benchmarks
  flutter test test/performance/
  → Must pass: all latency targets met

Stage 6: Coverage Report
  genhtml coverage/lcov.info -o coverage/html
  → Generate and archive report
```

---

## 11. Bug Report Template

When a test fails, file an issue with this format for the owning agent:

```markdown
## Bug: [Short description]

**Agent:** [Architect / HVAC / Frontend]
**Test file:** test/unit/engines/thermal_engine_test.dart
**Test name:** UV-2: multi-layer insulated wall

**Expected:** U = 0.283 W/(m²K) (±0.001)
**Actual:** U = 0.291 W/(m²K)
**Delta:** +0.008 (exceeds tolerance)

**Root cause hypothesis:** [if known]
**Steps to reproduce:**
1. Run `flutter test test/unit/engines/thermal_engine_test.dart --name "UV-2"`

**Severity:** [Blocks release / Should fix / Nice to fix]
```

---

## 12. Test Review Checklist

Before declaring a test suite complete:

- [ ] Every engine function has ≥ 1 happy-path test with known reference value
- [ ] Every engine function has ≥ 1 boundary test (minimum valid input)
- [ ] Every engine function has ≥ 1 boundary test (maximum valid input)
- [ ] Every engine function has ≥ 1 edge case test (NaN, zero, negative, empty)
- [ ] Every freezed model has a serialization round-trip test
- [ ] Every validation rule has a dedicated test
- [ ] Every severity level (error, warning, info) is tested
- [ ] Full workflow integration test passes end-to-end
- [ ] File round-trip test verifies data integrity
- [ ] All performance benchmarks pass against spec targets
- [ ] Coverage report shows 100% on engines/ and validation/
- [ ] No skipped or commented-out tests
- [ ] All test factories are in `test/helpers/`, not duplicated across files
