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

  /// [SupplyPipeInsulationType] name (ADR-008); null = not yet chosen.
  TextColumn get supplyPipeInsulationType => text().nullable()();
  /// JSON array of {x,y} for the route the connection pipes follow
  /// (ADR-040). Empty for circuits drawn as two separate pipes.
  TextColumn get centerlinePathJson =>
      text().withDefault(const Constant('[]'))();
  /// Distance between supply and return connection pipe (ADR-040).
  IntColumn get pipeSpacingMm =>
      integer().withDefault(const Constant(100))();
  /// Distance kept to the tubes of zones the pipes run through (ADR-040).
  IntColumn get zoneClearanceMm =>
      integer().withDefault(const Constant(100))();
  /// Distance kept to the face of walls the route runs along (ADR-040).
  IntColumn get wallClearanceMm =>
      integer().withDefault(const Constant(100))();

  /// Supply runs on the right of the route (ADR-041).
  BoolColumn get supplyOnRight =>
      boolean().withDefault(const Constant(false))();

  /// Distributor outlet stub the circuit is connected to (ADR-044).
  /// Null for circuits saved before v23 until the floor is next loaded.
  IntColumn get outletIndex => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
