// ADR-026 throttle contract for [annotationGeometryProvider].
//
// The dimension-annotation layer re-runs a per-wall / per-room `ui.Paragraph`
// layout whenever the walls/rooms list identity it is given changes. Feeding it
// `editorState` directly would relayout the whole floor every drag frame (the
// cause of wall-drag lag). [annotationGeometryProvider] instead:
//
//   (a) at rest, mirrors `editorStateProvider` live (same list identity) so a
//       normal edit relayouts labels immediately;
//   (b) during a drag (`activeDragProvider` true), holds a stable snapshot
//       between ~10 fps samples — many transient edits within one sample window
//       do NOT change the emitted identity, so the layer does not repaint;
//   (c) samples the latest geometry once per [annotationSampleInterval]; and
//   (d) on drag end, snaps back to the live (settled) geometry.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/ui/canvas/floor_plan_canvas.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';

import '../../helpers/test_factories.dart';

void main() {
  test(
      'at rest the annotation geometry mirrors editorState live '
      '(labels relayout immediately on an edit)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(annotationGeometryProvider, (_, __) {}); // canvas-like

    final editor = container.read(editorStateProvider.notifier);
    editor.replaceAllWalls([createTestWall()]);

    final geo = container.read(annotationGeometryProvider);
    expect(
      identical(geo.walls, container.read(editorStateProvider).walls),
      isTrue,
      reason: 'idle feed shares editorState list identity',
    );
  });

  test(
      'during a drag, transient edits within one sample window do NOT change '
      'the emitted geometry; a sample interval later it catches up; drag end '
      'snaps to the settled geometry', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // The throttle only arms its periodic timer when build() re-runs, which
    // requires the provider to be listened (eagerly rebuilt), exactly as the
    // canvas does in production.
    container.listen(annotationGeometryProvider, (_, __) {});

    final editor = container.read(editorStateProvider.notifier);
    final drag = container.read(activeDragProvider.notifier);

    final wall = createTestWall();
    editor.replaceAllWalls([wall]);

    // Drag start: snapshot is the drag-start geometry.
    drag.begin();
    final snapshot = container.read(annotationGeometryProvider);

    // A burst of transient frames within the first sample window. Each mints a
    // fresh editorState walls list, but the annotation feed must stay put.
    for (var i = 1; i <= 5; i++) {
      editor.updateWallTransient(
        wall.copyWith(endPoint: Point2D(x: 5000 + i * 10.0, y: 0)),
      );
    }
    expect(
      identical(
        container.read(annotationGeometryProvider).walls,
        snapshot.walls,
      ),
      isTrue,
      reason: 'no repaint between samples — mid-burst identity is unchanged',
    );

    // Let one sample interval elapse: the periodic sampler fires once and the
    // feed catches up to the latest transient geometry.
    await Future<void>.delayed(
      annotationSampleInterval + const Duration(milliseconds: 20),
    );
    final sampled = container.read(annotationGeometryProvider);
    expect(
      identical(sampled.walls, container.read(editorStateProvider).walls),
      isTrue,
      reason: 'sample tick adopts the current geometry',
    );
    expect(
      identical(sampled.walls, snapshot.walls),
      isFalse,
      reason: 'and it is a different identity than the drag-start snapshot',
    );

    // Final transient frame, then release.
    editor.updateWallTransient(
      wall.copyWith(endPoint: const Point2D(x: 6000, y: 0)),
    );
    drag.end();
    expect(
      identical(
        container.read(annotationGeometryProvider).walls,
        container.read(editorStateProvider).walls,
      ),
      isTrue,
      reason: 'drag end snaps back to the live, settled geometry',
    );
  });
}
