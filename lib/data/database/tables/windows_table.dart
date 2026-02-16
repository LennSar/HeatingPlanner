import 'package:drift/drift.dart';

import 'wall_segments_table.dart';

/// Drift table definition for [WindowElement] entities.
class Windows extends Table {
  TextColumn get id => text()();
  TextColumn get wallSegmentId =>
      text().references(WallSegments, #id, onDelete: KeyAction.cascade)();
  RealColumn get positionOnWallMm => real()();
  IntColumn get widthMm => integer().withDefault(const Constant(1200))();
  IntColumn get heightMm => integer().withDefault(const Constant(1400))();
  IntColumn get sillHeightMm => integer().withDefault(const Constant(900))();
  RealColumn get uValue => real().withDefault(const Constant(1.3))();

  @override
  Set<Column> get primaryKey => {id};
}
