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
  RealColumn get pumpHeadPa =>
      real().withDefault(const Constant(25000.0))();

  @override
  Set<Column> get primaryKey => {id};
}
