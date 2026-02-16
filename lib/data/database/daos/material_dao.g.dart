// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'material_dao.dart';

// ignore_for_file: type=lint
mixin _$MaterialDaoMixin on DatabaseAccessor<AppDatabase> {
  $MaterialEntriesTable get materialEntries => attachedDatabase.materialEntries;
  MaterialDaoManager get managers => MaterialDaoManager(this);
}

class MaterialDaoManager {
  final _$MaterialDaoMixin _db;
  MaterialDaoManager(this._db);
  $$MaterialEntriesTableTableManager get materialEntries =>
      $$MaterialEntriesTableTableManager(
        _db.attachedDatabase,
        _db.materialEntries,
      );
}
