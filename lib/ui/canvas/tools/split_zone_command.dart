import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/heating_circuit.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import 'undo_redo_service.dart';

/// Direction of an ADR-018 zone split.
enum SplitDirection {
  /// Cut along a vertical line — left/right halves.
  vertical,

  /// Cut along a horizontal line — top/bottom halves.
  horizontal,
}

/// Outcome of [SplitZoneCommand.tryBuild].
sealed class SplitBuildResult {
  const SplitBuildResult();
}

/// Split is valid — [command] is ready for `undoRedo.execute`.
class SplitBuildOk extends SplitBuildResult {
  /// Creates a [SplitBuildOk].
  const SplitBuildOk(this.command);

  /// The command to push onto [UndoRedoService].
  final SplitZoneCommand command;
}

/// The zone's shape cannot be cut into two pieces along the requested
/// direction (ADR-037 Rule 1).
class SplitBuildRejectedShape extends SplitBuildResult {
  /// Creates a [SplitBuildRejectedShape].
  const SplitBuildRejectedShape();
}

/// Either child would be < 100 mm (ADR-018 Rule 4).
class SplitBuildRejectedTooSmall extends SplitBuildResult {
  /// Creates a [SplitBuildRejectedTooSmall].
  const SplitBuildRejectedTooSmall();
}

/// Command: split a heating zone in two halves of equal area.
///
/// Shared by [ZoneDrawTool] (double-click on a floor zone, ADR-018
/// Rule 1.1) and [SelectTool] (right-click context menu, ADR-018 Rule 1.2).
/// Lives alongside [CreateZoneCommand] / [_MoveZoneCommand] /
/// [_DeleteZoneCommand]. See `DECISIONS.md` ADR-018 Rule 7.
///
/// `execute` removes [parent], inserts [childA] and [childB], and — when
/// [parentCircuit] is non-null — re-points its zone-FK to whichever child
/// inherits the circuit ([childWithCircuit]).
///
/// `undo` removes both children, re-inserts the captured [parent] (same
/// `id` and fields), and restores the circuit's zone-FK to the parent.
///
/// `redo` replays `execute` with the same captured child ids so the
/// re-insertion is byte-identical (ADR-018 Rule 7).
class SplitZoneCommand extends Command {
  /// Creates a [SplitZoneCommand].
  SplitZoneCommand({
    required this.parent,
    required this.childA,
    required this.childB,
    required this.parentCircuit,
    required this.childWithCircuit,
    required this.add,
    required this.remove,
    required this.updateCircuit,
    required this.label,
  });

  /// The original zone removed on [execute] and restored on [undo].
  final HeatingZone parent;

  /// First child (left for vertical split, top for horizontal split).
  final HeatingZone childA;

  /// Second child (right for vertical split, bottom for horizontal split).
  final HeatingZone childB;

  /// The parent zone's circuit at command-creation time, or null when
  /// the parent had no circuit.
  final HeatingCircuit? parentCircuit;

  /// Which child inherits [parentCircuit]. Either [childA] or [childB],
  /// or null when there is no circuit to reassign.
  final HeatingZone? childWithCircuit;

  /// Adds a zone to editor state (typically `EditorCallbacks.commitZone`).
  final void Function(HeatingZone) add;

  /// Removes a zone by id (typically `EditorCallbacks.removeZone`).
  final void Function(String) remove;

  /// Replaces an existing circuit (typically
  /// `EditorCallbacks.updateCircuit`). Used to swap the circuit's
  /// `heatingZoneId` between the parent and the inheriting child.
  final void Function(HeatingCircuit) updateCircuit;

  @override
  final String label;

  @override
  void execute() {
    remove(parent.id);
    add(childA);
    add(childB);
    if (parentCircuit != null && childWithCircuit != null) {
      updateCircuit(
        parentCircuit!.copyWith(heatingZoneId: childWithCircuit!.id),
      );
    }
  }

  @override
  void undo() {
    remove(childA.id);
    remove(childB.id);
    add(parent);
    if (parentCircuit != null) {
      updateCircuit(parentCircuit!);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Static helpers shared by ZoneDrawTool (double-click, ADR-018 Rule 1.1)
  // and SelectTool (right-click menu, ADR-018 Rule 1.2).
  // ──────────────────────────────────────────────────────────────────────

  /// Minimum half-dimension after a split, in mm (ADR-018 Rule 4 —
  /// inherits the ADR-013 Rule 5 zone-side minimum).
  static const double minHalfMm = 100.0;

  /// True when [polygon] is a 4-vertex axis-aligned rectangle within 1 mm
  /// tolerance (ADR-018 Rule 1; mirrors `SelectTool.rectangleZoneCorners`).
  static bool isRectangularZone(List<Point2D> polygon) {
    if (polygon.length != 4) return false;
    const tol = 1.0;
    final xs = <double>[];
    final ys = <double>[];
    for (final p in polygon) {
      if (!xs.any((v) => (v - p.x).abs() < tol)) xs.add(p.x);
      if (!ys.any((v) => (v - p.y).abs() < tol)) ys.add(p.y);
    }
    return xs.length == 2 && ys.length == 2;
  }

  /// Computes the cut that divides [polygon] along [dir] into two halves
  /// of **equal area** (ADR-037 Rule 2).
  ///
  /// For a rectangle this is the ADR-018 midpoint bisector with the
  /// ADR-018 Rule 2 vertex order. For any other simple polygon the cut
  /// line is moved until both sides have the same area, so an L-shaped
  /// zone still yields two equally sized children.
  ///
  /// `at` is the cut coordinate (x for [SplitDirection.vertical], y for
  /// [SplitDirection.horizontal]); `a` is the left/top child, `b` the
  /// right/bottom child; `start`/`end` are the ends of the cut segment.
  ///
  /// Returns null when the shape cannot be cut along [dir] into exactly
  /// two pieces (e.g. the line would cross a U-shaped zone twice).
  static ({
    double at,
    List<Point2D> a,
    List<Point2D> b,
    Point2D start,
    Point2D end,
  })? equalAreaCut(List<Point2D> polygon, SplitDirection dir) {
    if (polygon.length < 3) return null;
    final alongX = dir == SplitDirection.vertical;

    if (isRectangularZone(polygon)) {
      final polys = childPolygons(polygon, dir);
      final xs = polygon.map((p) => p.x).toList()..sort();
      final ys = polygon.map((p) => p.y).toList()..sort();
      final at = alongX
          ? (xs.first + xs.last) / 2
          : (ys.first + ys.last) / 2;
      return (
        at: at,
        a: polys.a,
        b: polys.b,
        start: alongX
            ? Point2D(x: at, y: ys.first)
            : Point2D(x: xs.first, y: at),
        end: alongX
            ? Point2D(x: at, y: ys.last)
            : Point2D(x: xs.last, y: at),
      );
    }

    if (!GeometryEngine.isSimplePolygon(polygon)) return null;
    final totalM2 = GeometryEngine.polygonAreaM2(polygon);
    if (totalM2.isNaN || totalM2 <= 0) return null;

    double coord(Point2D p) => alongX ? p.x : p.y;
    final coords = polygon.map(coord).toList()..sort();
    var lo = coords.first;
    var hi = coords.last;
    if (hi - lo < 1e-6) return null;

    List<Point2D> side(double at, {required bool lower}) =>
        GeometryEngine.clipPolygonToHalfPlane(
          polygon: polygon,
          alongX: alongX,
          at: at,
          keepLower: lower,
        );
    double lowerAreaM2(double at) {
      final clipped = side(at, lower: true);
      return clipped.isEmpty ? 0.0 : GeometryEngine.polygonAreaM2(clipped);
    }

    // The lower-side area grows monotonically with the cut coordinate.
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (lowerAreaM2(mid) < totalM2 / 2) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final at = (lo + hi) / 2;

    final a = GeometryEngine.removeCollinearVertices(side(at, lower: true));
    final b = GeometryEngine.removeCollinearVertices(side(at, lower: false));
    if (a.length < 3 || b.length < 3) return null;
    if (!GeometryEngine.isSimplePolygon(a) ||
        !GeometryEngine.isSimplePolygon(b)) {
      return null;
    }
    // Exactly two vertices on the line per child = one clean cut
    // segment. More means the line crossed the shape more than once.
    List<Point2D> onLine(List<Point2D> poly) =>
        poly.where((p) => (coord(p) - at).abs() < 1e-3).toList();
    final cutA = onLine(a);
    if (cutA.length != 2 || onLine(b).length != 2) return null;
    final areaA = GeometryEngine.polygonAreaM2(a);
    final areaB = GeometryEngine.polygonAreaM2(b);
    if ((areaA - areaB).abs() > 1e-3 * totalM2) return null;

    double other(Point2D p) => alongX ? p.y : p.x;
    cutA.sort((p, q) => other(p).compareTo(other(q)));
    return (at: at, a: a, b: b, start: cutA.first, end: cutA.last);
  }

  /// True when [polygon] can be split into two equal halves in at least
  /// one direction (ADR-037 Rule 1).
  static bool canSplit(List<Point2D> polygon) =>
      doubleClickDirection(polygon) != null;

  /// Returns the split direction the Zone tool double-click would choose
  /// for [polygon]: bisect the longer side of its bounding box (tie →
  /// vertical, ADR-018 Rule 3), falling back to the other direction when
  /// the shape cannot be cut that way (ADR-037 Rule 3). Returns null when
  /// neither direction yields two pieces.
  static SplitDirection? doubleClickDirection(List<Point2D> polygon) {
    if (polygon.length < 3) return null;
    final xs = polygon.map((p) => p.x).toList()..sort();
    final ys = polygon.map((p) => p.y).toList()..sort();
    final w = xs.last - xs.first;
    final h = ys.last - ys.first;
    final preferred = (w - h).abs() <= 1.0 || w >= h
        ? SplitDirection.vertical
        : SplitDirection.horizontal;
    if (equalAreaCut(polygon, preferred) != null) return preferred;
    final fallback = preferred == SplitDirection.vertical
        ? SplitDirection.horizontal
        : SplitDirection.vertical;
    return equalAreaCut(polygon, fallback) != null ? fallback : null;
  }

  /// Computes the line a Zone tool double-click would cut [polygon]
  /// along — the equal-area cut in [doubleClickDirection]. Returns
  /// `(start, end)` in world mm, or null when [polygon] cannot be split.
  /// World coordinates only — no grid snap (ADR-018 Rule 2 final
  /// sentence).
  static ({Point2D start, Point2D end})? bisectorForDoubleClick(
    List<Point2D> polygon,
  ) {
    final dir = doubleClickDirection(polygon);
    if (dir == null) return null;
    final cut = equalAreaCut(polygon, dir);
    if (cut == null) return null;
    return (start: cut.start, end: cut.end);
  }

  /// Builds the two child polygons for splitting a **rectangular**
  /// [polygon] along [dir] (ADR-018 Rule 2). Child A is left/top; child B
  /// is right/bottom. Non-rectangular zones go through [equalAreaCut].
  static ({List<Point2D> a, List<Point2D> b}) childPolygons(
    List<Point2D> polygon,
    SplitDirection dir,
  ) {
    final xs = polygon.map((p) => p.x).toList()..sort();
    final ys = polygon.map((p) => p.y).toList()..sort();
    final minX = xs.first;
    final maxX = xs.last;
    final minY = ys.first;
    final maxY = ys.last;
    final tl = Point2D(x: minX, y: minY);
    final tr = Point2D(x: maxX, y: minY);
    final br = Point2D(x: maxX, y: maxY);
    final bl = Point2D(x: minX, y: maxY);
    if (dir == SplitDirection.vertical) {
      final mx = (minX + maxX) / 2;
      final mt = Point2D(x: mx, y: minY);
      final mb = Point2D(x: mx, y: maxY);
      return (a: [tl, mt, mb, bl], b: [mt, tr, br, mb]);
    }
    final my = (minY + maxY) / 2;
    final ml = Point2D(x: minX, y: my);
    final mr = Point2D(x: maxX, y: my);
    return (a: [tl, tr, mr, ml], b: [ml, mr, br, bl]);
  }

  /// Attempts to build a [SplitZoneCommand] for splitting [parent] along
  /// [direction]. Returns a discriminated [SplitBuildResult] so callers
  /// can dispatch the right toast on rejection (ADR-018 Rule 4 / Rule 9).
  ///
  /// [circuits] is the editor's current circuit list — used to find the
  /// pipe terminus inside [parent] and pick the inheriting child (ADR-018
  /// Rule 6). [add], [remove], and [updateCircuit] are the editor mutators
  /// the command will invoke.
  static SplitBuildResult tryBuild({
    required HeatingZone parent,
    required SplitDirection direction,
    required Iterable<HeatingCircuit> circuits,
    required String label,
    required void Function(HeatingZone) add,
    required void Function(String) remove,
    required void Function(HeatingCircuit) updateCircuit,
  }) {
    final cut = equalAreaCut(parent.polygon, direction);
    if (cut == null) {
      return const SplitBuildRejectedShape();
    }

    // Each child must be at least [minHalfMm] deep across the cut.
    double coord(Point2D p) =>
        direction == SplitDirection.vertical ? p.x : p.y;
    final coords = parent.polygon.map(coord).toList()..sort();
    if (cut.at - coords.first < minHalfMm ||
        coords.last - cut.at < minHalfMm) {
      return const SplitBuildRejectedTooSmall();
    }

    final childA = parent.copyWith(
      id: IdGenerator.newId(),
      polygon: cut.a,
      circuitId: null,
    );
    final childB = parent.copyWith(
      id: IdGenerator.newId(),
      polygon: cut.b,
      circuitId: null,
    );

    HeatingCircuit? parentCircuit;
    HeatingZone? childWithCircuit;
    if (parent.circuitId != null) {
      parentCircuit = circuits
          .where((c) => c.id == parent.circuitId)
          .firstOrNull;
      if (parentCircuit != null) {
        final terminus = _pipeTerminusInsideParent(parentCircuit, parent);
        if (terminus != null &&
            GeometryEngine.isPointInPolygon(terminus, childB.polygon)) {
          childWithCircuit = childB.copyWith(circuitId: parent.circuitId);
        } else {
          // Default fallback: child A (left/top) keeps the circuit
          // (ADR-018 Rule 6 edge case).
          childWithCircuit = childA.copyWith(circuitId: parent.circuitId);
        }
      }
    }

    final finalChildA = childWithCircuit?.id == childA.id
        ? childWithCircuit!
        : childA;
    final finalChildB = childWithCircuit?.id == childB.id
        ? childWithCircuit!
        : childB;

    return SplitBuildOk(
      SplitZoneCommand(
        parent: parent,
        childA: finalChildA,
        childB: finalChildB,
        parentCircuit: parentCircuit,
        childWithCircuit: childWithCircuit,
        add: add,
        remove: remove,
        updateCircuit: updateCircuit,
        label: label,
      ),
    );
  }

  /// Returns the supply/return polyline endpoint of [circuit] that lies
  /// inside [parent]'s polygon, or null when neither endpoint lies inside
  /// (e.g. float drift). Tries supply-end first, then return-start.
  static Point2D? _pipeTerminusInsideParent(
    HeatingCircuit circuit,
    HeatingZone parent,
  ) {
    if (circuit.supplyRoutePath.isNotEmpty) {
      final p = circuit.supplyRoutePath.last;
      if (GeometryEngine.isPointInPolygon(p, parent.polygon)) return p;
    }
    if (circuit.returnRoutePath.isNotEmpty) {
      final p = circuit.returnRoutePath.first;
      if (GeometryEngine.isPointInPolygon(p, parent.polygon)) return p;
    }
    return null;
  }
}
