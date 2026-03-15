import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/heating_circuit.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../painters/interaction_data.dart';
import 'snap_service.dart';
import 'tool_base.dart';

/// Internal state of the routing operation.
enum _Phase { idle, supply, returnLine }

/// Tool for drawing heating circuit pipe routes.
///
/// Interaction flow (UI/UX §5.5):
///  1. User clicks the distributor → route starts from the
///     distributor centre. Supply waypoints are drawn in the
///     supply-pipe colour.
///  2. User clicks waypoints to extend the supply path.
///  3. User clicks a [HeatingZone] → supply route completes.
///     Return phase begins automatically in the return-pipe colour.
///  4. User clicks waypoints for the return path.
///  5. User clicks the distributor → circuit is complete.
///     A [HeatingCircuit] is committed and the zone's
///     [HeatingZone.circuitId] is updated.
///  6. Escape discards the partial route.
///
/// Cumulative pipe length is surfaced via
/// [RouteDrawData.cumulativeLengthMm] and shown in the status bar.
/// When the cursor hovers over a zone that already has a circuit,
/// [RouteDrawData.hoveredZoneAlreadyConnected] triggers a warning
/// indicator in the interaction painter.
class RouteDrawTool extends CanvasTool {
  /// Creates a [RouteDrawTool].
  RouteDrawTool({
    required super.callbacks,
    required super.onStateChanged,
  });

  _Phase _phase = _Phase.idle;
  final List<Point2D> _supplyPoints = [];
  final List<Point2D> _returnPoints = [];
  String? _targetZoneId;
  Point2D? _current;
  bool _hoveredZoneConnected = false;

  /// World-space hit radius for the distributor (mm).
  ///
  /// Covers the distributor body with comfortable click
  /// tolerance regardless of zoom level.
  static const double _distributorHitRadiusMm = 400.0;

  @override
  String get name => 'Route Pipe';

  @override
  void onTap(
    Point2D worldPoint,
    PointerDeviceKind deviceKind,
  ) {
    final snapped = SnapService.snapToGrid(worldPoint);
    switch (_phase) {
      case _Phase.idle:
        if (_isOnDistributor(worldPoint)) {
          final pos =
              callbacks.currentDistributor!.position;
          _supplyPoints.add(pos);
          _phase = _Phase.supply;
          onStateChanged();
        }

      case _Phase.supply:
        final zone = _zoneAt(worldPoint);
        if (zone != null) {
          // Finalise supply path at the snapped click point.
          _supplyPoints.add(snapped);
          _targetZoneId = zone.id;
          // Begin return path from the same point.
          _returnPoints.add(snapped);
          _phase = _Phase.returnLine;
          onStateChanged();
          return;
        }
        // Add a supply waypoint.
        _supplyPoints.add(snapped);
        onStateChanged();

      case _Phase.returnLine:
        if (_isOnDistributor(worldPoint)) {
          final pos =
              callbacks.currentDistributor!.position;
          _returnPoints.add(pos);
          _commitCircuit();
          return;
        }
        // Add a return waypoint.
        _returnPoints.add(snapped);
        onStateChanged();
    }
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    _current = worldPoint;
    // Show warning when hovering over an already-routed zone.
    if (_phase == _Phase.supply) {
      final zone = _zoneAt(worldPoint);
      _hoveredZoneConnected =
          zone != null && zone.circuitId != null;
    } else {
      _hoveredZoneConnected = false;
    }
    onStateChanged();
  }

  @override
  void cancel() => _reset();

  @override
  InteractionData? getInteractionData() {
    if (_phase == _Phase.idle) return null;
    return RouteDrawData(
      phase: _phase == _Phase.supply
          ? RoutePhase.supply
          : RoutePhase.returnLine,
      supplyPoints: List.unmodifiable(_supplyPoints),
      returnPoints: List.unmodifiable(_returnPoints),
      currentPoint: _current,
      hoveredZoneAlreadyConnected: _hoveredZoneConnected,
      cumulativeLengthMm: _cumulativeLengthMm(),
    );
  }

  // ----------------------------------------------------------------
  // Private helpers
  // ----------------------------------------------------------------

  /// True if [point] is within [_distributorHitRadiusMm] of
  /// the current distributor centre.
  bool _isOnDistributor(Point2D point) {
    final dist = callbacks.currentDistributor;
    if (dist == null) return false;
    return GeometryEngine.distanceMm(
          point,
          dist.position,
        ) <=
        _distributorHitRadiusMm;
  }

  /// Returns the first heating zone (floor or wall) whose polygon
  /// contains [point], or null.
  HeatingZone? _zoneAt(Point2D point) {
    for (final zone in callbacks.currentZones) {
      if (zone.polygon.length >= 3 &&
          GeometryEngine.isPointInPolygon(
            point,
            zone.polygon,
          )) {
        return zone;
      }
    }
    return null;
  }

  /// Total length of all committed segments plus the ghost
  /// edge to the cursor, in mm.
  double _cumulativeLengthMm() {
    var total = 0.0;
    for (var i = 0; i < _supplyPoints.length - 1; i++) {
      total += GeometryEngine.distanceMm(
        _supplyPoints[i],
        _supplyPoints[i + 1],
      );
    }
    for (var i = 0; i < _returnPoints.length - 1; i++) {
      total += GeometryEngine.distanceMm(
        _returnPoints[i],
        _returnPoints[i + 1],
      );
    }
    if (_current != null) {
      final last = _phase == _Phase.returnLine &&
              _returnPoints.isNotEmpty
          ? _returnPoints.last
          : (_supplyPoints.isNotEmpty
              ? _supplyPoints.last
              : null);
      if (last != null) {
        total +=
            GeometryEngine.distanceMm(last, _current!);
      }
    }
    return total;
  }

  /// Validate, build, and commit the completed circuit.
  void _commitCircuit() {
    final zoneId = _targetZoneId;
    if (zoneId == null ||
        _supplyPoints.length < 2 ||
        _returnPoints.length < 2) {
      _reset();
      return;
    }

    final circuitId = IdGenerator.newId();
    final circuit = HeatingCircuit(
      id: circuitId,
      distributorId: callbacks.currentDistributor!.id,
      heatingZoneId: zoneId,
      supplyRoutePath: List<Point2D>.from(_supplyPoints),
      returnRoutePath: List<Point2D>.from(_returnPoints),
    );

    callbacks.commitCircuit(circuit);

    // Update the zone to record its circuit link.
    final zone = callbacks.currentZones
        .cast<HeatingZone?>()
        .firstWhere(
          (z) => z?.id == zoneId,
          orElse: () => null,
        );
    if (zone != null) {
      callbacks.updateZone(
        zone.copyWith(circuitId: circuitId),
      );
    }

    _reset();
  }

  void _reset() {
    _phase = _Phase.idle;
    _supplyPoints.clear();
    _returnPoints.clear();
    _targetZoneId = null;
    _current = null;
    _hoveredZoneConnected = false;
    onStateChanged();
  }
}
