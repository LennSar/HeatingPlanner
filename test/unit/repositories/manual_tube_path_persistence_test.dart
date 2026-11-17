// ADR-046: a zone's manual tube path is written to the database and read
// back; a zone laid out automatically keeps `null`; a v24 database gains
// the column.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/repositories/heating_repository.dart';

const _zone = HeatingZone(
  id: 'zone-1',
  roomId: 'room-1',
  polygon: [
    Point2D(x: 0, y: 0),
    Point2D(x: 4000, y: 0),
    Point2D(x: 4000, y: 3000),
  ],
  tubeTypeId: '10000000-0000-4000-8000-000000000001',
  flooringMaterialId: '20000000-0000-4000-8000-000000000001',
);

void main() {
  late $db.AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = $db.AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [heatingDaoProvider.overrideWithValue(db.heatingDao)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('the manual tube path is written and read back', () async {
    const manual = [
      Point2D(x: 0, y: 200),
      Point2D(x: 3800, y: 200),
      Point2D(x: 3800, y: 350),
      Point2D(x: 0, y: 350),
    ];
    final repo = container.read(heatingRepositoryProvider);
    await repo.upsertHeatingZone(_zone.copyWith(manualTubePath: manual));
    await repo.upsertHeatingZone(_zone.copyWith(id: 'zone-2'));

    final zones = await repo.getZonesForRooms(['room-1']);
    final byId = {for (final z in zones) z.id: z};
    expect(byId['zone-1']!.manualTubePath, manual);
    expect(byId['zone-2']!.manualTubePath, isNull);
  });

  test('a v24 database gains the manual_tube_path_json column', () async {
    final old = $db.AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(
              'CREATE TABLE heating_zones (id TEXT NOT NULL PRIMARY KEY)',
            )
            ..execute("INSERT INTO heating_zones (id) VALUES ('z')")
            ..execute('PRAGMA user_version = 24');
        },
      ),
    );
    addTearDown(old.close);
    final row = await old
        .customSelect('SELECT manual_tube_path_json AS m FROM heating_zones')
        .getSingle();
    expect(row.read<String?>('m'), isNull);
  });

  test('a zone survives JSON with and without a manual path', () {
    const manual = [Point2D(x: 1, y: 2), Point2D(x: 3, y: 4)];
    final withPath = _zone.copyWith(manualTubePath: manual);
    // Through a real encode, as in an .hsp file.
    HeatingZone roundTrip(HeatingZone z) => HeatingZone.fromJson(
      jsonDecode(jsonEncode(z.toJson())) as Map<String, dynamic>,
    );
    expect(roundTrip(withPath), withPath);
    expect(roundTrip(_zone).manualTubePath, isNull);
  });
}
