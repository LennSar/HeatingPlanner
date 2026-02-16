import 'package:drift/drift.dart';

import 'wall_segments_table.dart';

/// Drift table definition for [Door] entities.
class Doors extends Table {
  TextColumn get id => text()();
  TextColumn get wallSegmentId =>
      text().references(WallSegments, #id, onDelete: KeyAction.cascade)();
  RealColumn get positionOnWallMm => real()();
  IntColumn get widthMm => integer().withDefault(const Constant(900))();
  IntColumn get heightMm => integer().withDefault(const Constant(2100))();
  IntColumn get sillHeightMm => integer().withDefault(const Constant(0))();
  RealColumn get uValue => real().withDefault(const Constant(2.0))();

  @override
  Set<Column> get primaryKey => {id};
}
