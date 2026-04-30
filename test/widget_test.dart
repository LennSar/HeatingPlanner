import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heating_planner/app.dart';

void main() {
  testWidgets('App smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: HeatingPlannerApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);

    // Tear down: replace the widget tree and drain pending timers left by
    // stream subscriptions (e.g. materialEntriesProvider's drift watch).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
