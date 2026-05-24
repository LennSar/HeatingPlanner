import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/heating_circuit.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import 'undo_redo_service.dart';

/// Direction of an ADR-018 zone split.
enum SplitDirection {
  /// Bisect along the perpendicular to the X axis — left/right halves.
  vertical,

  /// Bisect along the perpendicular to the Y axis — top/bottom halves.
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

/// The selected zone is not rectangular (ADR-018 Rule 1).
class SplitBuildRejectedNonRectangular extends SplitBuildResult {
  /// Creates a [SplitBuildRejectedNonRectangular].
  const SplitBuildRejectedNonRectangular();
}

/// Either child would be < 100 mm (ADR-018 Rule 4).
class SplitBuildRejectedTooSmall extends SplitBuildResult {
  /// Creates a [SplitBuildRejectedTooSmall].
  const SplitBuildRejectedTooSmall();
}

/// Command: split a rectangular heating zone in two equal halves.
///
/// Shared by [ZoneDrawTool] (double-click on a rectangular zone, ADR-018
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

  /// Returns the split direction the Zone tool double-click would choose
  /// for [polygon] (ADR-018 Rule 3 — bisect the longer side; tie → vertical).
  /// Returns null when [polygon] is not rectangle-eligible.
  static SplitDirection? doubleClickDirection(List<Point2D> polygon) {
    if (!isRectangularZone(polygon)) return null;
    final xs = polygon.map((p) => p.x).toList()..sort();
    final ys = polygon.map((p) => p.y).toList()..sort();
    final w = xs.last - xs.first;
    final h = ys.last - ys.first;
    if ((w - h).abs() <= 1.0) return SplitDirection.vertical;
    return w >= h ? SplitDirection.vertical : SplitDirection.horizontal;
  }

  /// Computes the perpendicular bisector along the longer side of a
  /// rectangular [polygon] — the line a Zone tool double-click would cut
  /// along. Returns `(start, end)` in world mm, or null when [polygon] is
  /// not rectangle-eligible. World coordinates only — no grid snap (ADR-
  /// 018 Rule 2 final sentence).
  static ({Point2D start, Point2D end})? bisectorForDoubleClick(
    List<Point2D> polygon,
  ) {
    final dir = doubleClickDirection(polygon);
    if (dir == null) return null;
    final xs = polygon.map((p) => p.x).toList()..sort();
    final ys = polygon.map((p) => p.y).toList()..sort();
    final minX = xs.first;
    final maxX = xs.last;
    final minY = ys.first;
    final maxY = ys.last;
    if (dir == SplitDirection.vertical) {
      final mx = (minX + maxX) / 2;
      return (
        start: Point2D(x: mx, y: minY),
        end: Point2D(x: mx, y: maxY),
      );
    }
    final my = (minY + maxY) / 2;
    return (
      start: Point2D(x: minX, y: my),
      end: Point2D(x: maxX, y: my),
    );
  }

  /// Builds the two child polygons for splitting [polygon] along [dir]
  /// (ADR-018 Rule 2). Child A is left/top; child B is right/bottom.
  /// Caller is responsible for the rectangle / size eligibility checks.
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
    if (!isRectangularZone(parent.polygon)) {
      return const SplitBuildRejectedNonRectangular();
    }

    final xs = parent.polygon.map((p) => p.x).toList()..sort();
    final ys = parent.polygon.map((p) => p.y).toList()..sort();
    final w = xs.last - xs.first;
    final h = ys.last - ys.first;
    final bisectedSide = direction == SplitDirection.vertical ? w : h;
    if (bisectedSide / 2 < minHalfMm) {
      return const SplitBuildRejectedTooSmall();
    }

    final polys = childPolygons(parent.polygon, direction);
    final childA = parent.copyWith(
      id: IdGenerator.newId(),
      polygon: polys.a,
      circuitId: null,
    );
    final childB = parent.copyWith(
      id: IdGenerator.newId(),
      polygon: polys.b,
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
