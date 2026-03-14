import 'package:drift/drift.dart';

import 'flooring_materials_table.dart';
import 'rooms_table.dart';
import 'tube_types_table.dart';
import 'wall_segments_table.dart';

/// Drift table definition for [HeatingZone] entities.
class HeatingZones extends Table {
  TextColumn get id => text()();
  TextColumn get roomId =>
      text().references(Rooms, #id, onDelete: KeyAction.cascade)();
  TextColumn get zoneType =>
      text().withDefault(const Constant('floorHeating'))();
  /// JSON array of {x, y} objects for the zone polygon in mm.
  TextColumn get polygonJson => text().withDefault(const Constant('[]'))();
  IntColumn get tubeSpacingMm =>
      integer().withDefault(const Constant(150))();
  TextColumn get tubeTypeId =>
      text().references(TubeTypes, #id, onDelete: KeyAction.restrict)();
  TextColumn get flooringMaterialId =>
      text().references(FlooringMaterials, #id, onDelete: KeyAction.restrict)();
  IntColumn get borderDistanceMm =>
      integer().withDefault(const Constant(100))();
  TextColumn get layoutPattern =>
      text().withDefault(const Constant('meander'))();
  TextColumn get circuitId => text().nullable()();

  /// UUID of the host [WallSegment]; null for floor-heating zones.
  TextColumn get wallSegmentId => text()
      .nullable()
      .references(WallSegments, #id, onDelete: KeyAction.setNull)();

  /// Height of the wall heating zone in mm; null for floor-heating zones.
  IntColumn get heightMm => integer().nullable()();

  /// Offset from wall start to zone left edge in mm; null for floor zones.
  RealColumn get positionOnWallMm => real().nullable()();

  /// Length of the zone along the wall in mm; null means full wall length.
  IntColumn get widthMm => integer().nullable()();

  /// User-specified surface covering resistance in m²·K/W.
  ///
  /// Only used when [flooringMaterialId] is the custom sentinel.
  /// Null until set by the user.
  RealColumn get customFlooringResistance => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
