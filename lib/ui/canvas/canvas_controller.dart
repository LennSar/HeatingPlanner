import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../data/models/point2d.dart';

/// Immutable snapshot of the canvas transform state.
@immutable
class CanvasState {
  /// Creates a [CanvasState].
  const CanvasState({
    required this.zoom,
    required this.panOffset,
  });

  /// Initial state: 100% zoom, no pan.
  static const initial = CanvasState(
    zoom: 1.0,
    panOffset: Offset.zero,
  );

  /// Current zoom factor (1.0 = 100%).
  final double zoom;

  /// Current pan offset in screen pixels.
  final Offset panOffset;

  /// Minimum allowed zoom (10%).
  static const double minZoom = 0.1;

  /// Maximum allowed zoom (500%).
  static const double maxZoom = 5.0;

  /// Build a [Matrix4] combining pan and zoom.
  ///
  /// Result maps world→screen as:
  /// `screen = pan + zoom * world`.
  Matrix4 get transform {
    return Matrix4.identity()
      ..setEntry(0, 0, zoom)
      ..setEntry(1, 1, zoom)
      ..setEntry(0, 3, panOffset.dx)
      ..setEntry(1, 3, panOffset.dy);
  }

  /// Convert a world-coordinate [Point2D] (mm) to screen
  /// pixels.
  Offset worldToScreen(Point2D world) {
    final v = transform.transform3(
      vm.Vector3(world.x, world.y, 0),
    );
    return Offset(v.x, v.y);
  }

  /// Convert screen pixels to world-coordinate [Point2D]
  /// (mm).
  Point2D screenToWorld(Offset screen) {
    final inv = Matrix4.inverted(transform);
    final v = inv.transform3(
      vm.Vector3(screen.dx, screen.dy, 0),
    );
    return Point2D(x: v.x, y: v.y);
  }

  /// Returns a copy with updated fields.
  CanvasState copyWith({
    double? zoom,
    Offset? panOffset,
  }) {
    return CanvasState(
      zoom: zoom ?? this.zoom,
      panOffset: panOffset ?? this.panOffset,
    );
  }
}

/// Manages canvas pan and zoom state.
class CanvasController extends Notifier<CanvasState> {
  Offset? _lastFocalPoint;

  /// Zoom at the moment the current pinch gesture started.
  ///
  /// The gesture's `scale` is cumulative (1.0 at gesture start), so the
  /// target zoom is always `_gestureStartZoom * scale`. Anchoring on this
  /// stored value — instead of multiplying the live zoom by a per-event
  /// delta derived from a stale, build-time snapshot — keeps zoom stable when
  /// several scale events fire within one frame, which otherwise caused the
  /// zoom to spike and snap back (flicker).
  double? _gestureStartZoom;

  @override
  CanvasState build() => CanvasState.initial;

  /// Begin a pan/zoom gesture at [focalPoint].
  void onScaleStart(Offset focalPoint) {
    _lastFocalPoint = focalPoint;
    _gestureStartZoom = state.zoom;
  }

  /// Update pan and zoom during a gesture.
  ///
  /// [scale] is the gesture's cumulative scale since [onScaleStart] (1.0 at
  /// the start of the gesture). The zoom is anchored at [focalPoint] so the
  /// point under the fingers stays fixed while pinching.
  void onScaleUpdate({
    required Offset focalPoint,
    required double scale,
  }) {
    final startZoom = _gestureStartZoom ?? state.zoom;
    final oldZoom = state.zoom;
    final newZoom = (startZoom * scale).clamp(
      CanvasState.minZoom,
      CanvasState.maxZoom,
    );

    // Pan from finger movement since the last event.
    final panDelta =
        focalPoint - (_lastFocalPoint ?? focalPoint);
    _lastFocalPoint = focalPoint;
    final pannedOffset = state.panOffset + panDelta;

    // Keep the focal point fixed under the fingers while zooming.
    final zoomRatio = oldZoom == 0 ? 1.0 : newZoom / oldZoom;
    final newPan =
        focalPoint - (focalPoint - pannedOffset) * zoomRatio;

    state = state.copyWith(
      zoom: newZoom,
      panOffset: newPan,
    );
  }

  /// Apply a discrete zoom step (e.g. scroll wheel).
  ///
  /// [delta] is positive for zoom-in, negative for
  /// zoom-out. [focalPoint] is the screen position to
  /// zoom towards.
  void zoomBy(double delta, Offset focalPoint) {
    final oldZoom = state.zoom;
    final newZoom = (oldZoom * (1 + delta)).clamp(
      CanvasState.minZoom,
      CanvasState.maxZoom,
    );
    if (newZoom == oldZoom) return;

    // Adjust pan so the focal point stays fixed.
    final scale = newZoom / oldZoom;
    final newPan = focalPoint -
        (focalPoint - state.panOffset) * scale;

    state = state.copyWith(
      zoom: newZoom,
      panOffset: newPan,
    );
  }

  /// Reset zoom to fit-all (identity transform).
  void zoomToFit() {
    state = CanvasState.initial;
  }

  /// Set zoom and pan in one call (used for initial view
  /// sizing based on canvas dimensions).
  void setInitialView(double zoom, Offset panOffset) {
    state = CanvasState(zoom: zoom, panOffset: panOffset);
  }

  /// Zoom percentage for display (e.g. "125%").
  int get zoomPercent => (state.zoom * 100).round();
}

/// Provider for the [CanvasController].
final canvasControllerProvider =
    NotifierProvider<CanvasController, CanvasState>(
  CanvasController.new,
);
