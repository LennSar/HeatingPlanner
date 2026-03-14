import '../../../data/models/distributor.dart';
import '../../../data/models/door.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';
import '../../../data/models/window_element.dart';

/// Callback interface that canvas tools use to mutate
/// editor state. Implemented by the canvas widget which
/// has access to Riverpod providers.
abstract class EditorCallbacks {
  // ---- Walls ----

  /// Commit a new wall segment to the editor state.
  void commitWall(WallSegment wall);

  /// Commit a new wall, splitting any existing room wall
  /// whose interior contains either endpoint (ADR-003).
  void commitWallWithSplit(WallSegment wall);

  /// Replace an existing wall segment (same ID).
  void updateWall(WallSegment wall);

  /// Remove a wall by ID.
  void removeWall(String wallId);

  // ---- Rooms ----

  /// Remove a room by ID and clear roomId on its walls.
  void destroyRoom(String roomId);

  /// Add a room back and reassign its walls (for undo).
  void restoreRoom(Room room, List<String> wallIds);

  /// Update a room (e.g. polygon change during drag).
  void updateRoom(Room room);

  /// Replace the entire wall list atomically (for undo/redo).
  void replaceAllWalls(List<WallSegment> walls);

  /// Replace walls and rooms atomically (for undo/redo).
  void replaceAllWallsAndRooms(
    List<WallSegment> walls,
    List<Room> rooms,
  );

  // ---- Windows ----

  /// Commit a new window element to the editor state.
  void commitWindow(WindowElement window);

  /// Replace an existing window element (same ID).
  void updateWindow(WindowElement window);

  /// Remove a window by ID.
  void removeWindow(String windowId);

  // ---- Doors ----

  /// Commit a new door element to the editor state.
  void commitDoor(Door door);

  /// Replace an existing door element (same ID).
  void updateDoor(Door door);

  /// Remove a door by ID.
  void removeDoor(String doorId);

  // ---- Distributor ----

  /// Set (or replace) the floor's distributor.
  void commitDistributor(Distributor distributor);

  /// Replace the existing distributor in-place (same ID).
  void updateDistributor(Distributor distributor);

  /// Remove the current distributor from the editor state.
  void removeDistributor();

  /// The current distributor on this floor, or null.
  Distributor? get currentDistributor;

  /// Show the "Replace existing distributor?" dialog.
  ///
  /// [onMove] is called when the user chooses to keep the
  /// existing distributor's properties and move it to the
  /// new position.  [onReplace] is called when the user
  /// chooses to create a fresh distributor at the new position.
  void requestDistributorReplaceDialog({
    required void Function() onMove,
    required void Function() onReplace,
  });

  /// Show the "Delete distributor and all connected circuits?"
  /// confirmation dialog.  [onConfirmed] is called if the user
  /// confirms the deletion.
  void requestDistributorDeleteDialog({
    required void Function() onConfirmed,
  });

  // ---- Zones ----

  /// Commit a new heating zone to the editor state.
  void commitZone(HeatingZone zone);

  /// Replace an existing heating zone (same ID).
  void updateZone(HeatingZone zone);

  /// Remove a heating zone by ID.
  void removeZone(String zoneId);

  // ---- Default IDs ----

  /// ID of the first available tube type (from seeded data).
  ///
  /// Used by [ZoneDrawTool] when creating a zone with defaults.
  String get defaultTubeTypeId;

  /// ID of the first available flooring material (from seeded data).
  ///
  /// Used by [ZoneDrawTool] when creating a zone with defaults.
  String get defaultFlooringMaterialId;

  // ---- Selection / UI ----

  /// Update the selected element in the properties panel.
  void selectElement(String? type, String? id);

  /// Request a room-name dialog after auto-detection.
  void requestRoomDialog(
    List<Point2D> polygon,
    List<String> wallIds,
  );

  /// Show a transient toast message.
  void showToast(String message);

  // ---- Read-only access ----

  /// All wall segments currently in the editor.
  List<WallSegment> get currentWalls;

  /// All rooms currently in the editor.
  List<Room> get currentRooms;

  /// All windows currently in the editor.
  List<WindowElement> get currentWindows;

  /// All doors currently in the editor.
  List<Door> get currentDoors;

  /// All heating zones currently in the editor.
  List<HeatingZone> get currentZones;

  /// The current canvas zoom level (for screen-space
  /// hit testing of handles).
  double get currentZoom;
}
