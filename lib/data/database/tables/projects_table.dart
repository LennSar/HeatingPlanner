import 'package:drift/drift.dart';

/// Drift table definition for [Project] entities.
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  RealColumn get designOutdoorTempC => real().withDefault(const Constant(-12.0))();
  RealColumn get defaultIndoorTempC => real().withDefault(const Constant(20.0))();
  IntColumn get floorHeightMm => integer().withDefault(const Constant(2600))();
  RealColumn get unheatedSpaceTempC => real().withDefault(const Constant(10.0))();

  /// Default total thickness in mm for exterior walls (ADR-017).
  IntColumn get defaultExteriorWallThicknessMm =>
      integer().withDefault(const Constant(240))();

  /// Default total thickness in mm for interior (shared) walls (ADR-017).
  IntColumn get defaultInteriorWallThicknessMm =>
      integer().withDefault(const Constant(120))();

  /// Default total thickness in mm for partition walls (ADR-017).
  IntColumn get defaultPartitionWallThicknessMm =>
      integer().withDefault(const Constant(100))();

  /// Serialised JSON blob for the optional GeoLocation.
  TextColumn get locationJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
