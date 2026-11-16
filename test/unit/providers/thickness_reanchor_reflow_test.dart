// ADR-017 Rule 6 — thickness re-anchor must keep the room closed.
//
// Regression for the reported bug: changing one wall's thickness (e.g.
// adding insulation) shifted only that wall's centerline, splitting the
// shared corners from its neighbours so the room lost its dimension. The
// re-anchor must instead move the neighbouring walls' shared endpoints to the
// new mitred corners and rebuild the room polygon, keeping the loop closed
// and every wall connected. Neighbours keep their direction and only change
// length; the thickened wall's anchored (inner) face stays put.
//
// Layout — an axis-aligned 5000 × 4000 mm room, polygon wound clockwise in
// screen coordinates (y down). Every wall is exterior / innerFace, 240 mm.
//
//   A(0,0) ── ab ──▶ B(5000,0)
//     ▲                 │
//     da               bc
//     │                 ▼
//   D(0,4000) ◀─ cd ── C(5000,4000)
//
// Thickening the top wall `ab` to 440 mm (Δt = 200) shifts its centerline
// 100 mm outward (−y). Corners A and B follow to (0,−100) and (5000,−100);
// `da` and `bc` grow by 100 mm; `cd` is untouched.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/material_layer.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_construction.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

const _a = Point2D(x: 0, y: 0);
const _b = Point2D(x: 5000, y: 0);
const _c = Point2D(x: 5000, y: 4000);
const _d = Point2D(x: 0, y: 4000);

WallSegment _wall(
  String id, {
  required Point2D start,
  required Point2D end,
  String? constructionId,
}) => WallSegment(
  id: id,
  roomId: 'room-1',
  startPoint: start,
  endPoint: end,
  wallType: WallType.exterior,
  thicknessMm: 240,
  anchorMode: WallAnchorMode.innerFace,
  constructionId: constructionId,
);

MaterialLayer _layer(String id, String constructionId, double thicknessMm) =>
    MaterialLayer(
      id: id,
      constructionId: constructionId,
      sortOrder: 0,
      materialId: 'mat-001',
      thicknessMm: thicknessMm,
      thermalConductivity: 0.5,
      density: 1200,
      specificHeat: 900,
    );

void _expectPoint(Point2D actual, Point2D expected, {String? reason}) {
  expect(actual.x, closeTo(expected.x, 0.01), reason: reason);
  expect(actual.y, closeTo(expected.y, 0.01), reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'thickening one wall keeps corners connected and the room polygon closed',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorStateProvider.notifier);

      notifier.state = EditorState(
        walls: [
          _wall('ab', start: _a, end: _b),
          _wall('bc', start: _b, end: _c),
          _wall('cd', start: _c, end: _d),
          _wall('da', start: _d, end: _a),
        ],
        rooms: const [
          Room(
            id: 'room-1',
            floorId: 'floor-1',
            name: 'Room 1',
            targetTempC: 20.0,
            polygon: [_a, _b, _c, _d],
          ),
        ],
        constructions: const [
          WallConstruction(id: 'c-440', name: '440 mm assembly'),
        ],
        materialLayers: [_layer('l-440', 'c-440', 440)],
      );

      // Add insulation: assign the 440 mm construction to the top wall.
      notifier.assignConstruction('ab', 'c-440');

      final post = container.read(editorStateProvider);
      final byId = {for (final w in post.walls) w.id: w};
      final ab = byId['ab']!;
      final bc = byId['bc']!;
      final cd = byId['cd']!;
      final da = byId['da']!;

      const aNew = Point2D(x: 0, y: -100);
      const bNew = Point2D(x: 5000, y: -100);

      // Thickness updated from the construction layer.
      expect(ab.thicknessMm, 440);

      // The thickened wall shifted 100 mm outward, staying horizontal.
      _expectPoint(ab.startPoint, aNew, reason: 'ab.start re-anchored');
      _expectPoint(ab.endPoint, bNew, reason: 'ab.end re-anchored');

      // Neighbours followed the corner: shared ends moved, far ends fixed.
      _expectPoint(da.startPoint, _d, reason: 'da far end fixed');
      _expectPoint(da.endPoint, aNew, reason: 'da follows corner A');
      _expectPoint(bc.startPoint, bNew, reason: 'bc follows corner B');
      _expectPoint(bc.endPoint, _c, reason: 'bc far end fixed');

      // The opposite wall is untouched.
      _expectPoint(cd.startPoint, _c);
      _expectPoint(cd.endPoint, _d);

      // Corners still shared → the loop is closed, not split.
      _expectPoint(
        ab.startPoint,
        da.endPoint,
        reason: 'corner A shared by ab and da',
      );
      _expectPoint(
        ab.endPoint,
        bc.startPoint,
        reason: 'corner B shared by ab and bc',
      );

      // Room polygon rebuilt to the new corners.
      final poly = post.rooms.single.polygon;
      expect(poly.length, 4);
      _expectPoint(poly[0], aNew);
      _expectPoint(poly[1], bNew);
      _expectPoint(poly[2], _c);
      _expectPoint(poly[3], _d);
    },
  );
}
