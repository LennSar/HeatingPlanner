import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart'
    show Vector3;

import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/enums.dart';
import '../../data/models/point2d.dart';
import '../../data/models/room.dart';
import '../../data/models/wall_segment.dart';
import '../panels/properties_panel.dart';
import '../providers/editor_state_provider.dart';
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
import 'tools/editor_callbacks.dart';
import 'tools/select_tool.dart';
import 'tools/tool_base.dart';
import 'tools/wall_draw_tool.dart';

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

  /// Default grid spacing (mm).
  static const _gridSpacingMm = 100.0;

  double _initialZoom = 1.0;

  /// Cached tool instances.
  final Map<DrawingTool, CanvasTool> _tools = {};

  /// Current interaction data from the active tool.
  InteractionData? _interactionData;

  /// Previous cancel counter to detect new cancels.
  int _lastCancelCount = 0;

  @override
  void initState() {
    super.initState();
    _initTools();
  }

  void _initTools() {
    void onChanged() {
      setState(() {
        _interactionData = _activeTool?.getInteractionData();
      });
    }

    _tools[DrawingTool.select] = SelectTool(
      callbacks: this,
      onStateChanged: onChanged,
    );
    _tools[DrawingTool.drawWall] = WallDrawTool(
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
  void commitWall(WallSegment wall) {
    ref.read(editorStateProvider.notifier).addWall(wall);
  }

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
    List<String> wallIds,
  ) {
    final roomNumber =
        ref.read(editorStateProvider.notifier).nextRoomNumber;

    showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(
          text: 'Room $roomNumber',
        );
        return AlertDialog(
          title: const Text('New Room Detected'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Room name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    ).then((name) {
      if (name == null || name.isEmpty) return;

      final roomId = IdGenerator.newId();
      final room = Room(
        id: roomId,
        floorId: 'preview',
        name: name,
        polygon: polygon,
      );

      ref.read(editorStateProvider.notifier).addRoom(room);
      ref
          .read(editorStateProvider.notifier)
          .assignWallsToRoom(wallIds, roomId);

      // Auto-select the new room.
      selectElement('room', roomId);
    });
  }

  @override
  List<WallSegment> get currentWalls =>
      ref.read(editorStateProvider).walls;

  @override
  List<Room> get currentRooms =>
      ref.read(editorStateProvider).rooms;

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasControllerProvider);
    final editorState = ref.watch(editorStateProvider);
    final colors = Theme.of(context)
        .extension<HeatingPlannerColors>()!;
    final onSurface =
        Theme.of(context).colorScheme.onSurface;

    // Watch selected tool to react to tool switches.
    ref.watch(selectedToolProvider);

    // Watch cancel signal.
    final cancelCount = ref.watch(toolCancelProvider);
    if (cancelCount != _lastCancelCount) {
      _lastCancelCount = cancelCount;
      _activeTool?.cancel();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
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
          child: GestureDetector(
            onScaleStart: (details) {
              _initialZoom = canvasState.zoom;
              ref
                  .read(canvasControllerProvider.notifier)
                  .onScaleStart(details.localFocalPoint);
            },
            onScaleUpdate: (details) {
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

                setState(() {
                  _hoverWorldPoint = worldOffset;
                  _interactionData =
                      _activeTool?.getInteractionData();
                });
              },
              onExit: (_) {
                ref
                    .read(cursorPositionProvider.notifier)
                    .update(null);
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
                      gridSpacingMm: _gridSpacingMm,
                      visibleRect: visibleRect,
                      colors: colors,
                      onSurface: onSurface,
                      hoverWorldPoint: _hoverWorldPoint,
                      walls: editorState.walls,
                      interactionData: _interactionData,
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
    return switch (tool) {
      DrawingTool.select => SystemMouseCursors.basic,
      DrawingTool.drawWall => SystemMouseCursors.precise,
      DrawingTool.placeWindow => SystemMouseCursors.precise,
      DrawingTool.placeDoor => SystemMouseCursors.precise,
      DrawingTool.drawZone => SystemMouseCursors.precise,
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
    this.hoverWorldPoint,
    this.interactionData,
  });

  final Matrix4 transform;
  final double gridSpacingMm;
  final Rect visibleRect;
  final HeatingPlannerColors colors;
  final Color onSurface;
  final Offset? hoverWorldPoint;
  final List<WallSegment> walls;
  final InteractionData? interactionData;

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
    ).paint(canvas, size);

    // Layer 5: Pipe routes
    PipeRoutePainter(
      supplyPipe: colors.supplyPipe,
      returnPipe: colors.returnPipe,
    ).paint(canvas, size);

    // Layer 6: Annotations
    AnnotationPainter(textColor: onSurface)
        .paint(canvas, size);

    // Layer 7: Interaction (no RepaintBoundary)
    InteractionPainter(
      hoverPoint: hoverWorldPoint,
      selectionHighlightColor: colors.selectionHighlight,
      interactionData: interactionData,
    ).paint(canvas, size);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CanvasCompositePainter oldDelegate) {
    return true; // Interaction layer changes frequently.
  }
}
