// Tests for ADR-011 Rule 4: shared-wall mirror synchronization in
// EditorStateNotifier.updateWall.
//
// Layout used in both scenarios (coordinates in mm):
//
//   B(5000, 0)
//   │  wall-orig  (room-1):  B → E  (mirrorId = wall-mirror)
//   E(5000, 4000)
//   │  wall-mirror (room-2): E → B  (mirrorId = wall-orig)
//
// Two scenarios:
//   Scenario 1 — constructionId change:  update wall-orig's constructionId
//                and verify the partner receives the same ID while its geometry
//                stays reversed.
//
//   Scenario 2 — geometry change:  update wall-orig's startPoint/endPoint
//                and verify the partner receives the reversed geometry while its
//                constructionId stays unchanged.
//
// Both scenarios check atomicity: both walls remain in state after a single
// updateWall call (ADR-011 Rule 4 "single state.copyWith").
//
// The ProviderContainer overrides appDatabaseProvider with an in-memory
// Drift database so that the unawaited DAO calls inside updateWall stay
// fully in-process and do not require platform services (path_provider).

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the Drift-generated WallSegment data class to avoid collision with the
// freezed model of the same name.
import 'package:heating_planner/data/database/app_database.dart'
    hide WallSegment;
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

// ── Shared geometry ────────────────────────────────────────────────────────

const _ptB = Point2D(x: 5000, y: 0);
const _ptE = Point2D(x: 5000, y: 4000);

// Interior wall on room-1 side: B → E.
const _wallOrig = WallSegment(
  id: 'wall-orig',
  roomId: 'room-1',
  startPoint: _ptB,
  endPoint: _ptE,
  wallType: WallType.interior,
  constructionId: 'constr-old',
  adjacentRoomId: 'room-2',
  mirrorId: 'wall-mirror',
);

// Interior mirror on room-2 side: E → B (reversed geometry).
const _wallMirror = WallSegment(
  id: 'wall-mirror',
  roomId: 'room-2',
  startPoint: _ptE,
  endPoint: _ptB,
  wallType: WallType.interior,
  constructionId: 'constr-old',
  adjacentRoomId: 'room-1',
  mirrorId: 'wall-orig',
);

// ── Test helpers ───────────────────────────────────────────────────────────

/// Provider override that injects an in-memory Drift database.
///
/// [ref.onDispose] closes the database when [ProviderContainer.dispose] is
/// called, matching the lifecycle of [appDatabaseProvider].
final _overrideWith = appDatabaseProvider.overrideWith((ref) {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  ref.onDispose(db.close);
  return db;
});

/// Builds a [ProviderContainer] with an in-memory database and seeds the
/// two linked interior walls via [EditorStateNotifier.replaceAllWalls].
///
/// [replaceAllWalls] writes only to in-memory state and fires no DAO calls,
/// so no database rows need to exist for the setup step.
(ProviderContainer, EditorStateNotifier) _makeContainer() {
  final container = ProviderContainer(overrides: [_overrideWith]);
  final notifier = container.read(editorStateProvider.notifier);
  notifier.replaceAllWalls([_wallOrig, _wallMirror]);
  return (container, notifier);
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    // Suppress the "multiple database instances" warning that arises because
    // each ProviderContainer creates a fresh AppDatabase per test.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // ── Scenario 1: constructionId change ─────────────────────────────────────

  group(
      'ADR-011 Rule 4 — Scenario 1: '
      'constructionId change propagates to mirror partner', () {
    test(
        'MS-1: updated wall receives the new constructionId', () async {
      final (container, notifier) = _makeContainer();
      addTearDown(container.dispose);

      notifier.updateWall(
        _wallOrig.copyWith(constructionId: 'constr-new'),
      );

      final walls = container.read(editorStateProvider).walls;
      final orig = walls.firstWhere((w) => w.id == 'wall-orig');
      expect(orig.constructionId, equals('constr-new'));
    });

    test(
        'MS-2: partner wall receives the same new constructionId', () async {
      final (container, notifier) = _makeContainer();
      addTearDown(container.dispose);

      notifier.updateWall(
        _wallOrig.copyWith(constructionId: 'constr-new'),
      );

      final walls = container.read(editorStateProvider).walls;
      final mirror = walls.firstWhere((w) => w.id == 'wall-mirror');
      expect(mirror.constructionId, equals('constr-new'));
    });

    test(
        'MS-3: partner endpoints remain the reverse of the updated wall '
        'when only constructionId changes', () async {
      final (container, notifier) = _makeContainer();
      addTearDown(container.dispose);

      notifier.updateWall(
        _wallOrig.copyWith(constructionId: 'constr-new'),
      );

      final walls = container.read(editorStateProvider).walls;
      final orig = walls.firstWhere((w) => w.id == 'wall-orig');
      final mirror = walls.firstWhere((w) => w.id == 'wall-mirror');

      expect(
        mirror.startPoint,
        equals(orig.endPoint),
        reason: 'mirror.startPoint must equal orig.endPoint (reversed)',
      );
      expect(
        mirror.endPoint,
        equals(orig.startPoint),
        reason: 'mirror.endPoint must equal orig.startPoint (reversed)',
      );
    });

    test(
        'MS-4: both walls remain in state after the update '
        '(single atomic copyWith)', () async {
      final (container, notifier) = _makeContainer();
      addTearDown(container.dispose);

      notifier.updateWall(
        _wallOrig.copyWith(constructionId: 'constr-new'),
      );

      final walls = container.read(editorStateProvider).walls;
      expect(walls.where((w) => w.id == 'wall-orig'), hasLength(1));
      expect(walls.where((w) => w.id == 'wall-mirror'), hasLength(1));
    });
  });

  // ── Scenario 2: geometry change ────────────────────────────────────────────

  group(
      'ADR-011 Rule 4 — Scenario 2: '
      'geometry change propagates reversed to mirror partner', () {
    // New geometry for wall-orig (shrink both endpoints inward by 500 mm).
    const newStart = Point2D(x: 5000, y: 500);
    const newEnd = Point2D(x: 5000, y: 3500);

    test(
        'MS-5: updated wall receives the new startPoint and endPoint', () async {
      final (container, notifier) = _makeContainer();
      addTearDown(container.dispose);

      notifier.updateWall(
        _wallOrig.copyWith(startPoint: newStart, endPoint: newEnd),
      );

      final walls = container.read(editorStateProvider).walls;
      final orig = walls.firstWhere((w) => w.id == 'wall-orig');
      expect(orig.startPoint, equals(newStart));
      expect(orig.endPoint, equals(newEnd));
    });

    test(
        'MS-6: partner startPoint equals updated wall endPoint (reversed)',
        () async {
      final (container, notifier) = _makeContainer();
      addTearDown(container.dispose);

      notifier.updateWall(
        _wallOrig.copyWith(startPoint: newStart, endPoint: newEnd),
      );

      final walls = container.read(editorStateProvider).walls;
      final mirror = walls.firstWhere((w) => w.id == 'wall-mirror');
      expect(
        mirror.startPoint,
        equals(newEnd),
        reason: 'mirror.startPoint must equal updated wall endPoint '
            '(reversed geometry)',
      );
    });

    test(
        'MS-7: partner endPoint equals updated wall startPoint (reversed)',
        () async {
      final (container, notifier) = _makeContainer();
      addTearDown(container.dispose);

      notifier.updateWall(
        _wallOrig.copyWith(startPoint: newStart, endPoint: newEnd),
      );

      final walls = container.read(editorStateProvider).walls;
      final mirror = walls.firstWhere((w) => w.id == 'wall-mirror');
      expect(
        mirror.endPoint,
        equals(newStart),
        reason: 'mirror.endPoint must equal updated wall startPoint '
            '(reversed geometry)',
      );
    });

    test(
        'MS-8: partner constructionId is unchanged after geometry-only update',
        () async {
      final (container, notifier) = _makeContainer();
      addTearDown(container.dispose);

      notifier.updateWall(
        _wallOrig.copyWith(startPoint: newStart, endPoint: newEnd),
      );

      final walls = container.read(editorStateProvider).walls;
      final mirror = walls.firstWhere((w) => w.id == 'wall-mirror');
      expect(
        mirror.constructionId,
        equals('constr-old'),
        reason: 'geometry-only update must not change partner constructionId',
      );
    });

    test(
        'MS-9: partner mirrorId remains cross-referenced after geometry update',
        () async {
      final (container, notifier) = _makeContainer();
      addTearDown(container.dispose);

      notifier.updateWall(
        _wallOrig.copyWith(startPoint: newStart, endPoint: newEnd),
      );

      final walls = container.read(editorStateProvider).walls;
      final mirror = walls.firstWhere((w) => w.id == 'wall-mirror');
      expect(
        mirror.mirrorId,
        equals('wall-orig'),
        reason: 'mirrorId is not a sync-ed field — it must remain unchanged',
      );
    });
  });
}
