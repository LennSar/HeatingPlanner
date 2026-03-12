import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/door.dart';
import '../../data/models/enums.dart';
import '../../data/models/heating_zone.dart';
import '../../data/models/material_layer.dart';
import '../../data/models/point2d.dart';
import '../../data/models/room.dart';
import '../../data/models/wall_construction.dart';
import '../../data/models/wall_segment.dart';
import '../../data/models/window_element.dart';

/// In-memory state for the editor canvas.
@immutable
class EditorState {
  /// Creates an [EditorState].
  const EditorState({
    this.walls = const [],
    this.rooms = const [],
    this.windows = const [],
    this.doors = const [],
    this.zones = const [],
    this.constructions = const [],
    this.materialLayers = const [],
  });

  /// All wall segments on the current floor.
  final List<WallSegment> walls;

  /// All rooms on the current floor.
  final List<Room> rooms;

  /// All window elements placed on wall segments.
  final List<WindowElement> windows;

  /// All door elements placed on wall segments.
  final List<Door> doors;

  /// All heating zones on the current floor (in-memory state).
  ///
  /// Zones are added here when drawn with [ZoneDrawTool] so that
  /// [HeatingZonePainter] can render them immediately. They are
  /// also persisted to the database via the heating repository.
  final List<HeatingZone> zones;

  /// All wall constructions on the current floor.
  final List<WallConstruction> constructions;

  /// All material layers belonging to constructions.
  final List<MaterialLayer> materialLayers;

  /// Returns a copy with updated fields.
  EditorState copyWith({
    List<WallSegment>? walls,
    List<Room>? rooms,
    List<WindowElement>? windows,
    List<Door>? doors,
    List<HeatingZone>? zones,
    List<WallConstruction>? constructions,
    List<MaterialLayer>? materialLayers,
  }) {
    return EditorState(
      walls: walls ?? this.walls,
      rooms: rooms ?? this.rooms,
      windows: windows ?? this.windows,
      doors: doors ?? this.doors,
      zones: zones ?? this.zones,
      constructions: constructions ?? this.constructions,
      materialLayers: materialLayers ?? this.materialLayers,
    );
  }
}

/// Manages in-memory wall, room, opening, and construction
/// state for the editor canvas.
class EditorStateNotifier extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  // ---- Walls ----

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

  // ---- Rooms ----

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

  // ---- Walls batch operations ----

  /// Replace the entire wall list in one state update.
  ///
  /// Used by undo/redo commands to restore a prior snapshot.
  void replaceAllWalls(List<WallSegment> walls) {
    state = state.copyWith(walls: walls);
  }

  /// Replace walls and rooms in one atomic state update.
  ///
  /// Used by undo/redo commands that affect both walls
  /// and room membership simultaneously.
  void replaceAllWallsAndRooms(
    List<WallSegment> walls,
    List<Room> rooms,
  ) {
    state = state.copyWith(walls: walls, rooms: rooms);
  }

  // ---- Windows ----

  /// Add a window element.
  void addWindow(WindowElement window) {
    state = state.copyWith(
      windows: [...state.windows, window],
    );
  }

  /// Replace a window with the same ID.
  void updateWindow(WindowElement window) {
    state = state.copyWith(
      windows: state.windows
          .map((w) => w.id == window.id ? window : w)
          .toList(),
    );
  }

  /// Remove a window by ID.
  void removeWindow(String windowId) {
    state = state.copyWith(
      windows: state.windows
          .where((w) => w.id != windowId)
          .toList(),
    );
  }

  /// Remove all windows on a given wall segment.
  void removeWindowsOnWall(String wallId) {
    state = state.copyWith(
      windows: state.windows
          .where((w) => w.wallSegmentId != wallId)
          .toList(),
    );
  }

  // ---- Doors ----

  /// Add a door element.
  void addDoor(Door door) {
    state = state.copyWith(
      doors: [...state.doors, door],
    );
  }

  /// Replace a door with the same ID.
  void updateDoor(Door door) {
    state = state.copyWith(
      doors: state.doors
          .map((d) => d.id == door.id ? door : d)
          .toList(),
    );
  }

  /// Remove a door by ID.
  void removeDoor(String doorId) {
    state = state.copyWith(
      doors: state.doors
          .where((d) => d.id != doorId)
          .toList(),
    );
  }

  /// Remove all doors on a given wall segment.
  void removeDoorsOnWall(String wallId) {
    state = state.copyWith(
      doors: state.doors
          .where((d) => d.wallSegmentId != wallId)
          .toList(),
    );
  }

  // ---- Zones ----

  /// Add a heating zone.
  void addZone(HeatingZone zone) {
    state = state.copyWith(
      zones: [...state.zones, zone],
    );
  }

  /// Remove a heating zone by ID.
  void removeZone(String zoneId) {
    state = state.copyWith(
      zones: state.zones
          .where((z) => z.id != zoneId)
          .toList(),
    );
  }

  // ---- Constructions ----

  /// Add a wall construction.
  void addConstruction(WallConstruction construction) {
    state = state.copyWith(
      constructions: [
        ...state.constructions,
        construction,
      ],
    );
  }

  /// Replace a construction with the same ID.
  void updateConstruction(WallConstruction construction) {
    state = state.copyWith(
      constructions: state.constructions
          .map(
            (c) => c.id == construction.id
                ? construction
                : c,
          )
          .toList(),
    );
  }

  /// Remove a construction by ID (and its layers).
  void removeConstruction(String constructionId) {
    state = state.copyWith(
      constructions: state.constructions
          .where((c) => c.id != constructionId)
          .toList(),
      materialLayers: state.materialLayers
          .where(
            (l) => l.constructionId != constructionId,
          )
          .toList(),
    );
  }

  // ---- Material layers ----

  /// Add a material layer.
  void addMaterialLayer(MaterialLayer layer) {
    state = state.copyWith(
      materialLayers: [...state.materialLayers, layer],
    );
  }

  /// Replace a material layer with the same ID.
  void updateMaterialLayer(MaterialLayer layer) {
    state = state.copyWith(
      materialLayers: state.materialLayers
          .map((l) => l.id == layer.id ? layer : l)
          .toList(),
    );
  }

  /// Remove a material layer by ID.
  void removeMaterialLayer(String layerId) {
    state = state.copyWith(
      materialLayers: state.materialLayers
          .where((l) => l.id != layerId)
          .toList(),
    );
  }

  /// Replace all layers for a construction atomically.
  ///
  /// Used when saving the wall construction editor so that
  /// the full before/after state can be snapshotted for undo.
  void replaceLayersForConstruction(
    String constructionId,
    List<MaterialLayer> newLayers,
  ) {
    final retained = state.materialLayers
        .where((l) => l.constructionId != constructionId)
        .toList();
    state = state.copyWith(
      materialLayers: [...retained, ...newLayers],
    );
  }

  // ---- Composite mutations ----

  /// Commit a new wall, splitting any existing room-assigned
  /// wall whose interior contains either of [wall]'s
  /// endpoints (ADR-003).
  ///
  /// Only walls with a non-empty [WallSegment.roomId] are
  /// split; unassigned walls are left intact.
  ///
  /// All mutations are committed in a single state update.
  void commitWallWithSplit(WallSegment wall) {
    var walls = List<WallSegment>.from(state.walls);

    for (final pt in [wall.startPoint, wall.endPoint]) {
      for (var i = 0; i < walls.length; i++) {
        final host = walls[i];
        if (host.roomId.isEmpty) continue;
        if (!_isStrictlyInterior(pt, host)) continue;

        final before = WallSegment(
          id: IdGenerator.newId(),
          roomId: host.roomId,
          startPoint: host.startPoint,
          endPoint: pt,
          wallType: host.wallType,
          constructionId: host.constructionId,
          adjacentRoomId: host.adjacentRoomId,
          orientation: host.orientation,
        );
        final after = WallSegment(
          id: IdGenerator.newId(),
          roomId: host.roomId,
          startPoint: pt,
          endPoint: host.endPoint,
          wallType: host.wallType,
          constructionId: host.constructionId,
          adjacentRoomId: host.adjacentRoomId,
          orientation: host.orientation,
        );

        walls.removeAt(i);
        walls.insertAll(i, [before, after]);
        break;
      }
    }

    walls.add(wall);
    state = state.copyWith(walls: walls);
  }

  /// Create a room from auto-detection results, handling
  /// shared walls correctly (ADR-001).
  ///
  /// All mutations are committed in a single state update.
  void addRoomFromDetection({
    required Room room,
    required List<String> wallIds,
  }) {
    final updatedWalls = [...state.walls];

    for (int i = 0; i < wallIds.length; i++) {
      final wallId = wallIds[i];
      final idx =
          updatedWalls.indexWhere((w) => w.id == wallId);
      if (idx == -1) continue;

      final wall = updatedWalls[idx];

      if (wall.roomId.isEmpty) {
        updatedWalls[idx] = wall.copyWith(roomId: room.id);
      } else {
        final neighbourRoomId = wall.roomId;
        updatedWalls[idx] = wall.copyWith(
          wallType: WallType.interior,
          adjacentRoomId: room.id,
        );

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

  /// Whether [pt] lies strictly on the interior of [wall]'s
  /// segment (not coinciding with either endpoint),
  /// within 1 mm tolerance.
  static bool _isStrictlyInterior(
    Point2D pt,
    WallSegment wall,
  ) {
    if (!GeometryEngine.isPointOnSegment(
        pt, wall.startPoint, wall.endPoint)) {
      return false;
    }
    final t = GeometryEngine.parameterAlongSegment(
        pt, wall.startPoint, wall.endPoint);
    const eps = 1e-4;
    return t > eps && t < 1.0 - eps;
  }
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

/// Stores the ID of the project currently open in the editor.
///
/// Set by [EditorScreen] on creation so that project-scoped
/// providers (e.g. [buildingHeatDemandProvider]) can be
/// parameterised without threading the ID through every widget.
/// Empty string when no project is open.
class CurrentProjectIdNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Update the active project ID.
  void set(String id) => state = id;
}

/// Provider for the active project ID.
final currentProjectIdProvider =
    NotifierProvider<CurrentProjectIdNotifier, String>(
  CurrentProjectIdNotifier.new,
);
