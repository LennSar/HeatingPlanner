import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';

/// Callback interface that canvas tools use to mutate
/// editor state. Implemented by the canvas widget which
/// has access to Riverpod providers.
abstract class EditorCallbacks {
  /// Commit a new wall segment to the editor state.
  void commitWall(WallSegment wall);

  /// Update the selected element in the properties panel.
  void selectElement(String? type, String? id);

  /// Request a room-name dialog after auto-detection.
  void requestRoomDialog(
    List<Point2D> polygon,
    List<String> wallIds,
  );

  /// All wall segments currently in the editor.
  List<WallSegment> get currentWalls;

  /// All rooms currently in the editor.
  List<Room> get currentRooms;
}
