import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart'
    show Vector3;

import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/distributor.dart';
import '../../data/models/enums.dart';
import '../../data/models/heating_circuit.dart';
import '../../data/models/point2d.dart';
import '../../data/models/room.dart';
import '../../data/models/door.dart';
import '../../data/models/wall_segment.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/window_element.dart';
import '../providers/editor_state_provider.dart';
import '../providers/selection_provider.dart';
import '../screens/editor_screen.dart';
import 'canvas_controller.dart';
import 'painters/annotation_painter.dart';
import 'painters/grid_painter.dart';
import 'painters/heating_zone_painter.dart';
import 'painters/interaction_data.dart';
import 'painters/interaction_painter.dart';
import 'painters/opening_painter.dart';
import 'painters/pipe_route_painter.dart';
import 'painters/wall_painter.dart';
import '../../data/models/heating_zone.dart';
import 'tools/editor_callbacks.dart';
import 'painters/distributor_painter.dart';
import 'tools/distributor_place_tool.dart';
import 'tools/door_place_tool.dart';
import 'tools/route_draw_tool.dart';
import 'tools/select_tool.dart';
import 'tools/tool_base.dart';
import 'tools/undo_redo_service.dart';
import 'tools/wall_draw_tool.dart';
import 'tools/window_place_tool.dart';
import 'tools/wall_zone_place_tool.dart';
import 'tools/zone_draw_tool.dart';
import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/providers/heat_demand_providers.dart';
import '../../calculation/providers/heat_output_providers.dart';
import '../../repositories/app_preferences.dart';

/// Provider that signals tools to cancel (incremented on
/// Escape). Tools check this to know when cancel is pressed.
final toolCancelProvider =
    NotifierProvider<ToolCancelNotifier, int>(
  ToolCancelNotifier.new,
);

/// Notifier that increments a counter to signal cancel.
class ToolCancelNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Signal all tools to cancel.
  void cancel() {
    state = state + 1;
  }
}

/// Provider that signals tools to delete the selection.
final toolDeleteProvider =
    NotifierProvider<ToolDeleteNotifier, int>(
  ToolDeleteNotifier.new,
);

/// Notifier that increments a counter to signal delete.
class ToolDeleteNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Signal the active tool to delete.
  void delete() {
    state = state + 1;
  }
}

/// Provider that signals the select tool to rotate the selected distributor.
final toolRotateDistributorProvider =
    NotifierProvider<ToolRotateDistributorNotifier, int>(
  ToolRotateDistributorNotifier.new,
);

// ----------------------------------------------------------
// Wall modifier flags (Shift / Ctrl / Alt and tablet toggles)
// ----------------------------------------------------------

/// Current modifier state for [WallDrawTool].
///
/// Updated by keyboard events ([EditorShortcuts.onKeyEvent]) on desktop
/// and by toggle buttons in the active-tool bar on tablet.
class WallModifiers {
  /// Creates [WallModifiers].
  const WallModifiers({
    this.orthoSnap = false,
    this.rectMode = false,
    this.freePlacement = false,
  });

  /// Shift held — constrain ghost line to 0° or 90°.
  final bool orthoSnap;

  /// Ctrl held — rectangle drag mode.
  final bool rectMode;

  /// Alt held — bypass grid snap.
  final bool freePlacement;
}

/// Notifier for [wallModifiersProvider].
class WallModifiersNotifier extends Notifier<WallModifiers> {
  @override
  WallModifiers build() => const WallModifiers();

  /// Patch one or more modifier flags; leave others unchanged.
  void update({bool? orthoSnap, bool? rectMode, bool? freePlacement}) {
    state = WallModifiers(
      orthoSnap: orthoSnap ?? state.orthoSnap,
      rectMode: rectMode ?? state.rectMode,
      freePlacement: freePlacement ?? state.freePlacement,
    );
  }
}

/// Provider that exposes the current wall-tool modifier flags.
final wallModifiersProvider =
    NotifierProvider<WallModifiersNotifier, WallModifiers>(
  WallModifiersNotifier.new,
);

/// Notifier that increments a counter to trigger distributor rotation.
class ToolRotateDistributorNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Signal a 90° clockwise rotation of the selected distributor.
  void rotate() {
    state = state + 1;
  }
}

/// The main 2D floor plan canvas with pan/zoom and
/// layered [CustomPaint] rendering.
///
/// Uses a custom [GestureDetector] + [Transform] instead
/// of [InteractiveViewer] for finer control over tool
/// delegation.
class FloorPlanCanvas extends ConsumerStatefulWidget {
  /// Creates a [FloorPlanCanvas].
  const FloorPlanCanvas({super.key});

  @override
  ConsumerState<FloorPlanCanvas> createState() =>
      _FloorPlanCanvasState();
}

class _FloorPlanCanvasState
    extends ConsumerState<FloorPlanCanvas>
    implements EditorCallbacks {
  /// Current mouse position in world coordinates for the
  /// interaction painter and status bar.
  Offset? _hoverWorldPoint;


  double _initialZoom = 1.0;

  /// Whether the canvas zoom has been initialised from the
  /// actual widget size. Set on the first [LayoutBuilder]
  /// callback so the initial view always shows ≥12 m in the
  /// smallest dimension (comfortably accommodating a 10 m
  /// wall), with the world origin centred on screen.
  bool _viewInitialized = false;

  /// Cached tool instances.
  final Map<DrawingTool, CanvasTool> _tools = {};

  /// Current interaction data from the active tool.
  InteractionData? _interactionData;

  /// Whether a drag is in progress.
  bool _isDragging = false;

  /// Whether tools have been initialised (deferred to first
  /// build so ref is available).
  bool _toolsInitialised = false;

  void _ensureToolsInitialised() {
    if (_toolsInitialised) return;
    _toolsInitialised = true;

    void onChanged() {
      setState(() {
        _interactionData = _activeTool?.getInteractionData();
      });
    }

    final undoRedo = ref.read(undoRedoProvider);
    _tools[DrawingTool.select] = SelectTool(
      callbacks: this,
      onStateChanged: onChanged,
      undoRedo: undoRedo,
    );
    _tools[DrawingTool.drawWall] = WallDrawTool(
      callbacks: this,
      onStateChanged: onChanged,
      undoRedo: undoRedo,
    );
    _tools[DrawingTool.placeWindow] = WindowPlaceTool(
      callbacks: this,
      onStateChanged: onChanged,
      undoRedo: undoRedo,
    );
    _tools[DrawingTool.placeDoor] = DoorPlaceTool(
      callbacks: this,
      onStateChanged: onChanged,
      undoRedo: undoRedo,
    );
    _tools[DrawingTool.drawZone] = ZoneDrawTool(
      callbacks: this,
      onStateChanged: onChanged,
      undoRedo: undoRedo,
    );
    _tools[DrawingTool.drawWallZone] = WallZonePlaceTool(
      callbacks: this,
      onStateChanged: onChanged,
      undoRedo: undoRedo,
    );
    _tools[DrawingTool.placeDistributor] = DistributorPlaceTool(
      callbacks: this,
      onStateChanged: onChanged,
      undoRedo: undoRedo,
    );
    _tools[DrawingTool.routePipe] = RouteDrawTool(
      callbacks: this,
      onStateChanged: onChanged,
    );
  }

  CanvasTool? get _activeTool {
    final tool = ref.read(selectedToolProvider);
    return _tools[tool];
  }

  // ---- EditorCallbacks implementation ----

  @override
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void commitWall(WallSegment wall) {
    ref.read(editorStateProvider.notifier).addWall(wall);
  }

  @override
  void commitWallWithSplit(WallSegment wall) {
    ref.read(editorStateProvider.notifier).commitWallWithSplit(wall);
  }

  @override
  void updateWall(WallSegment wall) {
    ref.read(editorStateProvider.notifier).updateWall(wall);
  }

  @override
  void removeWall(String wallId) {
    ref.read(editorStateProvider.notifier).removeWall(wallId);
  }

  @override
  void destroyRoom(String roomId) {
    final notifier = ref.read(editorStateProvider.notifier);
    notifier.clearRoomIdOnWalls(roomId);
    notifier.removeRoom(roomId);
  }

  @override
  void restoreRoom(Room room, List<String> wallIds) {
    final notifier = ref.read(editorStateProvider.notifier);
    notifier.addRoom(room);
    notifier.assignWallsToRoom(wallIds, room.id);
  }

  @override
  void updateRoom(Room room) {
    ref.read(editorStateProvider.notifier).updateRoom(room);
  }

  @override
  void replaceAllWalls(List<WallSegment> walls) {
    ref
        .read(editorStateProvider.notifier)
        .replaceAllWalls(walls);
  }

  @override
  void replaceAllWallsAndRooms(
    List<WallSegment> walls,
    List<Room> rooms,
  ) {
    ref
        .read(editorStateProvider.notifier)
        .replaceAllWallsAndRooms(walls, rooms);
  }

  @override
  void replaceAllWallsRoomsZones(
    List<WallSegment> walls,
    List<Room> rooms,
    List<HeatingZone> zones,
  ) {
    ref
        .read(editorStateProvider.notifier)
        .replaceAllWallsRoomsZones(walls, rooms, zones);
  }

  @override
  void addRoomFromDetection({
    required Room room,
    required List<String> wallIds,
  }) {
    ref
        .read(editorStateProvider.notifier)
        .addRoomFromDetection(room: room, wallIds: wallIds);
  }

  // ---- Windows ----

  @override
  void commitWindow(WindowElement window) {
    ref.read(editorStateProvider.notifier).addWindow(window);
  }

  @override
  void updateWindow(WindowElement window) {
    ref.read(editorStateProvider.notifier).updateWindow(window);
  }

  @override
  void removeWindow(String windowId) {
    ref.read(editorStateProvider.notifier).removeWindow(windowId);
  }

  // ---- Doors ----

  @override
  void commitDoor(Door door) {
    ref.read(editorStateProvider.notifier).addDoor(door);
  }

  @override
  void updateDoor(Door door) {
    ref.read(editorStateProvider.notifier).updateDoor(door);
  }

  @override
  void removeDoor(String doorId) {
    ref.read(editorStateProvider.notifier).removeDoor(doorId);
  }

  // ---- Zones ----

  @override
  void commitZone(HeatingZone zone) {
    ref.read(editorStateProvider.notifier).addZone(zone);
  }

  @override
  void updateZone(HeatingZone zone) {
    ref.read(editorStateProvider.notifier).updateZone(zone);
  }

  @override
  void removeZone(String zoneId) {
    ref.read(editorStateProvider.notifier).removeZone(zoneId);
  }

  // ---- Circuits ----

  @override
  void commitCircuit(HeatingCircuit circuit) {
    ref
        .read(editorStateProvider.notifier)
        .addCircuit(circuit);
  }

  @override
  void updateCircuit(HeatingCircuit circuit) {
    ref
        .read(editorStateProvider.notifier)
        .updateCircuit(circuit);
  }

  @override
  void removeCircuit(String circuitId) {
    final notifier = ref.read(editorStateProvider.notifier);
    notifier.removeCircuit(circuitId);
    for (final zone in ref.read(editorStateProvider).zones) {
      if (zone.circuitId == circuitId) {
        notifier.updateZone(zone.copyWith(circuitId: null));
      }
    }
  }

  @override
  void clearAllCircuits() {
    ref.read(editorStateProvider.notifier).clearAllCircuits();
  }

  @override
  List<HeatingCircuit> get currentCircuits =>
      ref.read(editorStateProvider).circuits;

  // ---- Default IDs (from seeded data in HeatingDao.seedDefaults) ----

  @override
  String get currentFloorId =>
      ref.read(currentFloorIdProvider);

  /// First available tube type ID (PE-Xa 16×2, seeded default).
  static const _defaultTubeTypeId =
      '10000000-0000-4000-8000-000000000001';

  /// First available flooring material ID (Ceramic tile, seeded default).
  static const _defaultFlooringMaterialId =
      '20000000-0000-4000-8000-000000000001';

  @override
  String get defaultTubeTypeId => _defaultTubeTypeId;

  @override
  String get defaultFlooringMaterialId => _defaultFlooringMaterialId;

  @override
  void selectElement(String? type, String? id) {
    if (type != null && id != null) {
      ref.read(selectedElementProvider.notifier).select(
            SelectedElement(type: type, id: id),
          );
    } else {
      ref.read(selectedElementProvider.notifier).select(null);
    }
  }

  @override
  void requestRoomDialog(
    List<Point2D> polygon,
    List<String> wallIds, {
    void Function(List<WallSegment> walls, List<Room> rooms)? onCreated,
  }) {
    final roomNumber =
        ref.read(editorStateProvider.notifier).nextRoomNumber;

    final l10n = AppLocalizations.of(context)!;
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(
          text: l10n.canvas_defaultRoomName(roomNumber),
        );
        return AlertDialog(
          title: Text(l10n.newRoomDetected),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.roomNameLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text),
              child: Text(l10n.create),
            ),
          ],
        );
      },
    ).then((name) {
      if (name == null || name.isEmpty) return;

      final roomId = IdGenerator.newId();
      final room = Room(
        id: roomId,
        floorId: currentFloorId,
        name: name,
        polygon: polygon,
      );

      // Snapshot state before mutation for undo.
      final oldState = ref.read(editorStateProvider);

      // addRoomFromDetection handles shared walls: it creates
      // a mirror WallSegment for each wall that already
      // belongs to another room, marks both copies as
      // WallType.interior, and cross-references them via
      // adjacentRoomId in a single atomic state update.
      ref
          .read(editorStateProvider.notifier)
          .addRoomFromDetection(room: room, wallIds: wallIds);

      // Snapshot state after mutation for redo.
      final newState = ref.read(editorStateProvider);

      if (onCreated != null) {
        // Rect-mode batch (ADR-009 §Rule 5): the caller registered a
        // combined undo command covering walls + room; notify it so it
        // can update its newWalls/newRooms snapshots.
        onCreated(newState.walls, newState.rooms);
      } else {
        // Single-wall mode: register a dedicated room undo command.
        // execute() is a no-op on first call (state is already newState).
        ref.read(undoRedoProvider).execute(
          _CreateRoomCommand(
            callbacks: this,
            oldWalls: oldState.walls,
            oldRooms: oldState.rooms,
            newWalls: newState.walls,
            newRooms: newState.rooms,
          ),
        );
      }

      // Auto-select the new room.
      selectElement('room', roomId);
    });
  }

  @override
  void showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  List<WallSegment> get currentWalls =>
      ref.read(editorStateProvider).walls;

  @override
  List<Room> get currentRooms =>
      ref.read(editorStateProvider).rooms;

  @override
  List<WindowElement> get currentWindows =>
      ref.read(editorStateProvider).windows;

  @override
  List<Door> get currentDoors =>
      ref.read(editorStateProvider).doors;

  @override
  List<HeatingZone> get currentZones =>
      ref.read(editorStateProvider).zones;

  // ---- Distributor ----

  @override
  void commitDistributor(Distributor distributor) {
    ref.read(editorStateProvider.notifier).setDistributor(distributor);
  }

  @override
  void updateDistributor(Distributor distributor) {
    ref.read(editorStateProvider.notifier).updateDistributor(distributor);
  }

  @override
  void removeDistributor() {
    ref.read(editorStateProvider.notifier).clearDistributor();
  }

  @override
  Distributor? get currentDistributor =>
      ref.read(editorStateProvider).distributor;

  @override
  void requestDistributorReplaceDialog({
    required void Function() onMove,
    required void Function() onReplace,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.distributorAlreadyPlaced),
        content: Text(l10n.distributorAlreadyPlacedContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onMove();
            },
            child: Text(l10n.move),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onReplace();
            },
            child: Text(l10n.replace),
          ),
        ],
      ),
    );
  }

  @override
  void requestDistributorDeleteDialog({
    required void Function() onConfirmed,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDistributorTitle),
        content: Text(l10n.deleteDistributorContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirmed();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  double get currentZoom =>
      ref.read(canvasControllerProvider).zoom;

  @override
  double get currentGridSpacingMm =>
      ref.read(gridSpacingMmProvider).maybeWhen(
        data: (v) => v.toDouble(),
        orElse: () => 100.0,
      );

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    _ensureToolsInitialised();
    final canvasState = ref.watch(canvasControllerProvider);
    final editorState = ref.watch(editorStateProvider);
    final gridSpacingMm = ref
            .watch(gridSpacingMmProvider)
            .when(data: (v) => v.toDouble(), loading: () => 100.0, error: (_, __) => 100.0);
    final hoveredElement = ref.watch(hoveredElementProvider);
    final colors = Theme.of(context)
        .extension<HeatingPlannerColors>()!;
    final onSurface =
        Theme.of(context).colorScheme.onSurface;

    // Compute ADR-004 zone display states from calculation providers.
    // Priority order is strict — see ADR-004 and DECISIONS.md.
    final zoneStates = <String, ZoneColorState>{};
    for (final zone in editorState.zones) {
      // Priority 1: no circuit assigned → red hatched.
      if (zone.circuitId == null) {
        zoneStates[zone.id] = ZoneColorState.unconnected;
        continue;
      }

      // Priority 1b: circuit route not connected to the distributor
      // (mirrors VR-05). Catches the case where the distributor was
      // moved but circuitId was not yet cleared, leaving the zone
      // with a stale circuit reference whose route no longer reaches
      // the manifold.
      final circuit = editorState.circuits
          .where((c) => c.id == zone.circuitId)
          .firstOrNull;
      final distributor = editorState.distributor;
      final bool routeConnected = circuit != null &&
          circuit.supplyRoutePath.isNotEmpty &&
          distributor != null &&
          GeometryEngine.distanceMm(
                circuit.supplyRoutePath.first,
                distributor.position,
              ) <=
              50.0;
      if (!routeConnected) {
        zoneStates[zone.id] = ZoneColorState.unconnected;
        continue;
      }

      // Priority 2: room demand is NaN (incomplete data, e.g. an
      // exterior wall has no construction) → grey.  This check MUST
      // come before the output check so that a valid output value
      // cannot mask missing demand data.
      final demandW =
          ref.watch(roomHeatDemandProvider(zone.roomId));
      if (demandW.isNaN) {
        zoneStates[zone.id] = ZoneColorState.noDemand;
        continue;
      }

      // Compute specific output (W/m²) now that demand is confirmed
      // to be a real number.  If output cannot be determined (e.g.
      // distributor not yet configured) fall back to unconnected.
      final specificOutput =
          ref.watch(zoneHeatOutputProvider(zone.id));
      if (specificOutput.isNaN) {
        zoneStates[zone.id] = ZoneColorState.unconnected;
        continue;
      }

      final areaM2 = zone.polygon.length >= 3
          ? GeometryEngine.polygonAreaM2(zone.polygon)
          : 0.0;
      if (areaM2 <= 0) {
        zoneStates[zone.id] = ZoneColorState.unconnected;
        continue;
      }

      final totalOutputW = specificOutput * areaM2;

      // Genuinely zero demand (e.g. interior room with equal adjacent
      // temperatures): no heating needed, so the zone is sufficient.
      if (demandW <= 0) {
        zoneStates[zone.id] = ZoneColorState.sufficient;
        continue;
      }

      // Priorities 3–5: compare output to demand.
      final ratio = totalOutputW / demandW;
      zoneStates[zone.id] = ratio >= 1.0
          ? ZoneColorState.sufficient
          : ratio >= 0.9
              ? ZoneColorState.marginal
              : ZoneColorState.insufficient;
    }

    // Watch selected tool to react to tool switches.
    ref.watch(selectedToolProvider);

    // Discard any in-progress drawing when the user switches tools.
    // Tool instances are cached in [_tools], so a multi-point tool
    // (zone, route, wall) would otherwise retain its uncommitted
    // points and re-emit them the next time it is selected. Resetting
    // the *previous* tool via its cancel() — the same reset path used
    // by Escape — ensures only fully committed elements persist and
    // every draw session starts from a clean, empty state.
    ref.listen<DrawingTool>(selectedToolProvider, (previous, next) {
      if (previous == null || previous == next) return;
      _tools[previous]?.cancel();
    });

    // React to cancel/delete signals after the build frame
    // completes. ref.listen fires its callback post-build,
    // avoiding "modified provider during build" errors.
    ref.listen<int>(toolCancelProvider, (_, __) {
      _activeTool?.cancel();
    });
    ref.listen<int>(toolDeleteProvider, (_, __) {
      _activeTool?.onDelete();
    });
    ref.listen<int>(toolRotateDistributorProvider, (_, __) {
      final t = _activeTool;
      if (t is SelectTool) t.onRotateDistributor();
    });

    // Forward the modifier flags to the WallDrawTool and ZoneDrawTool
    // (Shift/Ctrl/Alt — ADR-009/010/013), and the Ctrl flag to the
    // SelectTool (ADR-012 Rule 7).
    ref.listen<WallModifiers>(wallModifiersProvider, (_, mods) {
      final wt = _tools[DrawingTool.drawWall];
      if (wt is WallDrawTool) {
        wt.updateModifiers(
          shift: mods.orthoSnap,
          ctrl: mods.rectMode,
          alt: mods.freePlacement,
        );
      }
      final zt = _tools[DrawingTool.drawZone];
      if (zt is ZoneDrawTool) {
        zt.updateModifiers(
          shift: mods.orthoSnap,
          ctrl: mods.rectMode,
          alt: mods.freePlacement,
        );
      }
      final st = _tools[DrawingTool.select];
      if (st is SelectTool) {
        // Alt is forwarded so ADR-016 room-move can disable grid snap
        // (free placement, consistent with the other tools).
        st.updateModifiers(
          ctrl: mods.rectMode,
          alt: mods.freePlacement,
        );
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        // On first layout, set zoom so ≥12 m is visible in
        // the smallest dimension (guarantees a 10 m wall fits
        // without manual zoom-out), and centre the origin.
        if (!_viewInitialized &&
            viewSize.width > 0 &&
            viewSize.height > 0) {
          _viewInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final smallest = viewSize.shortestSide;
            final zoom = (smallest / 12000.0).clamp(
              CanvasState.minZoom,
              CanvasState.maxZoom,
            );
            final pan = Offset(
              viewSize.width / 2,
              viewSize.height / 2,
            );
            ref
                .read(canvasControllerProvider.notifier)
                .setInitialView(zoom, pan);
          });
        }

        final visibleRect = _computeVisibleRect(
          canvasState,
          viewSize,
        );

        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final ctrl =
                  ref.read(canvasControllerProvider.notifier);
              final delta =
                  -event.scrollDelta.dy / 1000.0;
              ctrl.zoomBy(delta, event.localPosition);
            }
          },
          onPointerDown: (event) {
            final worldOffset = _toWorld(
              canvasState,
              event.localPosition,
            );
            final worldPoint = Point2D(
              x: worldOffset.dx,
              y: worldOffset.dy,
            );

            // Forward secondary (right) clicks.
            if (event.buttons & kSecondaryButton != 0) {
              _activeTool?.onSecondaryTap(worldPoint);
              return;
            }

            // Forward pointer-down for drag initiation.
            _activeTool?.onPointerDown(
              worldPoint,
              event.buttons,
            );
          },
          onPointerMove: (event) {
            if (event.down) {
              // Drag in progress.
              final worldOffset = _toWorld(
                canvasState,
                event.localPosition,
              );
              final worldPoint = Point2D(
                x: worldOffset.dx,
                y: worldOffset.dy,
              );
              if (!_isDragging) {
                _isDragging = true;
              }
              _activeTool?.onDragUpdate(worldPoint);

              setState(() {
                _hoverWorldPoint = worldOffset;
                _interactionData =
                    _activeTool?.getInteractionData();
              });
            }
          },
          onPointerUp: (event) {
            final worldOffset = _toWorld(
              canvasState,
              event.localPosition,
            );
            final worldPoint = Point2D(
              x: worldOffset.dx,
              y: worldOffset.dy,
            );
            if (_isDragging) {
              _activeTool?.onDragEnd(worldPoint);
              _isDragging = false;
            } else {
              // Non-drag pointer-up: let tools execute deferred
              // actions (e.g. zone body drag threshold not reached).
              _activeTool?.onPointerUp(worldPoint);
            }
            setState(() {
              _interactionData =
                  _activeTool?.getInteractionData();
            });
          },
          child: GestureDetector(
            onScaleStart: (details) {
              if (_isDragging) return;
              _initialZoom = canvasState.zoom;
              ref
                  .read(canvasControllerProvider.notifier)
                  .onScaleStart(details.localFocalPoint);
            },
            onScaleUpdate: (details) {
              if (_isDragging) return;
              ref
                  .read(canvasControllerProvider.notifier)
                  .onScaleUpdate(
                    focalPoint: details.localFocalPoint,
                    scale: details.scale == 1.0
                        ? 1.0
                        : details.scale /
                            (canvasState.zoom /
                                _initialZoom),
                  );
            },
            onTapDown: (details) {
              final worldOffset = _toWorld(
                canvasState,
                details.localPosition,
              );
              final worldPoint = Point2D(
                x: worldOffset.dx,
                y: worldOffset.dy,
              );
              _activeTool?.onTap(
                worldPoint,
                details.kind ?? PointerDeviceKind.mouse,
              );
            },
            child: MouseRegion(
              cursor: _cursorForTool(
                ref.watch(selectedToolProvider),
              ),
              onHover: (event) {
                final worldOffset = _toWorld(
                  canvasState,
                  event.localPosition,
                );
                final worldPoint = Point2D(
                  x: worldOffset.dx,
                  y: worldOffset.dy,
                );

                // Update cursor position provider.
                ref
                    .read(cursorPositionProvider.notifier)
                    .update(worldPoint);

                // Notify active tool.
                _activeTool?.onPointerMove(worldPoint);

                final idata = _activeTool?.getInteractionData();

                // Surface tool hints to the status bar.
                final String? hint;
                if (idata is ZoneDrawData &&
                    idata.cursorOutsideValidArea) {
                  hint = 'Move cursor inside a room to '
                      'place zone vertices';
                } else if (ref.read(selectedToolProvider) ==
                        DrawingTool.drawWallZone &&
                    idata == null) {
                  hint = 'Hover over a wall to place a '
                      'wall heating zone';
                } else if (idata is RouteDrawData) {
                  final lenM =
                      idata.cumulativeLengthMm / 1000.0;
                  hint =
                      'Pipe length: '
                      '${lenM.toStringAsFixed(1)} m';
                } else {
                  hint = null;
                }
                ref
                    .read(toolStatusHintProvider.notifier)
                    .set(hint);

                setState(() {
                  _hoverWorldPoint = worldOffset;
                  _interactionData = idata;
                });
              },
              onExit: (_) {
                ref
                    .read(cursorPositionProvider.notifier)
                    .update(null);
                ref
                    .read(toolStatusHintProvider.notifier)
                    .set(null);
                setState(() => _hoverWorldPoint = null);
              },
              child: Container(
                color: Theme.of(context)
                    .colorScheme
                    .surface,
                child: ClipRect(
                  child: CustomPaint(
                    size: viewSize,
                    painter: _CanvasCompositePainter(
                      transform: canvasState.transform,
                      gridSpacingMm: gridSpacingMm,
                      visibleRect: visibleRect,
                      colors: colors,
                      onSurface: onSurface,
                      hoverWorldPoint: _hoverWorldPoint,
                      walls: editorState.walls,
                      windows: editorState.windows,
                      doors: editorState.doors,
                      zones: editorState.zones,
                      zoneStates: zoneStates,
                      circuits: editorState.circuits,
                      distributor: editorState.distributor,
                      interactionData: _interactionData,
                      hoveredElement: hoveredElement,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  MouseCursor _cursorForTool(DrawingTool tool) {
    // ADR-012 Rule 8: swap to the rect-crosshair (same cursor used by
    // rect-mode drawing) when Ctrl is held over an endpoint handle of
    // a rectangle-eligible room.
    if (tool == DrawingTool.select) {
      final st = _tools[DrawingTool.select];
      if (st is SelectTool) {
        if (st.shouldUseRectCrosshair) {
          return SystemMouseCursors.precise;
        }
        // ADR-016 / UI/UX §6.2: grab when hovering a room interior;
        // grabbing while the move drag is active.
        if (st.isMovingRoom) return SystemMouseCursors.grabbing;
        if (st.shouldUseGrabCursor) return SystemMouseCursors.grab;
      }
      return SystemMouseCursors.basic;
    }
    return switch (tool) {
      DrawingTool.select => SystemMouseCursors.basic,
      DrawingTool.drawWall => SystemMouseCursors.precise,
      DrawingTool.placeWindow => SystemMouseCursors.precise,
      DrawingTool.placeDoor => SystemMouseCursors.precise,
      DrawingTool.drawZone => SystemMouseCursors.precise,
      DrawingTool.drawWallZone => SystemMouseCursors.precise,
      DrawingTool.placeDistributor =>
        SystemMouseCursors.precise,
      DrawingTool.routePipe => SystemMouseCursors.precise,
      DrawingTool.measure => SystemMouseCursors.precise,
    };
  }

  Rect _computeVisibleRect(
    CanvasState state,
    Size viewSize,
  ) {
    final inv = Matrix4.inverted(state.transform);
    final tl = _transformPoint(inv, Offset.zero);
    final br = _transformPoint(
      inv,
      Offset(viewSize.width, viewSize.height),
    );
    return Rect.fromLTRB(tl.dx, tl.dy, br.dx, br.dy);
  }

  Offset _toWorld(CanvasState state, Offset screen) {
    final inv = Matrix4.inverted(state.transform);
    return _transformPoint(inv, screen);
  }

  static Offset _transformPoint(
    Matrix4 matrix,
    Offset point,
  ) {
    final result = matrix.transform3(
      Vector3(point.dx, point.dy, 0),
    );
    return Offset(result.x, result.y);
  }
}

/// Composite painter that draws all layers in order,
/// applying the world transform internally.
class _CanvasCompositePainter extends CustomPainter {
  const _CanvasCompositePainter({
    required this.transform,
    required this.gridSpacingMm,
    required this.visibleRect,
    required this.colors,
    required this.onSurface,
    required this.walls,
    required this.windows,
    required this.doors,
    required this.zones,
    required this.zoneStates,
    required this.circuits,
    this.distributor,
    this.hoverWorldPoint,
    this.interactionData,
    this.hoveredElement,
  });

  final Matrix4 transform;
  final double gridSpacingMm;
  final Rect visibleRect;
  final HeatingPlannerColors colors;
  final Color onSurface;
  final Offset? hoverWorldPoint;
  final List<WallSegment> walls;
  final List<WindowElement> windows;
  final List<Door> doors;
  final List<HeatingZone> zones;
  final Map<String, ZoneColorState> zoneStates;
  final List<HeatingCircuit> circuits;
  final Distributor? distributor;
  final InteractionData? interactionData;
  final SelectedElement? hoveredElement;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transform.storage);

    // Layer 1: Grid
    GridPainter(
      gridSpacingMm: gridSpacingMm,
      visibleRect: visibleRect,
      dotColor: colors.gridDot,
    ).paint(canvas, size);

    // Layer 2: Heating zones
    HeatingZonePainter(
      zoneGreen: colors.zoneGreen,
      zoneYellow: colors.zoneYellow,
      zoneRed: colors.zoneRed,
      zoneGrey: colors.zoneGrey,
      supplyPipe: colors.supplyPipe,
      zones: zones,
      zoneStates: zoneStates,
    ).paint(canvas, size);

    // Layer 3: Walls
    WallPainter(
      wallFill: colors.wallFill,
      wallStroke: colors.wallStroke,
      walls: walls,
    ).paint(canvas, size);

    // Layer 4: Openings (windows + doors)
    OpeningPainter(
      windowFill: colors.windowFill,
      doorFill: colors.doorFill,
      walls: walls,
      windows: windows,
      doors: doors,
    ).paint(canvas, size);

    // Layer 5: Distributor
    if (distributor != null) {
      DistributorPainter(
        distributor: distributor!,
        bodyColor: colors.wallFill,
        strokeColor: colors.wallStroke,
        labelColor: colors.wallStroke,
      ).paint(canvas, size);
    }

    // Layer 6: Pipe routes
    PipeRoutePainter(
      supplyPipe: colors.supplyPipe,
      returnPipe: colors.returnPipe,
      circuits: circuits,
    ).paint(canvas, size);

    // Layer 6: Annotations
    AnnotationPainter(textColor: onSurface)
        .paint(canvas, size);

    // Layer 7: Interaction (no RepaintBoundary)
    InteractionPainter(
      hoverPoint: hoverWorldPoint,
      selectionHighlightColor: colors.selectionHighlight,
      supplyPipeColor: colors.supplyPipe,
      returnPipeColor: colors.returnPipe,
      interactionData: interactionData,
    ).paint(canvas, size);

    // Layer 8: Hover highlight from warning-row hover (§5.8).
    _paintHoverHighlight(canvas);

    canvas.restore();
  }

  /// Draws a 2px [hoverHighlight]-coloured outline (60 % opacity) around
  /// the element identified by [hoveredElement], matching the spec §5.8.
  ///
  /// Element types handled: wall, zone, circuit, distributor.
  /// Rooms are highlighted by outlining every wall whose roomId matches.
  void _paintHoverHighlight(Canvas canvas) {
    final hovered = hoveredElement;
    if (hovered == null) return;

    // The canvas is in world-coordinate space. strokeWidth must be in world mm.
    // Target 8 screen pixels so the stroke is visible at all zoom levels.
    final scale = transform.storage[0]; // px per mm
    final strokeWidthMm = scale > 0.0 ? 8.0 / scale : 80.0;

    const fillColor = Color(0x55FF0000);
    const strokeColor = Color(0xCCFF0000);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidthMm
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (hovered.type) {
      case 'wall':
        final wall = walls.where((w) => w.id == hovered.id).firstOrNull;
        if (wall != null) {
          canvas.drawLine(
            Offset(wall.startPoint.x, wall.startPoint.y),
            Offset(wall.endPoint.x, wall.endPoint.y),
            strokePaint,
          );
        }
      case 'room':
        for (final wall in walls.where((w) => w.roomId == hovered.id)) {
          canvas.drawLine(
            Offset(wall.startPoint.x, wall.startPoint.y),
            Offset(wall.endPoint.x, wall.endPoint.y),
            strokePaint,
          );
        }
      case 'zone':
        final zone = zones.where((z) => z.id == hovered.id).firstOrNull;
        if (zone != null && zone.polygon.length >= 3) {
          final path = Path()
            ..moveTo(zone.polygon.first.x, zone.polygon.first.y);
          for (var i = 1; i < zone.polygon.length; i++) {
            path.lineTo(zone.polygon[i].x, zone.polygon[i].y);
          }
          path.close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, strokePaint);
        }
      case 'circuit':
        final circuit =
            circuits.where((c) => c.id == hovered.id).firstOrNull;
        if (circuit != null) {
          for (final pts in [
            circuit.supplyRoutePath,
            circuit.returnRoutePath,
          ]) {
            if (pts.length < 2) continue;
            final path = Path()..moveTo(pts.first.x, pts.first.y);
            for (var i = 1; i < pts.length; i++) {
              path.lineTo(pts[i].x, pts[i].y);
            }
            canvas.drawPath(path, strokePaint);
          }
        }
      case 'distributor':
        if (distributor != null && distributor!.id == hovered.id) {
          final d = distributor!;
          final bodyRect = Rect.fromCenter(
            center: Offset(d.position.x, d.position.y),
            width: d.widthMm.toDouble(),
            height: 240.0,
          );
          canvas.save();
          canvas.translate(d.position.x, d.position.y);
          canvas.rotate(d.rotationDeg * 3.141592653589793 / 180.0);
          canvas.translate(-d.position.x, -d.position.y);
          canvas.drawRect(bodyRect, fillPaint);
          canvas.drawRect(bodyRect, strokePaint);
          canvas.restore();
        }
    }
  }

  @override
  bool shouldRepaint(_CanvasCompositePainter oldDelegate) {
    return true; // Interaction layer changes frequently.
  }
}

// ================================================================
// Command classes
// ================================================================

/// Command: create a room from auto-detection dialog.
///
/// Captures the full walls+rooms state before and after
/// [addRoomFromDetection] so the operation can be reversed.
/// On first execution via [UndoRedoService.execute] the state
/// is already at [newWalls]/[newRooms], so [execute] is a no-op
/// in practice; it only matters for redo.
class _CreateRoomCommand extends Command {
  _CreateRoomCommand({
    required this.callbacks,
    required this.oldWalls,
    required this.oldRooms,
    required this.newWalls,
    required this.newRooms,
  });

  final EditorCallbacks callbacks;
  final List<WallSegment> oldWalls;
  final List<Room> oldRooms;
  final List<WallSegment> newWalls;
  final List<Room> newRooms;

  @override
  String get label => 'Create room';

  @override
  void execute() =>
      callbacks.replaceAllWallsAndRooms(newWalls, newRooms);

  @override
  void undo() =>
      callbacks.replaceAllWallsAndRooms(oldWalls, oldRooms);
}
