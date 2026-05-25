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

  /// ADR-020 Rule 1: default material catalog ID for the single
  /// auto-default layer of every new exterior wall's construction.
  /// Initial value points at the `Vertical coring brick` entry.
  TextColumn get defaultExteriorMaterialId =>
      text().withDefault(const Constant('mat-016'))();

  /// ADR-020 Rule 1: default material catalog ID for new interior walls.
  TextColumn get defaultInteriorMaterialId =>
      text().withDefault(const Constant('mat-016'))();

  /// ADR-020 Rule 1: default material catalog ID for new partition walls.
  TextColumn get defaultPartitionMaterialId =>
      text().withDefault(const Constant('mat-016'))();

  /// Serialised JSON blob for the optional GeoLocation.
  TextColumn get locationJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
