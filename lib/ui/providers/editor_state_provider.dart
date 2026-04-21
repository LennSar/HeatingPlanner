import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../repositories/building_repository.dart';
import '../../repositories/construction_repository.dart';
import '../../repositories/heating_repository.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/save_state_notifier.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/distributor.dart';
import '../../data/models/door.dart';
import '../../data/models/enums.dart';
import '../../data/models/heating_circuit.dart';
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
    this.circuits = const [],
    this.distributor,
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

  /// All heating circuits on the current floor (in-memory state).
  ///
  /// Circuits are added by [RouteDrawTool] when the user completes
  /// a supply-and-return pipe loop.
  final List<HeatingCircuit> circuits;

  /// The distributor placed on this floor, or null if none yet.
  final Distributor? distributor;

  /// All wall constructions on the current floor.
  final List<WallConstruction> constructions;

  /// All material layers belonging to constructions.
  final List<MaterialLayer> materialLayers;

  /// Returns a copy with updated fields.
  ///
  /// Pass [clearDistributor] = true to set [distributor] to null
  /// (since null cannot be distinguished from "no change" with the
  /// standard nullable-override pattern).
  EditorState copyWith({
    List<WallSegment>? walls,
    List<Room>? rooms,
    List<WindowElement>? windows,
    List<Door>? doors,
    List<HeatingZone>? zones,
    List<HeatingCircuit>? circuits,
    Distributor? distributor,
    bool clearDistributor = false,
    List<WallConstruction>? constructions,
    List<MaterialLayer>? materialLayers,
  }) {
    return EditorState(
      walls: walls ?? this.walls,
      rooms: rooms ?? this.rooms,
      windows: windows ?? this.windows,
      doors: doors ?? this.doors,
      zones: zones ?? this.zones,
      circuits: circuits ?? this.circuits,
      distributor: clearDistributor
          ? null
          : (distributor ?? this.distributor),
      constructions: constructions ?? this.constructions,
      materialLayers: materialLayers ?? this.materialLayers,
    );
  }
}

/// Manages in-memory wall, room, opening, and construction
/// state for the editor canvas.
class EditorStateNotifier extends Notifier<EditorState>
    with SaveStateMixin {
  @override
  EditorState build() => const EditorState();

  // ---- Startup restore ----

  /// Loads all floor data from the database and replaces the editor state
  /// in one atomic [state] assignment.
  ///
  /// Called on startup (session restore) and whenever the user switches
  /// to a different floor.
  Future<void> initFromFloor(String floorId) async {
    final bRepo = ref.read(buildingRepositoryProvider);
    final hRepo = ref.read(heatingRepositoryProvider);
    final cRepo = ref.read(constructionRepositoryProvider);

    final rooms = await bRepo.getRoomsForFloor(floorId);
    final walls = await bRepo.getWallSegmentsForFloor(floorId);
    final windows = await bRepo.getWindowsForFloor(floorId);
    final doors = await bRepo.getDoorsForFloor(floorId);

    final distributor = await hRepo.getDistributorForFloor(floorId);
    final roomIds = rooms.map((r) => r.id).toList();
    final zones = await hRepo.getZonesForRooms(roomIds);
    final circuits = distributor == null
        ? <HeatingCircuit>[]
        : await hRepo.getCircuitsForDistributor(distributor.id);

    final constructions = await cRepo.getAllConstructions();
    final materialLayers = await cRepo.getAllLayers();

    state = EditorState(
      walls: walls,
      rooms: rooms,
      windows: windows,
      doors: doors,
      zones: zones,
      circuits: circuits,
      distributor: distributor,
      constructions: constructions,
      materialLayers: materialLayers,
    );
  }

  // ---- Walls ----

  /// Returns [wall] with [WallSegment.orientation] recomputed from geometry.
  WallSegment _withOrientation(WallSegment wall) => wall.copyWith(
        orientation: CardinalDirection.fromAngleDegrees(
          GeometryEngine.segmentAngleDegrees(
            wall.startPoint,
            wall.endPoint,
          ),
        ),
      );

  /// Add a wall segment.
  void addWall(WallSegment wall) {
    final w = _withOrientation(wall);
    state = state.copyWith(
      walls: [...state.walls, w],
    );
    if (w.roomId.isNotEmpty) {
      final dao = ref.read(buildingDaoProvider);
      unawaited(upsertWallSegment(dao, w));
      markProjectDirty();
    }
  }

  /// Replace a wall with the same ID.
  ///
  /// When [wall] has a non-null [WallSegment.mirrorId], the partner wall is
  /// located by ID and updated atomically in the same [state.copyWith] call,
  /// syncing [constructionId], [startPoint]/[endPoint] (reversed), and
  /// [wallType] (ADR-011 Rule 4). Both walls are persisted to the DAO.
  void updateWall(WallSegment wall) {
    final w = _withOrientation(wall);
    final partnerId = w.mirrorId;

    if (partnerId != null) {
      final partnerIdx =
          state.walls.indexWhere((s) => s.id == partnerId);
      if (partnerIdx != -1) {
        final partner = state.walls[partnerIdx];
        final updatedPartner = _withOrientation(
          partner.copyWith(
            constructionId: w.constructionId,
            startPoint: w.endPoint,
            endPoint: w.startPoint,
            wallType: w.wallType,
          ),
        );
        state = state.copyWith(
          walls: [
            for (final s in state.walls)
              if (s.id == w.id)
                w
              else if (s.id == partnerId)
                updatedPartner
              else
                s,
          ],
        );
        final dao = ref.read(buildingDaoProvider);
        unawaited(upsertWallSegment(dao, w));
        unawaited(upsertWallSegment(dao, updatedPartner));
        markProjectDirty();
        return;
      }
    }

    // No mirror or partner not found: update single wall.
    state = state.copyWith(
      walls: state.walls
          .map((s) => s.id == w.id ? w : s)
          .toList(),
    );
    if (w.roomId.isNotEmpty) {
      final dao = ref.read(buildingDaoProvider);
      unawaited(upsertWallSegment(dao, w));
      markProjectDirty();
    }
  }

  /// Remove a wall by ID.
  void removeWall(String wallId) {
    state = state.copyWith(
      walls: state.walls
          .where((w) => w.id != wallId)
          .toList(),
    );
    final dao = ref.read(buildingDaoProvider);
    unawaited(deleteWallSegment(dao, wallId));
    markProjectDirty();
  }

  /// Clear roomId on all walls that reference [roomId].
  void clearRoomIdOnWalls(String roomId) {
    // Delete persisted walls before clearing their roomId in memory.
    final toDelete =
        state.walls.where((w) => w.roomId == roomId).toList();
    state = state.copyWith(
      walls: state.walls
          .map(
            (w) => w.roomId == roomId
                ? w.copyWith(roomId: '')
                : w,
          )
          .toList(),
    );
    if (toDelete.isNotEmpty) {
      final dao = ref.read(buildingDaoProvider);
      for (final w in toDelete) {
        unawaited(deleteWallSegment(dao, w.id));
      }
      markProjectDirty();
    }
  }

  /// Assign a list of walls to a room.
  void assignWallsToRoom(
    List<String> wallIds,
    String roomId,
  ) {
    final updated = state.walls
        .map(
          (w) => wallIds.contains(w.id)
              ? w.copyWith(roomId: roomId)
              : w,
        )
        .toList();
    state = state.copyWith(walls: updated);
    final dao = ref.read(buildingDaoProvider);
    for (final w in updated.where((w) => wallIds.contains(w.id))) {
      unawaited(upsertWallSegment(dao, w));
    }
    markProjectDirty();
  }

  // ---- Rooms ----

  /// Add a room.
  void addRoom(Room room) {
    state = state.copyWith(
      rooms: [...state.rooms, room],
    );
    final dao = ref.read(buildingDaoProvider);
    unawaited(upsertRoom(dao, room));
    markProjectDirty();
  }

  /// Update an existing room.
  void updateRoom(Room room) {
    state = state.copyWith(
      rooms: state.rooms
          .map((r) => r.id == room.id ? room : r)
          .toList(),
    );
    final dao = ref.read(buildingDaoProvider);
    unawaited(upsertRoom(dao, room));
    markProjectDirty();
  }

  /// Remove a room by ID.
  void removeRoom(String roomId) {
    state = state.copyWith(
      rooms: state.rooms
          .where((r) => r.id != roomId)
          .toList(),
    );
    final dao = ref.read(buildingDaoProvider);
    unawaited(deleteRoom(dao, roomId));
    markProjectDirty();
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
    final dao = ref.read(buildingDaoProvider);
    unawaited(upsertWindow(dao, window));
    markProjectDirty();
  }

  /// Replace a window with the same ID.
  void updateWindow(WindowElement window) {
    state = state.copyWith(
      windows: state.windows
          .map((w) => w.id == window.id ? window : w)
          .toList(),
    );
    final dao = ref.read(buildingDaoProvider);
    unawaited(upsertWindow(dao, window));
    markProjectDirty();
  }

  /// Remove a window by ID.
  void removeWindow(String windowId) {
    state = state.copyWith(
      windows: state.windows
          .where((w) => w.id != windowId)
          .toList(),
    );
    final dao = ref.read(buildingDaoProvider);
    unawaited(deleteWindow(dao, windowId));
    markProjectDirty();
  }

  /// Remove all windows on a given wall segment.
  void removeWindowsOnWall(String wallId) {
    final toDelete = state.windows
        .where((w) => w.wallSegmentId == wallId)
        .toList();
    state = state.copyWith(
      windows: state.windows
          .where((w) => w.wallSegmentId != wallId)
          .toList(),
    );
    if (toDelete.isNotEmpty) {
      final dao = ref.read(buildingDaoProvider);
      for (final w in toDelete) {
        unawaited(deleteWindow(dao, w.id));
      }
      markProjectDirty();
    }
  }

  // ---- Doors ----

  /// Add a door element.
  void addDoor(Door door) {
    state = state.copyWith(
      doors: [...state.doors, door],
    );
    final dao = ref.read(buildingDaoProvider);
    unawaited(upsertDoor(dao, door));
    markProjectDirty();
  }

  /// Replace a door with the same ID.
  void updateDoor(Door door) {
    state = state.copyWith(
      doors: state.doors
          .map((d) => d.id == door.id ? door : d)
          .toList(),
    );
    final dao = ref.read(buildingDaoProvider);
    unawaited(upsertDoor(dao, door));
    markProjectDirty();
  }

  /// Remove a door by ID.
  void removeDoor(String doorId) {
    state = state.copyWith(
      doors: state.doors
          .where((d) => d.id != doorId)
          .toList(),
    );
    final dao = ref.read(buildingDaoProvider);
    unawaited(deleteDoor(dao, doorId));
    markProjectDirty();
  }

  /// Remove all doors on a given wall segment.
  void removeDoorsOnWall(String wallId) {
    final toDelete = state.doors
        .where((d) => d.wallSegmentId == wallId)
        .toList();
    state = state.copyWith(
      doors: state.doors
          .where((d) => d.wallSegmentId != wallId)
          .toList(),
    );
    if (toDelete.isNotEmpty) {
      final dao = ref.read(buildingDaoProvider);
      for (final d in toDelete) {
        unawaited(deleteDoor(dao, d.id));
      }
      markProjectDirty();
    }
  }

  // ---- Zones ----

  /// Add a heating zone.
  void addZone(HeatingZone zone) {
    state = state.copyWith(
      zones: [...state.zones, zone],
    );
    final dao = ref.read(heatingDaoProvider);
    unawaited(upsertHeatingZone(dao, zone));
    markProjectDirty();
  }

  /// Replace a heating zone with the same ID.
  void updateZone(HeatingZone zone) {
    state = state.copyWith(
      zones: state.zones
          .map((z) => z.id == zone.id ? zone : z)
          .toList(),
    );
    final dao = ref.read(heatingDaoProvider);
    unawaited(upsertHeatingZone(dao, zone));
    markProjectDirty();
  }

  /// Updates wall heating zones whose [HeatingZone.heightMm] equals
  /// [oldHeightMm] to [newHeightMm].
  ///
  /// Called when the project's default floor height changes so that
  /// zones that were not manually adjusted follow the new value.
  /// Zones with a different [heightMm] (manually adjusted) are left
  /// unchanged.
  void updateWallZoneHeightsForFloor(
    int oldHeightMm,
    int newHeightMm,
  ) {
    if (oldHeightMm == newHeightMm) return;
    final changed = <HeatingZone>[];
    final updatedZones = state.zones.map((z) {
      if (z.zoneType == ZoneType.wallHeating &&
          z.heightMm == oldHeightMm) {
        final updated = z.copyWith(heightMm: newHeightMm);
        changed.add(updated);
        return updated;
      }
      return z;
    }).toList();
    state = state.copyWith(zones: updatedZones);
    if (changed.isNotEmpty) {
      final dao = ref.read(heatingDaoProvider);
      for (final z in changed) {
        unawaited(upsertHeatingZone(dao, z));
      }
      markProjectDirty();
    }
  }

  /// Remove a heating zone by ID.
  void removeZone(String zoneId) {
    state = state.copyWith(
      zones: state.zones
          .where((z) => z.id != zoneId)
          .toList(),
    );
    final dao = ref.read(heatingDaoProvider);
    unawaited(deleteHeatingZone(dao, zoneId));
    markProjectDirty();
  }

  // ---- Circuits ----

  /// Add a heating circuit.
  void addCircuit(HeatingCircuit circuit) {
    state = state.copyWith(
      circuits: [...state.circuits, circuit],
    );
    final dao = ref.read(heatingDaoProvider);
    unawaited(upsertHeatingCircuit(dao, circuit));
    markProjectDirty();
  }

  /// Remove a heating circuit by ID.
  void removeCircuit(String circuitId) {
    state = state.copyWith(
      circuits: state.circuits
          .where((c) => c.id != circuitId)
          .toList(),
    );
    final dao = ref.read(heatingDaoProvider);
    unawaited(deleteHeatingCircuit(dao, circuitId));
    markProjectDirty();
  }

  /// Remove all heating circuits (e.g. when the distributor is moved).
  void clearAllCircuits() {
    final ids = state.circuits.map((c) => c.id).toList();
    state = state.copyWith(circuits: []);
    if (ids.isEmpty) return;
    final dao = ref.read(heatingDaoProvider);
    for (final id in ids) {
      unawaited(deleteHeatingCircuit(dao, id));
    }
    markProjectDirty();
  }

  /// Replace a heating circuit with the same ID.
  void updateCircuit(HeatingCircuit circuit) {
    state = state.copyWith(
      circuits: state.circuits
          .map((c) => c.id == circuit.id ? circuit : c)
          .toList(),
    );
    final dao = ref.read(heatingDaoProvider);
    unawaited(upsertHeatingCircuit(dao, circuit));
    markProjectDirty();
  }

  // ---- Distributor ----

  /// Set (or replace) the floor's distributor.
  void setDistributor(Distributor d) {
    state = state.copyWith(distributor: d);
    final dao = ref.read(heatingDaoProvider);
    unawaited(upsertDistributor(dao, d));
    markProjectDirty();
  }

  /// Replace the existing distributor with an updated copy.
  void updateDistributor(Distributor d) {
    state = state.copyWith(distributor: d);
    final dao = ref.read(heatingDaoProvider);
    unawaited(upsertDistributor(dao, d));
    markProjectDirty();
  }

  /// Remove the distributor.
  void clearDistributor() {
    final id = state.distributor?.id;
    state = state.copyWith(clearDistributor: true);
    if (id != null) {
      final dao = ref.read(heatingDaoProvider);
      unawaited(deleteDistributor(dao, id));
      markProjectDirty();
    }
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
    final dao = ref.read(constructionDaoProvider);
    unawaited(upsertConstruction(dao, construction));
    markProjectDirty();
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
    final dao = ref.read(constructionDaoProvider);
    unawaited(upsertConstruction(dao, construction));
    markProjectDirty();
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
    final dao = ref.read(constructionDaoProvider);
    unawaited(deleteConstruction(dao, constructionId));
    markProjectDirty();
  }

  // ---- Material layers ----

  /// Add a material layer.
  void addMaterialLayer(MaterialLayer layer) {
    state = state.copyWith(
      materialLayers: [...state.materialLayers, layer],
    );
    final dao = ref.read(constructionDaoProvider);
    unawaited(upsertLayer(dao, layer));
    markProjectDirty();
  }

  /// Replace a material layer with the same ID.
  void updateMaterialLayer(MaterialLayer layer) {
    state = state.copyWith(
      materialLayers: state.materialLayers
          .map((l) => l.id == layer.id ? layer : l)
          .toList(),
    );
    final dao = ref.read(constructionDaoProvider);
    unawaited(upsertLayer(dao, layer));
    markProjectDirty();
  }

  /// Remove a material layer by ID.
  void removeMaterialLayer(String layerId) {
    state = state.copyWith(
      materialLayers: state.materialLayers
          .where((l) => l.id != layerId)
          .toList(),
    );
    final dao = ref.read(constructionDaoProvider);
    unawaited(deleteLayer(dao, layerId));
    markProjectDirty();
  }

  /// Save a deep copy of [constructionId] as a named preset.
  ///
  /// Creates a new [WallConstruction] with a fresh UUID, [presetName]
  /// as its name, `isPreset = true`, and the same rsi/rse as the
  /// original. All layers are deep-copied with new UUIDs pointing at
  /// the new construction ID. The preset is persisted immediately;
  /// the original construction is not modified.
  void saveConstructionAsPreset(
    String constructionId,
    String presetName,
  ) {
    final original = state.constructions
        .where((c) => c.id == constructionId)
        .firstOrNull;
    if (original == null) return;

    final newId = IdGenerator.newId();
    final preset = original.copyWith(
      id: newId,
      name: presetName,
      isPreset: true,
    );

    final copiedLayers = state.materialLayers
        .where((l) => l.constructionId == constructionId)
        .map(
          (l) => l.copyWith(
            id: IdGenerator.newId(),
            constructionId: newId,
          ),
        )
        .toList();

    addConstruction(preset);
    replaceLayersForConstruction(newId, copiedLayers);
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
    final dao = ref.read(constructionDaoProvider);
    for (final l in newLayers) {
      unawaited(upsertLayer(dao, l));
    }
    markProjectDirty();
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
    final removed = <String>[];
    final addedPersisted = <WallSegment>[];

    for (final pt in [wall.startPoint, wall.endPoint]) {
      for (var i = 0; i < walls.length; i++) {
        final host = walls[i];
        if (host.roomId.isEmpty) continue;
        if (!_isStrictlyInterior(pt, host)) continue;

        final before = _withOrientation(WallSegment(
          id: IdGenerator.newId(),
          roomId: host.roomId,
          startPoint: host.startPoint,
          endPoint: pt,
          wallType: host.wallType,
          constructionId: host.constructionId,
          adjacentRoomId: host.adjacentRoomId,
        ));
        final after = _withOrientation(WallSegment(
          id: IdGenerator.newId(),
          roomId: host.roomId,
          startPoint: pt,
          endPoint: host.endPoint,
          wallType: host.wallType,
          constructionId: host.constructionId,
          adjacentRoomId: host.adjacentRoomId,
        ));

        removed.add(host.id);
        addedPersisted.addAll([before, after]);
        walls.removeAt(i);
        walls.insertAll(i, [before, after]);
        break;
      }
    }

    walls.add(_withOrientation(wall));
    state = state.copyWith(walls: walls);

    if (removed.isNotEmpty || addedPersisted.isNotEmpty) {
      final dao = ref.read(buildingDaoProvider);
      for (final id in removed) {
        unawaited(deleteWallSegment(dao, id));
      }
      for (final w in addedPersisted) {
        unawaited(upsertWallSegment(dao, w));
      }
      markProjectDirty();
    }
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
    final toPersist = <WallSegment>[];

    for (int i = 0; i < wallIds.length; i++) {
      final wallId = wallIds[i];
      final idx =
          updatedWalls.indexWhere((w) => w.id == wallId);
      if (idx == -1) continue;

      final wall = updatedWalls[idx];

      if (wall.roomId.isEmpty) {
        final assigned = wall.copyWith(roomId: room.id);
        updatedWalls[idx] = assigned;
        toPersist.add(assigned);
      } else {
        final neighbourRoomId = wall.roomId;
        // Generate the mirror's ID upfront so both walls can
        // cross-reference each other (ADR-011 Rule 3).
        final newMirrorId = IdGenerator.newId();
        final updated = wall.copyWith(
          wallType: WallType.interior,
          adjacentRoomId: room.id,
          mirrorId: newMirrorId,
        );
        updatedWalls[idx] = updated;
        toPersist.add(updated);

        final mirror = WallSegment(
          id: newMirrorId,
          roomId: room.id,
          startPoint: wall.endPoint,
          endPoint: wall.startPoint,
          wallType: WallType.interior,
          constructionId: wall.constructionId,
          adjacentRoomId: neighbourRoomId,
          orientation: wall.orientation,
          mirrorId: updated.id,
        );
        updatedWalls.add(mirror);
        toPersist.add(mirror);
      }
    }

    state = state.copyWith(
      walls: updatedWalls,
      rooms: [...state.rooms, room],
    );

    final dao = ref.read(buildingDaoProvider);
    unawaited(upsertRoom(dao, room));
    for (final w in toPersist) {
      unawaited(upsertWallSegment(dao, w));
    }
    markProjectDirty();
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

/// Notifier for a transient status-bar hint produced by the
/// active tool.
class ToolStatusHintNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Set (or clear) the hint message.
  void set(String? hint) => state = hint;
}

/// Transient status-bar hint produced by the active tool.
///
/// A non-null value is shown in the status bar as a contextual
/// hint (e.g. "Move cursor inside a room to place zone vertices").
/// Reset to null when the cursor leaves the canvas or the tool
/// changes.
final toolStatusHintProvider =
    NotifierProvider<ToolStatusHintNotifier, String?>(
  ToolStatusHintNotifier.new,
);

/// Manages the ID of the floor currently displayed in the editor.
class CurrentFloorIdNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Update the active floor ID.
  void set(String id) => state = id;
}

/// Provider for the active floor ID.
///
/// Set by [EditorScreen] once the floor is resolved on startup.
final currentFloorIdProvider =
    NotifierProvider<CurrentFloorIdNotifier, String>(
  CurrentFloorIdNotifier.new,
);

/// Display name of the currently open project.
///
/// Derived from [currentProjectIdProvider] → [projectProvider].
/// Returns `'HeatingPlanner'` while the project is loading or no
/// project is open, so callers always receive a valid non-empty string.
final currentProjectNameProvider = Provider<String>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId.isEmpty) return 'HeatingPlanner';
  return ref
      .watch(projectProvider(projectId))
      .whenOrNull(data: (p) => p?.name) ??
      'HeatingPlanner';
});
