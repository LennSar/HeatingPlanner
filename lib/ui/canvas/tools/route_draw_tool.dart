import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../calculation/engines/pipe_layout_engine.dart';
import '../../../calculation/providers/pipe_layout_providers.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/heating_circuit.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../painters/interaction_data.dart';
import 'circuit_commands.dart';
import 'snap_service.dart';
import 'tool_base.dart';
import 'undo_redo_service.dart';

/// Tool for drawing the connection pipes of a heating circuit — the
/// supply and return run between the distributor and a zone (ADR-040).
///
/// Interaction flow:
///  1. Click the distributor — the route starts at its centre.
///  2. Click to place route points. A click inside a heating zone is an
///     ordinary route point, so the route can cross the zone the
///     distributor stands in and any zone on the way.
///  3. **Double-click inside the heating zone to connect.** The circuit
///     is committed and the zone's [HeatingZone.circuitId] is set.
///  4. Escape discards the route.
///
/// Only one line is drawn. The supply and the return pipe are laid out
/// parallel to it on every pointer move — [HeatingCircuit.pipeSpacingMm]
/// apart and [HeatingCircuit.wallClearanceMm] from walls the route runs
/// along — and surfaced through [RouteDrawData], so the preview always
/// shows what a double-click would commit.
///
/// A new circuit takes its three distances from the most recently drawn
/// circuit, so a value set once in the properties panel carries over to
/// the next pipes.
class RouteDrawTool extends CanvasTool {
  /// Creates a [RouteDrawTool].
  RouteDrawTool({
    required super.callbacks,
    required super.onStateChanged,
    required this.undoRedo,
  });

  /// Undo/redo stack — connecting a zone is one undo entry (ADR-042).
  final UndoRedoService undoRedo;

  /// Route points placed so far (grid-snapped clicks). The first one is
  /// the distributor centre. Empty while idle.
  final List<Point2D> _points = [];

  /// Raw cursor position, or null before the first pointer move.
  Point2D? _cursor;

  DateTime? _lastTapTime;
  Point2D? _lastTapPos;

  /// World-space hit radius for the distributor (mm).
  ///
  /// Covers the distributor body with comfortable click
  /// tolerance regardless of zoom level.
  static const double _distributorHitRadiusMm = 400.0;

  /// Two taps closer than this (and within [_doubleTapWindow]) form a
  /// double-click.
  static const double _doubleTapDistanceMm = 200.0;

  static const Duration _doubleTapWindow = Duration(milliseconds: 300);

  @override
  String get name => 'Route Pipe';

  /// True while a route is being drawn.
  bool get isDrawing => _points.isNotEmpty;

  @override
  void onTap(
    Point2D worldPoint,
    PointerDeviceKind deviceKind,
  ) {
    final now = DateTime.now();
    final isDoubleTap = _lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapWindow &&
        _lastTapPos != null &&
        GeometryEngine.distanceMm(worldPoint, _lastTapPos!) <=
            _doubleTapDistanceMm;
    _lastTapTime = now;
    _lastTapPos = worldPoint;

    if (!isDrawing) {
      // The route can only start on the distributor.
      if (_isOnDistributor(worldPoint)) {
        _points.add(callbacks.currentDistributor!.position);
        _cursor = worldPoint;
        // The starting click must not count as half of a double-click.
        _lastTapTime = null;
        onStateChanged();
      }
      return;
    }

    if (isDoubleTap) {
      _finishAt(worldPoint);
      return;
    }

    final snapped = SnapService.snapToGrid(
      worldPoint,
      callbacks.currentGridSpacingMm,
    );
    if (GeometryEngine.distanceMm(snapped, _points.last) > 1.0) {
      _points.add(snapped);
    }
    _cursor = worldPoint;
    onStateChanged();
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    _cursor = worldPoint;
    onStateChanged();
  }

  @override
  void cancel() => _reset();

  @override
  InteractionData? getInteractionData() {
    if (!isDrawing) return null;
    final cursor = _cursor;
    final route = [
      ..._points,
      if (cursor != null)
        SnapService.snapToGrid(cursor, callbacks.currentGridSpacingMm),
    ];
    final draft = _layOut(route);
    final hovered = cursor == null ? null : _zoneAt(cursor);
    return RouteDrawData(
      supplyPoints: draft?.supplyRoutePath ?? const [],
      returnPoints: draft?.returnRoutePath ?? const [],
      // Without the cursor point: only what has been placed.
      waypoints: _layOut(_points)?.centerlinePath ??
          List.unmodifiable(_points),
      currentPoint: cursor,
      hoveredZoneAlreadyConnected:
          hovered != null && hovered.circuitId != null,
      hoveredZoneConnectable: hovered != null && hovered.circuitId == null,
      cumulativeLengthMm: draft == null
          ? 0.0
          : GeometryEngine.polylineLengthMm(draft.supplyRoutePath) +
              GeometryEngine.polylineLengthMm(draft.returnRoutePath),
    );
  }

  // ----------------------------------------------------------------
  // Private helpers
  // ----------------------------------------------------------------

  /// Connects the route to the zone under [worldPoint] (the position of
  /// the double-click). The first click of the double-click has already
  /// placed the last route point.
  void _finishAt(Point2D worldPoint) {
    final zone = _zoneAt(worldPoint);
    if (zone == null) {
      callbacks.showToast(callbacks.l10n.route_doubleClickInZoneToast);
      return;
    }
    if (zone.circuitId != null) {
      callbacks.showToast(callbacks.l10n.route_zoneAlreadyConnectedToast);
      return;
    }

    // Make sure the route ends at the double-click position.
    final end = SnapService.snapToGrid(
      worldPoint,
      callbacks.currentGridSpacingMm,
    );
    final route = [
      ..._points,
      if (GeometryEngine.distanceMm(end, _points.last) > 1.0) end,
    ];
    final circuit = _layOut(route, zoneId: zone.id);
    if (circuit == null ||
        !GeometryEngine.isPointInPolygon(
          circuit.centerlinePath.last,
          zone.polygon,
        )) {
      callbacks.showToast(callbacks.l10n.route_doubleClickInZoneToast);
      return;
    }

    undoRedo.execute(CreateCircuitCommand(
      circuit: circuit,
      zoneBefore: zone,
      add: callbacks.commitCircuit,
      remove: callbacks.removeCircuit,
      updateZone: callbacks.updateZone,
      label: callbacks.l10n.undo_drawConnectionPipe,
    ));
    _reset();
  }

  /// Builds the circuit for [route], or null when it has fewer than two
  /// distinct points or there is no distributor.
  HeatingCircuit? _layOut(List<Point2D> route, {String zoneId = ''}) {
    final distributor = callbacks.currentDistributor;
    if (distributor == null) return null;
    // Distances carry over from the most recently drawn pair of pipes.
    final template = callbacks.currentCircuits
        .where((c) => c.centerlinePath.length >= 2)
        .lastOrNull;
    final circuit = relaidConnectionPipes(
      HeatingCircuit(
        id: IdGenerator.newId(),
        distributorId: distributor.id,
        heatingZoneId: zoneId,
        pipeSpacingMm: template?.pipeSpacingMm ?? 100,
        zoneClearanceMm: template?.zoneClearanceMm ?? 100,
        wallClearanceMm: template?.wallClearanceMm ?? 100,
        supplyPipeInsulationType: template?.supplyPipeInsulationType,
      ),
      callbacks.currentWalls,
      centerline: PipeLayoutEngine.dedupePolyline(route),
    );
    return circuit.centerlinePath.length < 2 ? null : circuit;
  }

  /// True if [point] is within [_distributorHitRadiusMm] of
  /// the current distributor centre.
  bool _isOnDistributor(Point2D point) {
    final dist = callbacks.currentDistributor;
    if (dist == null) return false;
    return GeometryEngine.distanceMm(point, dist.position) <=
        _distributorHitRadiusMm;
  }

  /// Returns the heating zone (floor or wall) whose polygon contains
  /// [point], preferring an unconnected one when zones overlap; null
  /// when there is none.
  HeatingZone? _zoneAt(Point2D point) {
    HeatingZone? connected;
    for (final zone in callbacks.currentZones) {
      if (zone.polygon.length < 3 ||
          !GeometryEngine.isPointInPolygon(point, zone.polygon)) {
        continue;
      }
      if (zone.circuitId == null) return zone;
      connected ??= zone;
    }
    return connected;
  }

  void _reset() {
    _points.clear();
    _cursor = null;
    _lastTapTime = null;
    _lastTapPos = null;
    onStateChanged();
  }
}
