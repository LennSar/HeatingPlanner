import 'package:drift/drift.dart';

import 'rooms_table.dart';
import 'wall_constructions_table.dart';

/// Drift table definition for [WallSegment] entities.
class WallSegments extends Table {
  TextColumn get id => text()();
  @ReferenceName('wallSegments')
  TextColumn get roomId =>
      text().references(Rooms, #id, onDelete: KeyAction.cascade)();
  /// JSON {x,y} for the start vertex.
  TextColumn get startPointJson => text()();
  /// JSON {x,y} for the end vertex.
  TextColumn get endPointJson => text()();
  TextColumn get wallType =>
      text().withDefault(const Constant('exterior'))();
  TextColumn get constructionId => text()
      .nullable()
      .references(WallConstructions, #id, onDelete: KeyAction.setNull)();
  @ReferenceName('adjacentWallSegments')
  TextColumn get adjacentRoomId =>
      text().nullable().references(Rooms, #id, onDelete: KeyAction.setNull)();
  TextColumn get orientation =>
      text().withDefault(const Constant('north'))();

  /// UUID of the mirror wall in an ADR-001 pair.
  ///
  /// Nullable self-referencing FK. Set to NULL via `ON DELETE SET NULL`
  /// when the partner wall is deleted (ADR-011 Rule 5).
  @ReferenceName('mirrorWallSegments')
  TextColumn get mirrorId => text()
      .nullable()
      .references(WallSegments, #id, onDelete: KeyAction.setNull)();

  @override
  Set<Column> get primaryKey => {id};
}
