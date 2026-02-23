import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/id_generator.dart';
import '../../data/models/enums.dart';
import '../../data/models/point2d.dart';
import '../../data/models/room.dart';
import '../../data/models/wall_segment.dart';

/// In-memory state for the editor canvas.
@immutable
class EditorState {
  /// Creates an [EditorState].
  const EditorState({
    this.walls = const [],
    this.rooms = const [],
  });

  /// All wall segments on the current floor.
  final List<WallSegment> walls;

  /// All rooms on the current floor.
  final List<Room> rooms;

  /// Returns a copy with updated fields.
  EditorState copyWith({
    List<WallSegment>? walls,
    List<Room>? rooms,
  }) {
    return EditorState(
      walls: walls ?? this.walls,
      rooms: rooms ?? this.rooms,
    );
  }
}

/// Manages in-memory wall and room state.
class EditorStateNotifier extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  /// Add a wall segment.
  void addWall(WallSegment wall) {
    state = state.copyWith(
      walls: [...state.walls, wall],
    );
  }

  /// Replace a wall with the same ID.
  void updateWall(WallSegment wall) {
    state = state.copyWith(
      walls: state.walls
          .map((w) => w.id == wall.id ? wall : w)
          .toList(),
    );
  }

  /// Remove a wall by ID.
  void removeWall(String wallId) {
    state = state.copyWith(
      walls: state.walls
          .where((w) => w.id != wallId)
          .toList(),
    );
  }

  /// Clear roomId on all walls that reference [roomId].
  void clearRoomIdOnWalls(String roomId) {
    state = state.copyWith(
      walls: state.walls
          .map(
            (w) => w.roomId == roomId
                ? w.copyWith(roomId: '')
                : w,
          )
          .toList(),
    );
  }

  /// Assign a list of walls to a room.
  void assignWallsToRoom(
    List<String> wallIds,
    String roomId,
  ) {
    state = state.copyWith(
      walls: state.walls
          .map(
            (w) => wallIds.contains(w.id)
                ? w.copyWith(roomId: roomId)
                : w,
          )
          .toList(),
    );
  }

  /// Add a room.
  void addRoom(Room room) {
    state = state.copyWith(
      rooms: [...state.rooms, room],
    );
  }

  /// Update an existing room.
  void updateRoom(Room room) {
    state = state.copyWith(
      rooms: state.rooms
          .map((r) => r.id == room.id ? room : r)
          .toList(),
    );
  }

  /// Remove a room by ID.
  void removeRoom(String roomId) {
    state = state.copyWith(
      rooms: state.rooms
          .where((r) => r.id != roomId)
          .toList(),
    );
  }

  /// Create a room from auto-detection results, handling
  /// shared walls correctly.
  ///
  /// For each wall in [wallIds]:
  /// - If the wall is unassigned (roomId empty), it is
  ///   simply assigned to [room].
  /// - If the wall already belongs to another room it is a
  ///   *shared* wall.  A duplicate [WallSegment] is created
  ///   at the same position for [room], both copies are
  ///   marked [WallType.interior], and their [adjacentRoomId]
  ///   fields are cross-referenced so that
  ///   [ThermalEngine.interiorCorrectionFactor] can look up
  ///   the neighbouring room temperature.
  ///
  /// All mutations are committed in a single state update.
  void addRoomFromDetection({
    required Room room,
    required List<String> wallIds,
  }) {
    final updatedWalls = [...state.walls];

    for (int i = 0; i < wallIds.length; i++) {
      final wallId = wallIds[i];
      final idx = updatedWalls.indexWhere((w) => w.id == wallId);
      if (idx == -1) continue;

      final wall = updatedWalls[idx];

      if (wall.roomId.isEmpty) {
        // Unassigned wall — claim it for the new room.
        updatedWalls[idx] = wall.copyWith(roomId: room.id);
      } else {
        // Shared wall — belongs to a neighbour room.
        // Keep the original wall; mark it interior and
        // point it at the new room.
        final neighbourRoomId = wall.roomId;
        updatedWalls[idx] = wall.copyWith(
          wallType: WallType.interior,
          adjacentRoomId: room.id,
        );

        // Create a mirror segment for the new room.
        // Start/end are swapped so the wall faces inward
        // from the new room's perspective.
        final mirror = WallSegment(
          id: IdGenerator.newId(),
          roomId: room.id,
          startPoint: wall.endPoint,
          endPoint: wall.startPoint,
          wallType: WallType.interior,
          constructionId: wall.constructionId,
          adjacentRoomId: neighbourRoomId,
          orientation: wall.orientation,
        );
        updatedWalls.add(mirror);
      }
    }

    state = state.copyWith(
      walls: updatedWalls,
      rooms: [...state.rooms, room],
    );
  }

  /// Next suggested room number.
  int get nextRoomNumber => state.rooms.length + 1;
}

/// Provider for in-memory editor state.
final editorStateProvider =
    NotifierProvider<EditorStateNotifier, EditorState>(
  EditorStateNotifier.new,
);

/// Notifier for cursor position in world coordinates.
class CursorPositionNotifier extends Notifier<Point2D?> {
  @override
  Point2D? build() => null;

  /// Update the cursor position.
  void update(Point2D? position) {
    state = position;
  }
}

/// Current cursor position in world coordinates (mm).
final cursorPositionProvider =
    NotifierProvider<CursorPositionNotifier, Point2D?>(
  CursorPositionNotifier.new,
);
