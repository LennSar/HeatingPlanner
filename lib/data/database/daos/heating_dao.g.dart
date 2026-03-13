// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'heating_dao.dart';

// ignore_for_file: type=lint
mixin _$HeatingDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTable get projects => attachedDatabase.projects;
  $FloorsTable get floors => attachedDatabase.floors;
  $RoomsTable get rooms => attachedDatabase.rooms;
  $TubeTypesTable get tubeTypes => attachedDatabase.tubeTypes;
  $FlooringMaterialsTable get flooringMaterials =>
      attachedDatabase.flooringMaterials;
  $WallConstructionsTable get wallConstructions =>
      attachedDatabase.wallConstructions;
  $WallSegmentsTable get wallSegments => attachedDatabase.wallSegments;
  $HeatingZonesTable get heatingZones => attachedDatabase.heatingZones;
  $DistributorsTable get distributors => attachedDatabase.distributors;
  $HeatingCircuitsTable get heatingCircuits => attachedDatabase.heatingCircuits;
  HeatingDaoManager get managers => HeatingDaoManager(this);
}

class HeatingDaoManager {
  final _$HeatingDaoMixin _db;
  HeatingDaoManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$FloorsTableTableManager get floors =>
      $$FloorsTableTableManager(_db.attachedDatabase, _db.floors);
  $$RoomsTableTableManager get rooms =>
      $$RoomsTableTableManager(_db.attachedDatabase, _db.rooms);
  $$TubeTypesTableTableManager get tubeTypes =>
      $$TubeTypesTableTableManager(_db.attachedDatabase, _db.tubeTypes);
  $$FlooringMaterialsTableTableManager get flooringMaterials =>
      $$FlooringMaterialsTableTableManager(
        _db.attachedDatabase,
        _db.flooringMaterials,
      );
  $$WallConstructionsTableTableManager get wallConstructions =>
      $$WallConstructionsTableTableManager(
        _db.attachedDatabase,
        _db.wallConstructions,
      );
  $$WallSegmentsTableTableManager get wallSegments =>
      $$WallSegmentsTableTableManager(_db.attachedDatabase, _db.wallSegments);
  $$HeatingZonesTableTableManager get heatingZones =>
      $$HeatingZonesTableTableManager(_db.attachedDatabase, _db.heatingZones);
  $$DistributorsTableTableManager get distributors =>
      $$DistributorsTableTableManager(_db.attachedDatabase, _db.distributors);
  $$HeatingCircuitsTableTableManager get heatingCircuits =>
      $$HeatingCircuitsTableTableManager(
        _db.attachedDatabase,
        _db.heatingCircuits,
      );
}
