import 'package:drift/drift.dart';

/// Drift table definition for [Project] entities.
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  RealColumn get designOutdoorTempC => real().withDefault(const Constant(-12.0))();
  RealColumn get defaultIndoorTempC => real().withDefault(const Constant(20.0))();
  /// Serialised JSON blob for the optional GeoLocation.
  TextColumn get locationJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
