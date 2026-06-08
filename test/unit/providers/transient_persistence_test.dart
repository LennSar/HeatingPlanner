// Debounced-persistence contract for the editor-state mutators.
//
// During a transient interaction (a drag in flight, a slider mid-tick)
// the in-memory `state` must update every frame but **no** SQLite write
// may be issued. The single persisting call at the interaction boundary
// (onDragEnd / onChangeEnd) is the only DAO upsert.
//
//   (a) No DB upsert is issued across a multi-frame transient sequence.
//   (b) Exactly one upsert per element when the interaction commits.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heating_planner/data/database/daos/building_dao.dart';
import 'package:heating_planner/data/database/daos/heating_dao.dart';
import 'package:heating_planner/data/models/distributor.dart';
import 'package:heating_planner/data/models/door.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/data/models/window_element.dart';
import 'package:heating_planner/repositories/building_repository.dart';
import 'package:heating_planner/repositories/heating_repository.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

/// Records how many times each DAO method is invoked, without a real
/// database. `noSuchMethod` forwards every call to the counter and
/// returns a completed future so the `unawaited(upsert…)` calls in the
/// notifier resolve cleanly.
class _CountingBuildingDao implements BuildingDao {
  final Map<Symbol, int> calls = {};
  int countOf(Symbol member) => calls[member] ?? 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.update(invocation.memberName, (v) => v + 1, ifAbsent: () => 1);
    return Future<void>.value();
  }
}

class _CountingHeatingDao implements HeatingDao {
  final Map<Symbol, int> calls = {};
  int countOf(Symbol member) => calls[member] ?? 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.update(invocation.memberName, (v) => v + 1, ifAbsent: () => 1);
    return Future<void>.value();
  }
}

void main() {
  late _CountingBuildingDao bDao;
  late _CountingHeatingDao hDao;
  late ProviderContainer container;
  late EditorStateNotifier notifier;

  setUp(() {
    bDao = _CountingBuildingDao();
    hDao = _CountingHeatingDao();
    container = ProviderContainer(
      overrides: [
        buildingDaoProvider.overrideWithValue(bDao),
        heatingDaoProvider.overrideWithValue(hDao),
      ],
    );
    addTearDown(container.dispose);
    notifier = container.read(editorStateProvider.notifier);
  });

  const wall = WallSegment(
    id: 'w1',
    roomId: 'room-1',
    startPoint: Point2D(x: 0, y: 0),
    endPoint: Point2D(x: 1000, y: 0),
  );
  const room = Room(
    id: 'room-1',
    floorId: 'floor-1',
    name: 'Room 1',
    polygon: [
      Point2D(x: 0, y: 0),
      Point2D(x: 1000, y: 0),
      Point2D(x: 1000, y: 1000),
    ],
  );
  const window = WindowElement(
    id: 'win-1',
    wallSegmentId: 'w1',
    positionOnWallMm: 100,
  );
  const door = Door(
    id: 'door-1',
    wallSegmentId: 'w1',
    positionOnWallMm: 100,
  );
  const zone = HeatingZone(
    id: 'zone-1',
    roomId: 'room-1',
    polygon: [
      Point2D(x: 0, y: 0),
      Point2D(x: 1000, y: 0),
      Point2D(x: 1000, y: 1000),
      Point2D(x: 0, y: 1000),
    ],
    tubeSpacingMm: 150,
    tubeTypeId: 'tube-1',
    flooringMaterialId: 'mat-1',
  );
  const distributor = Distributor(
    id: 'dist-1',
    floorId: 'floor-1',
    position: Point2D(x: 500, y: 500),
  );

  test('wall: 6 transient frames write nothing; commit writes exactly once',
      () {
    notifier.replaceAllWalls([wall]);
    for (var i = 1; i <= 6; i++) {
      notifier.updateWallTransient(
        wall.copyWith(endPoint: Point2D(x: 1000, y: i * 10.0)),
      );
    }
    expect(bDao.countOf(#upsertWallSegment), 0,
        reason: 'no upsert during a multi-frame drag');

    notifier.updateWall(wall.copyWith(endPoint: const Point2D(x: 1000, y: 60)));
    expect(bDao.countOf(#upsertWallSegment), 1,
        reason: 'exactly one upsert on commit');
  });

  test('room: transient frames write nothing; commit writes exactly once', () {
    for (var i = 1; i <= 5; i++) {
      notifier.updateRoomTransient(room.copyWith(targetTempC: 20.0 + i));
    }
    expect(bDao.countOf(#upsertRoom), 0);

    notifier.updateRoom(room.copyWith(targetTempC: 25));
    expect(bDao.countOf(#upsertRoom), 1);
  });

  test('window: transient frames write nothing; commit writes exactly once',
      () {
    for (var i = 1; i <= 5; i++) {
      notifier
          .updateWindowTransient(window.copyWith(positionOnWallMm: 100.0 + i));
    }
    expect(bDao.countOf(#upsertWindow), 0);

    notifier.updateWindow(window.copyWith(positionOnWallMm: 150));
    expect(bDao.countOf(#upsertWindow), 1);
  });

  test('door: transient frames write nothing; commit writes exactly once', () {
    for (var i = 1; i <= 5; i++) {
      notifier.updateDoorTransient(door.copyWith(positionOnWallMm: 100.0 + i));
    }
    expect(bDao.countOf(#upsertDoor), 0);

    notifier.updateDoor(door.copyWith(positionOnWallMm: 150));
    expect(bDao.countOf(#upsertDoor), 1);
  });

  test('zone: transient frames write nothing; commit writes exactly once', () {
    for (var i = 1; i <= 5; i++) {
      notifier.updateZoneTransient(zone.copyWith(tubeSpacingMm: 150 + i));
    }
    expect(hDao.countOf(#upsertZone), 0);

    notifier.updateZone(zone.copyWith(tubeSpacingMm: 200));
    expect(hDao.countOf(#upsertZone), 1);
  });

  test(
      'distributor: transient frames write nothing; commit writes exactly once',
      () {
    for (var i = 1; i <= 5; i++) {
      notifier.updateDistributorTransient(
        distributor.copyWith(supplyTempC: 35.0 + i),
      );
    }
    expect(hDao.countOf(#upsertDistributor), 0);

    notifier.updateDistributor(distributor.copyWith(supplyTempC: 40));
    expect(hDao.countOf(#upsertDistributor), 1);
  });

  test('setWallZoneHeightsForIds persists only when persist is true', () {
    notifier.replaceAllWallsRoomsZones(const [], const [], [zone]);
    for (var i = 1; i <= 5; i++) {
      notifier.setWallZoneHeightsForIds({'zone-1'}, 2500 + i, persist: false);
    }
    expect(hDao.countOf(#upsertZone), 0);

    notifier.setWallZoneHeightsForIds({'zone-1'}, 2600, persist: true);
    expect(hDao.countOf(#upsertZone), 1);
  });
}
