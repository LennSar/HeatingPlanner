import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';

/// Callback interface that canvas tools use to mutate
/// editor state. Implemented by the canvas widget which
/// has access to Riverpod providers.
abstract class EditorCallbacks {
  /// Commit a new wall segment to the editor state.
  void commitWall(WallSegment wall);

  /// Commit a new wall, splitting any existing room wall whose
  /// interior contains either endpoint (ADR-003).
  void commitWallWithSplit(WallSegment wall);

  /// Replace an existing wall segment (same ID).
  void updateWall(WallSegment wall);

  /// Remove a wall by ID.
  void removeWall(String wallId);

  /// Remove a room by ID and clear roomId on its walls.
  void destroyRoom(String roomId);

  /// Add a room back and reassign its walls (for undo).
  void restoreRoom(Room room, List<String> wallIds);

  /// Update a room (e.g. polygon change during drag).
  void updateRoom(Room room);

  /// Update the selected element in the properties panel.
  void selectElement(String? type, String? id);

  /// Request a room-name dialog after auto-detection.
  void requestRoomDialog(
    List<Point2D> polygon,
    List<String> wallIds,
  );

  /// Show a transient toast message.
  void showToast(String message);

  /// All wall segments currently in the editor.
  List<WallSegment> get currentWalls;

  /// All rooms currently in the editor.
  List<Room> get currentRooms;

  /// The current canvas zoom level (for screen-space hit
  /// testing of handles).
  double get currentZoom;
}
