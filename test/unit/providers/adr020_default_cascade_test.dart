// ADR-020 — cascade tests for project default wall material and
// thickness.
//
//   ADR-020-1  Changing `defaultExteriorMaterialId` rewrites the
//              `materialId` (+ thermal params) on the single layer of
//              every auto-default exterior wall — and only those —
//              leaving auto-default walls of other types and
//              user-edited (non-auto-default) walls alone.
//
//   ADR-020-2  Changing `defaultExteriorWallThicknessMm` rewrites the
//              single layer thickness on every auto-default exterior
//              construction and re-anchors the owning walls per
//              ADR-017 Rule 6. Walls whose construction is *not*
//              `isAutoDefault` are untouched.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heating_planner/calculation/providers/project_settings_provider.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/material_layer.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_construction.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

WallConstruction _autoDefault(String id) => WallConstruction(
      id: id,
      name: 'Auto-default $id',
      isAutoDefault: true,
    );

MaterialLayer _layer(
  String id, {
  required String constructionId,
  required String materialId,
  required double thicknessMm,
  double lambda = 0.50,
}) =>
    MaterialLayer(
      id: id,
      constructionId: constructionId,
      sortOrder: 0,
      materialId: materialId,
      thicknessMm: thicknessMm,
      thermalConductivity: lambda,
      density: 1200,
      specificHeat: 900,
    );

WallSegment _wall({
  required String id,
  required WallType type,
  required String? constructionId,
  required double thicknessMm,
  required Point2D start,
  required Point2D end,
}) =>
    WallSegment(
      id: id,
      roomId: 'room-1',
      startPoint: start,
      endPoint: end,
      wallType: type,
      thicknessMm: thicknessMm,
      anchorMode: WallAnchorMode.innerFace,
      constructionId: constructionId,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ADR-020-1: changing defaultExteriorMaterialId updates only auto-default '
    'exterior walls',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);
      final settings = container.read(projectSettingsProvider.notifier);

      // Seed:
      //   ext-auto    : exterior, auto-default, layer mat-016 240 mm
      //   ext-custom  : exterior, NOT auto-default, layer mat-001 240 mm
      //   int-auto    : interior, auto-default, layer mat-016 120 mm
      final constructions = [
        _autoDefault('c-ext-auto'),
        const WallConstruction(id: 'c-ext-custom', name: 'Custom assembly'),
        _autoDefault('c-int-auto'),
      ];
      final layers = [
        _layer('l-ext-auto',
            constructionId: 'c-ext-auto',
            materialId: 'mat-016',
            thicknessMm: 240),
        _layer('l-ext-custom',
            constructionId: 'c-ext-custom',
            materialId: 'mat-001',
            thicknessMm: 240,
            lambda: 1.05),
        _layer('l-int-auto',
            constructionId: 'c-int-auto',
            materialId: 'mat-016',
            thicknessMm: 120),
      ];
      final walls = [
        _wall(
          id: 'w-ext-auto',
          type: WallType.exterior,
          constructionId: 'c-ext-auto',
          thicknessMm: 240,
          start: const Point2D(x: 0, y: 0),
          end: const Point2D(x: 5000, y: 0),
        ),
        _wall(
          id: 'w-ext-custom',
          type: WallType.exterior,
          constructionId: 'c-ext-custom',
          thicknessMm: 240,
          start: const Point2D(x: 5000, y: 0),
          end: const Point2D(x: 5000, y: 4000),
        ),
        _wall(
          id: 'w-int-auto',
          type: WallType.interior,
          constructionId: 'c-int-auto',
          thicknessMm: 120,
          start: const Point2D(x: 5000, y: 4000),
          end: const Point2D(x: 0, y: 4000),
        ),
      ];
      notifier.state = EditorState(
        walls: walls,
        constructions: constructions,
        materialLayers: layers,
      );

      settings.setDefaultExteriorMaterialId('mat-009');
      notifier.recomputeAutoDefaultMaterialsForWallType(WallType.exterior);

      final post = container.read(editorStateProvider);
      final byId = {for (final l in post.materialLayers) l.id: l};
      expect(
        byId['l-ext-auto']!.materialId,
        'mat-009',
        reason: 'Auto-default exterior layer must adopt the new material',
      );
      expect(
        byId['l-ext-custom']!.materialId,
        'mat-001',
        reason: 'Non-auto-default exterior layer must NOT be touched',
      );
      expect(
        byId['l-int-auto']!.materialId,
        'mat-016',
        reason: 'Auto-default interior layer must NOT be touched (different '
            'wallType)',
      );
    },
  );

  test(
    'ADR-020-2: changing defaultExteriorWallThicknessMm updates only '
    'auto-default exterior layers and re-anchors the walls',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);
      final settings = container.read(projectSettingsProvider.notifier);

      // Seed the same shape as ADR-020-1.
      final constructions = [
        _autoDefault('c-ext-auto'),
        const WallConstruction(id: 'c-ext-custom', name: 'Custom assembly'),
      ];
      final layers = [
        _layer('l-ext-auto',
            constructionId: 'c-ext-auto',
            materialId: 'mat-016',
            thicknessMm: 240),
        _layer('l-ext-custom',
            constructionId: 'c-ext-custom',
            materialId: 'mat-001',
            thicknessMm: 240),
      ];
      final walls = [
        _wall(
          id: 'w-ext-auto',
          type: WallType.exterior,
          constructionId: 'c-ext-auto',
          thicknessMm: 240,
          start: const Point2D(x: 0, y: 0),
          end: const Point2D(x: 5000, y: 0),
        ),
        _wall(
          id: 'w-ext-custom',
          type: WallType.exterior,
          constructionId: 'c-ext-custom',
          thicknessMm: 240,
          start: const Point2D(x: 5000, y: 0),
          end: const Point2D(x: 5000, y: 4000),
        ),
      ];
      const room = Room(
        id: 'room-1',
        floorId: 'floor-1',
        name: 'Room 1',
        targetTempC: 20.0,
        polygon: [
          Point2D(x: 0, y: 0),
          Point2D(x: 5000, y: 0),
          Point2D(x: 5000, y: 4000),
          Point2D(x: 0, y: 4000),
        ],
      );
      notifier.state = EditorState(
        walls: walls,
        rooms: const [room],
        constructions: constructions,
        materialLayers: layers,
      );

      settings.setDefaultExteriorWallThicknessMm(360);
      notifier.recomputeAutoDefaultThicknessForWallType(WallType.exterior);

      final post = container.read(editorStateProvider);
      final byLayerId = {for (final l in post.materialLayers) l.id: l};
      final byWallId = {for (final w in post.walls) w.id: w};
      expect(
        byLayerId['l-ext-auto']!.thicknessMm,
        360.0,
        reason: 'Auto-default exterior layer thickness must follow the new '
            'project default',
      );
      expect(
        byLayerId['l-ext-custom']!.thicknessMm,
        240.0,
        reason: 'Non-auto-default exterior layer thickness must NOT change',
      );
      expect(
        byWallId['w-ext-auto']!.thicknessMm,
        360.0,
        reason: 'Auto-default exterior wall thicknessMm must follow the new '
            'project default (ADR-017 Rule 6 re-anchor)',
      );
      expect(
        byWallId['w-ext-custom']!.thicknessMm,
        240.0,
        reason: 'Non-auto-default exterior wall must NOT be re-anchored',
      );
    },
  );
}
