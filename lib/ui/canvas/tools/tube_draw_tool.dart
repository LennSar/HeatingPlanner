import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../calculation/engines/pipe_layout_engine.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../painters/interaction_data.dart';
import 'modifier_draw_tool.dart';
import 'tool_base.dart';
import 'tube_path_command.dart';
import 'undo_redo_service.dart';

/// Tool for drawing the tube inside a floor heating zone by hand
/// (ADR-046).
///
/// Interaction flow:
///  1. Click inside a floor zone. A connected zone's tube starts where its
///     supply pipe enters the zone; an unconnected zone's at the click.
///  2. Click to place corners. With snapping on (the panel toggle), each
///     segment is horizontal or vertical, rows lie a whole tube spacing
///     apart and turns line up in a column ([PipeLayoutEngine.snapTubePoint]).
///     **Alt** places the current corner freely. Corners outside the zone
///     are refused.
///  3. **Double-click** to finish. A connected zone's tube then runs on to
///     where its return pipe leaves the zone. The tube is stored as the
///     zone's [HeatingZone.manualTubePath] — one undo step, replacing any
///     earlier manual or automatic tube.
///  4. **Backspace / Delete** removes the last corner; **Escape** discards
///     the tube.
///
/// The preview shows the tube with its bend radius and its length.
class TubeDrawTool extends CanvasTool with ModifierDrawTool {
  /// Creates a [TubeDrawTool].
  TubeDrawTool({
    required super.callbacks,
    required super.onStateChanged,
    required this.undoRedo,
    required this.tubeCorners,
    required this.bendRadiusMm,
    required this.snapEnabled,
  });

  /// Undo/redo stack — a finished tube is one entry.
  final UndoRedoService undoRedo;

  /// Corner polyline of the tube currently drawn in a zone, by zone id;
  /// its first and last point are the supply entry and the return exit.
  final List<Point2D>? Function(String zoneId) tubeCorners;

  /// Bend radius of the tube in a zone (mm), for the preview.
  final double Function(String zoneId) bendRadiusMm;

  /// Whether snapping is on (the panel toggle). Alt overrides it.
  final bool Function() snapEnabled;

  String? _zoneId;
  final List<Point2D> _points = [];

  /// Where a connected zone's return pipe leaves it; null otherwise.
  Point2D? _exit;
  Point2D? _cursor;

  DateTime? _lastTapTime;
  Point2D? _lastTapPos;

  static const double _doubleTapDistanceMm = 200.0;
  static const Duration _doubleTapWindow = Duration(milliseconds: 300);

  @override
  String get name => 'Draw Tube';

  /// True while a tube is being drawn.
  bool get isDrawing => _points.isNotEmpty;

  HeatingZone? get _zone {
    final id = _zoneId;
    if (id == null) return null;
    return callbacks.currentZones.where((z) => z.id == id).firstOrNull;
  }

  @override
  void onTap(Point2D worldPoint, PointerDeviceKind deviceKind) {
    syncModifiersFromHardware();
    final now = DateTime.now();
    final isDoubleTap = _lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapWindow &&
        _lastTapPos != null &&
        GeometryEngine.distanceMm(worldPoint, _lastTapPos!) <=
            _doubleTapDistanceMm;
    _lastTapTime = now;
    _lastTapPos = worldPoint;

    if (!isDrawing) {
      _start(worldPoint);
      return;
    }
    if (isDoubleTap) {
      _finish();
      return;
    }
    final zone = _zone;
    if (zone == null) {
      _reset();
      return;
    }
    final point = _snap(worldPoint, zone);
    if (!GeometryEngine.isPointInPolygon(point, zone.polygon)) {
      callbacks.showToast(callbacks.l10n.tube_mustStayInZoneToast);
      return;
    }
    if (GeometryEngine.distanceMm(point, _points.last) > 1.0) {
      _points.add(point);
    }
    _cursor = worldPoint;
    onStateChanged();
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    if (!isDrawing) return;
    _cursor = worldPoint;
    onStateChanged();
  }

  @override
  void onDelete() {
    if (!isDrawing) return;
    if (_points.length > 1) {
      _points.removeLast();
      onStateChanged();
    } else {
      _reset();
    }
  }

  @override
  void cancel() => _reset();

  @override
  InteractionData? getInteractionData() {
    final zone = _zone;
    if (!isDrawing || zone == null) return null;
    final cursor = _cursor;
    final corners = [
      ..._points,
      if (cursor != null) _snap(cursor, zone),
    ];
    final radius = bendRadiusMm(zone.id);
    return TubePathData(
      corners: corners,
      drawing: true,
      bendRadiusMm: radius,
      lengthMm: GeometryEngine.polylineLengthMm(
        PipeLayoutEngine.filletPolyline(corners, radius),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Private helpers
  // ----------------------------------------------------------------

  void _start(Point2D worldPoint) {
    final zone = _floorZoneAt(worldPoint);
    if (zone == null) {
      callbacks.showToast(callbacks.l10n.tube_clickFloorZoneToast);
      return;
    }
    _zoneId = zone.id;
    final current = tubeCorners(zone.id) ?? const [];
    final connected = zone.circuitId != null && current.length >= 2;
    _points
      ..clear()
      ..add(connected ? current.first : _snap(worldPoint, zone));
    _exit = connected ? current.last : null;
    _cursor = worldPoint;
    // The starting click must not count as half of a double-click.
    _lastTapTime = null;
    callbacks.selectElement('zone', zone.id);
    onStateChanged();
  }

  void _finish() {
    final zone = _zone;
    if (zone == null) {
      _reset();
      return;
    }
    final exit = _exit;
    final path = PipeLayoutEngine.dedupePolyline([
      ..._points,
      if (exit != null) exit,
    ]);
    if (path.length < 2) {
      callbacks.showToast(callbacks.l10n.tube_placeCornersToast);
      return;
    }
    undoRedo.execute(UpdateTubePathCommand(
      oldZone: zone,
      newZone: zone.copyWith(manualTubePath: path),
      update: callbacks.updateZone,
      label: callbacks.l10n.undo_drawTubePath,
    ));
    _reset();
  }

  Point2D _snap(Point2D raw, HeatingZone zone) {
    if (!snapEnabled() || freePlacement) return raw;
    return PipeLayoutEngine.snapTubePoint(
      raw: raw,
      previous: _points.lastOrNull,
      corners: _points,
      spacingMm: zone.tubeSpacingMm.toDouble(),
      gridMm: callbacks.currentGridSpacingMm,
    );
  }

  HeatingZone? _floorZoneAt(Point2D point) {
    for (final zone in callbacks.currentZones) {
      if (zone.zoneType == ZoneType.floorHeating &&
          zone.polygon.length >= 3 &&
          GeometryEngine.isPointInPolygon(point, zone.polygon)) {
        return zone;
      }
    }
    return null;
  }

  void _reset() {
    _points.clear();
    _zoneId = null;
    _exit = null;
    _cursor = null;
    _lastTapTime = null;
    _lastTapPos = null;
    onStateChanged();
  }
}
