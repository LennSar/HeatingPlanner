import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Remove a wall by ID.
  void removeWall(String wallId) {
    state = state.copyWith(
      walls: state.walls
          .where((w) => w.id != wallId)
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
