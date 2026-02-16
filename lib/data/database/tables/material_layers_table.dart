import 'package:drift/drift.dart';

import 'material_entries_table.dart';
import 'wall_constructions_table.dart';

/// Drift table definition for [MaterialLayer] entities.
class MaterialLayers extends Table {
  TextColumn get id => text()();
  TextColumn get constructionId =>
      text().references(WallConstructions, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer()();
  TextColumn get materialId =>
      text().references(MaterialEntries, #id, onDelete: KeyAction.restrict)();
  RealColumn get thicknessMm => real()();
  RealColumn get thermalConductivity => real()();
  RealColumn get density => real()();
  RealColumn get specificHeat => real()();

  @override
  Set<Column> get primaryKey => {id};
}
