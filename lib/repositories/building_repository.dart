// TODO(architect): implement BuildingRepository wrapping BuildingDao.
// Exposes floors, rooms, wall segments, windows, doors as Stream APIs.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/door.dart';
import '../data/models/floor.dart';
import '../data/models/room.dart';
import '../data/models/wall_segment.dart';
import '../data/models/window_element.dart';

/// Reactive stream of a single [Floor] by ID.
///
/// Returns `null` if the floor does not exist.
/// TODO(architect): replace stub with BuildingDao.watchFloorById(floorId).
final floorProvider =
    StreamProvider.family<Floor?, String>((ref, floorId) async* {
  yield null;
});

/// Reactive stream of all [Floor]s belonging to a project.
///
/// TODO(architect): replace stub with BuildingDao.watchFloorsByProject.
final floorsProvider =
    StreamProvider.family<List<Floor>, String>((ref, projectId) async* {
  yield const [];
});

/// Reactive stream of a single [Room] by ID.
///
/// Returns `null` if the room does not exist.
/// TODO(architect): replace stub with BuildingDao.watchRoomById(roomId).
final roomProvider =
    StreamProvider.family<Room?, String>((ref, roomId) async* {
  yield null;
});

/// Reactive stream of all [Room]s on a floor.
///
/// TODO(architect): replace stub with BuildingDao.watchRoomsByFloor(floorId).
final roomsProvider =
    StreamProvider.family<List<Room>, String>((ref, floorId) async* {
  yield const [];
});

/// Reactive stream of all [WallSegment]s belonging to [roomId].
///
/// Per ADR-001, every room owns its own copy of shared walls.
/// TODO(architect): replace stub with BuildingDao.watchWallsByRoom(roomId).
final wallSegmentsProvider =
    StreamProvider.family<List<WallSegment>, String>((ref, roomId) async* {
  yield const [];
});

/// Reactive stream of all [WindowElement]s on a wall segment.
///
/// TODO(architect): replace stub with BuildingDao.watchWindowsByWall.
final windowsProvider =
    StreamProvider.family<List<WindowElement>, String>(
  (ref, wallSegmentId) async* {
    yield const [];
  },
);

/// Reactive stream of all [Door]s on a wall segment.
///
/// TODO(architect): replace stub with BuildingDao.watchDoorsByWall.
final doorsProvider = StreamProvider.family<List<Door>, String>(
  (ref, wallSegmentId) async* {
    yield const [];
  },
);
