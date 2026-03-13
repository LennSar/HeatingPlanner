import 'dart:ui' show VoidCallback;

import 'package:flutter/gestures.dart';

import '../../../data/models/point2d.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';

/// Abstract base class for all canvas tools.
///
/// Tools receive world-coordinate events and produce
/// [InteractionData] for the interaction painter.
abstract class CanvasTool {
  /// Creates a [CanvasTool] with [callbacks] for state
  /// mutation and [onStateChanged] to trigger repaints.
  CanvasTool({
    required this.callbacks,
    required this.onStateChanged,
  });

  /// Callback interface to mutate editor state.
  final EditorCallbacks callbacks;

  /// Called by the tool when its visual state changes
  /// (e.g. ghost line moved) to trigger a canvas repaint.
  final VoidCallback onStateChanged;

  /// Human-readable tool name for status display.
  String get name;

  /// Called when the user taps on the canvas.
  ///
  /// [worldPoint] is in millimetre coordinates.
  /// [deviceKind] distinguishes mouse from touch.
  void onTap(Point2D worldPoint, PointerDeviceKind deviceKind);

  /// Called when the pointer moves over the canvas.
  ///
  /// [worldPoint] is in millimetre coordinates.
  void onPointerMove(Point2D worldPoint);

  /// Called when a pointer-down starts a drag.
  ///
  /// [worldPoint] is in millimetre coordinates.
  /// [buttons] is the bitmask of pressed buttons.
  void onPointerDown(Point2D worldPoint, int buttons) {}

  /// Called each frame while a drag is in progress.
  void onDragUpdate(Point2D worldPoint) {}

  /// Called when the drag ends (pointer up).
  void onDragEnd(Point2D worldPoint) {}

  /// Called when the user right-clicks (or Ctrl+clicks).
  ///
  /// [worldPoint] is in millimetre coordinates.
  void onSecondaryTap(Point2D worldPoint) {}

  /// Called on Delete / Backspace key press.
  void onDelete() {}

  /// Called when the pointer is released without a drag having occurred.
  ///
  /// Only fired when [onDragEnd] is NOT fired (i.e. `_isDragging == false`
  /// in the canvas). Tools that need to distinguish pure clicks from
  /// click-hold-drags (e.g. zone body drag with a 5 px threshold) use this
  /// to execute deferred tap actions.
  void onPointerUp(Point2D worldPoint) {}

  /// Cancel the current operation (e.g. Escape pressed).
  void cancel();

  /// Returns interaction data for the painter, or null
  /// if there is nothing to draw.
  InteractionData? getInteractionData();
}
