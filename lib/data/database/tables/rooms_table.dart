import 'package:drift/drift.dart';

import 'floors_table.dart';

/// Drift table definition for [Room] entities.
///
/// The polygon is stored as a JSON text column (array of {x, y} objects).
class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get floorId =>
      text().references(Floors, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get targetTempC => real().withDefault(const Constant(20.0))();
  RealColumn get airChangeRate => real().withDefault(const Constant(0.5))();
  /// JSON array of {x, y} objects representing the room polygon in mm.
  TextColumn get polygonJson => text().withDefault(const Constant('[]'))();

  /// UUID of the floor construction; null = not assigned.
  TextColumn get floorConstructionId => text().nullable()();

  /// UUID of the ceiling construction; null = not assigned.
  TextColumn get ceilingConstructionId => text().nullable()();

  /// Boundary condition below the floor slab (stored as enum name).
  TextColumn get floorBoundary =>
      text().withDefault(const Constant('ground'))();

  /// Boundary condition above the ceiling slab (stored as enum name).
  TextColumn get ceilingBoundary =>
      text().withDefault(const Constant('exterior'))();

  /// User-supplied correction factor for unheated floor boundary
  /// (0.0–1.0).
  RealColumn get floorUnheatedCorrectionFactor => real().nullable()();

  /// User-supplied correction factor for unheated ceiling boundary
  /// (0.0–1.0).
  RealColumn get ceilingUnheatedCorrectionFactor => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
