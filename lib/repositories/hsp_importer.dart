import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart' as $db;
import '../data/models/enums.dart';

/// Imports a `.hsp` project snapshot into [_db], generating new UUIDs for
/// all project-specific entities so that the imported project coexists
/// with any pre-existing projects without ID collisions.
///
/// Shared lookup tables (tube types, flooring materials) are upserted with
/// their original IDs — they are project-agnostic and must remain stable
/// so that FK references from heating zones continue to resolve.
///
/// Usage:
/// ```dart
/// final bytes    = await File(path).readAsBytes();
/// final jsonStr  = utf8.decode(const GZipDecoder().decodeBytes(bytes));
/// final snapshot = jsonDecode(jsonStr) as Map<String, dynamic>;
/// final newId    = await HspImporter(db).importSnapshot(snapshot);
/// ```
class HspImporter {
  /// Creates an [HspImporter] bound to [_db].
  HspImporter(this._db);

  final $db.AppDatabase _db;

  static const _uuid = Uuid();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Imports [snapshot] (a decoded `.hsp` JSON map) into the database and
  /// returns the UUID of the newly created project.
  ///
  /// All project-hierarchy entity UUIDs (project, floors, rooms, walls,
  /// openings, zones, distributors, circuits, constructions, layers, custom
  /// materials) are replaced with freshly generated v4 UUIDs. Cross-entity
  /// references are updated using the same remap table.
  ///
  /// Tube types and flooring materials are upserted with their original IDs
  /// because they are shared across all projects.
  Future<String> importSnapshot(Map<String, dynamic> snapshot) async {
    // UUID remap: oldId → newId (project-specific entities only).
    final idMap = <String, String>{};
    // Returns the pre-generated new ID for [old], creating one on first call.
    String fresh(String old) =>
        idMap.putIfAbsent(old, () => _uuid.v4());

    // ── Pre-scan ─────────────────────────────────────────────────────────────
    // Generate new IDs for every entity before inserting anything. This
    // ensures forward references (e.g. heatingZone.circuitId) resolve to a
    // known new UUID even though the circuit row has not been written yet.
    final projectData =
        snapshot['project'] as Map<String, dynamic>;
    fresh(projectData['id'] as String);
    for (final key in const [
      'floors',
      'rooms',
      'wallSegments',
      'windows',
      'doors',
      'wallConstructions',
      'materialLayers',
      'customMaterials',
      'heatingZones',
      'distributors',
      'heatingCircuits',
    ]) {
      for (final e in _list(snapshot, key)) {
        fresh(e['id'] as String);
      }
    }

    // ── Shared lookup tables (keep original IDs) ──────────────────────────
    for (final t in _list(snapshot, 'tubeTypes')) {
      await _db
          .into(_db.tubeTypes)
          .insertOnConflictUpdate(_tubeCompanion(t));
    }
    for (final f in _list(snapshot, 'flooringMaterials')) {
      await _db
          .into(_db.flooringMaterials)
          .insertOnConflictUpdate(_flooringCompanion(f));
    }

    // ── Project-specific entities in topological (FK-dependency) order ────

    // Wall constructions — no FK dependencies inside the project hierarchy.
    for (final c in _list(snapshot, 'wallConstructions')) {
      await _db
          .into(_db.wallConstructions)
          .insert(_constructionCompanion(c, fresh));
    }

    // Material layers — depend on wallConstructions.
    for (final l in _list(snapshot, 'materialLayers')) {
      await _db
          .into(_db.materialLayers)
          .insert(_layerCompanion(l, fresh, idMap));
    }

    // Custom materials — no FK dependencies.
    for (final m in _list(snapshot, 'customMaterials')) {
      await _db
          .into(_db.materialEntries)
          .insert(_customMaterialCompanion(m, fresh));
    }

    // Project.
    await _db
        .into(_db.projects)
        .insert(_projectCompanion(projectData, fresh));

    // Floors — depend on project.
    for (final f in _list(snapshot, 'floors')) {
      await _db
          .into(_db.floors)
          .insert(_floorCompanion(f, fresh, idMap));
    }

    // Rooms — depend on floors.
    for (final r in _list(snapshot, 'rooms')) {
      await _db
          .into(_db.rooms)
          .insert(_roomCompanion(r, fresh, idMap));
    }

    // Wall segments — depend on rooms and (optionally) wall constructions.
    for (final w in _list(snapshot, 'wallSegments')) {
      await _db
          .into(_db.wallSegments)
          .insert(_wallSegmentCompanion(w, fresh, idMap));
    }

    // Windows — depend on wall segments.
    for (final w in _list(snapshot, 'windows')) {
      await _db
          .into(_db.windows)
          .insert(_windowCompanion(w, fresh, idMap));
    }

    // Doors — depend on wall segments.
    for (final d in _list(snapshot, 'doors')) {
      await _db
          .into(_db.doors)
          .insert(_doorCompanion(d, fresh, idMap));
    }

    // Distributors — depend on floors.
    for (final d in _list(snapshot, 'distributors')) {
      await _db
          .into(_db.distributors)
          .insert(_distributorCompanion(d, fresh, idMap));
    }

    // Heating zones — depend on rooms, tube types, flooring materials.
    // circuitId (nullable text, no FK) references a circuit pre-generated in
    // the pre-scan, so it is safe to set here even before circuits exist.
    for (final z in _list(snapshot, 'heatingZones')) {
      await _db
          .into(_db.heatingZones)
          .insert(_zoneCompanion(z, fresh, idMap));
    }

    // Heating circuits — depend on distributors and heating zones.
    for (final c in _list(snapshot, 'heatingCircuits')) {
      await _db
          .into(_db.heatingCircuits)
          .insert(_circuitCompanion(c, fresh, idMap));
    }

    return fresh(projectData['id'] as String);
  }

  // ── Companion builders ──────────────────────────────────────────────────────

  $db.TubeTypesCompanion _tubeCompanion(
    Map<String, dynamic> d,
  ) =>
      $db.TubeTypesCompanion.insert(
        id: d['id'] as String,
        name: d['name'] as String,
        material: d['material'] as String,
        outerDiameterMm:
            Value(_double(d, 'outerDiameterMm')),
        innerDiameterMm:
            Value(_double(d, 'innerDiameterMm')),
        wallThicknessMm:
            Value(_double(d, 'wallThicknessMm')),
        thermalConductivity:
            Value(_double(d, 'thermalConductivity')),
      );

  $db.FlooringMaterialsCompanion _flooringCompanion(
    Map<String, dynamic> d,
  ) =>
      $db.FlooringMaterialsCompanion.insert(
        id: d['id'] as String,
        name: d['name'] as String,
        thermalResistance: _double(d, 'thermalResistance'),
        surfaceType:
            Value(d['surfaceType'] as String? ?? 'floor'),
      );

  $db.WallConstructionsCompanion _constructionCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
  ) =>
      $db.WallConstructionsCompanion.insert(
        id: fresh(d['id'] as String),
        name: d['name'] as String,
        rsi: Value(_double(d, 'rsi')),
        rse: Value(_double(d, 'rse')),
        isPreset:
            Value((d['isPreset'] as bool? ?? false) ? 1 : 0),
      );

  $db.MaterialLayersCompanion _layerCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
    Map<String, String> idMap,
  ) =>
      $db.MaterialLayersCompanion.insert(
        id: fresh(d['id'] as String),
        constructionId:
            idMap[d['constructionId'] as String] ??
                d['constructionId'] as String,
        sortOrder: d['sortOrder'] as int,
        // materialId may reference a custom material (remapped) or a
        // built-in entry (not in idMap → keep original).
        materialId:
            idMap[d['materialId'] as String] ??
                d['materialId'] as String,
        thicknessMm: _double(d, 'thicknessMm'),
        thermalConductivity:
            _double(d, 'thermalConductivity'),
        density: _double(d, 'density'),
        specificHeat: _double(d, 'specificHeat'),
      );

  $db.MaterialEntriesCompanion _customMaterialCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
  ) =>
      $db.MaterialEntriesCompanion.insert(
        id: fresh(d['id'] as String),
        name: d['name'] as String,
        category: d['category'] as String,
        lambdaDefault: _double(d, 'lambdaDefault'),
        densityDefault: _double(d, 'densityDefault'),
        specificHeatDefault:
            _double(d, 'specificHeatDefault'),
        isBuiltIn: const Value(false),
      );

  $db.ProjectsCompanion _projectCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
  ) =>
      $db.ProjectsCompanion.insert(
        id: fresh(d['id'] as String),
        name: d['name'] as String,
        createdAt:
            DateTime.parse(d['createdAt'] as String),
        modifiedAt:
            DateTime.parse(d['modifiedAt'] as String),
        designOutdoorTempC:
            Value(_double(d, 'designOutdoorTempC')),
        defaultIndoorTempC:
            Value(_double(d, 'defaultIndoorTempC')),
      );

  $db.FloorsCompanion _floorCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
    Map<String, String> idMap,
  ) =>
      $db.FloorsCompanion.insert(
        id: fresh(d['id'] as String),
        projectId:
            idMap[d['projectId'] as String] ??
                d['projectId'] as String,
        name: d['name'] as String,
        level: Value(d['level'] as int? ?? 0),
        heightMm: Value(d['heightMm'] as int? ?? 2600),
      );

  $db.RoomsCompanion _roomCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
    Map<String, String> idMap,
  ) {
    final oldFloorId = d['floorId'] as String;
    final oldFloorConstrId =
        d['floorConstructionId'] as String?;
    final oldCeilConstrId =
        d['ceilingConstructionId'] as String?;
    return $db.RoomsCompanion.insert(
      id: fresh(d['id'] as String),
      floorId: idMap[oldFloorId] ?? oldFloorId,
      name: d['name'] as String,
      targetTempC: Value(_double(d, 'targetTempC')),
      airChangeRate:
          Value(_double(d, 'airChangeRate')),
      polygonJson: Value(jsonEncode(d['polygon'])),
      floorConstructionId: Value(
        oldFloorConstrId != null
            ? (idMap[oldFloorConstrId] ??
                oldFloorConstrId)
            : null,
      ),
      ceilingConstructionId: Value(
        oldCeilConstrId != null
            ? (idMap[oldCeilConstrId] ?? oldCeilConstrId)
            : null,
      ),
      floorBoundary: Value(
        d['floorBoundary'] as String? ?? 'ground',
      ),
      ceilingBoundary: Value(
        d['ceilingBoundary'] as String? ?? 'exterior',
      ),
      floorAdjacentTempC: Value(
        (d['floorAdjacentTempC'] as num?)?.toDouble(),
      ),
      ceilingAdjacentTempC: Value(
        (d['ceilingAdjacentTempC'] as num?)?.toDouble(),
      ),
    );
  }

  $db.WallSegmentsCompanion _wallSegmentCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
    Map<String, String> idMap,
  ) {
    final oldRoomId = d['roomId'] as String;
    final oldConstrId =
        d['constructionId'] as String?;
    final oldAdjRoomId =
        d['adjacentRoomId'] as String?;
    return $db.WallSegmentsCompanion.insert(
      id: fresh(d['id'] as String),
      roomId: idMap[oldRoomId] ?? oldRoomId,
      startPointJson: jsonEncode(d['startPoint']),
      endPointJson: jsonEncode(d['endPoint']),
      wallType:
          Value(d['wallType'] as String? ?? 'exterior'),
      constructionId: Value(
        oldConstrId != null
            ? (idMap[oldConstrId] ?? oldConstrId)
            : null,
      ),
      adjacentRoomId: Value(
        oldAdjRoomId != null
            ? (idMap[oldAdjRoomId] ?? oldAdjRoomId)
            : null,
      ),
      orientation: Value(
        d['orientation'] as String? ?? 'north',
      ),
      thicknessMm: (d['thicknessMm'] as num?)?.toDouble() ?? 0.0,
      anchorMode: d['anchorMode'] is int
          ? d['anchorMode'] as int
          : WallAnchorMode.centerline.index,
    );
  }

  $db.WindowsCompanion _windowCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
    Map<String, String> idMap,
  ) {
    final oldWallId = d['wallSegmentId'] as String;
    return $db.WindowsCompanion.insert(
      id: fresh(d['id'] as String),
      wallSegmentId:
          idMap[oldWallId] ?? oldWallId,
      positionOnWallMm:
          _double(d, 'positionOnWallMm'),
      widthMm: Value(d['widthMm'] as int? ?? 1200),
      heightMm: Value(d['heightMm'] as int? ?? 1400),
      sillHeightMm:
          Value(d['sillHeightMm'] as int? ?? 900),
      uValue: Value(_double(d, 'uValue')),
    );
  }

  $db.DoorsCompanion _doorCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
    Map<String, String> idMap,
  ) {
    final oldWallId = d['wallSegmentId'] as String;
    return $db.DoorsCompanion.insert(
      id: fresh(d['id'] as String),
      wallSegmentId:
          idMap[oldWallId] ?? oldWallId,
      positionOnWallMm:
          _double(d, 'positionOnWallMm'),
      widthMm: Value(d['widthMm'] as int? ?? 900),
      heightMm: Value(d['heightMm'] as int? ?? 2100),
      sillHeightMm:
          Value(d['sillHeightMm'] as int? ?? 0),
      uValue: Value(_double(d, 'uValue')),
    );
  }

  $db.DistributorsCompanion _distributorCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
    Map<String, String> idMap,
  ) {
    final oldFloorId = d['floorId'] as String;
    return $db.DistributorsCompanion.insert(
      id: fresh(d['id'] as String),
      floorId: idMap[oldFloorId] ?? oldFloorId,
      positionJson: jsonEncode(d['position']),
      supplyTempC:
          Value(_double(d, 'supplyTempC')),
      returnTempC:
          Value(_double(d, 'returnTempC')),
    );
  }

  $db.HeatingZonesCompanion _zoneCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
    Map<String, String> idMap,
  ) {
    final oldRoomId = d['roomId'] as String;
    final oldCircuitId = d['circuitId'] as String?;
    final oldWallSegId =
        d['wallSegmentId'] as String?;
    // Tube type and flooring material IDs are shared lookups — not remapped.
    final tubeTypeId = d['tubeTypeId'] as String;
    final flooringMatId =
        d['flooringMaterialId'] as String;
    return $db.HeatingZonesCompanion.insert(
      id: fresh(d['id'] as String),
      roomId: idMap[oldRoomId] ?? oldRoomId,
      tubeTypeId: tubeTypeId,
      flooringMaterialId: flooringMatId,
      zoneType: Value(
        d['zoneType'] as String? ?? 'floorHeating',
      ),
      polygonJson: Value(jsonEncode(d['polygon'])),
      tubeSpacingMm:
          Value(d['tubeSpacingMm'] as int? ?? 150),
      borderDistanceMm: Value(
        d['borderDistanceMm'] as int? ?? 100,
      ),
      layoutPattern: Value(
        d['layoutPattern'] as String? ?? 'meander',
      ),
      // circuitId has no FK constraint — safe to set before circuit exists.
      circuitId: Value(
        oldCircuitId != null
            ? (idMap[oldCircuitId] ?? oldCircuitId)
            : null,
      ),
      wallSegmentId: Value(
        oldWallSegId != null
            ? (idMap[oldWallSegId] ?? oldWallSegId)
            : null,
      ),
      heightMm: Value(d['heightMm'] as int?),
      positionOnWallMm: Value(
        (d['positionOnWallMm'] as num?)?.toDouble(),
      ),
      widthMm: Value(d['widthMm'] as int?),
      customFlooringResistance: Value(
        (d['customFlooringResistance'] as num?)
            ?.toDouble(),
      ),
    );
  }

  $db.HeatingCircuitsCompanion _circuitCompanion(
    Map<String, dynamic> d,
    String Function(String) fresh,
    Map<String, String> idMap,
  ) {
    final oldDistId = d['distributorId'] as String;
    final oldZoneId = d['heatingZoneId'] as String;
    return $db.HeatingCircuitsCompanion.insert(
      id: fresh(d['id'] as String),
      distributorId:
          idMap[oldDistId] ?? oldDistId,
      heatingZoneId:
          idMap[oldZoneId] ?? oldZoneId,
      supplyRoutePathJson:
          Value(jsonEncode(d['supplyRoutePath'])),
      returnRoutePathJson:
          Value(jsonEncode(d['returnRoutePath'])),
      tubeLengthM: Value(_double(d, 'tubeLengthM')),
      flowRateKgH: Value(_double(d, 'flowRateKgH')),
      pressureLossPa:
          Value(_double(d, 'pressureLossPa')),
      valveSetting:
          Value(_double(d, 'valveSetting')),
    );
  }

  // ── Utilities ────────────────────────────────────────────────────────────────

  /// Casts [snapshot[key]] to a `List<Map<String, dynamic>>`.
  static List<Map<String, dynamic>> _list(
    Map<String, dynamic> snap,
    String key,
  ) =>
      (snap[key] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

  /// Reads [key] from [d] as a `double` (handles both `int` and `double` JSON
  /// values, which differ by whether the literal contains a decimal point).
  static double _double(Map<String, dynamic> d, String key) =>
      (d[key] as num).toDouble();
}
