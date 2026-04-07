// JSON round-trip tests for every freezed model in lib/data/models/.
//
// Pattern per group (agent-test.md §2, §4):
//   1. Fully populated instance (all non-optional fields + ≥1 optional non-null).
//   2. toJson() → fromJson() round-trip.
//   3. Assert restored == original (freezed equality).
//   4. Spot-check ≥2 field values by name.
//   5. Minimal instance (required fields only, all optionals absent) also
//      round-trips to equality.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/door.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/material_layer.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/validation_result.dart';
import 'package:heating_planner/data/models/wall_construction.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/data/models/window_element.dart';

/// Serialize [value] to a JSON string and back.
///
/// This ensures nested freezed objects (e.g. [Point2D] inside a polygon list)
/// are fully converted to primitives before [fromJson] is called, matching the
/// real persistence path.
Map<String, dynamic> _fullRoundTrip(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

void main() {
  // ── Point2D ──────────────────────────────────────────────────────────────

  group('Point2D serialization', () {
    test('round-trip: fully populated', () {
      const original = Point2D(x: 1234.5, y: -678.9);
      final json = original.toJson();
      final restored = Point2D.fromJson(json);

      expect(restored, equals(original));
      expect(restored.x, 1234.5);
      expect(restored.y, -678.9);
    });

    test('round-trip: zero coordinates', () {
      const original = Point2D(x: 0, y: 0);
      final restored = Point2D.fromJson(original.toJson());
      expect(restored, equals(original));
      expect(restored.x, 0.0);
      expect(restored.y, 0.0);
    });
  });

  // ── Room ─────────────────────────────────────────────────────────────────

  group('Room serialization', () {
    test('round-trip: fully populated (all optionals set)', () {
      const original = Room(
        id: 'room-abc',
        floorId: 'floor-1',
        name: 'Living Room',
        targetTempC: 21.5,
        airChangeRate: 0.7,
        polygon: [
          Point2D(x: 0, y: 0),
          Point2D(x: 5000, y: 0),
          Point2D(x: 5000, y: 4000),
          Point2D(x: 0, y: 4000),
        ],
        floorConstructionId: 'constr-floor',
        ceilingConstructionId: 'constr-ceil',
        floorBoundary: BoundaryCondition.ground,
        ceilingBoundary: BoundaryCondition.exterior,
        floorAdjacentTempC: 10.0,
        ceilingAdjacentTempC: 15.0,
      );

      final restored = Room.fromJson(_fullRoundTrip(original.toJson()));

      expect(restored, equals(original));
      expect(restored.id, 'room-abc');
      expect(restored.targetTempC, 21.5);
      expect(restored.floorConstructionId, 'constr-floor');
      expect(restored.floorAdjacentTempC, 10.0);
    });

    test('round-trip: minimal (required fields only, optionals absent)', () {
      const original = Room(
        id: 'room-min',
        floorId: 'floor-1',
        name: 'Minimal Room',
      );

      final restored = Room.fromJson(_fullRoundTrip(original.toJson()));

      expect(restored, equals(original));
      expect(restored.floorConstructionId, isNull);
      expect(restored.ceilingConstructionId, isNull);
      expect(restored.floorAdjacentTempC, isNull);
      expect(restored.ceilingAdjacentTempC, isNull);
    });
  });

  // ── WallSegment ───────────────────────────────────────────────────────────

  group('WallSegment serialization', () {
    test('round-trip: fully populated (optionals set)', () {
      const original = WallSegment(
        id: 'wall-1',
        roomId: 'room-1',
        startPoint: Point2D(x: 0, y: 0),
        endPoint: Point2D(x: 5000, y: 0),
        wallType: WallType.interior,
        constructionId: 'constr-1',
        adjacentRoomId: 'room-2',
        orientation: CardinalDirection.south,
      );

      final restored = WallSegment.fromJson(_fullRoundTrip(original.toJson()));

      expect(restored, equals(original));
      expect(restored.wallType, WallType.interior);
      expect(restored.constructionId, 'constr-1');
      expect(restored.adjacentRoomId, 'room-2');
    });

    test('round-trip: minimal (no construction, no adjacent room)', () {
      const original = WallSegment(
        id: 'wall-min',
        roomId: 'room-1',
        startPoint: Point2D(x: 0, y: 0),
        endPoint: Point2D(x: 3000, y: 0),
      );

      final restored = WallSegment.fromJson(_fullRoundTrip(original.toJson()));

      expect(restored, equals(original));
      expect(restored.constructionId, isNull);
      expect(restored.adjacentRoomId, isNull);
    });
  });

  // ── WindowElement ─────────────────────────────────────────────────────────

  group('WindowElement serialization', () {
    test('round-trip: fully populated', () {
      const original = WindowElement(
        id: 'win-1',
        wallSegmentId: 'wall-1',
        positionOnWallMm: 1500.0,
        widthMm: 1800,
        heightMm: 1600,
        sillHeightMm: 800,
        uValue: 0.9,
      );

      final json = original.toJson();
      final restored = WindowElement.fromJson(json);

      expect(restored, equals(original));
      expect(restored.widthMm, 1800);
      expect(restored.uValue, 0.9);
    });

    test('round-trip: minimal (defaults only)', () {
      const original = WindowElement(
        id: 'win-min',
        wallSegmentId: 'wall-1',
        positionOnWallMm: 500.0,
      );

      final restored = WindowElement.fromJson(original.toJson());

      expect(restored, equals(original));
      expect(restored.widthMm, 1200);
      expect(restored.sillHeightMm, 900);
    });
  });

  // ── Door ─────────────────────────────────────────────────────────────────

  group('Door serialization', () {
    test('round-trip: fully populated', () {
      const original = Door(
        id: 'door-1',
        wallSegmentId: 'wall-1',
        positionOnWallMm: 200.0,
        widthMm: 1000,
        heightMm: 2200,
        sillHeightMm: 0,
        uValue: 1.6,
      );

      final json = original.toJson();
      final restored = Door.fromJson(json);

      expect(restored, equals(original));
      expect(restored.widthMm, 1000);
      expect(restored.uValue, 1.6);
    });

    test('round-trip: minimal (defaults only)', () {
      const original = Door(
        id: 'door-min',
        wallSegmentId: 'wall-1',
        positionOnWallMm: 100.0,
      );

      final restored = Door.fromJson(original.toJson());

      expect(restored, equals(original));
      expect(restored.widthMm, 900);
      expect(restored.heightMm, 2100);
    });
  });

  // ── WallConstruction ──────────────────────────────────────────────────────

  group('WallConstruction serialization', () {
    test('round-trip: fully populated (isPreset = true)', () {
      const original = WallConstruction(
        id: 'constr-1',
        name: 'Insulated Cavity Wall',
        rsi: 0.13,
        rse: 0.04,
        isPreset: true,
      );

      final json = original.toJson();
      final restored = WallConstruction.fromJson(json);

      expect(restored, equals(original));
      expect(restored.name, 'Insulated Cavity Wall');
      expect(restored.isPreset, isTrue);
    });

    test('round-trip: minimal (defaults: isPreset = false)', () {
      const original = WallConstruction(
        id: 'constr-min',
        name: 'Simple Wall',
      );

      final restored = WallConstruction.fromJson(original.toJson());

      expect(restored, equals(original));
      expect(restored.isPreset, isFalse);
      expect(restored.rsi, 0.13);
    });
  });

  // ── MaterialLayer ─────────────────────────────────────────────────────────

  group('MaterialLayer serialization', () {
    test('round-trip: fully populated', () {
      const original = MaterialLayer(
        id: 'layer-1',
        constructionId: 'constr-1',
        sortOrder: 2,
        materialId: 'mat-eps',
        thicknessMm: 100.0,
        thermalConductivity: 0.035,
        density: 20.0,
        specificHeat: 1450.0,
      );

      final json = original.toJson();
      final restored = MaterialLayer.fromJson(json);

      expect(restored, equals(original));
      expect(restored.thicknessMm, 100.0);
      expect(restored.thermalConductivity, 0.035);
    });

    test('round-trip: brick layer (sortOrder = 0)', () {
      const original = MaterialLayer(
        id: 'layer-brick',
        constructionId: 'constr-2',
        sortOrder: 0,
        materialId: 'mat-brick',
        thicknessMm: 200.0,
        thermalConductivity: 0.77,
        density: 1800.0,
        specificHeat: 840.0,
      );

      final restored = MaterialLayer.fromJson(original.toJson());

      expect(restored, equals(original));
      expect(restored.sortOrder, 0);
      expect(restored.density, 1800.0);
    });
  });

  // ── HeatingZone ───────────────────────────────────────────────────────────

  group('HeatingZone serialization', () {
    test('round-trip: fully populated (floor zone, all optionals set)', () {
      const original = HeatingZone(
        id: 'zone-1',
        roomId: 'room-1',
        zoneType: ZoneType.floorHeating,
        polygon: [
          Point2D(x: 0, y: 0),
          Point2D(x: 5000, y: 0),
          Point2D(x: 5000, y: 4000),
          Point2D(x: 0, y: 4000),
        ],
        tubeSpacingMm: 150,
        tubeTypeId: 'tube-1',
        flooringMaterialId: 'floor-mat-1',
        borderDistanceMm: 100,
        layoutPattern: LayoutPattern.spiral,
        circuitId: 'circuit-1',
        customFlooringResistance: 0.05,
      );

      final restored = HeatingZone.fromJson(_fullRoundTrip(original.toJson()));

      expect(restored, equals(original));
      expect(restored.layoutPattern, LayoutPattern.spiral);
      expect(restored.circuitId, 'circuit-1');
      expect(restored.customFlooringResistance, 0.05);
    });

    test('round-trip: wall zone (wallSegmentId, heightMm, positionOnWallMm, widthMm set)', () {
      const original = HeatingZone(
        id: 'zone-wall',
        roomId: 'room-1',
        zoneType: ZoneType.wallHeating,
        tubeTypeId: 'tube-1',
        flooringMaterialId: 'floor-mat-1',
        wallSegmentId: 'wall-1',
        heightMm: 2400,
        positionOnWallMm: 200.0,
        widthMm: 3000,
      );

      final restored = HeatingZone.fromJson(_fullRoundTrip(original.toJson()));

      expect(restored, equals(original));
      expect(restored.zoneType, ZoneType.wallHeating);
      expect(restored.wallSegmentId, 'wall-1');
      expect(restored.heightMm, 2400);
    });

    test('round-trip: minimal (required fields only)', () {
      const original = HeatingZone(
        id: 'zone-min',
        roomId: 'room-1',
        tubeTypeId: 'tube-1',
        flooringMaterialId: 'floor-mat-1',
      );

      final restored = HeatingZone.fromJson(_fullRoundTrip(original.toJson()));

      expect(restored, equals(original));
      expect(restored.circuitId, isNull);
      expect(restored.wallSegmentId, isNull);
    });
  });

  // ── Distributor ───────────────────────────────────────────────────────────

  group('Distributor serialization', () {
    test('round-trip: fully populated (pumpCapacityPa set)', () {
      const original = Distributor(
        id: 'dist-1',
        floorId: 'floor-1',
        position: Point2D(x: 500, y: 800),
        supplyTempC: 40.0,
        returnTempC: 30.0,
        pumpCapacityPa: 15000.0,
        widthMm: 600,
        rotationDeg: 90,
      );

      final restored = Distributor.fromJson(_fullRoundTrip(original.toJson()));

      expect(restored, equals(original));
      expect(restored.supplyTempC, 40.0);
      expect(restored.pumpCapacityPa, 15000.0);
    });

    test('round-trip: minimal (pumpCapacityPa absent)', () {
      const original = Distributor(
        id: 'dist-min',
        floorId: 'floor-1',
        position: Point2D(x: 0, y: 0),
      );

      final restored = Distributor.fromJson(_fullRoundTrip(original.toJson()));

      expect(restored, equals(original));
      expect(restored.pumpCapacityPa, isNull);
      expect(restored.rotationDeg, 0);
    });
  });

  // ── HeatingCircuit ────────────────────────────────────────────────────────

  group('HeatingCircuit serialization', () {
    test('round-trip: fully populated (routes + insulation type set)', () {
      const original = HeatingCircuit(
        id: 'circuit-1',
        distributorId: 'dist-1',
        heatingZoneId: 'zone-1',
        supplyRoutePath: [
          Point2D(x: 500, y: 800),
          Point2D(x: 1000, y: 800),
        ],
        returnRoutePath: [
          Point2D(x: 1000, y: 800),
          Point2D(x: 500, y: 800),
        ],
        tubeLengthM: 42.5,
        flowRateKgH: 18.3,
        pressureLossPa: 3200.0,
        valveSetting: 2.7,
        supplyPipeInsulationType: SupplyPipeInsulationType.corrugatedConduit,
      );

      final restored =
          HeatingCircuit.fromJson(_fullRoundTrip(original.toJson()));

      expect(restored, equals(original));
      expect(restored.tubeLengthM, 42.5);
      expect(restored.supplyPipeInsulationType,
          SupplyPipeInsulationType.corrugatedConduit);
    });

    test('round-trip: minimal (empty routes, insulation absent)', () {
      const original = HeatingCircuit(
        id: 'circuit-min',
        distributorId: 'dist-1',
        heatingZoneId: 'zone-1',
      );

      final restored = HeatingCircuit.fromJson(original.toJson());

      expect(restored, equals(original));
      expect(restored.supplyPipeInsulationType, isNull);
      expect(restored.supplyRoutePath, isEmpty);
    });
  });

  // ── ValidationResult ──────────────────────────────────────────────────────

  group('ValidationResult serialization', () {
    test('round-trip: fully populated (suggestedFix set)', () {
      const original = ValidationResult(
        severity: WarningSeverity.error,
        elementId: 'zone-1',
        elementType: 'zone',
        message: 'Tube length exceeds 100 m limit.',
        suggestedFix: 'Split the zone into two smaller circuits.',
      );

      final json = original.toJson();
      final restored = ValidationResult.fromJson(json);

      expect(restored, equals(original));
      expect(restored.severity, WarningSeverity.error);
      expect(restored.suggestedFix, 'Split the zone into two smaller circuits.');
    });

    test('round-trip: minimal (suggestedFix absent)', () {
      const original = ValidationResult(
        severity: WarningSeverity.warning,
        elementId: 'room-1',
        elementType: 'room',
        message: 'Target temperature is unusually high.',
      );

      final restored = ValidationResult.fromJson(original.toJson());

      expect(restored, equals(original));
      expect(restored.suggestedFix, isNull);
      expect(restored.elementType, 'room');
    });
  });
}
