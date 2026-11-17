// ADR-046: manual tube paths — the pure geometry behind editing the
// automatic layout and drawing the tube by hand.

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/calculation/engines/pipe_layout_engine.dart';
import 'package:heating_planner/data/models/point2d.dart';

const _square = [
  Point2D(x: 0, y: 0),
  Point2D(x: 4000, y: 0),
  Point2D(x: 4000, y: 3000),
  Point2D(x: 0, y: 3000),
];

// Two rows of a serpentine, 150 mm apart, entering at the left edge.
const _path = [
  Point2D(x: 0, y: 200),
  Point2D(x: 3800, y: 200),
  Point2D(x: 3800, y: 350),
  Point2D(x: 200, y: 350),
  Point2D(x: 0, y: 500),
];

void main() {
  group('attachManualPathEnds', () {
    test('moves only the two ends', () {
      final out = PipeLayoutEngine.attachManualPathEnds(
        _path,
        entry: const Point2D(x: 0, y: 100),
        exit: const Point2D(x: 0, y: 600),
      );
      expect(out.first, const Point2D(x: 0, y: 100));
      expect(out.last, const Point2D(x: 0, y: 600));
      expect(
        out.sublist(1, out.length - 1),
        _path.sublist(1, _path.length - 1),
      );
    });

    test('a missing end stays where it was drawn', () {
      final out = PipeLayoutEngine.attachManualPathEnds(_path);
      expect(out, _path);
    });
  });

  group('snapTubePoint', () {
    test('a segment is made horizontal or vertical', () {
      final p = PipeLayoutEngine.snapTubePoint(
        raw: const Point2D(x: 1000, y: 260),
        previous: const Point2D(x: 0, y: 200),
        corners: const [Point2D(x: 0, y: 200)],
        spacingMm: 150,
        gridMm: 100,
      );
      expect(p.y, 200);
      expect(p.x, 1000);
    });

    test('a step between rows ends a whole spacing from the row', () {
      // Row along y = 200, now stepping down from its end.
      final p = PipeLayoutEngine.snapTubePoint(
        raw: const Point2D(x: 3810, y: 370),
        previous: const Point2D(x: 3800, y: 200),
        corners: const [Point2D(x: 0, y: 200), Point2D(x: 3800, y: 200)],
        spacingMm: 150,
      );
      expect(p, const Point2D(x: 3800, y: 350));
    });

    test('a row end lines up with the end of the row before', () {
      final p = PipeLayoutEngine.snapTubePoint(
        raw: const Point2D(x: 3740, y: 500),
        previous: const Point2D(x: 200, y: 500),
        corners: _path,
        spacingMm: 150,
      );
      expect(p, const Point2D(x: 3800, y: 500));
    });

    test('the first point snaps to the grid', () {
      final p = PipeLayoutEngine.snapTubePoint(
        raw: const Point2D(x: 1040, y: 1960),
        previous: null,
        corners: const [],
        spacingMm: 150,
        gridMm: 100,
      );
      expect(p, const Point2D(x: 1000, y: 2000));
    });
  });

  group('editing', () {
    test('a corner moves, the ends do not', () {
      final moved = PipeLayoutEngine.moveTubeCorner(
        _path,
        1,
        const Point2D(x: 3500, y: 200),
      );
      expect(moved[1], const Point2D(x: 3500, y: 200));
      expect(
        PipeLayoutEngine.moveTubeCorner(_path, 0, const Point2D(x: 0, y: 0)),
        _path,
      );
      expect(
        PipeLayoutEngine.moveTubeCorner(
          _path,
          _path.length - 1,
          const Point2D(x: 0, y: 0),
        ),
        _path,
      );
    });

    test('a run moves as a whole and its neighbours stretch', () {
      final r = PipeLayoutEngine.moveTubeRun(_path, 1, -300, 0);
      // The turn at the far end moves 300 mm back; both rows shorten.
      expect(r.segment, 1);
      expect(r.path[1], const Point2D(x: 3500, y: 200));
      expect(r.path[2], const Point2D(x: 3500, y: 350));
      expect(r.path.length, _path.length);
    });

    test('moving the first run inserts a corner at the fixed end', () {
      final r = PipeLayoutEngine.moveTubeRun(_path, 0, 0, 100);
      expect(r.path.first, _path.first);
      expect(r.segment, 1);
      expect(r.path[1], const Point2D(x: 0, y: 300));
      expect(r.path[2], const Point2D(x: 3800, y: 300));
      expect(r.path.length, _path.length + 1);
    });

    test('a corner is inserted on the segment, nearest to the point', () {
      final out = PipeLayoutEngine.insertTubeCorner(
        _path,
        0,
        const Point2D(x: 1000, y: 260),
      );
      expect(out.length, _path.length + 1);
      expect(out[1], const Point2D(x: 1000, y: 200));
    });

    test('a corner is removed; the ends cannot be', () {
      expect(PipeLayoutEngine.removeTubeCorner(_path, 2).length, 4);
      expect(PipeLayoutEngine.removeTubeCorner(_path, 0), _path);
    });
  });

  group('manualTubePathIssues', () {
    test('a path inside the zone has no issues', () {
      final issues = PipeLayoutEngine.manualTubePathIssues(
        path: _path,
        polygon: _square,
      );
      expect(issues.leavesZone, isFalse);
      expect(issues.crossesCorridor, isFalse);
      expect(issues.selfCrossing, isFalse);
    });

    test('a corner outside the zone leaves it', () {
      final out = PipeLayoutEngine.moveTubeCorner(
        _path,
        1,
        const Point2D(x: 4500, y: 200),
      );
      expect(
        PipeLayoutEngine.manualTubePathIssues(
          path: out,
          polygon: _square,
        ).leavesZone,
        isTrue,
      );
    });

    test('a run through a corridor crosses it', () {
      const corridor = [
        Point2D(x: 2000, y: 0),
        Point2D(x: 2200, y: 0),
        Point2D(x: 2200, y: 3000),
        Point2D(x: 2000, y: 3000),
      ];
      expect(
        PipeLayoutEngine.manualTubePathIssues(
          path: _path,
          polygon: _square,
          keepOut: const [corridor],
        ).crossesCorridor,
        isTrue,
      );
    });

    test('a path crossing itself is reported', () {
      const crossing = [
        Point2D(x: 0, y: 200),
        Point2D(x: 3000, y: 200),
        Point2D(x: 3000, y: 1000),
        Point2D(x: 1000, y: 1000),
        Point2D(x: 1000, y: 0),
      ];
      expect(
        PipeLayoutEngine.manualTubePathIssues(
          path: crossing,
          polygon: _square,
        ).selfCrossing,
        isTrue,
      );
    });
  });
}
