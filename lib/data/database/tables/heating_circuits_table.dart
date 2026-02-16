import 'package:drift/drift.dart';

import 'distributors_table.dart';
import 'heating_zones_table.dart';

/// Drift table definition for [HeatingCircuit] entities.
class HeatingCircuits extends Table {
  TextColumn get id => text()();
  TextColumn get distributorId =>
      text().references(Distributors, #id, onDelete: KeyAction.cascade)();
  TextColumn get heatingZoneId =>
      text().references(HeatingZones, #id, onDelete: KeyAction.cascade)();
  /// JSON array of {x,y} for the supply route polyline.
  TextColumn get supplyRoutePathJson =>
      text().withDefault(const Constant('[]'))();
  /// JSON array of {x,y} for the return route polyline.
  TextColumn get returnRoutePathJson =>
      text().withDefault(const Constant('[]'))();
  RealColumn get tubeLengthM =>
      real().withDefault(const Constant(0.0))();
  RealColumn get flowRateKgH =>
      real().withDefault(const Constant(0.0))();
  RealColumn get pressureLossPa =>
      real().withDefault(const Constant(0.0))();
  RealColumn get valveSetting =>
      real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}
