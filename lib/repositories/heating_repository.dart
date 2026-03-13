import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart' as $db;
import '../data/database/daos/heating_dao.dart';
import '../data/models/distributor.dart';
import '../data/models/enums.dart';
import '../data/models/flooring_material.dart';
import '../data/models/heating_circuit.dart';
import '../data/models/heating_zone.dart';
import '../data/models/point2d.dart';
import '../data/models/tube_type.dart';

// ── DAO provider ──────────────────────────────────────────────────────────────

/// Provides the [HeatingDao] from the singleton [AppDatabase].
final _heatingDaoProvider = Provider<HeatingDao>((ref) {
  return ref.watch($db.appDatabaseProvider).heatingDao;
});

// ── Stream providers ──────────────────────────────────────────────────────────

/// Reactive stream of all [HeatingZone]s belonging to [roomId].
final heatingZonesProvider =
    StreamProvider.family<List<HeatingZone>, String>(
  (ref, roomId) {
    return ref
        .watch(_heatingDaoProvider)
        .watchZones(roomId)
        .map((rows) => rows.map(_zoneFromRow).toList());
  },
);

/// Reactive stream of the [Distributor] placed on [floorId], or
/// `null` if none has been placed yet.
final distributorProvider =
    StreamProvider.family<Distributor?, String>(
  (ref, floorId) {
    return ref
        .watch(_heatingDaoProvider)
        .watchDistributor(floorId)
        .map(
          (row) => row == null ? null : _distributorFromRow(row),
        );
  },
);

/// Reactive stream of all [HeatingCircuit]s attached to
/// [distributorId].
final circuitsProvider =
    StreamProvider.family<List<HeatingCircuit>, String>(
  (ref, distributorId) {
    return ref
        .watch(_heatingDaoProvider)
        .watchCircuits(distributorId)
        .map((rows) => rows.map(_circuitFromRow).toList());
  },
);

/// Reactive stream of all [TubeType]s, ordered by name.
final tubeTypesProvider = StreamProvider<List<TubeType>>((ref) {
  return ref
      .watch(_heatingDaoProvider)
      .watchTubeTypes()
      .map((rows) => rows.map(_tubeTypeFromRow).toList());
});

/// Reactive stream of all [FlooringMaterial]s, ordered by name.
final flooringMaterialsProvider =
    StreamProvider<List<FlooringMaterial>>((ref) {
  return ref
      .watch(_heatingDaoProvider)
      .watchFlooringMaterials()
      .map((rows) => rows.map(_flooringMaterialFromRow).toList());
});

// ── HeatingZone CRUD ──────────────────────────────────────────────────────────

/// Inserts or replaces [zone] in the database.
Future<void> upsertHeatingZone(
  HeatingDao dao,
  HeatingZone zone,
) =>
    dao.upsertZone(_zoneToCompanion(zone));

/// Deletes the [HeatingZone] with the given [id].
Future<void> deleteHeatingZone(HeatingDao dao, String id) =>
    dao.deleteZone(id);

// ── TubeType CRUD ─────────────────────────────────────────────────────────────

/// Inserts or replaces [tube] in the database.
Future<void> upsertTubeType(
  HeatingDao dao,
  TubeType tube,
) =>
    dao.upsertTubeType(_tubeTypeToCompanion(tube));

/// Deletes the [TubeType] with the given [id].
Future<void> deleteTubeType(HeatingDao dao, String id) =>
    dao.deleteTubeType(id);

// ── FlooringMaterial CRUD ─────────────────────────────────────────────────────

/// Inserts or replaces [material] in the database.
Future<void> upsertFlooringMaterial(
  HeatingDao dao,
  FlooringMaterial material,
) =>
    dao.upsertFlooringMaterial(_flooringMaterialToCompanion(material));

/// Deletes the [FlooringMaterial] with the given [id].
Future<void> deleteFlooringMaterial(HeatingDao dao, String id) =>
    dao.deleteFlooringMaterial(id);

// ── Distributor CRUD ──────────────────────────────────────────────────────────

/// Inserts or replaces [distributor] in the database.
Future<void> upsertDistributor(
  HeatingDao dao,
  Distributor distributor,
) =>
    dao.upsertDistributor(_distributorToCompanion(distributor));

/// Deletes the [Distributor] with the given [id].
Future<void> deleteDistributor(HeatingDao dao, String id) =>
    dao.deleteDistributor(id);

// ── HeatingCircuit CRUD ───────────────────────────────────────────────────────

/// Inserts or replaces [circuit] in the database.
Future<void> upsertHeatingCircuit(
  HeatingDao dao,
  HeatingCircuit circuit,
) =>
    dao.upsertCircuit(_circuitToCompanion(circuit));

/// Deletes the [HeatingCircuit] with the given [id].
Future<void> deleteHeatingCircuit(HeatingDao dao, String id) =>
    dao.deleteCircuit(id);

// ── Row → Model mapping ───────────────────────────────────────────────────────

HeatingZone _zoneFromRow($db.HeatingZone row) {
  return HeatingZone(
    id: row.id,
    roomId: row.roomId,
    zoneType: ZoneType.values.byName(row.zoneType),
    polygon: _decodePointList(row.polygonJson),
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
  );
}

TubeType _tubeTypeFromRow($db.TubeType row) {
  return TubeType(
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
  );
}

FlooringMaterial _flooringMaterialFromRow(
  $db.FlooringMaterial row,
) {
  return FlooringMaterial(
    id: row.id,
    name: row.name,
    thermalResistance: row.thermalResistance,
  );
}

Distributor _distributorFromRow($db.Distributor row) {
  return Distributor(
    id: row.id,
    floorId: row.floorId,
    position: _decodePoint(row.positionJson),
    supplyTempC: row.supplyTempC,
    returnTempC: row.returnTempC,
    pumpHeadPa: row.pumpHeadPa,
  );
}

HeatingCircuit _circuitFromRow($db.HeatingCircuit row) {
  return HeatingCircuit(
    id: row.id,
    distributorId: row.distributorId,
    heatingZoneId: row.heatingZoneId,
    supplyRoutePath: _decodePointList(row.supplyRoutePathJson),
    returnRoutePath: _decodePointList(row.returnRoutePathJson),
    tubeLengthM: row.tubeLengthM,
    flowRateKgH: row.flowRateKgH,
    pressureLossPa: row.pressureLossPa,
    valveSetting: row.valveSetting,
  );
}

// ── Model → Companion mapping ─────────────────────────────────────────────────

$db.HeatingZonesCompanion _zoneToCompanion(HeatingZone zone) {
  return $db.HeatingZonesCompanion(
    id: Value(zone.id),
    roomId: Value(zone.roomId),
    zoneType: Value(zone.zoneType.name),
    polygonJson: Value(_encodePointList(zone.polygon)),
    tubeSpacingMm: Value(zone.tubeSpacingMm),
    tubeTypeId: Value(zone.tubeTypeId),
    flooringMaterialId: Value(zone.flooringMaterialId),
    borderDistanceMm: Value(zone.borderDistanceMm),
    layoutPattern: Value(zone.layoutPattern.name),
    circuitId: Value(zone.circuitId),
    wallSegmentId: Value(zone.wallSegmentId),
    heightMm: Value(zone.heightMm),
    positionOnWallMm: Value(zone.positionOnWallMm),
    widthMm: Value(zone.widthMm),
  );
}

$db.TubeTypesCompanion _tubeTypeToCompanion(TubeType tube) {
  return $db.TubeTypesCompanion(
    id: Value(tube.id),
    name: Value(tube.name),
    material: Value(tube.material.name),
    outerDiameterMm: Value(tube.outerDiameterMm),
    innerDiameterMm: Value(tube.innerDiameterMm),
    wallThicknessMm: Value(tube.wallThicknessMm),
    thermalConductivity: Value(tube.thermalConductivity),
    roughness: Value(tube.roughness),
    maxOperatingTempC: Value(tube.maxOperatingTempC),
    maxOperatingPressure: Value(tube.maxOperatingPressure),
  );
}

$db.FlooringMaterialsCompanion _flooringMaterialToCompanion(
  FlooringMaterial material,
) {
  return $db.FlooringMaterialsCompanion(
    id: Value(material.id),
    name: Value(material.name),
    thermalResistance: Value(material.thermalResistance),
  );
}

$db.DistributorsCompanion _distributorToCompanion(
  Distributor distributor,
) {
  return $db.DistributorsCompanion(
    id: Value(distributor.id),
    floorId: Value(distributor.floorId),
    positionJson: Value(_encodePoint(distributor.position)),
    supplyTempC: Value(distributor.supplyTempC),
    returnTempC: Value(distributor.returnTempC),
    pumpHeadPa: Value(distributor.pumpHeadPa),
  );
}

$db.HeatingCircuitsCompanion _circuitToCompanion(
  HeatingCircuit circuit,
) {
  return $db.HeatingCircuitsCompanion(
    id: Value(circuit.id),
    distributorId: Value(circuit.distributorId),
    heatingZoneId: Value(circuit.heatingZoneId),
    supplyRoutePathJson: Value(
      _encodePointList(circuit.supplyRoutePath),
    ),
    returnRoutePathJson: Value(
      _encodePointList(circuit.returnRoutePath),
    ),
    tubeLengthM: Value(circuit.tubeLengthM),
    flowRateKgH: Value(circuit.flowRateKgH),
    pressureLossPa: Value(circuit.pressureLossPa),
    valveSetting: Value(circuit.valveSetting),
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
