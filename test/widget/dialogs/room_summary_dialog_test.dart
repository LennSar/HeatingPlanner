// Room summary dialog (ADR-045): one row per room and circuit, the
// difference between delivered heat and demand marked green or red.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/providers/room_summary_providers.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/ui/dialogs/room_summary_dialog.dart';

ZoneSummary _zone({required int? number, required double outputW}) => (
  zoneId: 'zone-$number',
  circuitId: number == null ? null : 'circuit-$number',
  circuitNumber: number,
  zoneType: ZoneType.floorHeating,
  areaM2: 12.5,
  supplyTempC: number == null ? double.nan : 35,
  returnTempC: number == null ? double.nan : 28,
  specificOutputWPerM2: outputW / 12.5,
  outputW: outputW,
  surfaceTempC: number == null ? double.nan : 25.4,
  flowRateKgH: number == null ? double.nan : 92.3,
  velocityMPerS: 0.2,
  tubeOuterDiameterMm: 16,
  tubeWallThicknessMm: 2,
  pressureLossPa: number == null ? double.nan : 7350,
  zoneTubeLengthM: 81.2,
  totalTubeLengthM: number == null ? double.nan : 95.6,
);

FloorSummary _floor() => summariseFloor([
  summariseRoom(
    roomId: 'r1',
    name: 'Living',
    isHeated: true,
    targetTempC: 20,
    demandW: 700,
    zones: [_zone(number: 1, outputW: 750)],
  ),
  summariseRoom(
    roomId: 'r2',
    name: 'Bath',
    isHeated: true,
    targetTempC: 24,
    demandW: 600,
    zones: [_zone(number: null, outputW: double.nan)],
  ),
  summariseRoom(
    roomId: 'r3',
    name: 'Store',
    isHeated: false,
    targetTempC: 12,
    demandW: 0,
    zones: const [],
  ),
]);

Future<void> _pump(
  WidgetTester tester,
  FloorSummary floor, {
  Locale locale = const Locale('en'),
  Size size = const Size(1600, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [floorSummaryProvider.overrideWithValue(floor)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en'), Locale('de')],
        home: const Scaffold(body: RoomSummaryDialog()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _balanceColor(WidgetTester tester, String text) {
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(text), matching: find.byType(DecoratedBox))
        .first,
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('lists rooms with their circuits and the totals', (tester) async {
    await _pump(tester, _floor());

    expect(find.text('Room summary'), findsOneWidget);
    expect(find.text('Living · 20 °C'), findsOneWidget);
    expect(find.text('Bath · 24 °C'), findsOneWidget);
    expect(find.text('Store · unheated'), findsOneWidget);
    expect(find.text('Circuit 1'), findsOneWidget);
    expect(find.text('Zone not connected'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    // Circuit row: temperatures, flow, heat flux, tube, pressure loss.
    expect(find.text('35 / 28'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    // The tube is known for the unconnected zone too.
    expect(find.text('16 × 2.0'), findsNWidgets(2));
    expect(find.text('25.4'), findsOneWidget);
    // Living row, its circuit row and the total row.
    expect(find.text('92.3'), findsNWidgets(3));
    expect(find.text('7.35'), findsNWidgets(3));

    // Tube in the room and including the connection pipes.
    expect(find.text('81.2'), findsNWidgets(4));
    expect(find.text('95.6'), findsNWidgets(3));
    expect(find.text('162.4'), findsOneWidget);

    // Totals: demand 1300 W, delivered 750 W.
    expect(find.text('1300'), findsOneWidget);
  });

  testWidgets('difference is green when covered and red when short', (
    tester,
  ) async {
    await _pump(tester, _floor());
    final colors = AppTheme.light().extension<HeatingPlannerColors>()!;

    // Living: 750 − 700 = +50 W.
    expect(find.text('+50'), findsOneWidget);
    expect(
      _balanceColor(tester, '+50').toARGB32() & 0xFFFFFF,
      colors.zoneGreen.toARGB32() & 0xFFFFFF,
    );
    // Bath: nothing connected, short by its whole demand.
    expect(find.text('-600'), findsOneWidget);
    expect(
      _balanceColor(tester, '-600').toARGB32() & 0xFFFFFF,
      colors.zoneRed.toARGB32() & 0xFFFFFF,
    );
    // Floor total: 750 − 1300.
    expect(find.text('-550'), findsOneWidget);

    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsNWidgets(2));
  });

  testWidgets('warns when a room demand is unknown', (tester) async {
    await _pump(
      tester,
      summariseFloor([
        summariseRoom(
          roomId: 'r1',
          name: 'Living',
          isHeated: true,
          targetTempC: 20,
          demandW: double.nan,
          zones: [_zone(number: 1, outputW: 750)],
        ),
      ]),
    );

    expect(find.textContaining('cannot be calculated yet'), findsOneWidget);
    // No balance for that room, so nothing is coloured in its row.
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
  });

  testWidgets('shows a hint when there are no rooms', (tester) async {
    await _pump(tester, summariseFloor(const []));

    expect(find.text('Draw a room to see its heat balance.'), findsOneWidget);
    expect(find.text('Total'), findsNothing);
  });

  testWidgets('fits a small window by scrolling', (tester) async {
    await _pump(tester, _floor(), size: const Size(700, 520));

    // No overflow error; the table is there and scrolls.
    expect(tester.takeException(), isNull);
    expect(find.text('Living · 20 °C'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNWidgets(2));
  });

  testWidgets('is translated to German', (tester) async {
    await _pump(tester, _floor(), locale: const Locale('de'));

    expect(find.text('Raumübersicht'), findsOneWidget);
    expect(find.text('Heizlast'), findsOneWidget);
    expect(find.text('Heizkreis 1'), findsOneWidget);
    expect(find.text('Store · unbeheizt'), findsOneWidget);
  });
}
