import 'package:drift/drift.dart';

import 'floors_table.dart';

/// Drift table definition for [Distributor] entities.
class Distributors extends Table {
  TextColumn get id => text()();
  TextColumn get floorId =>
      text().references(Floors, #id, onDelete: KeyAction.cascade)();
  /// JSON {x,y} position on the floor plan in mm.
  TextColumn get positionJson => text()();
  RealColumn get supplyTempC =>
      real().withDefault(const Constant(35.0))();
  RealColumn get returnTempC =>
      real().withDefault(const Constant(28.0))();
  /// Optional rated pump capacity entered by the user (Pa).
  RealColumn get pumpCapacityPa => real().nullable()();
  IntColumn get widthMm => integer().withDefault(const Constant(500))();
  IntColumn get rotationDeg => integer().withDefault(const Constant(0))();
  /// Number of outlet stubs / circuits the distributor holds (ADR-044).
  IntColumn get outletCount => integer().withDefault(const Constant(4))();

  @override
  Set<Column> get primaryKey => {id};
}
