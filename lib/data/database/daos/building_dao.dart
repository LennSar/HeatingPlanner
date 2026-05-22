import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/doors_table.dart';
import '../tables/floors_table.dart';
import '../tables/rooms_table.dart';
import '../tables/wall_segments_table.dart';
import '../tables/windows_table.dart';

part 'building_dao.g.dart';

/// DAO for floors, rooms, wall segments, windows, and doors.
@DriftAccessor(
  tables: [Floors, Rooms, WallSegments, Windows, Doors],
)
class BuildingDao extends DatabaseAccessor<AppDatabase>
    with _$BuildingDaoMixin {
  /// Creates a [BuildingDao] bound to [db].
  BuildingDao(super.db);

  // ── Floors ────────────────────────────────────────────────────────────────

  /// All floors for [projectId] ordered by [level] ascending.
  Stream<List<Floor>> watchFloors(String projectId) =>
      (select(floors)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.level)]))
          .watch();

  /// All floors for [projectId] ordered by [level] — one-shot fetch.
  Future<List<Floor>> getFloorsForProject(String projectId) =>
      (select(floors)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.level)]))
          .get();

  /// Inserts or replaces a floor row.
  Future<void> upsertFloor(FloorsCompanion companion) =>
      into(floors).insertOnConflictUpdate(companion);

  /// Deletes the floor with the given [id].
  Future<void> deleteFloor(String id) =>
      (delete(floors)..where((t) => t.id.equals(id))).go();

  // ── Rooms ─────────────────────────────────────────────────────────────────

  /// All rooms for [floorId].
  Stream<List<Room>> watchRooms(String floorId) =>
      (select(rooms)..where((t) => t.floorId.equals(floorId))).watch();

  /// Single room by [id].
  Stream<Room> watchRoom(String id) =>
      (select(rooms)..where((t) => t.id.equals(id))).watchSingle();

  /// Single room by [id], or null if not found.
  Stream<Room?> watchRoomNullable(String id) =>
      (select(rooms)..where((t) => t.id.equals(id)))
          .watch()
          .map((list) => list.isEmpty ? null : list.first);

  /// Single floor by [id], or null if not found.
  Stream<Floor?> watchFloorNullable(String id) =>
      (select(floors)..where((t) => t.id.equals(id)))
          .watch()
          .map((list) => list.isEmpty ? null : list.first);

  /// All rooms for [floorId] — one-shot fetch.
  Future<List<Room>> getRoomsForFloor(String floorId) =>
      (select(rooms)..where((t) => t.floorId.equals(floorId))).get();

  /// Inserts or replaces a room row.
  Future<void> upsertRoom(RoomsCompanion companion) =>
      into(rooms).insertOnConflictUpdate(companion);

  /// Deletes the room with the given [id].
  Future<void> deleteRoom(String id) =>
      (delete(rooms)..where((t) => t.id.equals(id))).go();

  // ── WallSegments ──────────────────────────────────────────────────────────

  /// All wall segments for [roomId].
  Stream<List<WallSegment>> watchWallSegments(String roomId) =>
      (select(wallSegments)..where((t) => t.roomId.equals(roomId))).watch();

  /// Single wall segment by [id]; emits `null` if the row does not exist.
  Stream<WallSegment?> watchWallById(String id) =>
      (select(wallSegments)..where((t) => t.id.equals(id)))
          .watch()
          .map((rows) => rows.isEmpty ? null : rows.first);

  /// All wall segments for any room on [floorId] — one-shot fetch.
  Future<List<WallSegment>> getWallSegmentsForFloor(String floorId) {
    final q = select(wallSegments).join(
      [innerJoin(rooms, rooms.id.equalsExp(wallSegments.roomId))],
    )..where(rooms.floorId.equals(floorId));
    return q.map((row) => row.readTable(wallSegments)).get();
  }

  /// Inserts or replaces a wall-segment row.
  Future<void> upsertWallSegment(WallSegmentsCompanion companion) =>
      into(wallSegments).insertOnConflictUpdate(companion);

  /// Deletes the wall segment with the given [id].
  Future<void> deleteWallSegment(String id) =>
      (delete(wallSegments)..where((t) => t.id.equals(id))).go();

  // ── Windows ───────────────────────────────────────────────────────────────

  /// All windows for [wallSegmentId].
  Stream<List<Window>> watchWindows(String wallSegmentId) =>
      (select(windows)
            ..where((t) => t.wallSegmentId.equals(wallSegmentId)))
          .watch();

  /// All windows on any wall segment on [floorId] — one-shot fetch.
  Future<List<Window>> getWindowsForFloor(String floorId) {
    final q = select(windows).join([
      innerJoin(wallSegments,
          wallSegments.id.equalsExp(windows.wallSegmentId)),
      innerJoin(rooms, rooms.id.equalsExp(wallSegments.roomId)),
    ])..where(rooms.floorId.equals(floorId));
    return q.map((row) => row.readTable(windows)).get();
  }

  /// Inserts or replaces a window row.
  Future<void> upsertWindow(WindowsCompanion companion) =>
      into(windows).insertOnConflictUpdate(companion);

  /// Deletes the window with the given [id].
  Future<void> deleteWindow(String id) =>
      (delete(windows)..where((t) => t.id.equals(id))).go();

  // ── Doors ─────────────────────────────────────────────────────────────────

  /// All doors for [wallSegmentId].
  Stream<List<Door>> watchDoors(String wallSegmentId) =>
      (select(doors)
            ..where((t) => t.wallSegmentId.equals(wallSegmentId)))
          .watch();

  /// All doors on any wall segment on [floorId] — one-shot fetch.
  Future<List<Door>> getDoorsForFloor(String floorId) {
    final q = select(doors).join([
      innerJoin(wallSegments,
          wallSegments.id.equalsExp(doors.wallSegmentId)),
      innerJoin(rooms, rooms.id.equalsExp(wallSegments.roomId)),
    ])..where(rooms.floorId.equals(floorId));
    return q.map((row) => row.readTable(doors)).get();
  }

  /// Inserts or replaces a door row.
  Future<void> upsertDoor(DoorsCompanion companion) =>
      into(doors).insertOnConflictUpdate(companion);

  /// Deletes the door with the given [id].
  Future<void> deleteDoor(String id) =>
      (delete(doors)..where((t) => t.id.equals(id))).go();
}
