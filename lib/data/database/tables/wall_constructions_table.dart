import 'package:drift/drift.dart';

/// Drift table definition for [WallConstruction] entities.
class WallConstructions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get nameDe => text().nullable()();
  RealColumn get rsi => real().withDefault(const Constant(0.13))();
  RealColumn get rse => real().withDefault(const Constant(0.04))();

  /// 1 = preset, 0 = regular construction.
  IntColumn get isPreset =>
      integer().withDefault(const Constant(0))();

  /// ADR-020 Rule 2: 1 = auto-default (created by wall-creation paths,
  /// single project-default layer), 0 = explicitly edited. Mutually
  /// exclusive with [isPreset].
  IntColumn get isAutoDefault =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
