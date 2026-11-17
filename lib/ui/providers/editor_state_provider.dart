import 'dart:async' show unawaited;
import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/providers/pipe_layout_providers.dart'
    show withCircuitsOnOutlets;
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

    // ADR-044: circuits saved before outlet stubs existed get one, and
    // every route starts at its stub. Stored quietly — it is a migration
    // of old data, not an edit.
    var onOutlets = (distributor: distributor, circuits: circuits);
    if (distributor != null) {
      final r = withCircuitsOnOutlets(distributor, circuits);
      onOutlets = (distributor: r.distributor, circuits: r.circuits);
      final dao = ref.read(heatingDaoProvider);
      if (r.distributor != distributor) {
        unawaited(upsertDistributor(dao, r.distributor));
      }
      for (var i = 0; i < circuits.length; i++) {
        if (!identical(r.circuits[i], circuits[i])) {
          unawaited(upsertHeatingCircuit(dao, r.circuits[i]));
        }
      }
    }

    state = EditorState(
      walls: walls,
      rooms: rooms,
      windows: windows,
      doors: doors,
      zones: zones,
      circuits: onOutlets.circuits,
      distributor: onOutlets.distributor,
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

  /// Commits a thickness re-anchor for [original] → [shifted] while keeping
  /// the room closed (ADR-017 Rule 6 corner reconciliation).
  ///
  /// [_shiftedForThickness] translates the wall's centerline perpendicular to
  /// itself for `innerFace` / `outerFace` anchors. That leaves the two
  /// neighbouring walls (and the `Room.polygon` corners) sharing the *old*
  /// endpoints, so the corner splits and the room loses its dimension. This
  /// method instead recomputes each moved corner as the mitre between the
  /// wall's new (parallel-shifted) line and the neighbour's own fixed line,
  /// then moves every wall endpoint and room-polygon vertex sitting on that
  /// old corner to the new one. Neighbours keep their direction and only
  /// change length; the loop stays closed and mitred.
  ///
  /// `centerline`-anchored recomputes do not shift the centerline, so they
  /// route straight through [updateWall] (thickness + ADR-011 mirror sync).
  void _applyReanchor(WallSegment original, WallSegment shifted) {
    final startMoved = GeometryEngine.distanceMm(
          original.startPoint,
          shifted.startPoint,
        ) >
        1e-6;
    final endMoved = GeometryEngine.distanceMm(
          original.endPoint,
          shifted.endPoint,
        ) >
        1e-6;

    if (!startMoved && !endMoved) {
      // Thickness-only change (centerline anchor, or degenerate/roomless
      // wall): no corner reflow needed. updateWall persists + mirror-syncs.
      updateWall(shifted);
      return;
    }

    // Neighbour walls in the same room whose fixed line the shifted wall
    // mitres against. The wall being re-anchored is never shared (Rule 3
    // forces shared walls to centerline, which cannot reach this branch),
    // so it has no mirror partner to special-case here.
    final roomWalls = state.walls
        .where((w) => w.roomId == original.roomId && w.id != original.id)
        .toList();

    final newStart = startMoved
        ? (_mitreCorner(
              sharedCorner: original.startPoint,
              neighbours: roomWalls,
              lineA: shifted.startPoint,
              lineB: shifted.endPoint,
            ) ??
            shifted.startPoint)
        : original.startPoint;
    final newEnd = endMoved
        ? (_mitreCorner(
              sharedCorner: original.endPoint,
              neighbours: roomWalls,
              lineA: shifted.startPoint,
              lineB: shifted.endPoint,
            ) ??
            shifted.endPoint)
        : original.endPoint;

    // Old-corner → new-corner remap, applied by coordinate so it reaches the
    // neighbour walls, any ADR-011 mirror partners of those neighbours (which
    // share the corner coordinate), and every room polygon touching it.
    final remap = <({Point2D from, Point2D to})>[
      if (startMoved) (from: original.startPoint, to: newStart),
      if (endMoved) (from: original.endPoint, to: newEnd),
    ];

    Point2D mapPoint(Point2D p) {
      for (final m in remap) {
        if (GeometryEngine.distanceMm(p, m.from) < 1.0) return m.to;
      }
      return p;
    }

    final reanchored = _withOrientation(
      shifted.copyWith(startPoint: newStart, endPoint: newEnd),
    );

    final newWalls = <WallSegment>[];
    final changedWallIds = <String>{reanchored.id};
    for (final w in state.walls) {
      if (w.id == reanchored.id) {
        newWalls.add(reanchored);
        continue;
      }
      final ms = mapPoint(w.startPoint);
      final me = mapPoint(w.endPoint);
      if (!identical(ms, w.startPoint) || !identical(me, w.endPoint)) {
        newWalls.add(_withOrientation(
          w.copyWith(startPoint: ms, endPoint: me),
        ));
        changedWallIds.add(w.id);
      } else {
        newWalls.add(w);
      }
    }

    final newRooms = <Room>[];
    final changedRoomIds = <String>{};
    for (final r in state.rooms) {
      var touched = false;
      final poly = <Point2D>[];
      for (final v in r.polygon) {
        final mapped = mapPoint(v);
        if (!identical(mapped, v)) touched = true;
        poly.add(mapped);
      }
      if (touched) {
        newRooms.add(r.copyWith(polygon: poly));
        changedRoomIds.add(r.id);
      } else {
        newRooms.add(r);
      }
    }

    state = state.copyWith(walls: newWalls, rooms: newRooms);

    final dao = ref.read(buildingDaoProvider);
    for (final w in newWalls) {
      if (changedWallIds.contains(w.id)) unawaited(upsertWallSegment(dao, w));
    }
    for (final r in newRooms) {
      if (changedRoomIds.contains(r.id)) unawaited(upsertRoom(dao, r));
    }
    markProjectDirty();
  }

  /// New mitred position of [sharedCorner]: the intersection of the fixed
  /// line of the neighbour wall meeting at [sharedCorner] with the shifted
  /// wall's new line [lineA]–[lineB]. Returns null when no usable
  /// (non-parallel) neighbour is attached there, so the caller falls back to
  /// the plain perpendicular-translated endpoint (a free wall end).
  Point2D? _mitreCorner({
    required Point2D sharedCorner,
    required List<WallSegment> neighbours,
    required Point2D lineA,
    required Point2D lineB,
  }) {
    for (final n in neighbours) {
      Point2D? far;
      if (GeometryEngine.distanceMm(n.startPoint, sharedCorner) < 1.0) {
        far = n.endPoint;
      } else if (GeometryEngine.distanceMm(n.endPoint, sharedCorner) < 1.0) {
        far = n.startPoint;
      }
      if (far == null) continue;
      final hit = GeometryEngine.lineIntersection(
        far,
        sharedCorner,
        lineA,
        lineB,
      );
      if (hit != null) return hit;
    }
    return null;
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
      categoryPath: const ['Masonry', 'Historic brick'],
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

  /// In-memory-only variant of [updateWall] for transient interactions
  /// (a wall drag in progress). Updates [state] every frame — including
  /// the ADR-011 mirror partner — but issues **no** DAO write and does
  /// **not** mark the project dirty. The committing call (`onDragEnd`'s
  /// undo command, which routes through the persisting [updateWall]) is
  /// the sole path that writes the final value to SQLite. Keeping the
  /// canvas state live each frame while debouncing the database write to
  /// the interaction boundary avoids one SQLite write per pointer-move.
  void updateWallTransient(WallSegment wall) {
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
        return;
      }
    }

    state = state.copyWith(
      walls: state.walls
          .map((s) => s.id == w.id ? w : s)
          .toList(),
    );
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
    _applyReanchor(
      withConstruction,
      _recomputeWallThickness(withConstruction),
    );
  }

  /// Detach the construction from wall [wallId] and re-anchor the
  /// centerline so its thickness reverts to the project default for the
  /// wall's [WallType] (ADR-017 Rule 9). Routes through [updateWall]
  /// for mirror sync.
  void clearConstruction(String wallId) {
    final wall = state.walls.where((w) => w.id == wallId).firstOrNull;
    if (wall == null) return;
    final withoutConstruction = wall.copyWith(constructionId: null);
    _applyReanchor(
      withoutConstruction,
      _recomputeWallThickness(withoutConstruction),
    );
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
      _applyReanchor(w, recomputed);
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
      _applyReanchor(w, recomputed);
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

  /// In-memory-only variant of [updateRoom] for transient interactions
  /// (room-polygon rebuild while a wall is dragged, or a slider in
  /// flight). Updates [state] only — no DAO write, no dirty marking.
  /// The interaction's commit (undo command via persisting [updateRoom])
  /// performs the single SQLite write.
  void updateRoomTransient(Room room) {
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
  /// Used by the "Delete room" undo / redo command. The in-memory tuple
  /// is replaced and SQLite is reconciled to match (see
  /// [_reconcileDb]) so an undone delete (or redone restore) survives a
  /// reload rather than re-materialising on the next [initFromFloor].
  void replaceAllForRoomCascade(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
    List<WindowElement> windows,
    List<Door> doors,
  ) {
    final wallsBefore = state.walls;
    final roomsBefore = state.rooms;
    final zonesBefore = state.zones;
    final windowsBefore = state.windows;
    final doorsBefore = state.doors;
    state = state.copyWith(
      walls: walls,
      rooms: rooms,
      zones: zones,
      windows: windows,
      doors: doors,
    );
    if (!_isDatabaseAvailable()) return;
    // Parents (rooms) before children (walls → windows/doors, zones).
    var wrote = _reconcileRoomsDb(roomsBefore, rooms);
    wrote = _reconcileWallsDb(wallsBefore, walls) || wrote;
    wrote = _reconcileZonesDb(zonesBefore, zones) || wrote;
    wrote = _reconcileWindowsDb(windowsBefore, windows) || wrote;
    wrote = _reconcileDoorsDb(doorsBefore, doors) || wrote;
    if (wrote) markProjectDirty();
  }

  // ---- Walls batch operations ----

  /// Replace the entire wall list in one state update.
  ///
  /// Used by undo/redo commands to restore a prior snapshot. SQLite is
  /// reconciled to the restored list so walls removed by an undo are
  /// also deleted from disk (and re-created walls re-persisted),
  /// preventing them from reappearing after a reload.
  void replaceAllWalls(List<WallSegment> walls) {
    final before = state.walls;
    state = state.copyWith(walls: walls);
    if (!_isDatabaseAvailable()) return;
    if (_reconcileWallsDb(before, walls)) markProjectDirty();
  }

  /// Replace walls, constructions, and material layers in one atomic
  /// state update (ADR-020 Rule 6/7 undo snapshot — "Update project
  /// defaults" command). SQLite is reconciled to the restored tuple.
  void replaceAllWallsConstructionsLayers(
    List<WallSegment> walls,
    List<WallConstruction> constructions,
    List<MaterialLayer> layers,
  ) {
    final wallsBefore = state.walls;
    final constructionsBefore = state.constructions;
    final layersBefore = state.materialLayers;
    state = state.copyWith(
      walls: walls,
      constructions: constructions,
      materialLayers: layers,
    );
    if (!_isDatabaseAvailable()) return;
    // Constructions before walls (FK setNull) and layers (FK cascade).
    var wrote = _reconcileConstructionsDb(constructionsBefore, constructions);
    wrote = _reconcileWallsDb(wallsBefore, walls) || wrote;
    wrote = _reconcileLayersDb(layersBefore, layers) || wrote;
    if (wrote) markProjectDirty();
  }

  /// Replace walls and rooms in one atomic state update.
  ///
  /// Used by undo/redo commands that affect both walls
  /// and room membership simultaneously. SQLite is reconciled to the
  /// restored tuple.
  void replaceAllWallsAndRooms(
    List<WallSegment> walls,
    List<Room> rooms,
  ) {
    final wallsBefore = state.walls;
    final roomsBefore = state.rooms;
    state = state.copyWith(walls: walls, rooms: rooms);
    if (!_isDatabaseAvailable()) return;
    // Parents (rooms) before children (walls, FK to rooms).
    var wrote = _reconcileRoomsDb(roomsBefore, rooms);
    wrote = _reconcileWallsDb(wallsBefore, walls) || wrote;
    if (wrote) markProjectDirty();
  }

  /// Replace walls, rooms, and zones in one atomic state update.
  ///
  /// Used by the ADR-016 "Move room" undo command so a single Ctrl+Z
  /// reverts every wall, room, and zone change made during the move,
  /// including regenerated/severed shared walls. SQLite is reconciled
  /// to the restored tuple.
  void replaceAllWallsRoomsZones(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
  ) {
    final wallsBefore = state.walls;
    final roomsBefore = state.rooms;
    final zonesBefore = state.zones;
    state = state.copyWith(walls: walls, rooms: rooms, zones: zones);
    if (!_isDatabaseAvailable()) return;
    // Parents (rooms) before children (walls, zones).
    var wrote = _reconcileRoomsDb(roomsBefore, rooms);
    wrote = _reconcileWallsDb(wallsBefore, walls) || wrote;
    wrote = _reconcileZonesDb(zonesBefore, zones) || wrote;
    if (wrote) markProjectDirty();
  }

  // ---- Undo/redo SQLite reconciliation ──────────────────────────────────

  /// Reconciles a persisted entity collection so SQLite matches [after]
  /// after an undo/redo snapshot restore.
  ///
  /// The editor persists every mutation eagerly, but the snapshot-restore
  /// helpers above only swap the in-memory tuple. Without reconciliation a
  /// create that was undone (or a delete that was redone) lingers in the
  /// database and the element reappears on the next [initFromFloor] reload.
  ///
  /// Deletes rows whose id disappeared from [after] (or became
  /// non-persistable), and upserts rows in [after] that are new or
  /// value-changed versus [before]. Entities that were never persistable
  /// (e.g. a bare wall with an empty `roomId`) are skipped on both sides.
  /// Returns true when at least one DAO write was issued.
  static bool _reconcileDb<T>(
    Iterable<T> before,
    Iterable<T> after, {
    required String Function(T) idOf,
    required void Function(T) upsert,
    required void Function(String) delete,
    bool Function(T)? isPersistable,
  }) {
    var wrote = false;
    final afterById = {for (final e in after) idOf(e): e};
    for (final e in before) {
      if (isPersistable != null && !isPersistable(e)) continue;
      final id = idOf(e);
      final now = afterById[id];
      if (now == null || (isPersistable != null && !isPersistable(now))) {
        delete(id);
        wrote = true;
      }
    }
    final beforeById = {for (final e in before) idOf(e): e};
    for (final e in after) {
      if (isPersistable != null && !isPersistable(e)) continue;
      final prev = beforeById[idOf(e)];
      if (prev == null || prev != e) {
        upsert(e);
        wrote = true;
      }
    }
    return wrote;
  }

  bool _reconcileWallsDb(
    List<WallSegment> before,
    List<WallSegment> after,
  ) {
    final dao = ref.read(buildingDaoProvider);
    return _reconcileDb<WallSegment>(
      before,
      after,
      idOf: (w) => w.id,
      upsert: (w) => unawaited(upsertWallSegment(dao, w)),
      delete: (id) => unawaited(deleteWallSegment(dao, id)),
      // Bare walls (no room) are never written to SQLite; the startup
      // query inner-joins on rooms so they would not reload anyway.
      isPersistable: (w) => w.roomId.isNotEmpty,
    );
  }

  bool _reconcileRoomsDb(List<Room> before, List<Room> after) {
    final dao = ref.read(buildingDaoProvider);
    return _reconcileDb<Room>(
      before,
      after,
      idOf: (r) => r.id,
      upsert: (r) => unawaited(upsertRoom(dao, r)),
      delete: (id) => unawaited(deleteRoom(dao, id)),
    );
  }

  bool _reconcileZonesDb(
    List<HeatingZone> before,
    List<HeatingZone> after,
  ) {
    final dao = ref.read(heatingDaoProvider);
    return _reconcileDb<HeatingZone>(
      before,
      after,
      idOf: (z) => z.id,
      upsert: (z) => unawaited(upsertHeatingZone(dao, z)),
      delete: (id) => unawaited(deleteHeatingZone(dao, id)),
    );
  }

  bool _reconcileWindowsDb(
    List<WindowElement> before,
    List<WindowElement> after,
  ) {
    final dao = ref.read(buildingDaoProvider);
    return _reconcileDb<WindowElement>(
      before,
      after,
      idOf: (w) => w.id,
      upsert: (w) => unawaited(upsertWindow(dao, w)),
      delete: (id) => unawaited(deleteWindow(dao, id)),
    );
  }

  bool _reconcileDoorsDb(List<Door> before, List<Door> after) {
    final dao = ref.read(buildingDaoProvider);
    return _reconcileDb<Door>(
      before,
      after,
      idOf: (d) => d.id,
      upsert: (d) => unawaited(upsertDoor(dao, d)),
      delete: (id) => unawaited(deleteDoor(dao, id)),
    );
  }

  bool _reconcileConstructionsDb(
    List<WallConstruction> before,
    List<WallConstruction> after,
  ) {
    final dao = ref.read(constructionDaoProvider);
    return _reconcileDb<WallConstruction>(
      before,
      after,
      idOf: (c) => c.id,
      upsert: (c) => unawaited(upsertConstruction(dao, c)),
      delete: (id) => unawaited(deleteConstruction(dao, id)),
    );
  }

  bool _reconcileLayersDb(
    List<MaterialLayer> before,
    List<MaterialLayer> after,
  ) {
    final dao = ref.read(constructionDaoProvider);
    return _reconcileDb<MaterialLayer>(
      before,
      after,
      idOf: (l) => l.id,
      upsert: (l) => unawaited(upsertLayer(dao, l)),
      delete: (id) => unawaited(deleteLayer(dao, id)),
    );
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

  /// In-memory-only variant of [updateWindow] for transient interactions
  /// (an opening drag in progress). Updates [state] only — no DAO write,
  /// no dirty marking. The drag's commit (undo command via persisting
  /// [updateWindow]) performs the single SQLite write.
  void updateWindowTransient(WindowElement window) {
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

  /// In-memory-only variant of [updateDoor] for transient interactions
  /// (an opening drag in progress). Updates [state] only — no DAO write,
  /// no dirty marking. The drag's commit (undo command via persisting
  /// [updateDoor]) performs the single SQLite write.
  void updateDoorTransient(Door door) {
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

  /// In-memory-only variant of [updateZone] for transient interactions
  /// (a zone drag, or a zone slider in flight). Updates [state] only —
  /// no DAO write, no dirty marking. The interaction's commit (undo
  /// command via persisting [updateZone]) performs the single SQLite
  /// write.
  void updateZoneTransient(HeatingZone zone) {
    state = state.copyWith(
      zones: state.zones
          .map((z) => z.id == zone.id ? zone : z)
          .toList(),
    );
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

  /// Sets every zone in [zoneIds] to [newHeightMm].
  ///
  /// In-memory only when [persist] is false — used by the project-settings
  /// room-height slider so each pointer tick updates the canvas without a
  /// SQLite write. The single `onChangeEnd` call with [persist] = true
  /// upserts exactly the affected zones once. The caller captures the set
  /// of "auto" wall-zone ids (those whose `heightMm` matched the floor
  /// height) at drag start, so manually-adjusted zones are never touched.
  void setWallZoneHeightsForIds(
    Set<String> zoneIds,
    int newHeightMm, {
    required bool persist,
  }) {
    if (zoneIds.isEmpty) return;
    final updated = <HeatingZone>[];
    final newZones = state.zones.map((z) {
      if (zoneIds.contains(z.id)) {
        final u = z.copyWith(heightMm: newHeightMm);
        updated.add(u);
        return u;
      }
      return z;
    }).toList();
    if (updated.isEmpty) return;
    state = state.copyWith(zones: newZones);
    if (persist) {
      final dao = ref.read(heatingDaoProvider);
      for (final z in updated) {
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

  /// In-memory-only circuit update for a drag in progress (ADR-023).
  ///
  /// Mutates editor state only — no DB write, no dirty flag. The
  /// committing [updateCircuit] at the end of the drag persists.
  void updateCircuitTransient(HeatingCircuit circuit) {
    state = state.copyWith(
      circuits: state.circuits
          .map((c) => c.id == circuit.id ? circuit : c)
          .toList(),
    );
  }

  // ---- Distributor ----

  /// Set (or replace) the floor's distributor.
  void setDistributor(Distributor d) => updateDistributor(d);

  /// Replace the existing distributor with an updated copy.
  ///
  /// The connection pipes of its circuits follow their outlet stubs
  /// (ADR-044). Every circuit of the distributor is written as well — a
  /// preceding drag moved them with [updateDistributorTransient] only.
  void updateDistributor(Distributor d) {
    final placed = _placeDistributor(d);
    final dao = ref.read(heatingDaoProvider);
    unawaited(upsertDistributor(dao, placed));
    for (final c in state.circuits) {
      if (c.distributorId == placed.id) {
        unawaited(upsertHeatingCircuit(dao, c));
      }
    }
    markProjectDirty();
  }

  /// In-memory-only variant of [updateDistributor] for transient
  /// interactions (a distributor drag, or a temperature slider in
  /// flight). Updates [state] only — no DAO write, no dirty marking.
  /// The interaction's commit (undo command or `onChangeEnd`, via the
  /// persisting [updateDistributor]) performs the single SQLite write.
  void updateDistributorTransient(Distributor d) => _placeDistributor(d);

  /// Sets [d] as the distributor and moves the start of every circuit of
  /// it to its outlet stub (ADR-044). Returns the distributor as stored —
  /// its outlet count is raised if it has more circuits than outlets.
  Distributor _placeDistributor(Distributor d) {
    final r = withCircuitsOnOutlets(d, state.circuits);
    state = state.copyWith(distributor: r.distributor, circuits: r.circuits);
    return r.distributor;
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
  /// When [splitNewWall] is true (the room-draw default), the **new** wall
  /// is also split — symmetrically to the host split — at any existing
  /// room-wall endpoint that lies on its interior. This handles the case
  /// where the new wall is *longer* than an existing wall it runs along
  /// (e.g. drawing a wide room after an adjacent narrow one): the new wall
  /// is divided at the narrow wall's corners so the shared sub-segment
  /// becomes its own graph edge. The fragment that coincides with the
  /// existing wall is dropped rather than duplicated — room detection then
  /// closes the new room through the existing wall and
  /// [addRoomFromDetection] promotes it to a shared (mirrored) wall, just
  /// as in the reverse draw order. Callers that build the room boundary
  /// themselves (e.g. the ADR-016 room-move reconciliation) pass false to
  /// keep the new wall intact.
  ///
  /// Returns the wall segment that should seed room detection: a freshly
  /// committed fragment that is a real edge on the new room's boundary, so
  /// the planar-face trace closes correctly even when the new wall was
  /// reverse-split. (Equal to [wall] with defaults applied when no split
  /// occurred.)
  ///
  /// All mutations are committed in a single state update.
  WallSegment commitWallWithSplit(
    WallSegment wall, {
    bool splitNewWall = true,
  }) {
    var walls = List<WallSegment>.from(state.walls);
    final removed = <String>[];
    final addedPersisted = <WallSegment>[];

    // Host-room polygons gain each split vertex so every fragment still
    // matches a polygon edge in [GeometryEngine.roomFaceEdges]. Without this
    // the split edge no longer matches any wall (each fragment is only part
    // of it), so the fragments lose their mitred faces and the host room
    // appears to detach at that corner. Keyed by room id; seeded lazily from
    // the current polygon and mutated per split.
    final roomPolys = <String, List<Point2D>>{};

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

        // Insert [pt] into the host room's polygon between the two vertices
        // of the edge being split (this may be a fragment from an earlier
        // split, so match against the current host's endpoints).
        final base = roomPolys[host.roomId] ??
            state.rooms
                .where((r) => r.id == host.roomId)
                .firstOrNull
                ?.polygon;
        if (base != null && base.isNotEmpty) {
          roomPolys[host.roomId] = _insertPolygonVertexOnEdge(
            base,
            host.startPoint,
            host.endPoint,
            pt,
          );
        }
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

    // Reverse split (symmetric to the host split above): subdivide the new
    // wall at any existing room-wall endpoint lying on its interior. Every
    // fragment shares [prepared]'s thermal/geometric properties — they are
    // one physical wall drawn by the user.
    final boundary = <Point2D>[prepared.startPoint, prepared.endPoint];
    if (splitNewWall) {
      final seenKeys = <String>{};
      final splitVertices = <Point2D>[];
      for (final host in walls) {
        if (host.roomId.isEmpty) continue;
        for (final v in [host.startPoint, host.endPoint]) {
          if (!_isStrictlyInterior(v, prepared)) continue;
          final key = '${v.x.round()},${v.y.round()}';
          if (seenKeys.add(key)) splitVertices.add(v);
        }
      }
      splitVertices.sort((a, b) => GeometryEngine
          .parameterAlongSegment(a, prepared.startPoint, prepared.endPoint)
          .compareTo(GeometryEngine.parameterAlongSegment(
              b, prepared.startPoint, prepared.endPoint)));
      boundary.insertAll(1, splitVertices);
    }

    final addedNew = <WallSegment>[];
    WallSegment? coincidentSeed;
    for (var i = 0; i < boundary.length - 1; i++) {
      final a = boundary[i];
      final b = boundary[i + 1];
      // Drop a fragment that lies on top of an existing room wall: that wall
      // (a host-split piece, or the neighbour's wall) already provides the
      // graph edge, so room detection closes the new room through it and
      // addRoomFromDetection promotes it to a shared/mirrored wall. Adding a
      // coincident copy would leave an orphan duplicate over the shared wall
      // (ADR-009 §Rule 2, sub-segment level). Only the room-draw path
      // (splitNewWall) drops; callers that build the boundary themselves
      // (splitNewWall=false) keep the wall intact.
      if (splitNewWall) {
        final existing = _coincidentRoomWall(a, b, walls);
        if (existing != null) {
          coincidentSeed ??= existing;
          continue;
        }
      }
      addedNew.add(_withOrientation(prepared.copyWith(
        id: addedNew.isEmpty ? prepared.id : IdGenerator.newId(),
        startPoint: a,
        endPoint: b,
      )));
    }

    walls.addAll(addedNew);

    // Fold the split vertices into each host room's polygon (see roomPolys).
    final updatedRooms = roomPolys.isEmpty
        ? state.rooms
        : [
            for (final r in state.rooms)
              roomPolys.containsKey(r.id)
                  ? r.copyWith(polygon: roomPolys[r.id]!)
                  : r,
          ];
    state = state.copyWith(walls: walls, rooms: updatedRooms);

    final dao = ref.read(buildingDaoProvider);
    if (removed.isNotEmpty || addedPersisted.isNotEmpty) {
      for (final id in removed) {
        unawaited(deleteWallSegment(dao, id));
      }
      for (final w in addedPersisted) {
        unawaited(upsertWallSegment(dao, w));
      }
    }
    for (final id in roomPolys.keys) {
      final r = updatedRooms.where((x) => x.id == id).firstOrNull;
      if (r != null) unawaited(upsertRoom(dao, r));
    }
    // Persist any new fragment carrying a roomId so the ADR-017 startup
    // restore picks up its constructionId. Bare (roomId-empty) walls remain
    // in-memory until promoted to a room.
    final persistedNew = addedNew.where((w) => w.roomId.isNotEmpty).toList();
    for (final w in persistedNew) {
      unawaited(upsertWallSegment(dao, w));
    }
    if (removed.isNotEmpty ||
        addedPersisted.isNotEmpty ||
        persistedNew.isNotEmpty ||
        roomPolys.isNotEmpty) {
      markProjectDirty();
    }

    // Seed for room detection: a freshly added fragment when one exists,
    // otherwise the existing wall the whole drawn wall coincides with (the
    // host-split piece that will be promoted to a shared wall).
    if (addedNew.isNotEmpty) return addedNew.first;
    return coincidentSeed ?? _withOrientation(prepared);
  }

  /// Returns [polygon] with [pt] inserted between the consecutive vertices
  /// matching edge [a]→[b] (direction-agnostic, 1 mm tolerance). When no
  /// edge matches (the split wall is not on this room's boundary) the polygon
  /// is returned unchanged.
  List<Point2D> _insertPolygonVertexOnEdge(
    List<Point2D> polygon,
    Point2D a,
    Point2D b,
    Point2D pt,
  ) {
    bool eq(Point2D p, Point2D q) => GeometryEngine.distanceMm(p, q) < 1.0;
    for (var i = 0; i < polygon.length; i++) {
      final v1 = polygon[i];
      final v2 = polygon[(i + 1) % polygon.length];
      if ((eq(v1, a) && eq(v2, b)) || (eq(v1, b) && eq(v2, a))) {
        final out = List<Point2D>.from(polygon);
        out.insert(i + 1, pt);
        return out;
      }
    }
    return polygon;
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

  /// The existing room-assigned wall in [walls] that segment [a]→[b] lies on
  /// top of (both endpoints match within 1 mm, either direction), or null.
  /// Used by the reverse split to drop a duplicate shared sub-segment and to
  /// seed room detection from the existing wall.
  static WallSegment? _coincidentRoomWall(
    Point2D a,
    Point2D b,
    List<WallSegment> walls,
  ) {
    const tolMm = 1.0;
    for (final w in walls) {
      if (w.roomId.isEmpty) continue;
      final fwd = GeometryEngine.distanceMm(w.startPoint, a) <= tolMm &&
          GeometryEngine.distanceMm(w.endPoint, b) <= tolMm;
      final rev = GeometryEngine.distanceMm(w.startPoint, b) <= tolMm &&
          GeometryEngine.distanceMm(w.endPoint, a) <= tolMm;
      if (fwd || rev) return w;
    }
    return null;
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
