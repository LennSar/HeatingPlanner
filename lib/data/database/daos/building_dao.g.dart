// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'building_dao.dart';

// ignore_for_file: type=lint
mixin _$BuildingDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTable get projects => attachedDatabase.projects;
  $FloorsTable get floors => attachedDatabase.floors;
  $RoomsTable get rooms => attachedDatabase.rooms;
  $WallConstructionsTable get wallConstructions =>
      attachedDatabase.wallConstructions;
  $WallSegmentsTable get wallSegments => attachedDatabase.wallSegments;
  $WindowsTable get windows => attachedDatabase.windows;
  $DoorsTable get doors => attachedDatabase.doors;
  BuildingDaoManager get managers => BuildingDaoManager(this);
}

class BuildingDaoManager {
  final _$BuildingDaoMixin _db;
  BuildingDaoManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$FloorsTableTableManager get floors =>
      $$FloorsTableTableManager(_db.attachedDatabase, _db.floors);
  $$RoomsTableTableManager get rooms =>
      $$RoomsTableTableManager(_db.attachedDatabase, _db.rooms);
  $$WallConstructionsTableTableManager get wallConstructions =>
      $$WallConstructionsTableTableManager(
        _db.attachedDatabase,
        _db.wallConstructions,
      );
  $$WallSegmentsTableTableManager get wallSegments =>
      $$WallSegmentsTableTableManager(_db.attachedDatabase, _db.wallSegments);
  $$WindowsTableTableManager get windows =>
      $$WindowsTableTableManager(_db.attachedDatabase, _db.windows);
  $$DoorsTableTableManager get doors =>
      $$DoorsTableTableManager(_db.attachedDatabase, _db.doors);
}
