import 'package:drift/drift.dart';

import 'projects_table.dart';

/// Drift table definition for [Floor] entities.
class Floors extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get level => integer().withDefault(const Constant(0))();
  IntColumn get heightMm => integer().withDefault(const Constant(2600))();

  @override
  Set<Column> get primaryKey => {id};
}
