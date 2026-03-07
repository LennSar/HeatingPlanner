/// Test data factories.
///
/// Per agent-test.md Section 9. Each factory creates a minimal but
/// fully valid model instance. Parameters that matter for a specific
/// test should be overridden via named arguments; everything else
/// falls back to sensible defaults so call-sites stay concise.
library;

import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/material_layer.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_construction.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/data/models/window_element.dart';

// ── Geometry helpers ──────────────────────────────────────────────────────

/// A 5 m × 4 m rectangle (vertices in mm). Area = 20.0 m².
List<Point2D> rectanglePolygon5x4() => [
      const Point2D(x: 0, y: 0),
      const Point2D(x: 5000, y: 0),
      const Point2D(x: 5000, y: 4000),
      const Point2D(x: 0, y: 4000),
    ];

// ── Room ─────────────────────────────────────────────────────────────────

/// Creates a [Room] with a 5 m × 4 m polygon by default.
///
/// Override [polygon] to test rooms with different shapes or sizes.
Room createTestRoom({
  String id = 'room-1',
  String floorId = 'floor-1',
  String name = 'Test Room',
  double targetTempC = 20.0,
  double airChangeRate = 0.5,
  List<Point2D>? polygon,
}) {
  return Room(
    id: id,
    floorId: floorId,
    name: name,
    targetTempC: targetTempC,
    airChangeRate: airChangeRate,
    polygon: polygon ?? rectanglePolygon5x4(),
  );
}

// ── WallSegment ───────────────────────────────────────────────────────────

/// Creates an exterior [WallSegment] along the south face of the
/// default 5 m × 4 m room (y = 0, 5 000 mm long).
WallSegment createTestWall({
  String id = 'wall-1',
  String roomId = 'room-1',
  Point2D startPoint = const Point2D(x: 0, y: 0),
  Point2D endPoint = const Point2D(x: 5000, y: 0),
  WallType wallType = WallType.exterior,
  String? constructionId,
  String? adjacentRoomId,
  CardinalDirection orientation = CardinalDirection.south,
}) {
  return WallSegment(
    id: id,
    roomId: roomId,
    startPoint: startPoint,
    endPoint: endPoint,
    wallType: wallType,
    constructionId: constructionId,
    adjacentRoomId: adjacentRoomId,
    orientation: orientation,
  );
}

// ── WallConstruction ──────────────────────────────────────────────────────

/// Creates a [WallConstruction] with ISO 6946 default surface
/// resistances. Pass [name] to distinguish constructions in tests.
WallConstruction createTestConstruction({
  String id = 'constr-1',
  String name = 'Test Construction',
  double rsi = 0.13,
  double rse = 0.04,
}) {
  return WallConstruction(
    id: id,
    name: name,
    rsi: rsi,
    rse: rse,
  );
}

// ── MaterialLayer ─────────────────────────────────────────────────────────

/// Creates a single [MaterialLayer] representing 200 mm solid brick
/// (λ = 0.77 W/m·K, UV-1 reference material).
MaterialLayer createBrickLayer({
  String id = 'layer-1',
  String constructionId = 'constr-1',
  int sortOrder = 0,
  double thicknessMm = 200.0,
  double thermalConductivity = 0.77,
}) {
  return MaterialLayer(
    id: id,
    constructionId: constructionId,
    sortOrder: sortOrder,
    materialId: 'mat-brick',
    thicknessMm: thicknessMm,
    thermalConductivity: thermalConductivity,
    density: 1800.0,
    specificHeat: 840.0,
  );
}

/// Creates the four-layer insulated wall from UV-2:
/// 15mm render + 100mm EPS + 200mm hollow brick + 15mm plaster.
/// U ≈ 0.283 W/(m²K).
List<MaterialLayer> createInsulatedWallLayers({
  String constructionId = 'constr-1',
}) {
  return [
    MaterialLayer(
      id: 'layer-render',
      constructionId: constructionId,
      sortOrder: 0,
      materialId: 'mat-render',
      thicknessMm: 15.0,
      thermalConductivity: 1.00,
      density: 1800.0,
      specificHeat: 840.0,
    ),
    MaterialLayer(
      id: 'layer-eps',
      constructionId: constructionId,
      sortOrder: 1,
      materialId: 'mat-eps',
      thicknessMm: 100.0,
      thermalConductivity: 0.035,
      density: 20.0,
      specificHeat: 1450.0,
    ),
    MaterialLayer(
      id: 'layer-brick',
      constructionId: constructionId,
      sortOrder: 2,
      materialId: 'mat-hollow-brick',
      thicknessMm: 200.0,
      thermalConductivity: 0.44,
      density: 900.0,
      specificHeat: 840.0,
    ),
    MaterialLayer(
      id: 'layer-plaster',
      constructionId: constructionId,
      sortOrder: 3,
      materialId: 'mat-plaster',
      thicknessMm: 15.0,
      thermalConductivity: 0.40,
      density: 1100.0,
      specificHeat: 840.0,
    ),
  ];
}

// ── WindowElement ─────────────────────────────────────────────────────────

/// Creates a [WindowElement] matching the HD-1 reference window:
/// 1 500 mm × 1 400 mm, U = 1.3 W/(m²K).
WindowElement createTestWindow({
  String id = 'window-1',
  String wallSegmentId = 'wall-1',
  double positionOnWallMm = 1500.0,
  int widthMm = 1500,
  int heightMm = 1400,
  int sillHeightMm = 900,
  double uValue = 1.3,
}) {
  return WindowElement(
    id: id,
    wallSegmentId: wallSegmentId,
    positionOnWallMm: positionOnWallMm,
    widthMm: widthMm,
    heightMm: heightMm,
    sillHeightMm: sillHeightMm,
    uValue: uValue,
  );
}

// ── HeatingZone ───────────────────────────────────────────────────────────

/// Creates a floor-heating [HeatingZone] that covers the full 5 m × 4 m
/// room by default.
HeatingZone createTestZone({
  String id = 'zone-1',
  String roomId = 'room-1',
  ZoneType zoneType = ZoneType.floorHeating,
  List<Point2D>? polygon,
  int tubeSpacingMm = 150,
  String tubeTypeId = 'tube-type-1',
  String flooringMaterialId = 'flooring-1',
  int borderDistanceMm = 100,
  LayoutPattern layoutPattern = LayoutPattern.meander,
  String? circuitId,
}) {
  return HeatingZone(
    id: id,
    roomId: roomId,
    zoneType: zoneType,
    polygon: polygon ?? rectanglePolygon5x4(),
    tubeSpacingMm: tubeSpacingMm,
    tubeTypeId: tubeTypeId,
    flooringMaterialId: flooringMaterialId,
    borderDistanceMm: borderDistanceMm,
    layoutPattern: layoutPattern,
    circuitId: circuitId,
  );
}

// ── HeatingCircuit ────────────────────────────────────────────────────────

/// Creates a [HeatingCircuit] with zero calculated values.
/// Override [tubeLengthM], [flowRateKgH], [pressureLossPa] for
/// hydraulic tests.
HeatingCircuit createTestCircuit({
  String id = 'circuit-1',
  String distributorId = 'dist-1',
  String heatingZoneId = 'zone-1',
  List<Point2D>? supplyRoutePath,
  List<Point2D>? returnRoutePath,
  double tubeLengthM = 0.0,
  double flowRateKgH = 0.0,
  double pressureLossPa = 0.0,
  double valveSetting = 0.0,
}) {
  return HeatingCircuit(
    id: id,
    distributorId: distributorId,
    heatingZoneId: heatingZoneId,
    supplyRoutePath: supplyRoutePath ?? const [],
    returnRoutePath: returnRoutePath ?? const [],
    tubeLengthM: tubeLengthM,
    flowRateKgH: flowRateKgH,
    pressureLossPa: pressureLossPa,
    valveSetting: valveSetting,
  );
}
