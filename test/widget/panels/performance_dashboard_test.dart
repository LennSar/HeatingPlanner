// Widget tests for the hover-to-highlight interaction in PerformanceDashboardPanel.
//
// Per agent-test.md §6.1. Tests exercise the _WarningRow hover/long-press
// interactions through the public PerformanceDashboardPanel widget (Warnings
// tab, initialIndex: 2). All heavy providers are overridden with stubs;
// no database, calculation, or repository access is needed.
//
// Covered scenarios:
//   WH-1  Mouse enter → hoveredElementProvider set to matching element
//   WH-2  Mouse exit  → hoveredElementProvider cleared
//   WH-3  Long press  → hoveredElementProvider set immediately
//   WH-4  Long press  → hoveredElementProvider auto-cleared after 2 s
//   WH-5  Multiple rows: hovering a different row updates the provider

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/validation_result.dart';
import 'package:heating_planner/ui/panels/performance_dashboard.dart';
import 'package:heating_planner/ui/providers/selection_provider.dart';
import 'package:heating_planner/validation/validation_service.dart';

// ── Fixed test results ────────────────────────────────────────────────────────

const _circuitError = ValidationResult(
  severity: WarningSeverity.error,
  elementId: 'circuit-42',
  elementType: 'circuit',
  message: 'Circuit supply route is not connected to the distributor.',
  suggestedFix: 'Use the Route Pipe tool to redraw this circuit.',
);

const _wallWarning = ValidationResult(
  severity: WarningSeverity.warning,
  elementId: 'wall-7',
  elementType: 'wall',
  message: 'Exterior wall has no construction assigned.',
);

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _buildPanel(List<ValidationResult> results) {
  return ProviderScope(
    overrides: [
      // validationResultsProvider is a Provider.family — override with a
      // plain function that ignores the projectId argument.
      validationResultsProvider.overrideWith((ref, _) => results),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      // Full-screen Scaffold avoids layout overflow in the warnings header.
      home: const Scaffold(
        body: PerformanceDashboardPanel(initialIndex: 2),
      ),
    ),
  );
}

// ── Helper: read hoveredElementProvider from the container ────────────────────

/// Returns the [SelectedElement?] currently held by [hoveredElementProvider].
///
/// Uses [MaterialApp] as the context passed to [ProviderScope.containerOf]
/// because that widget is a child of the root [ProviderScope], satisfying
/// the requirement that the context must have a [ProviderScope] ancestor.
SelectedElement? _readHovered(WidgetTester tester) {
  final ctx = tester.element(find.byType(MaterialApp).first);
  return ProviderScope.containerOf(ctx).read(hoveredElementProvider);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('_WarningRow — mouse hover (desktop)', () {
    testWidgets(
        'WH-1: entering a warning row sets hoveredElementProvider '
        'to the matching element', (tester) async {
      await tester.pumpWidget(_buildPanel([_circuitError]));
      await tester.pumpAndSettle();

      // Locate the row by its message text.
      final rowFinder = find.text(_circuitError.message);
      expect(rowFinder, findsOneWidget);

      // Simulate pointer entering the MouseRegion.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(rowFinder));
      await tester.pump();

      final hovered = _readHovered(tester);
      expect(hovered, isNotNull);
      expect(hovered!.type, equals('circuit'));
      expect(hovered.id, equals('circuit-42'));
    });

    testWidgets(
        'WH-2: exiting a warning row clears hoveredElementProvider',
        (tester) async {
      await tester.pumpWidget(_buildPanel([_circuitError]));
      await tester.pumpAndSettle();

      final rowFinder = find.text(_circuitError.message);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // Enter.
      await gesture.moveTo(tester.getCenter(rowFinder));
      await tester.pump();
      expect(_readHovered(tester), isNotNull);

      // Exit: move far off-screen.
      await gesture.moveTo(const Offset(2000, 2000));
      await tester.pump();
      expect(_readHovered(tester), isNull);
    });

    testWidgets(
        'WH-5: hovering a second row updates the provider to that row',
        (tester) async {
      await tester.pumpWidget(_buildPanel([_circuitError, _wallWarning]));
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // Hover first row.
      await gesture.moveTo(tester.getCenter(find.text(_circuitError.message)));
      await tester.pump();
      expect(_readHovered(tester)!.id, equals('circuit-42'));

      // Move to second row.
      await gesture.moveTo(tester.getCenter(find.text(_wallWarning.message)));
      await tester.pump();
      final hovered = _readHovered(tester);
      expect(hovered!.type, equals('wall'));
      expect(hovered.id, equals('wall-7'));
    });
  });

  group('_WarningRow — long press (tablet)', () {
    testWidgets(
        'WH-3: long-pressing a warning row sets hoveredElementProvider',
        (tester) async {
      await tester.pumpWidget(_buildPanel([_circuitError]));
      await tester.pumpAndSettle();

      await tester.longPress(find.text(_circuitError.message));
      await tester.pump();

      final hovered = _readHovered(tester);
      expect(hovered, isNotNull);
      expect(hovered!.type, equals('circuit'));
      expect(hovered.id, equals('circuit-42'));
    });

    testWidgets(
        'WH-4: after long press the provider auto-clears after 2 seconds',
        (tester) async {
      // Note: tester.longPress internally pumps kLongPressTimeout (500 ms),
      // so the fake clock is already at ~500 ms when onLongPress fires and
      // the 2-second auto-clear timer starts. Pumping another 2 s guarantees
      // the timer elapses without needing intermediate checks.
      await tester.pumpWidget(_buildPanel([_circuitError]));
      await tester.pumpAndSettle();

      await tester.longPress(find.text(_circuitError.message));
      await tester.pump();

      // Provider should be set immediately after long press.
      expect(_readHovered(tester), isNotNull);

      // Advance 2 s past the current point → timer fires and clears.
      await tester.pump(const Duration(seconds: 2));
      expect(_readHovered(tester), isNull);
    });
  });

  group('_WarningRow — both error and warning severity', () {
    testWidgets('WH-6: error row highlights correctly', (tester) async {
      await tester.pumpWidget(_buildPanel([_circuitError]));
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.text(_circuitError.message)));
      await tester.pump();

      expect(_readHovered(tester)?.id, equals('circuit-42'));
    });

    testWidgets('WH-7: warning row highlights correctly', (tester) async {
      await tester.pumpWidget(_buildPanel([_wallWarning]));
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.text(_wallWarning.message)));
      await tester.pump();

      final hovered = _readHovered(tester);
      expect(hovered?.type, equals('wall'));
      expect(hovered?.id, equals('wall-7'));
    });
  });
}
