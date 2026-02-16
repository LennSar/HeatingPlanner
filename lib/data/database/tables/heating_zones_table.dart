import 'package:drift/drift.dart';

import 'flooring_materials_table.dart';
import 'rooms_table.dart';
import 'tube_types_table.dart';

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

  @override
  Set<Column> get primaryKey => {id};
}
