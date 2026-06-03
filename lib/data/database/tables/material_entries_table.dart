import 'package:drift/drift.dart';

/// Drift table definition for [MaterialEntry] entities.
class MaterialEntries extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get nameDe => text().nullable()();
  TextColumn get categoryPath => text()();
  RealColumn get lambdaDefault => real()();
  RealColumn get densityDefault => real()();
  RealColumn get specificHeatDefault => real()();
  BoolColumn get isBuiltIn =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
