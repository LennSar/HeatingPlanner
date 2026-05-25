import 'dart:async' show unawaited;
import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/providers/project_settings_provider.dart';
import '../../data/database/app_database.dart' show appDatabaseProvider;
import '../../repositories/app_preferences.dart';
import '../../repositories/building_repository.dart';
import '../../repositories/construction_repository.dart';
import '../../repositories/heating_repository.dart';
import '../../repositories/material_repository.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/save_state_notifier.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/distributor.dart';
import '../../data/models/door.dart';
import '../../data/models/enums.dart';
import '../../data/models/heating_circuit.dart';
import '../../data/models/heating_zone.dart';
import '../../data/models/localized_catalog_row.dart';
import '../../data/models/material_entry.dart';
import '../../data/models/material_layer.dart';
import '../../data/models/point2d.dart';
import '../../data/models/room.dart';
import '../../data/models/validation_result.dart';
import '../../data/models/wall_construction.dart';
import '../../data/models/wall_segment.dart';
import '../../data/models/window_element.dart';
import 'transient_warnings_provider.dart';

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

  // ── ADR-017: wall-thickness source-of-truth + re-anchor cascade ──────────

  /// Authoritative thickness for [wall] per ADR-017:
  /// `sum(layers.thicknessMm)` when `constructionId != null` (the layers
  /// drive the value), otherwise the project default for [wall.wallType].
  ///
  /// Reads layers from [state.materialLayers] and defaults from
  /// [projectSettingsProvider]; falls back to the current
  /// [WallSegment.thicknessMm] if no construction layers exist yet
  /// (an in-progress construction edit) so the wall does not collapse
  /// to zero during the edit.
  double _thicknessSourceOfTruth(WallSegment wall) {
    if (wall.constructionId != null) {
      final layers = state.materialLayers
          .where((l) => l.constructionId == wall.constructionId)
          .toList();
      if (layers.isNotEmpty) {
        return layers.fold<double>(0.0, (s, l) => s + l.thicknessMm);
      }
      return wall.thicknessMm;
    }
    final settings = ref.read(projectSettingsProvider);
    return switch (wall.wallType) {
      WallType.exterior =>
        settings.defaultExteriorWallThicknessMm.toDouble(),
      WallType.interior =>
        settings.defaultInteriorWallThicknessMm.toDouble(),
      WallType.partition =>
        settings.defaultPartitionWallThicknessMm.toDouble(),
    };
  }

  /// Returns [wall] with its centerline shifted by `½Δt` along the
  /// room's outward normal per ADR-017 Rule 6.
  ///
  /// [WallAnchorMode.centerline] → no shift (the centerline is the
  /// anchor; both faces move outward by ½Δt each). [innerFace] shifts
  /// the centerline outward by ½Δt; [outerFace] shifts it inward by
  /// ½Δt. Outward direction is derived from the owning [Room]'s polygon
  /// winding (positive shoelace = math-CCW → right-hand normal is
  /// outward, see [GeometryEngine.offsetPolygonPerEdge]). When the
  /// room cannot be resolved or the segment is degenerate the centerline
  /// is left untouched — the thickness still updates.
  WallSegment _shiftedForThickness(WallSegment wall, double newThicknessMm) {
    final delta = newThicknessMm - wall.thicknessMm;
    if (delta.abs() < 1e-6 ||
        wall.anchorMode == WallAnchorMode.centerline) {
      return wall.copyWith(thicknessMm: newThicknessMm);
    }
    final room =
        state.rooms.where((r) => r.id == wall.roomId).firstOrNull;
    if (room == null || room.polygon.length < 3) {
      return wall.copyWith(thicknessMm: newThicknessMm);
    }
    var signedArea2 = 0.0;
    for (var i = 0; i < room.polygon.length; i++) {
      final a = room.polygon[i];
      final b = room.polygon[(i + 1) % room.polygon.length];
      signedArea2 += a.x * b.y - b.x * a.y;
    }
    final windingSign = signedArea2 > 0 ? 1.0 : -1.0;
    final dx = wall.endPoint.x - wall.startPoint.x;
    final dy = wall.endPoint.y - wall.startPoint.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1e-6) return wall.copyWith(thicknessMm: newThicknessMm);
    final nx = windingSign * dy / len;
    final ny = -windingSign * dx / len;
    // innerFace pins the inner face → centerline moves outward by ½Δt;
    // outerFace pins the outer face → centerline moves inward by −½Δt.
    final sign = wall.anchorMode == WallAnchorMode.innerFace ? 1.0 : -1.0;
    final shift = sign * delta / 2.0;
    return wall.copyWith(
      thicknessMm: newThicknessMm,
      startPoint: Point2D(
        x: wall.startPoint.x + nx * shift,
        y: wall.startPoint.y + ny * shift,
      ),
      endPoint: Point2D(
        x: wall.endPoint.x + nx * shift,
        y: wall.endPoint.y + ny * shift,
      ),
    );
  }

  /// Returns [wall] with `thicknessMm` recomputed from its
  /// source-of-truth and the centerline shifted per [anchorMode]
  /// (ADR-017 Rule 6). The **only** path that mutates
  /// `WallSegment.thicknessMm`; every other code path must call this
  /// before writing the wall back through [updateWall] so ADR-011
  /// mirror sync propagates the new thickness/anchorMode to the
  /// partner.
  ///
  /// Returns [wall] unchanged when the new thickness matches the
  /// current value (avoids spurious mirror updates).
  WallSegment _recomputeWallThickness(WallSegment wall) {
    final newThickness = _thicknessSourceOfTruth(wall);
    if ((newThickness - wall.thicknessMm).abs() < 1e-6) return wall;
    return _shiftedForThickness(wall, newThickness);
  }

  /// Applies ADR-017 Rule 2 creation-time anchor defaults to [wall]:
  /// exterior walls coming in with the freezed fallback
  /// `WallAnchorMode.centerline` are upgraded to `innerFace` so that
  /// changing the exterior project default later (Rule 9) preserves
  /// the room's inner clear dimension. Walls explicitly set to a
  /// non-centerline anchor mode upstream — and every interior /
  /// partition wall — are returned unchanged. Used only on creation
  /// paths ([addWall], [commitWallWithSplit]); [updateWall] honours
  /// the caller's chosen anchorMode verbatim.
  WallSegment _withRule2Defaults(WallSegment wall) {
    if (wall.wallType == WallType.exterior &&
        wall.anchorMode == WallAnchorMode.centerline &&
        wall.mirrorId == null) {
      return wall.copyWith(anchorMode: WallAnchorMode.innerFace);
    }
    return wall;
  }

  /// Applies ADR-017 Rule 1 creation-time thickness defaults to [wall]:
  /// a fresh wall coming in with the freezed fallback `thicknessMm = 0`
  /// is upgraded to its source-of-truth — `sum(layers.thicknessMm)` when
  /// `constructionId != null`, otherwise the matching project default
  /// for [wall.wallType]. Walls already carrying a positive thickness
  /// (a split fragment that inherited the host's thickness, an undo
  /// restore, or a caller that supplied an explicit value) are returned
  /// unchanged. Used only on creation paths ([addWall],
  /// [commitWallWithSplit]); [updateWall] honours the caller's chosen
  /// thickness verbatim.
  WallSegment _withThicknessDefaults(WallSegment wall) {
    if (wall.thicknessMm > 0) return wall;
    return wall.copyWith(thicknessMm: _thicknessSourceOfTruth(wall));
  }

  // ── ADR-020: auto-default constructions ───────────────────────────────────

  /// Project-default material catalog ID for [wallType] (ADR-020 Rule 1).
  String _projectDefaultMaterialIdFor(WallType wallType) {
    final s = ref.read(projectSettingsProvider);
    return switch (wallType) {
      WallType.exterior => s.defaultExteriorMaterialId,
      WallType.interior => s.defaultInteriorMaterialId,
      WallType.partition => s.defaultPartitionMaterialId,
    };
  }

  /// Project-default thickness in mm for [wallType] (ADR-017 Rule 1 case 2).
  double _projectDefaultThicknessFor(WallType wallType) {
    final s = ref.read(projectSettingsProvider);
    return _projectDefaultForType(s, wallType);
  }

  /// Looks up the [MaterialEntry] for [materialId] from
  /// [materialEntriesProvider]; returns a generic placeholder when the
  /// catalog has not finished loading or the ID is missing so the
  /// auto-default construction is always seedable.
  MaterialEntry _resolveMaterial(String materialId) {
    // Synchronous lookup: read the *cached* state of the materials
    // provider only when it has already been mounted. We never trigger
    // a fresh stream subscription here because the underlying Drift
    // database is opened lazily and pulls in `path_provider`, which
    // crashes on a vanilla `ProviderContainer()` without
    // `TestWidgetsFlutterBinding.ensureInitialized()`. The Project
    // Settings dialog and the construction editor open the catalog
    // separately when they need it for display; for the initial
    // auto-default construction it is enough to ship known good
    // defaults for `mat-016` (Vertical coring brick).
    final cached = ref.exists(materialEntriesProvider)
        ? ref.read(materialEntriesProvider).asData?.value
        : null;
    final hit = cached?.where((m) => m.id == materialId).firstOrNull;
    if (hit != null) return hit;
    return MaterialEntry(
      id: materialId,
      name: materialId,
      category: 'Masonry',
      subcategory: 'Historic brick',
      lambdaDefault: 0.50,
      densityDefault: 1200,
      specificHeatDefault: 900,
    );
  }

  /// ADR-020 Rule 3 — creates a fresh auto-default [WallConstruction] for
  /// [wallType] plus its single project-default [MaterialLayer], commits
  /// both to in-memory state, persists them when a Drift DAO is
  /// available, and returns the new construction id. Caller is expected
  /// to use the returned id as the wall's `constructionId`.
  String _spawnAutoDefaultConstruction(WallType wallType) {
    final mat = _resolveMaterial(_projectDefaultMaterialIdFor(wallType));
    final thickness = _projectDefaultThicknessFor(wallType);
    final cid = IdGenerator.newId();
    final construction = WallConstruction(
      id: cid,
      name: 'Auto-default ${wallType.name}',
      isAutoDefault: true,
    );
    final layer = MaterialLayer(
      id: IdGenerator.newId(),
      constructionId: cid,
      sortOrder: 0,
      materialId: mat.id,
      thicknessMm: thickness,
      thermalConductivity: mat.lambdaDefault,
      density: mat.densityDefault,
      specificHeat: mat.specificHeatDefault,
    );
    state = state.copyWith(
      constructions: [...state.constructions, construction],
      materialLayers: [...state.materialLayers, layer],
    );
    // DAO writes are best-effort: bare-bones unit tests run without an
    // `appDatabaseProvider` override, in which case opening the real
    // Drift database needs `path_provider` and crashes the binding on
    // the very first query. Persist only when the DB provider already
    // has a mounted, error-free element in this container.
    if (_isDatabaseAvailable()) {
      final cDao = ref.read(constructionDaoProvider);
      unawaited(upsertConstruction(cDao, construction));
      unawaited(upsertLayer(cDao, layer));
    }
    return cid;
  }

  /// True when [appDatabaseProvider] has been overridden / mounted in
  /// the current [ProviderContainer]. Used by the ADR-020 spawn /
  /// cascade helpers to skip DAO writes in lightweight unit tests
  /// that intentionally construct a bare `ProviderContainer()` and
  /// never override [appDatabaseProvider].
  bool _isDatabaseAvailable() => ref.exists(appDatabaseProvider);

  /// ADR-020 Rule 6 cascade — push the new project-default material into
  /// the single layer of every auto-default construction whose owning
  /// walls have [wallType]. Walls whose construction has
  /// `isAutoDefault == false` are untouched.
  void recomputeAutoDefaultMaterialsForWallType(WallType wallType) {
    final mat = _resolveMaterial(_projectDefaultMaterialIdFor(wallType));
    final wallsOfType = state.walls.where((w) => w.wallType == wallType);
    final targetConstructionIds = <String>{
      for (final w in wallsOfType)
        if (w.constructionId != null) w.constructionId!,
    };
    final affected = state.constructions
        .where(
          (c) => c.isAutoDefault && targetConstructionIds.contains(c.id),
        )
        .map((c) => c.id)
        .toSet();
    if (affected.isEmpty) return;
    final updatedLayers = state.materialLayers.map((l) {
      if (!affected.contains(l.constructionId)) return l;
      return l.copyWith(
        materialId: mat.id,
        thermalConductivity: mat.lambdaDefault,
        density: mat.densityDefault,
        specificHeat: mat.specificHeatDefault,
      );
    }).toList();
    state = state.copyWith(materialLayers: updatedLayers);
    if (_isDatabaseAvailable()) {
      final cDao = ref.read(constructionDaoProvider);
      for (final l in updatedLayers) {
        if (!affected.contains(l.constructionId)) continue;
        unawaited(upsertLayer(cDao, l));
      }
    }
    markProjectDirty();
  }

  /// ADR-020 Rule 7 cascade — set the single layer's `thicknessMm` to the
  /// new project default for [wallType] on every auto-default
  /// construction, then re-anchor each owning wall per ADR-017 Rule 6.
  void recomputeAutoDefaultThicknessForWallType(WallType wallType) {
    final newThickness = _projectDefaultThicknessFor(wallType);
    final wallsOfType =
        state.walls.where((w) => w.wallType == wallType).toList();
    final targetConstructionIds = <String>{
      for (final w in wallsOfType)
        if (w.constructionId != null) w.constructionId!,
    };
    final affected = state.constructions
        .where(
          (c) => c.isAutoDefault && targetConstructionIds.contains(c.id),
        )
        .map((c) => c.id)
        .toSet();
    if (affected.isEmpty) return;
    final updatedLayers = state.materialLayers.map((l) {
      if (!affected.contains(l.constructionId)) return l;
      return l.copyWith(thicknessMm: newThickness);
    }).toList();
    state = state.copyWith(materialLayers: updatedLayers);
    if (_isDatabaseAvailable()) {
      final cDao = ref.read(constructionDaoProvider);
      for (final l in updatedLayers) {
        if (!affected.contains(l.constructionId)) continue;
        unawaited(upsertLayer(cDao, l));
      }
    }
    // ADR-017 Rule 6 re-anchor for every wall whose construction is in
    // [affected]. recomputeWallsForConstruction handles mirror sync.
    for (final cid in affected) {
      recomputeWallsForConstruction(cid);
    }
  }

  /// Returns the project-default thickness in mm for [wallType] from
  /// [settings]. Used by the ADR-017 Rule 8 promotion logic to classify
  /// a wall as "default" (constructionId null AND thicknessMm matches).
  static double _projectDefaultForType(
    ProjectSettings settings,
    WallType wallType,
  ) =>
      switch (wallType) {
        WallType.exterior =>
          settings.defaultExteriorWallThicknessMm.toDouble(),
        WallType.interior =>
          settings.defaultInteriorWallThicknessMm.toDouble(),
        WallType.partition =>
          settings.defaultPartitionWallThicknessMm.toDouble(),
      };

  /// Add a wall segment.
  ///
  /// ADR-020 Rule 3: when [wall] arrives with a null `constructionId`, a
  /// fresh auto-default [WallConstruction] is spawned (project default
  /// material + thickness for the wall's [WallType]) and the wall is
  /// linked to it. Walls supplied with an explicit `constructionId`
  /// (split fragments, undo restores, shared-wall mirrors) are left
  /// alone so their existing construction stays intact.
  void addWall(WallSegment wall) {
    var prepared = _withThicknessDefaults(_withRule2Defaults(wall));
    if (prepared.constructionId == null) {
      final cid = _spawnAutoDefaultConstruction(prepared.wallType);
      prepared = prepared.copyWith(
        constructionId: cid,
        thicknessMm: _projectDefaultThicknessFor(prepared.wallType),
      );
    }
    final w = _withOrientation(prepared);
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
  /// syncing [constructionId], [startPoint]/[endPoint] (reversed),
  /// [wallType], and per ADR-017 Rule 7 also [thicknessMm] and
  /// [anchorMode] (ADR-011 Rule 4 extended). Both walls are persisted to
  /// the DAO.
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
            thicknessMm: w.thicknessMm,
            anchorMode: w.anchorMode,
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

  /// Assign [constructionId] to wall [wallId] and re-anchor its
  /// centerline per ADR-017 Rule 6.
  ///
  /// Routes through [_recomputeWallThickness] so the wall's new
  /// `thicknessMm` becomes the layer-sum of the assigned construction
  /// and [updateWall] propagates the change to a mirror partner.
  /// No-op if the wall is unknown.
  void assignConstruction(String wallId, String constructionId) {
    final wall = state.walls.where((w) => w.id == wallId).firstOrNull;
    if (wall == null) return;
    final withConstruction =
        wall.copyWith(constructionId: constructionId);
    updateWall(_recomputeWallThickness(withConstruction));
  }

  /// Detach the construction from wall [wallId] and re-anchor the
  /// centerline so its thickness reverts to the project default for the
  /// wall's [WallType] (ADR-017 Rule 9). Routes through [updateWall]
  /// for mirror sync.
  void clearConstruction(String wallId) {
    final wall = state.walls.where((w) => w.id == wallId).firstOrNull;
    if (wall == null) return;
    final withoutConstruction = wall.copyWith(constructionId: null);
    updateWall(_recomputeWallThickness(withoutConstruction));
  }

  /// Re-anchor every wall whose `constructionId` equals [constructionId]
  /// after that construction's layers change (ADR-017 Rule 6, invoked
  /// from the wall-construction-editor Save handler).
  ///
  /// Mirror partners are picked up by [updateWall]; the caller is
  /// responsible for wrapping the whole edit in a single
  /// `UndoRedoService` command so one Ctrl+Z reverts the source-of-truth
  /// change and every re-anchor it cascaded.
  void recomputeWallsForConstruction(String constructionId) {
    final affected = state.walls
        .where((w) => w.constructionId == constructionId)
        .toList();
    final visited = <String>{};
    for (final w in affected) {
      if (!visited.add(w.id)) continue;
      final recomputed = _recomputeWallThickness(w);
      if (identical(recomputed, w)) continue;
      // Skip the partner if updateWall will sync it via ADR-011.
      if (recomputed.mirrorId != null) visited.add(recomputed.mirrorId!);
      updateWall(recomputed);
    }
  }

  /// Re-anchor every unassigned wall (no `constructionId`) of
  /// [wallType] when its project-default thickness changes (ADR-017
  /// Rule 9). Caller wraps the cascade in a single `UndoRedoService`
  /// command.
  void recomputeWallsForProjectDefault(WallType wallType) {
    final affected = state.walls
        .where(
          (w) => w.constructionId == null && w.wallType == wallType,
        )
        .toList();
    final visited = <String>{};
    for (final w in affected) {
      if (!visited.add(w.id)) continue;
      final recomputed = _recomputeWallThickness(w);
      if (identical(recomputed, w)) continue;
      if (recomputed.mirrorId != null) visited.add(recomputed.mirrorId!);
      updateWall(recomputed);
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

  /// Delete [roomId] and every child element keyed by it, per ADR-019.
  ///
  /// Cascade scope (Rule 1):
  ///   - every wall with `roomId == roomId`,
  ///   - every zone with `roomId == roomId`,
  ///   - every window / door whose `wallSegmentId` references a
  ///     removed wall,
  ///   - the room entity itself.
  ///
  /// For each removed wall with `mirrorId != null` the surviving
  /// partner is reverted to `exterior` with `mirrorId` and
  /// `adjacentRoomId` cleared and `anchorMode = innerFace`
  /// (ADR-017 Rule 2); `thicknessMm` and `constructionId` are
  /// preserved (Rule 2).
  ///
  /// All of the above happens in a single `state.copyWith` (Rule 3).
  /// DAO writes follow; the snapshot-based "Delete room" command
  /// captures pre- and post-state for one-Ctrl+Z undo (Rule 4).
  void destroyRoomCascade(String roomId) {
    final wallsToRemove =
        state.walls.where((w) => w.roomId == roomId).toList();
    if (wallsToRemove.isEmpty &&
        state.rooms.where((r) => r.id == roomId).isEmpty) {
      // Nothing to do — neither room nor any walls reference it.
      return;
    }
    final wallIdsToRemove = wallsToRemove.map((w) => w.id).toSet();
    final partnerIds = <String>{
      for (final w in wallsToRemove)
        if (w.mirrorId != null) w.mirrorId!,
    };
    final zonesToRemove =
        state.zones.where((z) => z.roomId == roomId).toList();
    final windowsToRemove = state.windows
        .where((w) => wallIdsToRemove.contains(w.wallSegmentId))
        .toList();
    final doorsToRemove = state.doors
        .where((d) => wallIdsToRemove.contains(d.wallSegmentId))
        .toList();

    final partnersUpdated = <WallSegment>[];
    final newWalls = <WallSegment>[];
    for (final w in state.walls) {
      if (wallIdsToRemove.contains(w.id)) continue;
      if (partnerIds.contains(w.id)) {
        final reverted = w.copyWith(
          wallType: WallType.exterior,
          mirrorId: null,
          adjacentRoomId: null,
          anchorMode: WallAnchorMode.innerFace,
        );
        partnersUpdated.add(reverted);
        newWalls.add(reverted);
      } else {
        newWalls.add(w);
      }
    }

    state = state.copyWith(
      walls: newWalls,
      rooms: state.rooms.where((r) => r.id != roomId).toList(),
      zones: state.zones.where((z) => z.roomId != roomId).toList(),
      windows: state.windows
          .where((w) => !wallIdsToRemove.contains(w.wallSegmentId))
          .toList(),
      doors: state.doors
          .where((d) => !wallIdsToRemove.contains(d.wallSegmentId))
          .toList(),
    );

    final bDao = ref.read(buildingDaoProvider);
    final hDao = ref.read(heatingDaoProvider);
    for (final w in wallsToRemove) {
      unawaited(deleteWallSegment(bDao, w.id));
    }
    for (final p in partnersUpdated) {
      unawaited(upsertWallSegment(bDao, p));
    }
    for (final z in zonesToRemove) {
      unawaited(deleteHeatingZone(hDao, z.id));
    }
    for (final w in windowsToRemove) {
      unawaited(deleteWindow(bDao, w.id));
    }
    for (final d in doorsToRemove) {
      unawaited(deleteDoor(bDao, d.id));
    }
    unawaited(deleteRoom(bDao, roomId));
    markProjectDirty();
  }

  /// Replace walls, rooms, zones, windows, and doors atomically — the
  /// inverse of [destroyRoomCascade] (ADR-019 Rule 4 snapshot restore).
  ///
  /// Used by the "Delete room" undo / redo command. Memory only; DAO
  /// sync is handled by the initial [destroyRoomCascade] call and is
  /// not re-applied on undo (the existing snapshot-restore pattern for
  /// `_MoveRoomCommand` / `_RectDrawCommand` follows the same
  /// convention).
  void replaceAllForRoomCascade(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
    List<WindowElement> windows,
    List<Door> doors,
  ) {
    state = state.copyWith(
      walls: walls,
      rooms: rooms,
      zones: zones,
      windows: windows,
      doors: doors,
    );
  }

  // ---- Walls batch operations ----

  /// Replace the entire wall list in one state update.
  ///
  /// Used by undo/redo commands to restore a prior snapshot.
  void replaceAllWalls(List<WallSegment> walls) {
    state = state.copyWith(walls: walls);
  }

  /// Replace walls, constructions, and material layers in one atomic
  /// state update (ADR-020 Rule 6/7 undo snapshot — "Update project
  /// defaults" command). DAO sync is handled by the originating
  /// mutation; undo/redo restores the in-memory tuple only.
  void replaceAllWallsConstructionsLayers(
    List<WallSegment> walls,
    List<WallConstruction> constructions,
    List<MaterialLayer> layers,
  ) {
    state = state.copyWith(
      walls: walls,
      constructions: constructions,
      materialLayers: layers,
    );
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

  /// Replace walls, rooms, and zones in one atomic state update.
  ///
  /// Used by the ADR-016 "Move room" undo command so a single Ctrl+Z
  /// reverts every wall, room, and zone change made during the move,
  /// including regenerated/severed shared walls.
  void replaceAllWallsRoomsZones(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
  ) {
    state = state.copyWith(walls: walls, rooms: rooms, zones: zones);
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
  /// the original construction is not modified. Any existing
  /// localised display name on the source construction is preserved
  /// on the preset via [WallConstruction.copyWith] without explicit
  /// override.
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

        // ADR-003 Rule 5 + ADR-017: flanking segments inherit the host's
        // thermal/geometric properties — including `thicknessMm` and
        // `anchorMode` so the split halves continue to render and
        // calculate as the same physical wall.
        final before = _withOrientation(WallSegment(
          id: IdGenerator.newId(),
          roomId: host.roomId,
          startPoint: host.startPoint,
          endPoint: pt,
          wallType: host.wallType,
          thicknessMm: host.thicknessMm,
          anchorMode: host.anchorMode,
          constructionId: host.constructionId,
          adjacentRoomId: host.adjacentRoomId,
        ));
        final after = _withOrientation(WallSegment(
          id: IdGenerator.newId(),
          roomId: host.roomId,
          startPoint: pt,
          endPoint: host.endPoint,
          wallType: host.wallType,
          thicknessMm: host.thicknessMm,
          anchorMode: host.anchorMode,
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

    var prepared = _withThicknessDefaults(_withRule2Defaults(wall));
    if (prepared.constructionId == null) {
      // ADR-020 Rule 3: every fresh wall carries an auto-default
      // construction. Split fragments above kept the host's
      // constructionId so they remain on the original construction.
      final cid = _spawnAutoDefaultConstruction(prepared.wallType);
      prepared = prepared.copyWith(
        constructionId: cid,
        thicknessMm: _projectDefaultThicknessFor(prepared.wallType),
      );
    }
    final newWall = _withOrientation(prepared);
    walls.add(newWall);
    state = state.copyWith(walls: walls);

    final dao = ref.read(buildingDaoProvider);
    if (removed.isNotEmpty || addedPersisted.isNotEmpty) {
      for (final id in removed) {
        unawaited(deleteWallSegment(dao, id));
      }
      for (final w in addedPersisted) {
        unawaited(upsertWallSegment(dao, w));
      }
    }
    // Persist the newly added wall whenever it carries a roomId so the
    // ADR-017 startup restore picks up its constructionId. Bare
    // (roomId-empty) walls remain in-memory until promoted to a room.
    if (newWall.roomId.isNotEmpty) {
      unawaited(upsertWallSegment(dao, newWall));
    }
    if (removed.isNotEmpty || addedPersisted.isNotEmpty ||
        newWall.roomId.isNotEmpty) {
      markProjectDirty();
    }
  }

  /// Create a room from auto-detection results, handling
  /// shared walls correctly (ADR-001).
  ///
  /// All mutations are committed in a single state update.
  ///
  /// Per ADR-017 Rules 3 and 7–8, every shared-wall promotion forces
  /// `anchorMode = WallAnchorMode.centerline` on both members of the
  /// mirror pair and resolves [thicknessMm] / [constructionId] per
  /// Rule 8 cases 8a–8d.
  ///
  /// [movedSideProperties] supplies the new-room-side wall's
  /// pre-move [thicknessMm] / [constructionId] / [wallType] for shared
  /// walls promoted via the ADR-016 room-move reconciliation path
  /// (keyed by the matched host wall's id). The room-draw path passes
  /// null, which the resolver treats as "new side is default" — the
  /// historical invariant before ADR-016.
  void addRoomFromDetection({
    required Room room,
    required List<String> wallIds,
    Map<String, WallSegment>? movedSideProperties,
  }) {
    final updatedWalls = [...state.walls];
    var updatedConstructions = [...state.constructions];
    var updatedLayers = [...state.materialLayers];
    final toPersist = <WallSegment>[];
    final conflicts = <ValidationResult>[];
    final settings = ref.read(projectSettingsProvider);

    // Local helpers so the loop body stays readable. ADR-020 Rule 7's
    // safety-net text — "keep its safety-net behaviour for any
    // constructionId == null wall that might still exist" — applies
    // here too: a wall with null `constructionId` is treated as
    // auto-default for promotion-decision purposes.
    bool isAutoDefault(String? cid) {
      if (cid == null) return true;
      return updatedConstructions
              .where((c) => c.id == cid)
              .firstOrNull
              ?.isAutoDefault ==
          true;
    }

    void dropAutoDefault(String cid) {
      updatedConstructions =
          updatedConstructions.where((c) => c.id != cid).toList();
      updatedLayers =
          updatedLayers.where((l) => l.constructionId != cid).toList();
      if (_isDatabaseAvailable()) {
        final cDao = ref.read(constructionDaoProvider);
        unawaited(deleteConstruction(cDao, cid));
      }
    }

    String spawnSharedAutoDefault() {
      // ADR-020 Rule 8a: create a fresh shared auto-default interior
      // construction. _spawnAutoDefaultConstruction commits to state &
      // DAO, but state is read again on the next iteration via
      // `updatedConstructions`, so refresh from the notifier state.
      final cid = _spawnAutoDefaultConstruction(WallType.interior);
      updatedConstructions = [...state.constructions];
      updatedLayers = [...state.materialLayers];
      return cid;
    }

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

        // ADR-020 reinterprets ADR-017 Rule 8: "default" means
        // `construction.isAutoDefault == true`.
        //   8a both auto-default              → fresh shared auto-default
        //   8b exactly one side non-auto-def. → adopt that side
        //   8c both non-auto-default, equal   → preserve
        //   8d both non-auto-default, diff.   → adopt host + warning
        //
        // When [movedSideProperties] is null (room-draw path) the moved
        // side is treated as auto-default (the wall was just drawn and
        // its auto-default construction was spawned in `addWall` /
        // `commitWallWithSplit`).
        final movedSide = movedSideProperties?[wallId];
        final hostAutoDefault = isAutoDefault(wall.constructionId);
        final movedAutoDefault = movedSide == null
            ? true
            : isAutoDefault(movedSide.constructionId);

        final double resolvedThickness;
        final String? resolvedConstructionId;
        final bool resolvedIsAutoDefault;
        if (hostAutoDefault && movedAutoDefault) {
          // Case 8a — both auto-default → fresh shared auto-default.
          final sharedCid = spawnSharedAutoDefault();
          // Orphan the previous auto-defaults if any.
          final wallCid = wall.constructionId;
          if (wallCid != null) {
            dropAutoDefault(wallCid);
          }
          final movedCid = movedSide?.constructionId;
          if (movedCid != null && movedCid != wallCid) {
            dropAutoDefault(movedCid);
          }
          resolvedThickness =
              settings.defaultInteriorWallThicknessMm.toDouble();
          resolvedConstructionId = sharedCid;
          resolvedIsAutoDefault = true;
        } else if (!hostAutoDefault && movedAutoDefault) {
          // Case 8b (host non-auto-default) — adopt host.
          final movedCid = movedSide?.constructionId;
          if (movedCid != null && movedCid != wall.constructionId) {
            dropAutoDefault(movedCid);
          }
          resolvedThickness = wall.thicknessMm;
          resolvedConstructionId = wall.constructionId;
          resolvedIsAutoDefault = false;
        } else if (hostAutoDefault && !movedAutoDefault) {
          // Case 8b (moved non-auto-default) — adopt moved side.
          // `movedAutoDefault == false` implies movedSide is non-null
          // (the null branch sets movedAutoDefault = true), so flow
          // analysis already narrows movedSide here.
          final moved = movedSide;
          final wallCid = wall.constructionId;
          if (wallCid != null && moved.constructionId != wallCid) {
            dropAutoDefault(wallCid);
          }
          resolvedThickness = moved.thicknessMm;
          resolvedConstructionId = moved.constructionId;
          resolvedIsAutoDefault = false;
        } else if (movedSide != null &&
            movedSide.constructionId == wall.constructionId &&
            (movedSide.thicknessMm - wall.thicknessMm).abs() < 1e-6) {
          // Case 8c — both non-auto-default and equal → preserve.
          resolvedThickness = wall.thicknessMm;
          resolvedConstructionId = wall.constructionId;
          resolvedIsAutoDefault = false;
        } else {
          // Case 8d — both non-auto-default and different. Adopt host.
          resolvedThickness = wall.thicknessMm;
          resolvedConstructionId = wall.constructionId;
          resolvedIsAutoDefault = false;
          final movedCid = movedSide?.constructionId;
          if (movedCid != null && movedCid != wall.constructionId) {
            // The moved side's now-unreferenced construction may have
            // been a preset or an edited user construction — leave it
            // for the user. Only orphan when it was auto-default.
            if (isAutoDefault(movedCid)) {
              dropAutoDefault(movedCid);
            }
          }
          conflicts.add(
            ValidationResult(
              severity: WarningSeverity.warning,
              elementType: 'wall',
              elementId: wall.id,
              message:
                  'Shared wall construction conflict — adopted host wall '
                  'configuration; review.',
            ),
          );
        }
        // resolvedIsAutoDefault is the post-promotion isAutoDefault
        // value documented by ADR-020 Rule 8; it is already implied by
        // the chosen [resolvedConstructionId]'s row in the construction
        // table, so no extra write is needed here.
        assert(
          resolvedConstructionId == null ||
              isAutoDefault(resolvedConstructionId) ==
                  resolvedIsAutoDefault,
          'ADR-020 Rule 8: post-promotion construction isAutoDefault flag '
          'must match the resolved value.',
        );

        final updated = wall.copyWith(
          wallType: WallType.interior,
          adjacentRoomId: room.id,
          mirrorId: newMirrorId,
          thicknessMm: resolvedThickness,
          anchorMode: WallAnchorMode.centerline,
          constructionId: resolvedConstructionId,
        );
        updatedWalls[idx] = updated;
        toPersist.add(updated);

        final mirror = WallSegment(
          id: newMirrorId,
          roomId: room.id,
          startPoint: wall.endPoint,
          endPoint: wall.startPoint,
          wallType: WallType.interior,
          thicknessMm: resolvedThickness,
          anchorMode: WallAnchorMode.centerline,
          constructionId: resolvedConstructionId,
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
      constructions: updatedConstructions,
      materialLayers: updatedLayers,
    );

    final dao = ref.read(buildingDaoProvider);
    unawaited(upsertRoom(dao, room));
    for (final w in toPersist) {
      unawaited(upsertWallSegment(dao, w));
    }
    // ADR-017 Rule 8d: surface any non-blocking promotion conflicts to
    // the validation service (no-op when [conflicts] is empty, which is
    // the current expected case — see the Rule 8 commentary above).
    if (conflicts.isNotEmpty) {
      final warnings = ref.read(transientWarningsProvider.notifier);
      for (final c in conflicts) {
        warnings.add(c);
      }
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

/// In-memory wall constructions paired with their locale-resolved
/// display name and the alternate-locale name (for cross-locale search).
///
/// Sourced from [editorStateProvider]'s `constructions` list rather than
/// the DAO so any test that overrides the editor state automatically
/// drives this provider — no Drift stream is opened. Returns an empty
/// list when no constructions exist yet.
final localizedWallConstructionsProvider =
    Provider<List<LocalizedCatalogRow<WallConstruction>>>((ref) {
  final locale = ref.watch(currentLocaleProvider);
  final state = ref.watch(editorStateProvider);
  final isDe = locale.languageCode == 'de';
  return [
    for (final c in state.constructions)
      LocalizedCatalogRow<WallConstruction>(
        row: c,
        displayName: isDe ? (c.nameDe ?? c.name) : c.name,
        alternateName: isDe ? c.name : c.nameDe,
      ),
  ];
});

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
