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

  /// Stud width in mm. Non-null → inhomogeneous layer. Always set together
  /// with [studClearGapMm] and [studLambda].
  RealColumn get studWidthMm => real().nullable()();

  /// Clear gap between studs in mm (edge-to-edge, not centre-to-centre).
  RealColumn get studClearGapMm => real().nullable()();

  /// Thermal conductivity of the stud material in W/(m·K).
  RealColumn get studLambda => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
