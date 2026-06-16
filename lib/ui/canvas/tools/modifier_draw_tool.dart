import 'package:flutter/services.dart';

import '../../../data/models/point2d.dart';
import 'tool_base.dart';

/// Shared desktop modifier-key vocabulary for click/drag drawing tools.
///
/// Tracks the Shift / Ctrl / Alt flags fed from `wallModifiersProvider`
/// (the same provider that drives [WallDrawTool] and [SelectTool]) and
/// provides the ortho constraint and ortho-guideline helpers, so
/// [WallDrawTool] and [ZoneDrawTool] share one implementation instead
/// of duplicating it.
///
/// | Modifier | Flag            | Effect                                  |
/// |----------|-----------------|-----------------------------------------|
/// | Shift    | [orthoSnap]     | Constrain a segment to 0° or 90°.       |
/// | Ctrl     | [rectMode]      | Rectangle drag mode (corner to corner). |
/// | Alt      | [freePlacement] | Bypass grid snap (raw world coords).    |
///
/// Flags are independent — [orthoSnap] and [freePlacement] may both be
/// active; [rectMode] is independent of both.
///
/// See `DECISIONS.md` ADR-009 / ADR-010 (wall rect mode) and ADR-013
/// (heating-zone rect mode).
mixin ModifierDrawTool on CanvasTool {
  /// Shift held — constrain the ghost segment to 0° or 90°.
  bool orthoSnap = false;

  /// Ctrl held — rectangle drag mode (drag corner to corner).
  bool rectMode = false;

  /// Alt held — bypass grid snap; use the raw world coordinate.
  bool freePlacement = false;

  /// Update the modifier flags from a keyboard event.
  ///
  /// Call on both key-down and key-up so the flags stay in sync.
  /// Mirrors the canvas → tool plumbing that [WallDrawTool] and
  /// [SelectTool] already use via `wallModifiersProvider`.
  void updateModifiers({
    required bool shift,
    required bool ctrl,
    required bool alt,
  }) {
    orthoSnap = shift;
    rectMode = ctrl;
    freePlacement = alt;
    onStateChanged();
  }

  /// Logical keys that count as Shift / Ctrl / Alt. Cmd on macOS maps to
  /// the same Ctrl role via the keyboard-shortcut layer.
  static final Set<LogicalKeyboardKey> _shiftKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.shift,
  };
  static final Set<LogicalKeyboardKey> _ctrlKeys = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.meta,
  };
  static final Set<LogicalKeyboardKey> _altKeys = {
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.alt,
  };

  /// Test seam: when true, [syncModifiersFromHardware] is a no-op so unit
  /// tests can drive the flags purely through [updateModifiers] without
  /// the (empty) test hardware-key state clobbering them.
  static bool debugDisableHardwareSync = false;

  /// Re-sync the modifier flags from the live hardware key state.
  ///
  /// The cached flags track key-down/up events forwarded from the canvas
  /// keyboard handler, but those events can be lost when focus shifts
  /// mid-stroke — e.g. pressing Ctrl on the canvas, clicking into a
  /// properties text field, then releasing Ctrl there (the canvas handler
  /// ignores the key-up while a field is focused). That strands a flag
  /// "on" (rect/square mode stuck enabled) or "off" (Shift/Ctrl drawing
  /// can't be re-enabled). Polling [HardwareKeyboard] at the start of a
  /// stroke makes the flags reflect the actual key state.
  ///
  /// Mirrors `SelectTool._syncCtrlHeldFromHardware` (ADR-012).
  void syncModifiersFromHardware() {
    if (debugDisableHardwareSync) return;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final shift = pressed.any(_shiftKeys.contains);
    final ctrl = pressed.any(_ctrlKeys.contains);
    final alt = pressed.any(_altKeys.contains);
    if (shift == orthoSnap && ctrl == rectMode && alt == freePlacement) {
      return;
    }
    orthoSnap = shift;
    rectMode = ctrl;
    freePlacement = alt;
    onStateChanged();
  }

  /// Constrain [endpoint] to 0° or 90° from [anchor] when [orthoSnap]
  /// is active; otherwise return [endpoint] unchanged.
  ///
  /// Picks the axis closest to the raw endpoint: if |Δx| ≥ |Δy| the
  /// Y is locked to the anchor (horizontal run), otherwise the X is
  /// locked (vertical run).
  Point2D applyOrtho(Point2D anchor, Point2D endpoint) {
    if (!orthoSnap) return endpoint;
    final dx = (endpoint.x - anchor.x).abs();
    final dy = (endpoint.y - anchor.y).abs();
    if (dx >= dy) {
      // Horizontal: lock Y.
      return Point2D(x: endpoint.x, y: anchor.y);
    } else {
      // Vertical: lock X.
      return Point2D(x: anchor.x, y: endpoint.y);
    }
  }

  /// Endpoints of the dashed ortho guideline for [anchor] given the
  /// current cursor [current], or `(null, null)` when [orthoSnap] is
  /// inactive.
  ///
  /// The guideline extends [extentMm] in each direction along the
  /// constrained axis so it visually spans the canvas at any zoom.
  (Point2D?, Point2D?) orthoGuideline(
    Point2D anchor,
    Point2D current, {
    double extentMm = 20000.0,
  }) {
    if (!orthoSnap) return (null, null);
    final dx = (current.x - anchor.x).abs();
    final dy = (current.y - anchor.y).abs();
    if (dx >= dy) {
      // Horizontal axis (Y locked to anchor.y).
      return (
        Point2D(x: anchor.x - extentMm, y: anchor.y),
        Point2D(x: anchor.x + extentMm, y: anchor.y),
      );
    } else {
      // Vertical axis (X locked to anchor.x).
      return (
        Point2D(x: anchor.x, y: anchor.y - extentMm),
        Point2D(x: anchor.x, y: anchor.y + extentMm),
      );
    }
  }
}
