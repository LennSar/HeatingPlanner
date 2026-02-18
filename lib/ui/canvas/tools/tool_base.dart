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

  /// Cancel the current operation (e.g. Escape pressed).
  void cancel();

  /// Returns interaction data for the painter, or null
  /// if there is nothing to draw.
  InteractionData? getInteractionData();
}
