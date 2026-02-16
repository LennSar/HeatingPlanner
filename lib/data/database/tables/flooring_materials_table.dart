import 'package:drift/drift.dart';

/// Drift table definition for [FlooringMaterial] entities.
class FlooringMaterials extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  RealColumn get thermalResistance => real()();

  @override
  Set<Column> get primaryKey => {id};
}
