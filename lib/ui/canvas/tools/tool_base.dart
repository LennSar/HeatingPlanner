import 'package:flutter/gestures.dart';

/// Abstract base class for all canvas drawing/interaction tools.
abstract class ToolBase {
  /// Called when the pointer is pressed on the canvas.
  void onPointerDown(PointerDownEvent event);

  /// Called when the pointer moves on the canvas.
  void onPointerMove(PointerMoveEvent event);

  /// Called when the pointer is released.
  void onPointerUp(PointerUpEvent event);

  /// Called when the tool is deactivated; clean up any transient state.
  void deactivate();
}
