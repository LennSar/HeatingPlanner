// Smoke test: HeatingZonePainter paints a zone with a tube layout and
// transit corridors (ADR-038) without throwing.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/pipe_layout_engine.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/ui/canvas/painters/heating_zone_painter.dart';

void main() {
  const zone = HeatingZone(
    id: 'zone-1',
    roomId: 'room-1',
    polygon: [
      Point2D(x: 0, y: 0),
      Point2D(x: 4000, y: 0),
      Point2D(x: 4000, y: 3000),
      Point2D(x: 0, y: 3000),
    ],
    tubeTypeId: 'tube-1',
    flooringMaterialId: 'mat-1',
  );

  HeatingZonePainter painter(Map<String, ZonePipeLayout> layouts) =>
      HeatingZonePainter(
        zoneGreen: Colors.green,
        zoneYellow: Colors.yellow,
        zoneRed: Colors.red,
        zoneGrey: Colors.grey,
        supplyPipe: Colors.red,
        zones: const [zone],
        zoneStates: const {'zone-1': ZoneColorState.sufficient},
        layouts: layouts,
      );

  void paint(HeatingZonePainter p) {
    final recorder = ui.PictureRecorder();
    p.paint(Canvas(recorder), const Size(4000, 3000));
    recorder.endRecording().dispose();
  }

  test('paints with a layout and corridors, and without a layout', () {
    final corridors = PipeLayoutEngine.transitCorridors(
      routes: const [
        [Point2D(x: -500, y: 1500), Point2D(x: 4500, y: 1500)],
      ],
      halfWidthMm: 75,
    );
    final path = PipeLayoutEngine.meanderPath(
      polygon: zone.polygon,
      tubeSpacingMm: zone.tubeSpacingMm,
      borderDistanceMm: zone.borderDistanceMm,
      entryPoint: const Point2D(x: 0, y: 200),
    );
    expect(
      () => paint(painter({'zone-1': (pipePath: path, corridors: corridors)})),
      returnsNormally,
    );
    expect(() => paint(painter(const {})), returnsNormally);
  });

  test('repaints when the layouts change', () {
    final a = painter(const {});
    final b = painter({
      'zone-1': (pipePath: const <Point2D>[], corridors: const []),
    });
    expect(b.shouldRepaint(a), isTrue);
  });

  test('paints every layout pattern with an identity palette, and '
      'repaints when the colours change', () {
    for (final pattern in LayoutPattern.values) {
      final p = HeatingZonePainter(
        zoneGreen: Colors.green,
        zoneYellow: Colors.yellow,
        zoneRed: Colors.red,
        zoneGrey: Colors.grey,
        supplyPipe: Colors.red,
        zones: [zone.copyWith(layoutPattern: pattern)],
        palette: const [Colors.blue, Colors.orange],
        colorIndices: const {'zone-1': 1},
      );
      expect(() => paint(p), returnsNormally, reason: pattern.name);
    }
    final a = painter(const {});
    const b = HeatingZonePainter(
      zoneGreen: Colors.green,
      zoneYellow: Colors.yellow,
      zoneRed: Colors.red,
      zoneGrey: Colors.grey,
      supplyPipe: Colors.red,
      zones: [zone],
      zoneStates: {'zone-1': ZoneColorState.sufficient},
      colorIndices: {'zone-1': 3},
    );
    expect(b.shouldRepaint(a), isTrue);
  });
}
