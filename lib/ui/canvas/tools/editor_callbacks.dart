import '../../../data/models/distributor.dart';
import '../../../data/models/door.dart';
import '../../../data/models/heating_circuit.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';
import '../../../data/models/window_element.dart';
import '../../../l10n/app_localizations.dart';

/// Callback interface that canvas tools use to mutate
/// editor state. Implemented by the canvas widget which
/// has access to Riverpod providers.
abstract class EditorCallbacks {
  /// Locale-resolved UI strings. Implemented by the canvas widget
  /// via `AppLocalizations.of(context)!`. Tools read this when they
  /// construct undo/redo commands so the labels match the active UI
  /// locale.
  AppLocalizations get l10n;
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

  /// Replace walls, rooms, and heating zones atomically (for undo/redo).
  ///
  /// Used by the ADR-016 "Move room" command so a single Ctrl+Z reverts
  /// the entire move — including any shared walls regenerated on drop
  /// and the moved room's heating zones.
  void replaceAllWallsRoomsZones(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
  );

  /// Reconcile a room against its walls using the room-draw shared-wall
  /// pipeline (ADR-001 mirror copy, ADR-011 mirrorId, promote-to-interior).
  ///
  /// Exposed for tools that re-commit a room without going through the
  /// room-detection dialog — currently the ADR-016 move-room flow in
  /// [SelectTool]. Wraps `EditorStateNotifier.addRoomFromDetection`.
  void addRoomFromDetection({
    required Room room,
    required List<String> wallIds,
  });

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

  // ---- Circuits ----

  /// Commit a completed heating circuit to the editor state.
  void commitCircuit(HeatingCircuit circuit);

  /// Replace an existing heating circuit (same ID).
  void updateCircuit(HeatingCircuit circuit);

  /// Remove a heating circuit by ID, persist the delete, and disconnect
  /// any zone whose [circuitId] matches.
  void removeCircuit(String circuitId);

  /// Remove all heating circuits from editor state and persist the deletes.
  void clearAllCircuits();

  /// All heating circuits currently in the editor.
  List<HeatingCircuit> get currentCircuits;

  // ---- Zones ----

  /// Commit a new heating zone to the editor state.
  void commitZone(HeatingZone zone);

  /// Replace an existing heating zone (same ID).
  void updateZone(HeatingZone zone);

  /// Remove a heating zone by ID.
  void removeZone(String zoneId);

  // ---- Default IDs ----

  /// UUID of the floor currently active in the editor.
  ///
  /// Used by tools when creating entities that must carry a
  /// [floorId] foreign key (rooms, distributors).
  String get currentFloorId;

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
  ///
  /// When [onCreated] is provided (rect-mode batch, ADR-009 §Rule 5),
  /// the caller handles undo registration and [onCreated] is invoked
  /// with the post-room walls and rooms lists instead of pushing a
  /// separate undo command. When [onCreated] is null (single-wall
  /// mode), the implementation registers its own undo command.
  void requestRoomDialog(
    List<Point2D> polygon,
    List<String> wallIds, {
    void Function(List<WallSegment> walls, List<Room> rooms)? onCreated,
  });

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

  /// The active drawing grid spacing in mm, read from [gridSpacingMmProvider].
  double get currentGridSpacingMm;
}
