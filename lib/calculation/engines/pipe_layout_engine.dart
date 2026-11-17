import 'dart:math' as math;

import '../../data/models/enums.dart';
import '../../data/models/point2d.dart';
import 'geometry_engine.dart';

/// Pipe layout of one floor heating zone, ready for painting.
///
/// [pipePath] is the continuous tube polyline from the zone entry
/// (supply) through the meander and back to the zone exit (return); it
/// is empty when no layout fits. [corridors] are the strips of the zone
/// that belong to transit lines of other circuits (ADR-038) — the zone
/// carries no tube and no heat output there.
typedef ZonePipeLayout = ({
  List<Point2D> pipePath,
  List<List<Point2D>> corridors,
});

/// One scanline interval `[lo, hi]` in mm.
typedef _Span = ({double lo, double hi});

/// One meander row: scanline position [v] and its tube interval.
typedef _Row = ({double v, double lo, double hi});

/// Pure geometry for laying tube out inside a heating zone (ADR-038).
///
/// All functions are pure static. Coordinates are millimetres. Functions
/// returning a number return [double.nan] for invalid inputs; functions
/// returning geometry return an empty list.
class PipeLayoutEngine {
  PipeLayoutEngine._(); // coverage:ignore-line

  /// Tolerance used when comparing coordinates, in mm.
  static const double _tolMm = 1.0;

  // ──────────────────────────────────────────────────────────────────────
  // Zone entry / exit
  // ──────────────────────────────────────────────────────────────────────

  /// Point where the supply line enters the zone [polygon].
  ///
  /// Resolution order (ADR-038 Rule 1):
  /// 1. the last crossing of [supplyRoutePath] (distributor → zone) with
  ///    the zone boundary;
  /// 2. the boundary point nearest to [distributorPosition];
  /// 3. null — the caller lets the layout pick its own start corner.
  static Point2D? zoneEntryPoint({
    required List<Point2D> polygon,
    List<Point2D> supplyRoutePath = const [],
    Point2D? distributorPosition,
  }) {
    if (polygon.length < 3) return null;
    final crossing = _lastCrossing(supplyRoutePath, polygon);
    if (crossing != null) return crossing.point;
    if (distributorPosition == null) return null;
    return nearestBoundaryPoint(polygon, distributorPosition);
  }

  /// Point where the return line leaves the zone [polygon]: the first
  /// crossing of [returnRoutePath] (zone → distributor) with the zone
  /// boundary, or null when the path never crosses it.
  static Point2D? zoneExitPoint({
    required List<Point2D> polygon,
    List<Point2D> returnRoutePath = const [],
  }) {
    if (polygon.length < 3) return null;
    return _firstCrossing(returnRoutePath, polygon)?.point;
  }

  /// The part of a supply route (distributor → zone) that lies before
  /// its entry into the zone [polygon]. Returns [path] unchanged when it
  /// never crosses the boundary.
  static List<Point2D> supplyRouteOutsideZone(
    List<Point2D> path,
    List<Point2D> polygon,
  ) {
    if (polygon.length < 3) return path;
    final crossing = _lastCrossing(path, polygon);
    if (crossing == null) return path;
    return [...path.sublist(0, crossing.segment + 1), crossing.point];
  }

  /// The part of a return route (zone → distributor) that lies after its
  /// exit from the zone [polygon]. Returns [path] unchanged when it never
  /// crosses the boundary.
  static List<Point2D> returnRouteOutsideZone(
    List<Point2D> path,
    List<Point2D> polygon,
  ) {
    if (polygon.length < 3) return path;
    final crossing = _firstCrossing(path, polygon);
    if (crossing == null) return path;
    return [crossing.point, ...path.sublist(crossing.segment + 1)];
  }

  /// Point on the boundary of [polygon] closest to [point], or null for
  /// a polygon with fewer than 3 vertices.
  static Point2D? nearestBoundaryPoint(List<Point2D> polygon, Point2D point) {
    final n = polygon.length;
    if (n < 3) return null;
    Point2D? best;
    var bestDist = double.infinity;
    for (var i = 0; i < n; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % n];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final len2 = dx * dx + dy * dy;
      var t = len2 < 1e-9
          ? 0.0
          : ((point.x - a.x) * dx + (point.y - a.y) * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final candidate = Point2D(x: a.x + dx * t, y: a.y + dy * t);
      final dist = GeometryEngine.distanceMm(candidate, point);
      if (dist < bestDist) {
        bestDist = dist;
        best = candidate;
      }
    }
    return best;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Transit corridors
  // ──────────────────────────────────────────────────────────────────────

  /// Corridor quads around every segment of [routes].
  ///
  /// Each segment is widened by [halfWidthMm] on both sides and extended
  /// by [halfWidthMm] at both ends so consecutive segments overlap at
  /// their joint. When [polygon] is given, segments whose corridor cannot
  /// touch its bounding box are dropped.
  static List<List<Point2D>> transitCorridors({
    required List<List<Point2D>> routes,
    required double halfWidthMm,
    List<Point2D>? polygon,
  }) {
    if (halfWidthMm <= 0 || halfWidthMm.isNaN) return const [];
    double? minX;
    double? maxX;
    double? minY;
    double? maxY;
    if (polygon != null && polygon.length >= 3) {
      minX = polygon.map((p) => p.x).reduce(math.min) - halfWidthMm;
      maxX = polygon.map((p) => p.x).reduce(math.max) + halfWidthMm;
      minY = polygon.map((p) => p.y).reduce(math.min) - halfWidthMm;
      maxY = polygon.map((p) => p.y).reduce(math.max) + halfWidthMm;
    }
    final out = <List<Point2D>>[];
    for (final route in routes) {
      for (var i = 0; i + 1 < route.length; i++) {
        final a = route[i];
        final b = route[i + 1];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 1e-6) continue;
        if (minX != null &&
            (math.max(a.x, b.x) < minX ||
                math.min(a.x, b.x) > maxX! ||
                math.max(a.y, b.y) < minY! ||
                math.min(a.y, b.y) > maxY!)) {
          continue;
        }
        final ux = dx / len * halfWidthMm;
        final uy = dy / len * halfWidthMm;
        // Left normal of the segment, scaled to the half width.
        final nx = -uy;
        final ny = ux;
        out.add([
          Point2D(x: a.x - ux + nx, y: a.y - uy + ny),
          Point2D(x: b.x + ux + nx, y: b.y + uy + ny),
          Point2D(x: b.x + ux - nx, y: b.y + uy - ny),
          Point2D(x: a.x - ux - nx, y: a.y - uy - ny),
        ]);
      }
    }
    return out;
  }

  /// Area of [polygon] not covered by any of the [exclusions] (m²).
  ///
  /// Overlapping exclusions are counted once. Equals
  /// [GeometryEngine.polygonAreaM2] when nothing overlaps. Returns
  /// [double.nan] for a polygon with fewer than 3 vertices.
  static double effectiveAreaM2({
    required List<Point2D> polygon,
    List<List<Point2D>> exclusions = const [],
  }) {
    final fullM2 = GeometryEngine.polygonAreaM2(polygon);
    if (fullM2.isNaN || exclusions.isEmpty) return fullM2;

    final minY = polygon.map((p) => p.y).reduce(math.min);
    final maxY = polygon.map((p) => p.y).reduce(math.max);
    final height = maxY - minY;
    if (height <= 0) return fullM2;

    // Midpoint-rule integration of the excluded chord length.
    final stepMm = (height / 800.0).clamp(0.5, 10.0);
    final steps = (height / stepMm).ceil();
    final dy = height / steps;
    var excludedMm2 = 0.0;
    for (var i = 0; i < steps; i++) {
      final y = minY + (i + 0.5) * dy;
      final inside = _spansAt(polygon, y, false);
      if (inside.isEmpty) continue;
      var remaining = inside;
      for (final ex in exclusions) {
        if (ex.length < 3) continue;
        remaining = _subtract(remaining, _spansAt(ex, y, false));
        if (remaining.isEmpty) break;
      }
      excludedMm2 += (_totalLength(inside) - _totalLength(remaining)) * dy;
    }
    return math.max(0.0, fullM2 - excludedMm2 / 1e6);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Meander
  // ──────────────────────────────────────────────────────────────────────

  /// Width of the edge zone of [LayoutPattern.edgeZoneMeander], in mm
  /// (ADR-043 Rule 4).
  static const double edgeZoneWidthMm = 1000.0;

  /// Tube spacing in the edge zone of [LayoutPattern.edgeZoneMeander]:
  /// half the zone's spacing, but at least 50 mm (ADR-043 Rule 4).
  static double edgeZoneSpacingMm(int tubeSpacingMm) =>
      math.max(50.0, tubeSpacingMm / 2.0);

  /// Continuous tube path for a zone in the given layout [pattern]
  /// (ADR-043): `entry → tube → exit`.
  ///
  /// - [LayoutPattern.meander] — single serpentine: rows back and forth,
  ///   the tube returns along one side (the return lane). Supply enters
  ///   the first row, so the water cools from one side of the zone to
  ///   the other.
  /// - [LayoutPattern.doubleMeander] — double serpentine: supply and
  ///   return run side by side through the serpentine and fold back at
  ///   the far end, so warm and cool rows alternate.
  /// - [LayoutPattern.counterflow] — counterflow spiral (snail): the
  ///   supply spirals in to the centre at double spacing and the return
  ///   spirals back out between its turns. Where rings would cover less
  ///   than 70 % of the zone (an L-shape) the double serpentine is used,
  ///   which also alternates supply and return.
  /// - [LayoutPattern.edgeZoneMeander] — serpentine with an edge zone:
  ///   rows parallel to the longest of [exteriorEdges] (zone edges along
  ///   an exterior wall), the first [edgeZoneWidthMm] at
  ///   [edgeZoneSpacingMm], fed by the supply first. Without an exterior
  ///   edge it is a plain serpentine.
  ///
  /// Tubes keep [borderDistanceMm] from the zone boundary. The pitch is
  /// at most [tubeSpacingMm]; the serpentines tighten it slightly where
  /// needed for an even row count, and keep out of [exclusions] (the
  /// spiral does not route around them). Where nothing of the requested
  /// pattern fits, the single serpentine is used.
  ///
  /// Among the possible layouts the one starting closest to [entryPoint]
  /// is preferred, and its leads must not cross the tube (ADR-041).
  /// [exitPoint] defaults to [entryPoint]. Returns an empty list when the
  /// inputs are invalid or nothing fits.
  static List<Point2D> tubePath({
    required LayoutPattern pattern,
    required List<Point2D> polygon,
    required int tubeSpacingMm,
    required int borderDistanceMm,
    Point2D? entryPoint,
    Point2D? exitPoint,
    List<List<Point2D>> exclusions = const [],
    List<({Point2D start, Point2D end})> exteriorEdges = const [],
  }) {
    if (polygon.length < 3 || tubeSpacingMm <= 0 || borderDistanceMm < 0) {
      return const [];
    }
    List<List<Point2D>> serpentine(LayoutPattern p) => _serpentineBodies(
      pattern: p,
      polygon: polygon,
      tubeSpacingMm: tubeSpacingMm,
      borderDistanceMm: borderDistanceMm,
      entryPoint: entryPoint,
      exclusions: exclusions,
      exteriorEdges: exteriorEdges,
    );
    var bodies = pattern == LayoutPattern.counterflow
        ? _spiralBodies(
            polygon: polygon,
            spacing: tubeSpacingMm.toDouble(),
            border: borderDistanceMm.toDouble(),
            entryPoint: entryPoint,
          )
        : serpentine(pattern);
    if (pattern == LayoutPattern.counterflow && bodies.isNotEmpty) {
      // Rings stop as soon as the narrowest part of the zone is full. If
      // that leaves much of the zone without tube, the double serpentine
      // — which also alternates supply and return — is used instead.
      final coveredM2 =
          GeometryEngine.polylineLengthMm(bodies.first) * tubeSpacingMm / 1e6;
      if (coveredM2 < 0.7 * GeometryEngine.polygonAreaM2(polygon)) {
        bodies = serpentine(LayoutPattern.doubleMeander);
      }
    }
    if (pattern == LayoutPattern.counterflow && bodies.isEmpty) {
      bodies = serpentine(LayoutPattern.doubleMeander);
    }
    if (bodies.isEmpty && pattern != LayoutPattern.meander) {
      bodies = serpentine(LayoutPattern.meander);
    }
    return _pickCrossingFree(
      bodies,
      entryPoint,
      exitPoint ?? entryPoint,
      // The edge zone must get the supply first: reversing its flow is a
      // last resort.
      reverseFlowPenaltyMm: pattern == LayoutPattern.edgeZoneMeander &&
              exteriorEdges.isNotEmpty
          ? 1e7
          : _reverseFlowPenaltyMm,
    );
  }

  /// [tubePath] for [LayoutPattern.meander].
  static List<Point2D> meanderPath({
    required List<Point2D> polygon,
    required int tubeSpacingMm,
    required int borderDistanceMm,
    Point2D? entryPoint,
    Point2D? exitPoint,
    List<List<Point2D>> exclusions = const [],
  }) => tubePath(
    pattern: LayoutPattern.meander,
    polygon: polygon,
    tubeSpacingMm: tubeSpacingMm,
    borderDistanceMm: borderDistanceMm,
    entryPoint: entryPoint,
    exitPoint: exitPoint,
    exclusions: exclusions,
  );

  /// Candidate tube bodies (without leads) of the row-based layouts, best
  /// first. Each body is listed in its preferred direction of flow.
  ///
  /// Of the eight row arrangements (rows along X or Y, return lane /
  /// start side on either side, start at either end) those covering at
  /// least 80 % of the best coverage are kept, ordered by how close
  /// their start is to [entryPoint]; arrangements that jump a transit
  /// corridor, have a stepped lane, or have the entry away from the
  /// first-row side are ranked down. Without an [entryPoint] the rows
  /// run along the longer side of the zone.
  static List<List<Point2D>> _serpentineBodies({
    required LayoutPattern pattern,
    required List<Point2D> polygon,
    required int tubeSpacingMm,
    required int borderDistanceMm,
    required Point2D? entryPoint,
    required List<List<Point2D>> exclusions,
    List<({Point2D start, Point2D end})> exteriorEdges = const [],
  }) {
    final spacing = tubeSpacingMm.toDouble();
    final border = borderDistanceMm.toDouble();

    // Edge zone (ADR-043 Rule 4): rows parallel to the longest exterior
    // edge, starting at it, densely spaced for the first metre.
    ({bool swap, bool fromMin})? edgeSide;
    if (pattern == LayoutPattern.edgeZoneMeander && exteriorEdges.isNotEmpty) {
      final edge = exteriorEdges.reduce(
        (a, b) => GeometryEngine.distanceMm(a.start, a.end) >=
                GeometryEngine.distanceMm(b.start, b.end)
            ? a
            : b,
      );
      final horizontal = (edge.end.x - edge.start.x).abs() >=
          (edge.end.y - edge.start.y).abs();
      final cx = polygon.map((p) => p.x).reduce((a, b) => a + b) /
          polygon.length;
      final cy = polygon.map((p) => p.y).reduce((a, b) => a + b) /
          polygon.length;
      edgeSide = horizontal
          ? (swap: false, fromMin: (edge.start.y + edge.end.y) / 2 < cy)
          : (swap: true, fromMin: (edge.start.x + edge.end.x) / 2 < cx);
    }
    final dense = edgeSide == null
        ? null
        : (
            widthMm: edgeZoneWidthMm,
            spacingMm: edgeZoneSpacingMm(tubeSpacingMm),
          );

    final minX = polygon.map((p) => p.x).reduce(math.min);
    final maxX = polygon.map((p) => p.x).reduce(math.max);
    final minY = polygon.map((p) => p.y).reduce(math.min);
    final maxY = polygon.map((p) => p.y).reduce(math.max);
    // Rows along X (swap = false) are preferred for a wide zone.
    final preferSwap = (maxY - minY) > (maxX - minX);

    final candidates = <_Candidate>[];
    for (final swap in const [false, true]) {
      for (final fromMin in const [true, false]) {
        if (edgeSide != null &&
            (swap != edgeSide.swap || fromMin != edgeSide.fromMin)) {
          continue;
        }
        final entryUv = entryPoint == null
            ? null
            : (
                u: swap ? entryPoint.y : entryPoint.x,
                v: swap ? entryPoint.x : entryPoint.y,
              );
        final built = _buildRows(
          polygon: polygon,
          exclusions: exclusions,
          spacing: spacing,
          border: border,
          swap: swap,
          fromMin: fromMin,
          entryU: entryUv?.u,
          dense: dense,
        );
        final rows = built.rows;
        if (rows.length < 2) continue;
        final coverage = rows.fold<double>(
          0.0,
          (sum, r) => sum + (r.hi - r.lo),
        );
        for (final laneLo in const [true, false]) {
          final near0 = laneLo ? rows.first.lo : rows.first.hi;
          final straight = rows.every(
            (r) => ((laneLo ? r.lo : r.hi) - near0).abs() <= _tolMm,
          );
          final startU = near0 + (laneLo ? spacing : -spacing);
          // The return lane steps in by the row pitch; in the edge zone
          // that is the denser one.
          var score = straight ? 0.0 : 1e7;
          if (entryUv != null) {
            final du = entryUv.u - startU;
            final dv = entryUv.v - rows.first.v;
            score += math.sqrt(du * du + dv * dv);
            // Entry on the first-row side: both leads stay in the
            // border strip and cross no tube.
            if (dv.abs() > border + spacing) score += 1e5;
          }
          if (swap != preferSwap) score += 2 * spacing;
          // Every corridor the serpentine has to jump means crossing a
          // transit line twice.
          score += built.jumps * 1e4;
          candidates.add((
            rows: rows,
            swap: swap,
            laneLo: laneLo,
            coverage: coverage,
            score: score,
          ));
        }
      }
    }
    if (candidates.isEmpty) return const [];

    final bestCoverage = candidates.map((c) => c.coverage).reduce(math.max);
    final eligible = [
      for (final c in candidates)
        if (c.coverage >= 0.8 * bestCoverage) c,
    ]..sort((a, b) => a.score.compareTo(b.score));

    final bodies = <List<Point2D>>[];
    for (final c in eligible) {
      final List<Point2D> body;
      if (pattern == LayoutPattern.doubleMeander) {
        body = _assembleBifilar(rows: c.rows, swap: c.swap, startLo: c.laneLo);
      } else {
        final laneStep =
            dense == null ? spacing : math.min(spacing, dense.spacingMm);
        body = _assemblePath(
          rows: c.rows,
          swap: c.swap,
          laneLo: c.laneLo,
          spacing: laneStep,
          entryPoint: null,
          exitPoint: null,
        );
        if (dense != null) {
          // Entry on the far side of the zone: feed the edge zone along
          // the lane instead of running the leads across the zone.
          final fedFromFar = _assemblePath(
            rows: c.rows,
            swap: c.swap,
            laneLo: c.laneLo,
            spacing: laneStep,
            entryPoint: null,
            exitPoint: null,
            feedFromFar: true,
          );
          if (fedFromFar.length >= 4) bodies.add(fedFromFar);
        }
      }
      if (body.length >= 4) bodies.add(body);
    }
    return bodies;
  }

  /// Extra lead length a layout may cost before its direction of flow is
  /// reversed instead, in mm.
  static const double _reverseFlowPenaltyMm = 1500.0;

  /// Adds the leads to the one of [bodies] — as listed or reversed —
  /// whose leads cross nothing (ADR-041) and are shortest.
  /// When none is crossing-free the one with the fewest crossings wins.
  /// Without an [entry] the first body is returned as it is.
  static List<Point2D> _pickCrossingFree(
    List<List<Point2D>> bodies,
    Point2D? entry,
    Point2D? exit, {
    double reverseFlowPenaltyMm = _reverseFlowPenaltyMm,
  }) {
    if (bodies.isEmpty) return const [];
    if (entry == null || exit == null) return bodies.first;
    List<Point2D>? fallback;
    var fallbackCrossings = 1 << 30;
    // Among the crossing-free options the one with the shortest leads
    // wins. A body's own direction of flow — which is what tells the
    // meander from the counterflow layout — is given up only when the
    // reversed direction saves more than [_reverseFlowPenaltyMm] of lead.
    List<Point2D>? best;
    var bestCost = double.infinity;
    for (final body in bodies) {
      for (final reversed in const [false, true]) {
        final ordered = reversed ? body.reversed.toList() : body;
        final path = [entry, ...ordered, exit];
        final crossings = leadCrossings(path);
        if (crossings == 0) {
          final cost = GeometryEngine.distanceMm(entry, ordered.first) +
              GeometryEngine.distanceMm(ordered.last, exit) +
              (reversed ? reverseFlowPenaltyMm : 0.0);
          if (cost < bestCost) {
            bestCost = cost;
            best = path;
          }
        } else if (crossings < fallbackCrossings) {
          fallbackCrossings = crossings;
          fallback = path;
        }
      }
    }
    if (best != null) return best;
    return fallback ?? const [];
  }

  /// Double-meander body for [rows] (ADR-042 Rule 2): a serpentine
  /// centre line through every pair of rows, with the tube laid as a
  /// pair half a pitch either side of it and folded at the far end.
  /// The body starts and ends side by side, one pitch apart.
  static List<Point2D> _assembleBifilar({
    required List<_Row> rows,
    required bool swap,
    required bool startLo,
  }) {
    if (rows.length < 2) return const [];
    final pitch = (rows[1].v - rows[0].v).abs();
    if (pitch < _tolMm) return const [];
    Point2D world(double u, double v) =>
        swap ? Point2D(x: v, y: u) : Point2D(x: u, y: v);

    final vs = <double>[];
    final nearEnds = <double>[];
    final farEnds = <double>[];
    for (var i = 0; i + 1 < rows.length; i += 2) {
      final a = rows[i];
      final b = rows[i + 1];
      final lo = math.max(a.lo, b.lo) + pitch / 2;
      final hi = math.min(a.hi, b.hi) - pitch / 2;
      if (hi - lo < pitch) continue;
      vs.add((a.v + b.v) / 2);
      nearEnds.add(startLo ? lo : hi);
      farEnds.add(startLo ? hi : lo);
    }
    _squareOffTurns(nearEnds, farEnds, 4 * pitch, lastTurn: vs.length - 2);
    final centre = <Point2D>[];
    for (var i = 0; i < vs.length; i++) {
      if (i.isEven) {
        centre
          ..add(world(nearEnds[i], vs[i]))
          ..add(world(farEnds[i], vs[i]));
      } else {
        centre
          ..add(world(farEnds[i], vs[i]))
          ..add(world(nearEnds[i], vs[i]));
      }
    }
    if (centre.length < 2) return const [];
    final left = offsetPolyline(centre, pitch / 2);
    final right = offsetPolyline(centre, -pitch / 2);
    if (left.length < 2 || right.length < 2) return const [];
    return [...left, ...right.reversed];
  }

  /// Snail bodies for [polygon] (ADR-042 Rule 2), best first.
  ///
  /// Concentric rings are taken [spacing] apart, starting [border]
  /// inside the boundary. The supply runs along rings 0, 2, 4 …, leaving
  /// each ring two spacings before it would close and stepping in to the
  /// next but one; the return does the same on rings 1, 3, 5 …; the two
  /// are joined by a U-turn at the innermost ring. Both tubes therefore
  /// start side by side at one corner of the outermost ring.
  ///
  /// One body per convex start corner and sense of rotation, ordered by
  /// the distance of that corner from [entryPoint]. Empty when fewer
  /// than two rings fit.
  static List<List<Point2D>> _spiralBodies({
    required List<Point2D> polygon,
    required double spacing,
    required double border,
    required Point2D? entryPoint,
  }) {
    final base = GeometryEngine.removeCollinearVertices(polygon);
    final n = base.length;
    if (n < 3) return const [];

    final rings = <List<Point2D>>[];
    for (var k = 0; k < 400; k++) {
      final ring = GeometryEngine.offsetPolygonPerEdge(
        centerline: base,
        edgeOffsetsMm: List<double>.filled(n, -(border + k * spacing)),
      );
      if (ring.length != n) break;
      var shortest = double.infinity;
      for (var i = 0; i < n; i++) {
        shortest = math.min(
          shortest,
          GeometryEngine.distanceMm(ring[i], ring[(i + 1) % n]),
        );
      }
      // A ring narrower than one spacing has no room for the U-turn.
      if (shortest <= spacing + _tolMm) break;
      rings.add(ring);
    }
    if (rings.length < 2) return const [];

    var area2 = 0.0;
    for (var i = 0; i < n; i++) {
      final a = base[i];
      final b = base[(i + 1) % n];
      area2 += a.x * b.y - b.x * a.y;
    }

    final scored = <({double distance, List<Point2D> body})>[];
    for (var start = 0; start < n; start++) {
      // Only convex corners make a clean start.
      final prev = base[(start + n - 1) % n];
      final cur = base[start];
      final next = base[(start + 1) % n];
      final turn =
          (cur.x - prev.x) * (next.y - cur.y) -
          (cur.y - prev.y) * (next.x - cur.x);
      if (turn * area2 <= 0) continue;

      for (final forward in const [true, false]) {
        // The closing edge of every ring used (the edge leading into the
        // start corner) must leave room to step in two spacings before
        // the corner; deeper rings are dropped once it does not.
        var ringCount = 0;
        while (ringCount < rings.length) {
          final ring = rings[ringCount];
          final into = ring[(forward ? start - 1 + n : start + 1) % n];
          if (GeometryEngine.distanceMm(into, ring[start]) <=
              2 * spacing + _tolMm) {
            break;
          }
          ringCount++;
        }
        if (ringCount < 2) continue;
        // Ring k re-ordered to begin at the start corner.
        List<Point2D> ordered(int k) => [
          for (var i = 0; i < n; i++)
            rings[k][(forward ? start + i : start - i + n) % n],
        ];
        // Point on ring k's closing edge, [back] before its start corner.
        Point2D before(List<Point2D> ring, double back) {
          final s0 = ring.first;
          final last = ring.last;
          final len = GeometryEngine.distanceMm(last, s0);
          return Point2D(
            x: s0.x - (s0.x - last.x) / len * back,
            y: s0.y - (s0.y - last.y) / len * back,
          );
        }

        final supply = <Point2D>[];
        final back = <Point2D>[before(ordered(0), spacing)];
        final lastRing = ringCount - 1;
        for (var k = 0; k <= lastRing; k++) {
          final ring = ordered(k);
          final chain = k.isEven ? supply : back;
          chain.addAll(ring);
          // The innermost ring runs one spacing further — that is where
          // the U-turn to the other tube sits.
          chain.add(before(ring, k == lastRing ? spacing : 2 * spacing));
        }
        final body = dedupePolyline([...supply, ...back.reversed]);
        final distance = entryPoint == null
            ? 0.0
            : GeometryEngine.distanceMm(entryPoint, body.first);
        scored.add((distance: distance, body: body));
      }
    }
    scored.sort((a, b) => a.distance.compareTo(b.distance));
    return [for (final c in scored) c.body];
  }

  /// Number of places where the two leads of a zone tube [path] — its
  /// first segment (from the supply pipe) and its last segment (to the
  /// return pipe) — cross or touch another segment of the path or each
  /// other (ADR-041).
  ///
  /// Touching counts: a lead running through a corner of the tube looks
  /// the same as a crossing. Neighbouring segments, which share an end by
  /// construction, are not compared; neither are the two leads when they
  /// start from the same point (no separate return pipe yet).
  static int leadCrossings(List<Point2D> path) {
    final n = path.length;
    if (n < 4) return 0;
    final sharedStart =
        GeometryEngine.distanceMm(path.first, path.last) <= _tolMm;
    var count = 0;
    final leads = <int>{0, n - 2};
    for (final lead in leads) {
      final a = path[lead];
      final b = path[lead + 1];
      for (var j = 0; j < n - 1; j++) {
        if ((j - lead).abs() <= 1) continue;
        if (leads.contains(j)) {
          // The two leads: compared once, and not at all when they start
          // from the same point.
          if (j < lead || sharedStart) continue;
        }
        if (_segmentDistanceMm(a, b, path[j], path[j + 1]) <= _tolMm) {
          count++;
        }
      }
    }
    return count;
  }

  /// Shortest distance between segments [a1]→[a2] and [b1]→[b2] (mm);
  /// 0 when they cross.
  static double _segmentDistanceMm(
    Point2D a1,
    Point2D a2,
    Point2D b1,
    Point2D b2,
  ) {
    if (GeometryEngine.segmentsIntersect(a1, a2, b1, b2)) return 0.0;
    return [
      _pointSegmentDistanceMm(a1, b1, b2),
      _pointSegmentDistanceMm(a2, b1, b2),
      _pointSegmentDistanceMm(b1, a1, a2),
      _pointSegmentDistanceMm(b2, a1, a2),
    ].reduce(math.min);
  }

  static double _pointSegmentDistanceMm(Point2D p, Point2D a, Point2D b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 < 1e-12) return GeometryEngine.distanceMm(p, a);
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
    return GeometryEngine.distanceMm(
      p,
      Point2D(x: a.x + dx * t, y: a.y + dy * t),
    );
  }

  /// Builds the serpentine rows of one layout in the (u, v) frame — u
  /// along the rows, v across them. With [swap] the rows run along Y.
  static ({List<_Row> rows, int jumps}) _buildRows({
    required List<Point2D> polygon,
    required List<List<Point2D>> exclusions,
    required double spacing,
    required double border,
    required bool swap,
    required bool fromMin,
    required double? entryU,
    ({double widthMm, double spacingMm})? dense,
  }) {
    final vs = polygon.map((p) => swap ? p.x : p.y);
    final v0 = vs.reduce(math.min) + border;
    final v1 = vs.reduce(math.max) - border;
    final extent = v1 - v0;
    if (extent < spacing / 2) return (rows: const <_Row>[], jumps: 0);

    final offsets = _rowOffsets(extent, spacing, dense);
    // Sample slightly inside the border offset so the first and last
    // rows still see the polygon edge they run along.
    final probe = math.max(0.0, border - 0.5);

    final rows = <_Row>[];
    var jumps = 0;
    var jumping = false;
    for (final offset in offsets) {
      final v = fromMin ? v0 + offset : v1 - offset;
      var spans = _spansAt(polygon, v, swap);
      if (probe > 0) {
        spans = _intersect(spans, _spansAt(polygon, v - probe, swap));
        spans = _intersect(spans, _spansAt(polygon, v + probe, swap));
      }
      spans = [
        for (final s in spans)
          if (s.hi - s.lo > 2 * border) (lo: s.lo + border, hi: s.hi - border),
      ];
      final hadRoom = spans.any((s) => s.hi - s.lo > spacing + _tolMm);
      for (final ex in exclusions) {
        if (ex.length < 3) continue;
        spans = _subtract(spans, _spansAt(ex, v, swap));
      }
      spans = [
        for (final s in spans)
          if (s.hi - s.lo > spacing + _tolMm) s,
      ];
      // A row swallowed by a transit corridor running along it is left
      // out; the serpentine carries on behind the corridor.
      if (spans.isEmpty && hadRoom && rows.isNotEmpty) {
        jumping = true;
        continue;
      }

      _Span? chosen;
      if (rows.isEmpty) {
        var bestKey = double.infinity;
        for (final s in spans) {
          final key = entryU == null
              ? -(s.hi - s.lo)
              : (entryU < s.lo
                    ? s.lo - entryU
                    : (entryU > s.hi ? entryU - s.hi : 0.0));
          if (key < bestKey) {
            bestKey = key;
            chosen = s;
          }
        }
        // Leading rows with no room are skipped.
        if (chosen == null) continue;
      } else {
        final prev = rows.last;
        var bestOverlap = 0.0;
        for (final s in spans) {
          final overlap = math.min(s.hi, prev.hi) - math.max(s.lo, prev.lo);
          if (overlap > bestOverlap) {
            bestOverlap = overlap;
            chosen = s;
          }
        }
        // The serpentine cannot jump a gap — stop at the first row
        // that no longer connects to the previous one.
        if (chosen == null) break;
      }
      if (jumping) {
        jumps += 1;
        jumping = false;
      }
      rows.add((v: v, lo: chosen.lo, hi: chosen.hi));
    }

    // An even row count brings the last row back to the lane side.
    if (rows.length.isOdd) rows.removeLast();
    return (rows: rows, jumps: jumps);
  }

  /// Distances of the serpentine rows from the start side, across an
  /// [extent] of the zone (ADR-043).
  ///
  /// Without [dense] the rows are evenly spaced at most [spacing] apart.
  /// With it, the first `dense.widthMm` are covered at
  /// `dense.spacingMm` (the edge zone) and the rest at most [spacing]
  /// apart. The count is always even so the last row ends on the side
  /// of the return lane, and the last row lies exactly at [extent].
  static List<double> _rowOffsets(
    double extent,
    double spacing,
    ({double widthMm, double spacingMm})? dense,
  ) {
    List<double> even(double from, double to, double maxPitch, int parity) {
      final span = to - from;
      var gaps = math.max(1, (span / maxPitch - 1e-6).ceil());
      if (gaps % 2 != parity) gaps += 1;
      return [for (var i = 1; i <= gaps; i++) from + span * i / gaps];
    }

    if (dense == null ||
        dense.spacingMm <= 0 ||
        dense.widthMm < dense.spacingMm ||
        extent <= dense.widthMm + spacing) {
      // One even block: rows 0 … gaps, gaps odd for an even count.
      return [0.0, ...even(0.0, extent, spacing, 1)];
    }
    final denseGaps = (dense.widthMm / dense.spacingMm).floor();
    final denseEnd = denseGaps * dense.spacingMm;
    final denseRows = [
      for (var i = 0; i <= denseGaps; i++) i * dense.spacingMm,
    ];
    // The rest must bring the total to an even count.
    final restParity = denseRows.length.isOdd ? 1 : 0;
    return [
      ...denseRows,
      ...even(denseEnd, extent, spacing, restParity),
    ];
  }

  /// Turns [rows] into the world-space tube polyline.
  static List<Point2D> _assemblePath({
    required List<_Row> rows,
    required bool swap,
    required bool laneLo,
    required double spacing,
    required Point2D? entryPoint,
    required Point2D? exitPoint,
    bool feedFromFar = false,
  }) {
    Point2D world(double u, double v) =>
        swap ? Point2D(x: v, y: u) : Point2D(x: u, y: v);
    double near(_Row r) => laneLo ? r.lo : r.hi;
    double far(_Row r) => laneLo ? r.hi : r.lo;
    final inward = laneLo ? spacing : -spacing;

    final path = <Point2D>[];
    if (entryPoint != null) path.add(entryPoint);
    final last = rows.length - 1;
    if (feedFromFar) {
      // ADR-043 Rule 4: the lane comes first — from the far end of the
      // rows back to the first row — so the supply reaches the first
      // row (the edge zone) before anything else.
      for (var i = last; i >= 0; i--) {
        path.add(world(near(rows[i]), rows[i].v));
      }
    }
    final nearEnds = [
      // Every row but the last stops one spacing short of the lane; with
      // the lane fed first, the last row does too.
      for (var i = 0; i <= last; i++)
        i == last && !feedFromFar ? near(rows[i]) : near(rows[i]) + inward,
    ];
    final farEnds = [for (final r in rows) far(r)];
    _squareOffTurns(nearEnds, farEnds, 2 * spacing, lastTurn: last - 1);
    for (var i = 0; i <= last; i++) {
      final r = rows[i];
      if (i.isEven) {
        path
          ..add(world(nearEnds[i], r.v))
          ..add(world(farEnds[i], r.v));
      } else {
        path
          ..add(world(farEnds[i], r.v))
          ..add(world(nearEnds[i], r.v));
      }
    }
    // Return lane back along the near side to the first row.
    if (!feedFromFar) {
      for (var i = last - 1; i >= 0; i--) {
        path.add(world(near(rows[i]), rows[i].v));
      }
    }
    if (exitPoint != null) path.add(exitPoint);
    return path;
  }

  /// Squares off the turns of a serpentine whose rows differ in length.
  ///
  /// Row `i` and row `i + 1` are joined on the far side when `i` is even
  /// and on the near side when it is odd. Where the two row ends differ
  /// by more than [maxStepMm] — the zone has a step there — both are
  /// pulled back to the shorter one, so the turn stays inside the zone
  /// instead of running diagonally across the step. The stub of the
  /// longer row beyond the turn stays without tube.
  ///
  /// Turns up to index [lastTurn] are treated; [nearEnds] and [farEnds]
  /// are modified in place.
  static void _squareOffTurns(
    List<double> nearEnds,
    List<double> farEnds,
    double maxStepMm, {
    required int lastTurn,
  }) {
    for (var i = 0; i <= lastTurn && i + 1 < nearEnds.length; i++) {
      final ends = i.isEven ? farEnds : nearEnds;
      if ((ends[i] - ends[i + 1]).abs() <= maxStepMm) continue;
      // "Shorter" = closer to the opposite side of the row.
      final towardsFar = farEnds[i] >= nearEnds[i];
      final farSide = i.isEven;
      final pickSmaller = farSide == towardsFar;
      final inner = pickSmaller
          ? math.min(ends[i], ends[i + 1])
          : math.max(ends[i], ends[i + 1]);
      ends[i] = inner;
      ends[i + 1] = inner;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Bends
  // ──────────────────────────────────────────────────────────────────────

  /// Minimum bending radius of a tube: [bendRadiusFactor] × its outer
  /// diameter (ADR-039 Rule 3).
  static const double bendRadiusFactor = 5.0;

  /// Minimum bending radius in mm for a tube of [outerDiameterMm].
  /// Returns [double.nan] for a non-positive diameter.
  static double minBendRadiusMm(double outerDiameterMm) {
    if (outerDiameterMm.isNaN || outerDiameterMm <= 0) return double.nan;
    return bendRadiusFactor * outerDiameterMm;
  }

  /// Rounds every corner of [points] with a circular arc of [radiusMm]
  /// (ADR-039 Rule 3).
  ///
  /// The arc is tangent to both segments of a corner. Where a segment is
  /// too short for the full radius, the arc may use at most half of that
  /// segment, so the radius shrinks at that corner — see
  /// [tightestBendRadiusMm] to detect it. Each arc is approximated by
  /// chords of at most [maxStepDegrees].
  ///
  /// The first and last point are kept. Returns [points] unchanged for
  /// fewer than 3 points or a non-positive radius.
  static List<Point2D> filletPolyline(
    List<Point2D> points,
    double radiusMm, {
    double maxStepDegrees = 10.0,
  }) {
    if (points.length < 3 || radiusMm.isNaN || radiusMm <= 0) return points;
    final out = <Point2D>[points.first];
    for (var i = 1; i + 1 < points.length; i++) {
      final corner = _cornerArc(
        points[i - 1],
        points[i],
        points[i + 1],
        radiusMm,
      );
      if (corner == null) {
        out.add(points[i]);
        continue;
      }
      final steps = math.max(
        2,
        (corner.sweepRad.abs() * 180 / math.pi / maxStepDegrees).ceil(),
      );
      for (var k = 0; k <= steps; k++) {
        final angle = corner.startRad + corner.sweepRad * k / steps;
        out.add(
          Point2D(
            x: corner.center.x + corner.radius * math.cos(angle),
            y: corner.center.y + corner.radius * math.sin(angle),
          ),
        );
      }
    }
    out.add(points.last);
    return out;
  }

  /// Smallest bend radius [filletPolyline] can realise on [points] for a
  /// requested [radiusMm]: equal to [radiusMm] when every corner has
  /// room for it, smaller when a short segment forces a tighter bend.
  /// Returns [radiusMm] when there is no corner.
  static double tightestBendRadiusMm(List<Point2D> points, double radiusMm) {
    if (radiusMm.isNaN || radiusMm <= 0) return double.nan;
    var tightest = radiusMm;
    for (var i = 1; i + 1 < points.length; i++) {
      final corner = _cornerArc(
        points[i - 1],
        points[i],
        points[i + 1],
        radiusMm,
      );
      if (corner != null && corner.radius < tightest) {
        tightest = corner.radius;
      }
    }
    return tightest;
  }

  /// Arc that rounds the corner [a]→[p]→[b], or null when the corner is
  /// straight, a full reversal, or degenerate.
  static ({Point2D center, double radius, double startRad, double sweepRad})?
  _cornerArc(Point2D a, Point2D p, Point2D b, double radiusMm) {
    final inLen = GeometryEngine.distanceMm(a, p);
    final outLen = GeometryEngine.distanceMm(p, b);
    if (inLen < 1e-6 || outLen < 1e-6) return null;
    final ux = (p.x - a.x) / inLen;
    final uy = (p.y - a.y) / inLen;
    final vx = (b.x - p.x) / outLen;
    final vy = (b.y - p.y) / outLen;
    final cross = ux * vy - uy * vx;
    final dot = ux * vx + uy * vy;
    // Turning angle between the incoming and outgoing direction.
    final turn = math.atan2(cross, dot);
    if (turn.abs() < 1e-3 || turn.abs() > math.pi - 1e-3) return null;

    final tanHalf = math.tan(turn.abs() / 2);
    final tangent = math.min(radiusMm * tanHalf, math.min(inLen, outLen) / 2);
    final radius = tangent / tanHalf;
    if (radius < 1e-6) return null;

    final side = turn > 0 ? 1.0 : -1.0;
    // Arc start: back along the incoming segment by the tangent length.
    final sx = p.x - ux * tangent;
    final sy = p.y - uy * tangent;
    // Centre: perpendicular to the incoming direction, on the turn side.
    final cx = sx - uy * side * radius;
    final cy = sy + ux * side * radius;
    return (
      center: Point2D(x: cx, y: cy),
      radius: radius,
      startRad: math.atan2(sy - cy, sx - cx),
      sweepRad: turn,
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Connection pipe pair (ADR-040)
  // ──────────────────────────────────────────────────────────────────────

  /// How far beyond its target distance a route section may be from a
  /// wall and still be pulled to it by [snapRouteToWalls], in mm.
  static const double wallCaptureMm = 250.0;

  /// Removes points that coincide with their predecessor (within 1 mm).
  static List<Point2D> dedupePolyline(List<Point2D> points) {
    final out = <Point2D>[];
    for (final p in points) {
      if (out.isEmpty || GeometryEngine.distanceMm(out.last, p) > _tolMm) {
        out.add(p);
      }
    }
    return out;
  }

  /// Polyline parallel to [points], [offsetMm] to the left of the
  /// direction of travel (negative = right).
  ///
  /// Corners are mitred so every section stays exactly [offsetMm] from
  /// its original. At a turn sharper than about 150° the mitre would run
  /// away, so the corner is offset square to the incoming section
  /// instead. Coincident points are dropped first; the result has one
  /// point per remaining input point. Returns an empty list for fewer
  /// than 2 distinct points.
  static List<Point2D> offsetPolyline(List<Point2D> points, double offsetMm) {
    final pts = dedupePolyline(points);
    final n = pts.length;
    if (n < 2 || offsetMm.isNaN) return const [];

    // Left unit normal of every section.
    final nx = List<double>.filled(n - 1, 0);
    final ny = List<double>.filled(n - 1, 0);
    for (var i = 0; i < n - 1; i++) {
      final dx = pts[i + 1].x - pts[i].x;
      final dy = pts[i + 1].y - pts[i].y;
      final len = math.sqrt(dx * dx + dy * dy);
      nx[i] = -dy / len;
      ny[i] = dx / len;
    }

    final out = <Point2D>[];
    for (var i = 0; i < n; i++) {
      final a = i == 0 ? 0 : i - 1; // incoming section
      final b = i == n - 1 ? n - 2 : i; // outgoing section
      final k = 1 + nx[a] * nx[b] + ny[a] * ny[b];
      if (a == b || k < 0.07) {
        out.add(
          Point2D(
            x: pts[i].x + nx[a] * offsetMm,
            y: pts[i].y + ny[a] * offsetMm,
          ),
        );
      } else {
        out.add(
          Point2D(
            x: pts[i].x + (nx[a] + nx[b]) * offsetMm / k,
            y: pts[i].y + (ny[a] + ny[b]) * offsetMm / k,
          ),
        );
      }
    }
    return out;
  }

  /// Supply and return pipe for a route drawn as one [centerline] from
  /// the distributor to the zone (ADR-040 Rule 2).
  ///
  /// The two pipes run [pipeSpacingMm] apart, half on each side of the
  /// centerline: supply on the left of the direction of travel, return on
  /// the right — or the other way round with [supplyOnRight] (ADR-041). Both are tied to the distributor at the centerline's
  /// first point, so `supply.first` and `back.last` are that point.
  /// `supply` runs distributor → zone, `back` runs zone → distributor.
  ///
  /// Returns two empty lists when the centerline has fewer than 2
  /// distinct points or the spacing is not positive.
  static ({List<Point2D> supply, List<Point2D> back}) connectionPipePair({
    required List<Point2D> centerline,
    required double pipeSpacingMm,
    bool supplyOnRight = false,
  }) {
    final pts = dedupePolyline(centerline);
    if (pts.length < 2 || pipeSpacingMm.isNaN || pipeSpacingMm <= 0) {
      return (supply: const <Point2D>[], back: const <Point2D>[]);
    }
    final half = supplyOnRight ? -pipeSpacingMm / 2 : pipeSpacingMm / 2;
    final left = offsetPolyline(pts, half);
    final right = offsetPolyline(pts, -half);
    return (supply: [pts.first, ...left], back: [...right.reversed, pts.first]);
  }

  /// Moves every section of [path] that runs along a wall so the pipe
  /// nearest the wall is [wallClearanceMm] from the wall face (ADR-040
  /// Rule 4).
  ///
  /// A section follows a wall when it is parallel to it (within 3°),
  /// overlaps it along its length, and its outer pipe is no further than
  /// `wallClearanceMm + captureMm` from the face. It is then shifted
  /// square to the wall; a corner between two such sections takes both
  /// shifts. Sections that cross a wall or run free in the room are left
  /// alone, and the first point (on the distributor) never moves.
  ///
  /// [walls] are centerline segments with their thickness; the face on
  /// the route's side is used. The result is stable: applying it again
  /// changes nothing.
  static List<Point2D> snapRouteToWalls({
    required List<Point2D> path,
    required List<({Point2D start, Point2D end, double thicknessMm})> walls,
    required double wallClearanceMm,
    required double pipeSpacingMm,
    double captureMm = wallCaptureMm,
  }) {
    final n = path.length;
    if (n < 2 || walls.isEmpty || wallClearanceMm < 0) return path;
    const sinTolerance = 0.0523; // sin 3°

    // Shift of every section, or (0, 0).
    final sx = List<double>.filled(n - 1, 0);
    final sy = List<double>.filled(n - 1, 0);
    for (var i = 0; i < n - 1; i++) {
      final p = path[i];
      final q = path[i + 1];
      final segLen = GeometryEngine.distanceMm(p, q);
      if (segLen < _tolMm) continue;
      final ux = (q.x - p.x) / segLen;
      final uy = (q.y - p.y) / segLen;
      final mx = (p.x + q.x) / 2;
      final my = (p.y + q.y) / 2;

      var bestDist = double.infinity;
      for (final w in walls) {
        final wallLen = GeometryEngine.distanceMm(w.start, w.end);
        if (wallLen < _tolMm) continue;
        final wx = (w.end.x - w.start.x) / wallLen;
        final wy = (w.end.y - w.start.y) / wallLen;
        if ((ux * wy - uy * wx).abs() > sinTolerance) continue;

        // Signed distance of the section from the wall centerline.
        final signed = (mx - w.start.x) * -wy + (my - w.start.y) * wx;
        final dist = signed.abs();
        if (dist < _tolMm || dist >= bestDist) continue;
        final target = w.thicknessMm / 2 + wallClearanceMm + pipeSpacingMm / 2;
        if (dist > target + captureMm) continue;

        // The section must run alongside the wall, not just be in line
        // with it further down the room.
        final t0 = (p.x - w.start.x) * wx + (p.y - w.start.y) * wy;
        final t1 = (q.x - w.start.x) * wx + (q.y - w.start.y) * wy;
        final overlap =
            math.min(math.max(t0, t1), wallLen + target) -
            math.max(math.min(t0, t1), -target);
        if (overlap < 0.5 * math.min(segLen, wallLen)) continue;

        bestDist = dist;
        final side = signed > 0 ? 1.0 : -1.0;
        sx[i] = -wy * side * (target - dist);
        sy[i] = wx * side * (target - dist);
      }
    }

    final out = <Point2D>[path.first];
    for (var j = 1; j < n; j++) {
      final ax = sx[j - 1];
      final ay = sy[j - 1];
      final bx = j < n - 1 ? sx[j] : 0.0;
      final by = j < n - 1 ? sy[j] : 0.0;
      final aLen = math.sqrt(ax * ax + ay * ay);
      final bLen = math.sqrt(bx * bx + by * by);
      double dx;
      double dy;
      if (aLen < 1e-9 || bLen < 1e-9) {
        dx = ax + bx;
        dy = ay + by;
      } else if ((ax * by - ay * bx).abs() < sinTolerance * aLen * bLen) {
        // Both sections follow the same wall direction — one shift.
        dx = aLen >= bLen ? ax : bx;
        dy = aLen >= bLen ? ay : by;
      } else {
        dx = ax + bx;
        dy = ay + by;
      }
      out.add(Point2D(x: path[j].x + dx, y: path[j].y + dy));
    }
    return out;
  }

  /// Lays out a pair of connection pipes for a drawn [centerline]
  /// (ADR-040): drops coincident points, applies the wall distance
  /// ([snapRouteToWalls]) and derives the supply and return pipe
  /// ([connectionPipePair]).
  ///
  /// `centerline` in the result is the adjusted route to store. All three
  /// lists are empty when fewer than 2 distinct points are given.
  static ({List<Point2D> centerline, List<Point2D> supply, List<Point2D> back})
  layOutConnectionPipes({
    required List<Point2D> centerline,
    required int pipeSpacingMm,
    required int wallClearanceMm,
    List<({Point2D start, Point2D end, double thicknessMm})> walls = const [],
    double captureMm = wallCaptureMm,
    bool supplyOnRight = false,
  }) {
    final pts = dedupePolyline(centerline);
    if (pts.length < 2 || pipeSpacingMm <= 0) {
      return (
        centerline: const <Point2D>[],
        supply: const <Point2D>[],
        back: const <Point2D>[],
      );
    }
    final snapped = dedupePolyline(
      snapRouteToWalls(
        path: pts,
        walls: walls,
        wallClearanceMm: wallClearanceMm.toDouble(),
        pipeSpacingMm: pipeSpacingMm.toDouble(),
        captureMm: captureMm,
      ),
    );
    final pair = connectionPipePair(
      centerline: snapped,
      pipeSpacingMm: pipeSpacingMm.toDouble(),
      supplyOnRight: supplyOnRight,
    );
    return (centerline: snapped, supply: pair.supply, back: pair.back);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Scanline helpers
  // ──────────────────────────────────────────────────────────────────────

  /// Intervals of the scanline at [v] that lie inside [polygon]. The
  /// scanline is horizontal (`y = v`) unless [swap], then vertical.
  static List<_Span> _spansAt(List<Point2D> polygon, double v, bool swap) {
    final crossings = <double>[];
    final n = polygon.length;
    for (var i = 0; i < n; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % n];
      final au = swap ? a.y : a.x;
      final av = swap ? a.x : a.y;
      final bu = swap ? b.y : b.x;
      final bv = swap ? b.x : b.y;
      if ((av > v) != (bv > v)) {
        crossings.add(au + (v - av) / (bv - av) * (bu - au));
      }
    }
    crossings.sort();
    final out = <_Span>[];
    for (var i = 0; i + 1 < crossings.length; i += 2) {
      if (crossings[i + 1] > crossings[i]) {
        out.add((lo: crossings[i], hi: crossings[i + 1]));
      }
    }
    return out;
  }

  static List<_Span> _intersect(List<_Span> a, List<_Span> b) {
    final out = <_Span>[];
    for (final s in a) {
      for (final t in b) {
        final lo = math.max(s.lo, t.lo);
        final hi = math.min(s.hi, t.hi);
        if (hi > lo) out.add((lo: lo, hi: hi));
      }
    }
    return out;
  }

  static List<_Span> _subtract(List<_Span> a, List<_Span> b) {
    var current = a;
    for (final cut in b) {
      final next = <_Span>[];
      for (final s in current) {
        if (cut.hi <= s.lo || cut.lo >= s.hi) {
          next.add(s);
          continue;
        }
        if (cut.lo > s.lo) next.add((lo: s.lo, hi: cut.lo));
        if (cut.hi < s.hi) next.add((lo: cut.hi, hi: s.hi));
      }
      current = next;
    }
    return current;
  }

  static double _totalLength(List<_Span> spans) =>
      spans.fold<double>(0.0, (sum, s) => sum + (s.hi - s.lo));

  // ──────────────────────────────────────────────────────────────────────
  // Route / boundary crossings
  // ──────────────────────────────────────────────────────────────────────

  /// Last crossing of [path] with the boundary of [polygon], walking from
  /// the end of the path backwards.
  static ({Point2D point, int segment})? _lastCrossing(
    List<Point2D> path,
    List<Point2D> polygon,
  ) {
    for (var i = path.length - 2; i >= 0; i--) {
      final ts = _crossingParams(path[i], path[i + 1], polygon);
      if (ts.isEmpty) continue;
      final t = ts.reduce(math.max);
      return (point: _lerp(path[i], path[i + 1], t), segment: i);
    }
    return null;
  }

  /// First crossing of [path] with the boundary of [polygon], walking
  /// from the start of the path forwards.
  static ({Point2D point, int segment})? _firstCrossing(
    List<Point2D> path,
    List<Point2D> polygon,
  ) {
    for (var i = 0; i + 1 < path.length; i++) {
      final ts = _crossingParams(path[i], path[i + 1], polygon);
      if (ts.isEmpty) continue;
      final t = ts.reduce(math.min);
      return (point: _lerp(path[i], path[i + 1], t), segment: i);
    }
    return null;
  }

  /// Parameters `t ∈ [0, 1]` at which segment [p]→[q] crosses an edge of
  /// [polygon]. Parallel (collinear) edges are ignored.
  static List<double> _crossingParams(
    Point2D p,
    Point2D q,
    List<Point2D> polygon,
  ) {
    final out = <double>[];
    final rx = q.x - p.x;
    final ry = q.y - p.y;
    final n = polygon.length;
    for (var i = 0; i < n; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % n];
      final sx = b.x - a.x;
      final sy = b.y - a.y;
      final denom = rx * sy - ry * sx;
      if (denom.abs() < 1e-9) continue;
      final t = ((a.x - p.x) * sy - (a.y - p.y) * sx) / denom;
      final s = ((a.x - p.x) * ry - (a.y - p.y) * rx) / denom;
      if (t >= -1e-9 && t <= 1 + 1e-9 && s >= -1e-9 && s <= 1 + 1e-9) {
        out.add(t.clamp(0.0, 1.0));
      }
    }
    return out;
  }

  static Point2D _lerp(Point2D a, Point2D b, double t) =>
      Point2D(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t);

  // ──────────────────────────────────────────────────────────────────────
  // Manual tube paths (ADR-046)
  // ──────────────────────────────────────────────────────────────────────

  /// Returns [path] with its first point moved to [entry] and its last
  /// point to [exit], so a manual tube stays attached to the connection
  /// pipes when they move. A missing [entry] / [exit] leaves that end as
  /// it is; fewer than 2 points are returned unchanged.
  static List<Point2D> attachManualPathEnds(
    List<Point2D> path, {
    Point2D? entry,
    Point2D? exit,
  }) {
    if (path.length < 2) return path;
    return [
      entry ?? path.first,
      ...path.sublist(1, path.length - 1),
      exit ?? path.last,
    ];
  }

  /// Snaps [raw], the next corner of a tube being drawn after [previous],
  /// for a zone with [spacingMm] between tube runs (ADR-046).
  ///
  /// 1. The new segment is made horizontal or vertical, whichever is
  ///    closer to the cursor.
  /// 2. Its end lines up with the end of an earlier parallel run of
  ///    [corners] within half a spacing, so the turns of a serpentine
  ///    form a straight column.
  /// 3. Otherwise the end lies a whole number of spacings from the
  ///    nearest run across it: a step between two rows ends exactly one
  ///    (or more) spacing from the row it leaves.
  /// 4. With no run across it yet, the end snaps to [gridMm].
  ///
  /// Without [previous] the point snaps to [gridMm] (no snap when ≤ 0).
  /// Returns [raw] for a non-positive [spacingMm].
  static Point2D snapTubePoint({
    required Point2D raw,
    required Point2D? previous,
    required List<Point2D> corners,
    required double spacingMm,
    double gridMm = 0,
  }) {
    double gridded(double v) =>
        gridMm > 0 ? (v / gridMm).roundToDouble() * gridMm : v;
    if (previous == null) return Point2D(x: gridded(raw.x), y: gridded(raw.y));
    if (spacingMm.isNaN || spacingMm <= 0) return raw;

    final horizontal = (raw.x - previous.x).abs() >= (raw.y - previous.y).abs();
    // Coordinate along the new segment — the one that is snapped.
    double along(Point2D p) => horizontal ? p.x : p.y;
    Point2D make(double a) => horizontal
        ? Point2D(x: a, y: previous.y)
        : Point2D(x: previous.x, y: a);

    final across = <double>[];
    final parallelEnds = <double>[];
    for (var i = 0; i + 1 < corners.length; i++) {
      final a = corners[i];
      final b = corners[i + 1];
      final isH = (a.y - b.y).abs() <= _tolMm && (a.x - b.x).abs() > _tolMm;
      final isV = (a.x - b.x).abs() <= _tolMm && (a.y - b.y).abs() > _tolMm;
      if (!isH && !isV) continue;
      if (isH == horizontal) {
        parallelEnds
          ..add(along(a))
          ..add(along(b));
      } else {
        // A run across the new segment: its fixed coordinate.
        across.add(horizontal ? a.x : a.y);
      }
    }

    final target = along(raw);
    double? nearest(List<double> values) => values.isEmpty
        ? null
        : values.reduce(
            (a, b) => (a - target).abs() <= (b - target).abs() ? a : b,
          );

    final end = nearest(parallelEnds);
    if (end != null && (end - target).abs() <= spacingMm / 2) {
      return make(end);
    }
    final origin = nearest(across);
    if (origin != null) {
      final steps = ((target - origin) / spacingMm).roundToDouble();
      return make(origin + steps * spacingMm);
    }
    return make(gridded(target));
  }

  /// [path] with corner [index] moved to [point]. The first and last
  /// point (attached to the connection pipes) do not move; an index out
  /// of range returns [path] unchanged.
  static List<Point2D> moveTubeCorner(
    List<Point2D> path,
    int index,
    Point2D point,
  ) {
    if (index <= 0 || index >= path.length - 1) return path;
    return [...path]..[index] = point;
  }

  /// [path] with segment [segment] (from corner `segment` to
  /// `segment + 1`) translated by ([dx], [dy]); its neighbours stretch.
  ///
  /// An end of the path stays put: moving the first or last segment
  /// inserts a corner at that end first, so the segment can still move
  /// and a jog appears (as for connection pipes, ADR-039). Returns the
  /// new path and the index of the moved segment in it.
  static ({List<Point2D> path, int segment}) moveTubeRun(
    List<Point2D> path,
    int segment,
    double dx,
    double dy,
  ) {
    if (segment < 0 || segment >= path.length - 1) {
      return (path: path, segment: segment);
    }
    final out = [...path];
    var first = segment;
    if (first == 0) {
      out.insert(0, out.first);
      first = 1;
    }
    if (first + 1 == out.length - 1) {
      out.add(out.last);
    }
    for (final i in [first, first + 1]) {
      out[i] = Point2D(x: out[i].x + dx, y: out[i].y + dy);
    }
    return (path: out, segment: first);
  }

  /// [path] with a corner inserted on segment [segment] at the point of
  /// that segment nearest to [point]. Returns [path] unchanged for an
  /// index out of range.
  static List<Point2D> insertTubeCorner(
    List<Point2D> path,
    int segment,
    Point2D point,
  ) {
    if (segment < 0 || segment >= path.length - 1) return path;
    final a = path[segment];
    final b = path[segment + 1];
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0
        ? 0.0
        : (((point.x - a.x) * dx + (point.y - a.y) * dy) / len2).clamp(
            0.0,
            1.0,
          );
    return [...path]..insert(segment + 1, _lerp(a, b, t));
  }

  /// [path] without corner [index]. The two ends cannot be removed, and a
  /// path keeps at least 2 points.
  static List<Point2D> removeTubeCorner(List<Point2D> path, int index) {
    if (index <= 0 || index >= path.length - 1 || path.length <= 2) {
      return path;
    }
    return [...path]..removeAt(index);
  }

  /// Problems with a manual tube [path] in a zone [polygon]
  /// (validation rule TP-01).
  ///
  /// - `leavesZone` — a corner lies outside the zone or a segment crosses
  ///   its boundary. The two ends sit on the boundary by construction
  ///   (where the connection pipes arrive) and are not checked.
  /// - `crossesCorridor` — a segment runs through one of the [keepOut]
  ///   strips of other circuits' connection pipes (ADR-038 Rule 3).
  /// - `selfCrossing` — two non-adjacent segments cross or touch.
  static ({bool leavesZone, bool crossesCorridor, bool selfCrossing})
  manualTubePathIssues({
    required List<Point2D> path,
    required List<Point2D> polygon,
    List<List<Point2D>> keepOut = const [],
  }) {
    const none = (
      leavesZone: false,
      crossesCorridor: false,
      selfCrossing: false,
    );
    if (path.length < 2 || polygon.length < 3) return none;

    var leaves = false;
    for (var i = 1; i < path.length - 1 && !leaves; i++) {
      if (!GeometryEngine.isPointInPolygon(path[i], polygon)) leaves = true;
    }
    for (var i = 0; i + 1 < path.length && !leaves; i++) {
      final mid = _lerp(path[i], path[i + 1], 0.5);
      if (!GeometryEngine.isPointInPolygon(mid, polygon)) {
        leaves = true;
        break;
      }
      for (var k = 0; k < polygon.length; k++) {
        if (_crossesProperly(
          path[i],
          path[i + 1],
          polygon[k],
          polygon[(k + 1) % polygon.length],
        )) {
          leaves = true;
          break;
        }
      }
    }

    var corridor = false;
    for (final strip in keepOut) {
      if (strip.length < 3 || corridor) continue;
      for (var i = 0; i + 1 < path.length && !corridor; i++) {
        final a = path[i];
        final b = path[i + 1];
        if (GeometryEngine.isPointInPolygon(_lerp(a, b, 0.5), strip)) {
          corridor = true;
          break;
        }
        for (var k = 0; k < strip.length; k++) {
          if (GeometryEngine.segmentsIntersect(
            a,
            b,
            strip[k],
            strip[(k + 1) % strip.length],
          )) {
            corridor = true;
            break;
          }
        }
      }
    }

    var self = false;
    for (var i = 0; i + 1 < path.length && !self; i++) {
      for (var j = i + 2; j + 1 < path.length; j++) {
        // The first and the last segment meet only in a closed loop.
        if (i == 0 &&
            j == path.length - 2 &&
            GeometryEngine.distanceMm(path.first, path.last) <= _tolMm) {
          continue;
        }
        if (_segmentDistanceMm(path[i], path[i + 1], path[j], path[j + 1]) <=
            _tolMm) {
          self = true;
          break;
        }
      }
    }
    return (leavesZone: leaves, crossesCorridor: corridor, selfCrossing: self);
  }

  /// True when segments [a1]→[a2] and [b1]→[b2] cross at a point inside
  /// both (touching at an end does not count).
  static bool _crossesProperly(Point2D a1, Point2D a2, Point2D b1, Point2D b2) {
    double cross(Point2D o, Point2D p, Point2D q) =>
        (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x);
    final d1 = cross(b1, b2, a1);
    final d2 = cross(b1, b2, a2);
    final d3 = cross(a1, a2, b1);
    final d4 = cross(a1, a2, b2);
    const eps = 1e-6;
    return ((d1 > eps && d2 < -eps) || (d1 < -eps && d2 > eps)) &&
        ((d3 > eps && d4 < -eps) || (d3 < -eps && d4 > eps));
  }
}

/// One evaluated meander layout.
typedef _Candidate = ({
  List<_Row> rows,
  bool swap,
  bool laneLo,
  double coverage,
  double score,
});
