import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart' as $db;
import '../data/database/daos/building_dao.dart';
import '../data/models/door.dart';
import '../data/models/enums.dart';
import '../data/models/floor.dart';
import '../data/models/point2d.dart';
import '../data/models/room.dart';
import '../data/models/wall_segment.dart';
import '../data/models/window_element.dart';

// ── DAO provider ──────────────────────────────────────────────────────────────

/// Provides the [BuildingDao] from the singleton [AppDatabase].
final buildingDaoProvider = Provider<BuildingDao>((ref) {
  return ref.watch($db.appDatabaseProvider).buildingDao;
});

// ── Stream providers ──────────────────────────────────────────────────────────

/// Reactive stream of a single [Floor] by ID.
///
/// Returns `null` if the floor does not exist.
final floorProvider =
    StreamProvider.family<Floor?, String>((ref, floorId) {
  return ref
      .watch(buildingDaoProvider)
      .watchFloorNullable(floorId)
      .map((row) => row == null ? null : _floorFromRow(row));
});

/// Reactive stream of all [Floor]s belonging to a project.
final floorsProvider =
    StreamProvider.family<List<Floor>, String>((ref, projectId) {
  return ref
      .watch(buildingDaoProvider)
      .watchFloors(projectId)
      .map((rows) => rows.map(_floorFromRow).toList());
});

/// Reactive stream of a single [Room] by ID.
///
/// Returns `null` if the room does not exist.
final roomProvider =
    StreamProvider.family<Room?, String>((ref, roomId) {
  return ref
      .watch(buildingDaoProvider)
      .watchRoomNullable(roomId)
      .map((row) => row == null ? null : _roomFromRow(row));
});

/// Reactive stream of all [Room]s on a floor.
final roomsProvider =
    StreamProvider.family<List<Room>, String>((ref, floorId) {
  return ref
      .watch(buildingDaoProvider)
      .watchRooms(floorId)
      .map((rows) => rows.map(_roomFromRow).toList());
});

/// Reactive stream of all [WallSegment]s belonging to [roomId].
///
/// Per ADR-001, every room owns its own copy of shared walls.
final wallSegmentsProvider =
    StreamProvider.family<List<WallSegment>, String>((ref, roomId) {
  return ref
      .watch(buildingDaoProvider)
      .watchWallSegments(roomId)
      .map((rows) => rows.map(_wallSegmentFromRow).toList());
});

/// Reactive stream of all [WindowElement]s on a wall segment.
final windowsProvider =
    StreamProvider.family<List<WindowElement>, String>(
  (ref, wallSegmentId) {
    return ref
        .watch(buildingDaoProvider)
        .watchWindows(wallSegmentId)
        .map((rows) => rows.map(_windowFromRow).toList());
  },
);

/// Reactive stream of all [Door]s on a wall segment.
final doorsProvider = StreamProvider.family<List<Door>, String>(
  (ref, wallSegmentId) {
    return ref
        .watch(buildingDaoProvider)
        .watchDoors(wallSegmentId)
        .map((rows) => rows.map(_doorFromRow).toList());
  },
);

// ── Floor CRUD ────────────────────────────────────────────────────────────────

/// Inserts or replaces [floor] in the database.
Future<void> upsertFloor(
  BuildingDao dao,
  Floor floor,
  String projectId,
) =>
    dao.upsertFloor(_floorToCompanion(floor, projectId));

/// Deletes the [Floor] with the given [id].
Future<void> deleteFloor(BuildingDao dao, String id) =>
    dao.deleteFloor(id);

// ── Room CRUD ─────────────────────────────────────────────────────────────────

/// Inserts or replaces [room] in the database.
Future<void> upsertRoom(BuildingDao dao, Room room) =>
    dao.upsertRoom(_roomToCompanion(room));

/// Deletes the [Room] with the given [id].
Future<void> deleteRoom(BuildingDao dao, String id) =>
    dao.deleteRoom(id);

// ── WallSegment CRUD ──────────────────────────────────────────────────────────

/// Inserts or replaces [wall] in the database.
Future<void> upsertWallSegment(
  BuildingDao dao,
  WallSegment wall,
) =>
    dao.upsertWallSegment(_wallSegmentToCompanion(wall));

/// Deletes the [WallSegment] with the given [id].
Future<void> deleteWallSegment(BuildingDao dao, String id) =>
    dao.deleteWallSegment(id);

// ── Window CRUD ───────────────────────────────────────────────────────────────

/// Inserts or replaces [window] in the database.
Future<void> upsertWindow(
  BuildingDao dao,
  WindowElement window,
) =>
    dao.upsertWindow(_windowToCompanion(window));

/// Deletes the [WindowElement] with the given [id].
Future<void> deleteWindow(BuildingDao dao, String id) =>
    dao.deleteWindow(id);

// ── Door CRUD ─────────────────────────────────────────────────────────────────

/// Inserts or replaces [door] in the database.
Future<void> upsertDoor(BuildingDao dao, Door door) =>
    dao.upsertDoor(_doorToCompanion(door));

/// Deletes the [Door] with the given [id].
Future<void> deleteDoor(BuildingDao dao, String id) =>
    dao.deleteDoor(id);

// ── Row → Model mapping ───────────────────────────────────────────────────────

Floor _floorFromRow($db.Floor row) {
  return Floor(
    id: row.id,
    name: row.name,
    level: row.level,
    heightMm: row.heightMm,
  );
}

Room _roomFromRow($db.Room row) {
  return Room(
    id: row.id,
    floorId: row.floorId,
    name: row.name,
    targetTempC: row.targetTempC,
    airChangeRate: row.airChangeRate,
    polygon: _decodePointList(row.polygonJson),
    floorConstructionId: row.floorConstructionId,
    ceilingConstructionId: row.ceilingConstructionId,
    floorBoundary:
        BoundaryCondition.values.byName(row.floorBoundary),
    ceilingBoundary:
        BoundaryCondition.values.byName(row.ceilingBoundary),
    floorAdjacentTempC: row.floorAdjacentTempC,
    ceilingAdjacentTempC: row.ceilingAdjacentTempC,
  );
}

WallSegment _wallSegmentFromRow($db.WallSegment row) {
  return WallSegment(
    id: row.id,
    roomId: row.roomId,
    startPoint: _decodePoint(row.startPointJson),
    endPoint: _decodePoint(row.endPointJson),
    wallType: WallType.values.byName(row.wallType),
    constructionId: row.constructionId,
    adjacentRoomId: row.adjacentRoomId,
    orientation: CardinalDirection.values.byName(row.orientation),
  );
}

WindowElement _windowFromRow($db.Window row) {
  return WindowElement(
    id: row.id,
    wallSegmentId: row.wallSegmentId,
    positionOnWallMm: row.positionOnWallMm,
    widthMm: row.widthMm,
    heightMm: row.heightMm,
    sillHeightMm: row.sillHeightMm,
    uValue: row.uValue,
  );
}

Door _doorFromRow($db.Door row) {
  return Door(
    id: row.id,
    wallSegmentId: row.wallSegmentId,
    positionOnWallMm: row.positionOnWallMm,
    widthMm: row.widthMm,
    heightMm: row.heightMm,
    sillHeightMm: row.sillHeightMm,
    uValue: row.uValue,
  );
}

// ── Model → Companion mapping ─────────────────────────────────────────────────

$db.FloorsCompanion _floorToCompanion(Floor floor, String projectId) {
  return $db.FloorsCompanion(
    id: Value(floor.id),
    projectId: Value(projectId),
    name: Value(floor.name),
    level: Value(floor.level),
    heightMm: Value(floor.heightMm),
  );
}

$db.RoomsCompanion _roomToCompanion(Room room) {
  return $db.RoomsCompanion(
    id: Value(room.id),
    floorId: Value(room.floorId),
    name: Value(room.name),
    targetTempC: Value(room.targetTempC),
    airChangeRate: Value(room.airChangeRate),
    polygonJson: Value(_encodePointList(room.polygon)),
    floorConstructionId: Value(room.floorConstructionId),
    ceilingConstructionId: Value(room.ceilingConstructionId),
    floorBoundary: Value(room.floorBoundary.name),
    ceilingBoundary: Value(room.ceilingBoundary.name),
    floorAdjacentTempC: Value(room.floorAdjacentTempC),
    ceilingAdjacentTempC: Value(room.ceilingAdjacentTempC),
  );
}

$db.WallSegmentsCompanion _wallSegmentToCompanion(WallSegment wall) {
  return $db.WallSegmentsCompanion(
    id: Value(wall.id),
    roomId: Value(wall.roomId),
    startPointJson: Value(_encodePoint(wall.startPoint)),
    endPointJson: Value(_encodePoint(wall.endPoint)),
    wallType: Value(wall.wallType.name),
    constructionId: Value(wall.constructionId),
    adjacentRoomId: Value(wall.adjacentRoomId),
    orientation: Value(wall.orientation.name),
  );
}

$db.WindowsCompanion _windowToCompanion(WindowElement window) {
  return $db.WindowsCompanion(
    id: Value(window.id),
    wallSegmentId: Value(window.wallSegmentId),
    positionOnWallMm: Value(window.positionOnWallMm),
    widthMm: Value(window.widthMm),
    heightMm: Value(window.heightMm),
    sillHeightMm: Value(window.sillHeightMm),
    uValue: Value(window.uValue),
  );
}

$db.DoorsCompanion _doorToCompanion(Door door) {
  return $db.DoorsCompanion(
    id: Value(door.id),
    wallSegmentId: Value(door.wallSegmentId),
    positionOnWallMm: Value(door.positionOnWallMm),
    widthMm: Value(door.widthMm),
    heightMm: Value(door.heightMm),
    sillHeightMm: Value(door.sillHeightMm),
    uValue: Value(door.uValue),
  );
}

// ── JSON helpers ──────────────────────────────────────────────────────────────

List<Point2D> _decodePointList(String json) {
  final list = jsonDecode(json) as List<dynamic>;
  return list
      .map((e) => Point2D.fromJson(e as Map<String, dynamic>))
      .toList();
}

Point2D _decodePoint(String json) {
  return Point2D.fromJson(
    jsonDecode(json) as Map<String, dynamic>,
  );
}

String _encodePointList(List<Point2D> points) {
  return jsonEncode(points.map((pt) => pt.toJson()).toList());
}

String _encodePoint(Point2D point) {
  return jsonEncode(point.toJson());
}
