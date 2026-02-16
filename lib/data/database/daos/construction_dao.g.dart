// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'construction_dao.dart';

// ignore_for_file: type=lint
mixin _$ConstructionDaoMixin on DatabaseAccessor<AppDatabase> {
  $WallConstructionsTable get wallConstructions =>
      attachedDatabase.wallConstructions;
  $MaterialEntriesTable get materialEntries => attachedDatabase.materialEntries;
  $MaterialLayersTable get materialLayers => attachedDatabase.materialLayers;
  ConstructionDaoManager get managers => ConstructionDaoManager(this);
}

class ConstructionDaoManager {
  final _$ConstructionDaoMixin _db;
  ConstructionDaoManager(this._db);
  $$WallConstructionsTableTableManager get wallConstructions =>
      $$WallConstructionsTableTableManager(
        _db.attachedDatabase,
        _db.wallConstructions,
      );
  $$MaterialEntriesTableTableManager get materialEntries =>
      $$MaterialEntriesTableTableManager(
        _db.attachedDatabase,
        _db.materialEntries,
      );
  $$MaterialLayersTableTableManager get materialLayers =>
      $$MaterialLayersTableTableManager(
        _db.attachedDatabase,
        _db.materialLayers,
      );
}
