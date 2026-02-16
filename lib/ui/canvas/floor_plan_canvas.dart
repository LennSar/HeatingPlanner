import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart'
    show Vector3;

import '../../core/theme/app_theme.dart';
import 'canvas_controller.dart';
import 'painters/annotation_painter.dart';
import 'painters/grid_painter.dart';
import 'painters/heating_zone_painter.dart';
import 'painters/interaction_painter.dart';
import 'painters/opening_painter.dart';
import 'painters/pipe_route_painter.dart';
import 'painters/wall_painter.dart';

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
    extends ConsumerState<FloorPlanCanvas> {
  /// Current mouse position in world coordinates for the
  /// interaction painter and status bar.
  Offset? _hoverWorldPoint;

  /// Default grid spacing (mm).
  static const _gridSpacingMm = 100.0;

  double _initialZoom = 1.0;

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasControllerProvider);
    final colors = Theme.of(context)
        .extension<HeatingPlannerColors>()!;
    final onSurface =
        Theme.of(context).colorScheme.onSurface;

    // Compute visible rect in world coords for the grid
    // painter.  We use the layout size + inverse transform.
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
            onTapDown: (_) {
              // Tool delegation placeholder.
            },
            child: MouseRegion(
              onHover: (event) {
                setState(() {
                  _hoverWorldPoint = _toWorld(
                    canvasState,
                    event.localPosition,
                  );
                });
              },
              onExit: (_) {
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
      // ignore: always_specify_types
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
    this.hoverWorldPoint,
  });

  final Matrix4 transform;
  final double gridSpacingMm;
  final Rect visibleRect;
  final HeatingPlannerColors colors;
  final Color onSurface;
  final Offset? hoverWorldPoint;

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
    ).paint(canvas, size);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CanvasCompositePainter oldDelegate) {
    return true; // Interaction layer changes frequently.
  }
}
