import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../../data/models/point2d.dart';
import '../painters/interaction_data.dart';
import 'snap_service.dart';
import 'tool_base.dart';

/// Tool for measuring the distance between two points (ADR-030).
///
/// First click sets the start point, the cursor then drives a live
/// dimension line whose length is shown both on the canvas and in the
/// status bar. The second click freezes the measurement so the user can
/// read it without holding the cursor steady. A subsequent click starts
/// a fresh measurement. Escape cancels and clears the current line.
///
/// **Snapping is opt-in (ADR-031).** By default both endpoints take the
/// raw cursor position, so an ad-hoc measurement is never pulled off the
/// point the user aimed at. Holding **Shift** enables [SnapService] snap
/// (wall endpoints, wall interiors, grid) so corner-to-corner distances
/// read exactly. The flag is fed from `wallModifiersProvider` (Shift) and
/// re-synced from live hardware at each gesture, mirroring the draw-tool
/// plumbing (ADR-029) so it can never strand "on" after a focus change.
///
/// The tool is purely visual: it never mutates editor state, so it
/// participates in neither persistence nor undo/redo.
class MeasureTool extends CanvasTool {
  /// Creates a [MeasureTool].
  MeasureTool({
    required super.callbacks,
    required super.onStateChanged,
  });

  /// First endpoint of the measurement, or null before the first click.
  Point2D? _start;

  /// Second endpoint: tracks the cursor until [_finalized], then frozen.
  Point2D? _end;

  /// Snap type of the most recent cursor position (drives the indicator).
  SnapType? _snapType;

  /// True once the second point has been clicked.
  bool _finalized = false;

  /// Shift held — enable [SnapService] snapping for this measurement.
  /// Off by default (raw cursor position).
  bool _snapEnabled = false;

  /// Logical keys that count as Shift.
  static final Set<LogicalKeyboardKey> _shiftKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.shift,
  };

  /// Test seam: when true, [_syncSnapFromHardware] is a no-op so unit
  /// tests can drive [_snapEnabled] through [updateSnapEnabled] without
  /// the (empty) test hardware-key state clobbering it.
  static bool debugDisableHardwareSync = false;

  @override
  String get name => 'Measure';

  /// Whether snapping is currently active (Shift held). Exposed so the
  /// canvas can surface a "hold Shift to snap" hint.
  bool get snapEnabled => _snapEnabled;

  /// Update the snap flag from the canvas modifier plumbing
  /// (`wallModifiersProvider`, Shift). Call on key-down and key-up.
  void updateSnapEnabled(bool enabled) {
    if (_snapEnabled == enabled) return;
    _snapEnabled = enabled;
    onStateChanged();
  }

  /// Re-sync [_snapEnabled] from the live hardware key state, mirroring
  /// `ModifierDrawTool.syncModifiersFromHardware` (ADR-029): the cached
  /// flag can strand "on" if Shift is released while a text field holds
  /// focus, so polling at gesture start keeps it honest.
  void _syncSnapFromHardware() {
    if (debugDisableHardwareSync) return;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    _snapEnabled = pressed.any(_shiftKeys.contains);
  }

  /// Resolve [worldPoint]: snapped via [SnapService] when Shift is held,
  /// otherwise the raw cursor position (no snap).
  Point2D _resolve(Point2D worldPoint) {
    if (!_snapEnabled) {
      _snapType = SnapType.none;
      return worldPoint;
    }
    final result = SnapService.snap(
      worldPoint,
      callbacks.currentWalls,
      callbacks.currentGridSpacingMm,
    );
    _snapType = result.type;
    return result.point;
  }

  @override
  void onTap(Point2D worldPoint, PointerDeviceKind deviceKind) {
    _syncSnapFromHardware();
    final point = _resolve(worldPoint);

    if (_start == null || _finalized) {
      // Begin a new measurement (first click, or click after a finished one).
      _start = point;
      _end = point;
      _finalized = false;
    } else {
      // Second click: freeze the measurement.
      _end = point;
      _finalized = true;
    }
    onStateChanged();
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    _syncSnapFromHardware();
    final point = _resolve(worldPoint);
    if (_start != null && !_finalized) {
      _end = point;
    }
    onStateChanged();
  }

  @override
  void cancel() {
    _start = null;
    _end = null;
    _snapType = null;
    _finalized = false;
    onStateChanged();
  }

  @override
  InteractionData? getInteractionData() {
    final start = _start;
    final end = _end;
    if (start == null || end == null) return null;
    return MeasureData(
      start: start,
      end: end,
      finalized: _finalized,
      snapEnabled: _snapEnabled,
      snapIndicator: (!_finalized &&
              (_snapType == SnapType.endpoint ||
                  _snapType == SnapType.wallPoint))
          ? end
          : null,
    );
  }
}
