import 'package:flutter/gestures.dart';

import '../../../core/utils/geometry_utils.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';
import '../painters/interaction_data.dart';
import 'tool_base.dart';

/// Tool for selecting walls and rooms by clicking.
///
/// Hit-tests walls first (distance to segment), then rooms
/// (point-in-polygon). Clicking empty space deselects.
class SelectTool extends CanvasTool {
  /// Creates a [SelectTool].
  SelectTool({
    required super.callbacks,
    required super.onStateChanged,
  });

  /// Hit-test threshold for walls (half wall thickness).
  static const double _wallHitThresholdMm = 100.0;

  /// Currently selected wall, if any.
  WallSegment? _selectedWall;

  /// Currently selected room, if any.
  Room? _selectedRoom;

  @override
  String get name => 'Select';

  @override
  void onTap(
    Point2D worldPoint,
    PointerDeviceKind deviceKind,
  ) {
    // Try to hit-test walls first.
    final wall = _hitTestWall(worldPoint);
    if (wall != null) {
      _selectedWall = wall;
      _selectedRoom = null;
      callbacks.selectElement('wall', wall.id);
      onStateChanged();
      return;
    }

    // Try to hit-test rooms.
    final room = _hitTestRoom(worldPoint);
    if (room != null) {
      _selectedWall = null;
      _selectedRoom = room;
      callbacks.selectElement('room', room.id);
      onStateChanged();
      return;
    }

    // Nothing hit — deselect.
    _selectedWall = null;
    _selectedRoom = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    // No hover behavior for select tool currently.
  }

  @override
  void cancel() {
    _selectedWall = null;
    _selectedRoom = null;
    callbacks.selectElement(null, null);
    onStateChanged();
  }

  @override
  InteractionData? getInteractionData() {
    if (_selectedWall == null && _selectedRoom == null) {
      return null;
    }

    return SelectionHighlightData(
      selectedWalls:
          _selectedWall != null ? [_selectedWall!] : const [],
      selectedRoom: _selectedRoom,
    );
  }

  /// Find the nearest wall within the hit threshold.
  WallSegment? _hitTestWall(Point2D point) {
    WallSegment? nearest;
    var minDist = double.infinity;

    for (final wall in callbacks.currentWalls) {
      final dist = GeometryUtils.distanceToSegment(
        point,
        wall.startPoint,
        wall.endPoint,
      );
      if (dist < minDist) {
        minDist = dist;
        nearest = wall;
      }
    }

    if (nearest != null && minDist <= _wallHitThresholdMm) {
      return nearest;
    }
    return null;
  }

  /// Find the room whose polygon contains [point].
  Room? _hitTestRoom(Point2D point) {
    for (final room in callbacks.currentRooms) {
      if (room.polygon.length >= 3 &&
          GeometryUtils.containsPoint(room.polygon, point)) {
        return room;
      }
    }
    return null;
  }
}
