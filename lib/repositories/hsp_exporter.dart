import 'dart:convert';

import '../core/utils/category_path_codec.dart';
import '../data/database/app_database.dart' as $db;
import '../data/models/distributor.dart';
import '../data/models/door.dart';
import '../data/models/enums.dart';
import '../data/models/floor.dart';
import '../data/models/flooring_material.dart';
import '../data/models/heating_circuit.dart';
import '../data/models/heating_zone.dart';
import '../data/models/material_entry.dart';
import '../data/models/material_layer.dart';
import '../data/models/point2d.dart';
import '../data/models/project.dart';
import '../data/models/room.dart';
import '../data/models/tube_type.dart';
import '../data/models/wall_construction.dart';
import '../data/models/wall_segment.dart';
import '../data/models/window_element.dart';

/// Assembles a complete project snapshot as a JSON-serialisable map.
///
/// The snapshot matches the §7.5 `.hsp` file format. Each entity is converted
/// to its domain-model `toJson()` representation so that importers can
/// reconstruct the full object graph using the corresponding `fromJson()`
/// constructors.
class HspExporter {
  /// Creates an [HspExporter] bound to [db].
  HspExporter(this._db);

  final $db.AppDatabase _db;

  /// Returns a JSON-serialisable map for the full project snapshot.
  ///
  /// Queries every entity belonging to [projectId] in a single pass, plus all
  /// shared lookup tables (wall constructions, material layers, custom
  /// materials, tube types, flooring materials).
  ///
  /// Throws a [StateError] if [projectId] is not found in the database.
  Future<Map<String, dynamic>> buildSnapshot(String projectId) async {
    // ── Project ────────────────────────────────────────────────────────────
    final projectRow = await (_db.select(_db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingleOrNull();
    if (projectRow == null) {
      throw StateError('Project $projectId not found in database');
    }

    // ── Floors ─────────────────────────────────────────────────────────────
    final floorRows = await (_db.select(_db.floors)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final floorIds = floorRows.map((r) => r.id).toList();

    // ── Rooms ──────────────────────────────────────────────────────────────
    final roomRows = floorIds.isEmpty
        ? <$db.Room>[]
        : await (_db.select(_db.rooms)
              ..where((t) => t.floorId.isIn(floorIds)))
            .get();
    final roomIds = roomRows.map((r) => r.id).toList();

    // ── Wall segments ──────────────────────────────────────────────────────
    final wallRows = roomIds.isEmpty
        ? <$db.WallSegment>[]
        : await (_db.select(_db.wallSegments)
              ..where((t) => t.roomId.isIn(roomIds)))
            .get();
    final wallIds = wallRows.map((r) => r.id).toList();

    // ── Windows ────────────────────────────────────────────────────────────
    final windowRows = wallIds.isEmpty
        ? <$db.Window>[]
        : await (_db.select(_db.windows)
              ..where((t) => t.wallSegmentId.isIn(wallIds)))
            .get();

    // ── Doors ──────────────────────────────────────────────────────────────
    final doorRows = wallIds.isEmpty
        ? <$db.Door>[]
        : await (_db.select(_db.doors)
              ..where((t) => t.wallSegmentId.isIn(wallIds)))
            .get();

    // ── Heating zones ──────────────────────────────────────────────────────
    final zoneRows = roomIds.isEmpty
        ? <$db.HeatingZone>[]
        : await (_db.select(_db.heatingZones)
              ..where((t) => t.roomId.isIn(roomIds)))
            .get();

    // ── Distributors ───────────────────────────────────────────────────────
    final distributorRows = floorIds.isEmpty
        ? <$db.Distributor>[]
        : await (_db.select(_db.distributors)
              ..where((t) => t.floorId.isIn(floorIds)))
            .get();
    final distributorIds = distributorRows.map((r) => r.id).toList();

    // ── Heating circuits ───────────────────────────────────────────────────
    final circuitRows = distributorIds.isEmpty
        ? <$db.HeatingCircuit>[]
        : await (_db.select(_db.heatingCircuits)
              ..where((t) => t.distributorId.isIn(distributorIds)))
            .get();

    // ── Shared lookup tables ───────────────────────────────────────────────
    final constructionRows = await _db.select(_db.wallConstructions).get();
    final layerRows = await _db.select(_db.materialLayers).get();
    final tubeRows = await _db.select(_db.tubeTypes).get();
    final flooringRows = await _db.select(_db.flooringMaterials).get();
    final customMaterialRows = await (_db.select(_db.materialEntries)
          ..where((t) => t.isBuiltIn.equals(false)))
        .get();

    // ── Assemble snapshot ──────────────────────────────────────────────────
    return {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'project': _projectJson(projectRow),
      'floors': floorRows.map(_floorJson).toList(),
      'rooms': roomRows.map(_roomJson).toList(),
      'wallSegments': wallRows.map(_wallSegmentJson).toList(),
      'windows': windowRows.map(_windowJson).toList(),
      'doors': doorRows.map(_doorJson).toList(),
      'wallConstructions': constructionRows.map(_constructionJson).toList(),
      'materialLayers': layerRows.map(_layerJson).toList(),
      'customMaterials': customMaterialRows.map(_materialEntryJson).toList(),
      'heatingZones': zoneRows.map(_zoneJson).toList(),
      'tubeTypes': tubeRows.map(_tubeTypeJson).toList(),
      'flooringMaterials': flooringRows.map(_flooringMaterialJson).toList(),
      'distributors': distributorRows.map(_distributorJson).toList(),
      'heatingCircuits': circuitRows.map(_circuitJson).toList(),
    };
  }

  // ── Row → domain model → toJson() ─────────────────────────────────────────

  Map<String, dynamic> _projectJson($db.Project row) {
    GeoLocation? location;
    if (row.locationJson != null) {
      location = GeoLocation.fromJson(
        jsonDecode(row.locationJson!) as Map<String, dynamic>,
      );
    }
    return Project(
      id: row.id,
      name: row.name,
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
      designOutdoorTempC: row.designOutdoorTempC,
      defaultIndoorTempC: row.defaultIndoorTempC,
      floorHeightMm: row.floorHeightMm,
      unheatedSpaceTempC: row.unheatedSpaceTempC,
      defaultExteriorWallThicknessMm: row.defaultExteriorWallThicknessMm,
      defaultInteriorWallThicknessMm: row.defaultInteriorWallThicknessMm,
      defaultPartitionWallThicknessMm: row.defaultPartitionWallThicknessMm,
      location: location,
    ).toJson();
  }

  Map<String, dynamic> _floorJson($db.Floor row) {
    final json = Floor(
      id: row.id,
      name: row.name,
      level: row.level,
      heightMm: row.heightMm,
    ).toJson();
    // projectId is not part of the Floor domain model (it is a DB-level FK).
    // Inject it explicitly so that the importer can reconstruct the FK link.
    return {...json, 'projectId': row.projectId};
  }

  Map<String, dynamic> _roomJson($db.Room row) => Room(
        id: row.id,
        floorId: row.floorId,
        name: row.name,
        targetTempC: row.targetTempC,
        airChangeRate: row.airChangeRate,
        polygon: _decodePoints(row.polygonJson),
        floorConstructionId: row.floorConstructionId,
        ceilingConstructionId: row.ceilingConstructionId,
        floorBoundary:
            BoundaryCondition.values.byName(row.floorBoundary),
        ceilingBoundary:
            BoundaryCondition.values.byName(row.ceilingBoundary),
        floorAdjacentTempC: row.floorAdjacentTempC,
        ceilingAdjacentTempC: row.ceilingAdjacentTempC,
      ).toJson();

  Map<String, dynamic> _wallSegmentJson($db.WallSegment row) => WallSegment(
        id: row.id,
        roomId: row.roomId,
        startPoint: _decodePoint(row.startPointJson),
        endPoint: _decodePoint(row.endPointJson),
        wallType: WallType.values.byName(row.wallType),
        thicknessMm: row.thicknessMm,
        anchorMode: WallAnchorMode.values[row.anchorMode],
        constructionId: row.constructionId,
        adjacentRoomId: row.adjacentRoomId,
        orientation: CardinalDirection.values.byName(row.orientation),
        mirrorId: row.mirrorId,
      ).toJson();

  Map<String, dynamic> _windowJson($db.Window row) => WindowElement(
        id: row.id,
        wallSegmentId: row.wallSegmentId,
        positionOnWallMm: row.positionOnWallMm,
        widthMm: row.widthMm,
        heightMm: row.heightMm,
        sillHeightMm: row.sillHeightMm,
        uValue: row.uValue,
      ).toJson();

  Map<String, dynamic> _doorJson($db.Door row) => Door(
        id: row.id,
        wallSegmentId: row.wallSegmentId,
        positionOnWallMm: row.positionOnWallMm,
        widthMm: row.widthMm,
        heightMm: row.heightMm,
        sillHeightMm: row.sillHeightMm,
        uValue: row.uValue,
      ).toJson();

  Map<String, dynamic> _constructionJson($db.WallConstruction row) =>
      WallConstruction(
        id: row.id,
        name: row.name,
        rsi: row.rsi,
        rse: row.rse,
        isPreset: row.isPreset == 1,
      ).toJson();

  Map<String, dynamic> _layerJson($db.MaterialLayer row) => MaterialLayer(
        id: row.id,
        constructionId: row.constructionId,
        sortOrder: row.sortOrder,
        materialId: row.materialId,
        thicknessMm: row.thicknessMm,
        thermalConductivity: row.thermalConductivity,
        density: row.density,
        specificHeat: row.specificHeat,
      ).toJson();

  Map<String, dynamic> _materialEntryJson($db.MaterialEntry row) =>
      MaterialEntry(
        id: row.id,
        name: row.name,
        categoryPath: decodeCategoryPath(row.categoryPath),
        lambdaDefault: row.lambdaDefault,
        densityDefault: row.densityDefault,
        specificHeatDefault: row.specificHeatDefault,
        isBuiltIn: row.isBuiltIn,
      ).toJson();

  Map<String, dynamic> _zoneJson($db.HeatingZone row) => HeatingZone(
        id: row.id,
        roomId: row.roomId,
        zoneType: ZoneType.values.byName(row.zoneType),
        polygon: _decodePoints(row.polygonJson),
        tubeSpacingMm: row.tubeSpacingMm,
        tubeTypeId: row.tubeTypeId,
        flooringMaterialId: row.flooringMaterialId,
        borderDistanceMm: row.borderDistanceMm,
        layoutPattern: LayoutPattern.values.byName(row.layoutPattern),
        circuitId: row.circuitId,
        wallSegmentId: row.wallSegmentId,
        heightMm: row.heightMm,
        positionOnWallMm: row.positionOnWallMm,
        widthMm: row.widthMm,
        customFlooringResistance: row.customFlooringResistance,
      ).toJson();

  Map<String, dynamic> _tubeTypeJson($db.TubeType row) => TubeType(
        id: row.id,
        name: row.name,
        material: TubeMaterial.values.byName(row.material),
        outerDiameterMm: row.outerDiameterMm,
        innerDiameterMm: row.innerDiameterMm,
        wallThicknessMm: row.wallThicknessMm,
        thermalConductivity: row.thermalConductivity,
        roughness: row.roughness,
        maxOperatingTempC: row.maxOperatingTempC,
        maxOperatingPressure: row.maxOperatingPressure,
      ).toJson();

  Map<String, dynamic> _flooringMaterialJson($db.FlooringMaterial row) =>
      FlooringMaterial(
        id: row.id,
        name: row.name,
        thermalResistance: row.thermalResistance,
        surfaceType: SurfaceType.values.byName(row.surfaceType),
      ).toJson();

  Map<String, dynamic> _distributorJson($db.Distributor row) => Distributor(
        id: row.id,
        floorId: row.floorId,
        position: _decodePoint(row.positionJson),
        supplyTempC: row.supplyTempC,
        returnTempC: row.returnTempC,
        pumpCapacityPa: row.pumpCapacityPa,
      ).toJson();

  Map<String, dynamic> _circuitJson($db.HeatingCircuit row) => HeatingCircuit(
        id: row.id,
        distributorId: row.distributorId,
        heatingZoneId: row.heatingZoneId,
        supplyRoutePath: _decodePoints(row.supplyRoutePathJson),
        returnRoutePath: _decodePoints(row.returnRoutePathJson),
        tubeLengthM: row.tubeLengthM,
        flowRateKgH: row.flowRateKgH,
        pressureLossPa: row.pressureLossPa,
        valveSetting: row.valveSetting,
      ).toJson();

  // ── JSON helpers ───────────────────────────────────────────────────────────

  static Point2D _decodePoint(String json) =>
      Point2D.fromJson(jsonDecode(json) as Map<String, dynamic>);

  static List<Point2D> _decodePoints(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => Point2D.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
