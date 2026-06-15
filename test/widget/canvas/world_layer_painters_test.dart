// Tests for the split non-interactive world layers (agent-frontend.md §4.3).
//
// The floor plan's static world is painted as four stacked layers —
// GridLayerPainter, GeometryLayerPainter, PipeLayerPainter, AnnotationLayerPainter
// — each behind its own RepaintBoundary with a tight shouldRepaint keyed only on
// its real inputs. Central guarantees verified here: a geometry edit (which mints
// fresh walls/rooms list identities every drag frame) must NOT repaint the grid
// or pipe layers, and the expensive annotation layer must stay still between the
// ~10 fps geometry samples it is fed during a drag (ADR-026).
//
// Naming: WLP-Gnn grid, WLP-GEnn geometry, WLP-PInn pipe, WLP-ANnn annotation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/heating_circuit.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/data/models/room.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/ui/canvas/painters/world_layer_painters.dart';

import '../../helpers/test_factories.dart';

void main() {
  // Shared fixtures.
  final transform = Matrix4.diagonal3Values(0.05, 0.05, 1);
  const visibleRect = Rect.fromLTRB(0, 0, 10000, 8000);
  final colors = HeatingPlannerColors.light();
  const onSurface = Color(0xFF1A1A2E);

  GridLayerPainter grid({
    Matrix4? t,
    double spacing = 100,
    Rect rect = visibleRect,
    Color dot = const Color(0xFFD1D5DB),
  }) {
    return GridLayerPainter(
      transform: t ?? transform,
      gridSpacingMm: spacing,
      visibleRect: rect,
      dotColor: dot,
    );
  }

  group('GridLayerPainter.shouldRepaint', () {
    test('WLP-G01: grid does NOT repaint when only wall geometry changed', () {
      // Simulate a wall-drag rebuild: the parent passes a fresh walls/rooms
      // list each frame, but the grid layer holds none of that geometry. With
      // every grid input unchanged, shouldRepaint must be false so the grid is
      // never redrawn mid-drag.
      final before = grid();
      final after = grid(); // identical grid inputs; geometry changed elsewhere
      expect(after.shouldRepaint(before), isFalse);
    });

    test('WLP-G02: repaints when the transform changes (pan/zoom)', () {
      final before = grid();
      final after = grid(t: Matrix4.diagonal3Values(0.06, 0.06, 1));
      expect(after.shouldRepaint(before), isTrue);
    });

    test('WLP-G03: repaints when the grid spacing changes', () {
      expect(grid(spacing: 250).shouldRepaint(grid(spacing: 100)), isTrue);
    });

    test('WLP-G04: repaints when the visible rect changes', () {
      final after = grid(rect: const Rect.fromLTRB(100, 100, 10100, 8100));
      expect(after.shouldRepaint(grid()), isTrue);
    });

    test('WLP-G05: repaints when the dot colour changes', () {
      expect(
        grid(dot: const Color(0xFF000000)).shouldRepaint(grid()),
        isTrue,
      );
    });
  });

  group('GeometryLayerPainter.shouldRepaint', () {
    GeometryLayerPainter geometry({
      required List<WallSegment> walls,
      required List<Room> rooms,
    }) {
      return GeometryLayerPainter(
        transform: transform,
        colors: colors,
        walls: walls,
        rooms: rooms,
        windows: const [],
        doors: const [],
        zones: const [],
        zoneStates: const {},
      );
    }

    test('WLP-GE01: repaints when the walls list identity changes', () {
      final wallsA = [createTestWall()];
      final roomsA = [createTestRoom()];
      // A drag mints a new list with the moved wall — fresh identity.
      final wallsB = [
        createTestWall(endPoint: const Point2D(x: 5100, y: 0)),
      ];
      final before = geometry(walls: wallsA, rooms: roomsA);
      final after = geometry(walls: wallsB, rooms: roomsA);
      expect(after.shouldRepaint(before), isTrue);
    });

    test('WLP-GE02: does NOT repaint when nothing changed (same identities)',
        () {
      final walls = [createTestWall()];
      final rooms = [createTestRoom()];
      final before = geometry(walls: walls, rooms: rooms);
      final after = geometry(walls: walls, rooms: rooms);
      expect(after.shouldRepaint(before), isFalse);
    });
  });

  group('PipeLayerPainter.shouldRepaint', () {
    PipeLayerPainter pipes({List<HeatingCircuit>? circuits}) {
      return PipeLayerPainter(
        transform: transform,
        colors: colors,
        circuits: circuits ?? const [],
      );
    }

    test('WLP-PI01: a fresh walls/rooms identity does NOT repaint the pipe '
        'layer (ADR-026: geometry lives on the geometry/annotation layers)',
        () {
      // The pipe layer holds no wall/room geometry, so the per-frame geometry
      // churn of a wall drag must never invalidate it.
      expect(pipes().shouldRepaint(pipes()), isFalse);
    });

    test('WLP-PI02: repaints when the circuits identity changes', () {
      // const [] is canonical (identical); a fresh list forces a repaint.
      expect(pipes(circuits: []).shouldRepaint(pipes()), isTrue);
    });
  });

  group('AnnotationLayerPainter.shouldRepaint', () {
    AnnotationLayerPainter annotations({
      required List<WallSegment> walls,
      required List<Room> rooms,
      String? selectedWallId,
    }) {
      return AnnotationLayerPainter(
        transform: transform,
        onSurface: onSurface,
        walls: walls,
        rooms: rooms,
        selectedWallId: selectedWallId,
      );
    }

    test('WLP-AN01: repaints when wall geometry changes (annotation labels)',
        () {
      final rooms = [createTestRoom()];
      // A new sample from annotationGeometryProvider mints a fresh walls list.
      final before = annotations(walls: [createTestWall()], rooms: rooms);
      final after = annotations(walls: [createTestWall()], rooms: rooms);
      expect(after.shouldRepaint(before), isTrue);
    });

    test('WLP-AN02: repaints when the selected wall changes', () {
      final walls = [createTestWall()];
      final rooms = [createTestRoom()];
      final before = annotations(walls: walls, rooms: rooms);
      final after =
          annotations(walls: walls, rooms: rooms, selectedWallId: 'wall-1');
      expect(after.shouldRepaint(before), isTrue);
    });

    test(
        'WLP-AN03: does NOT repaint when the geometry identity is unchanged '
        '(stable between 10 fps samples → no text layout)', () {
      // Between samples annotationGeometryProvider returns the SAME lists, so
      // the layer must not repaint and the per-wall/room text layout is skipped
      // — the whole point of ADR-026.
      final walls = [createTestWall()];
      final rooms = [createTestRoom()];
      final before = annotations(walls: walls, rooms: rooms);
      final after = annotations(walls: walls, rooms: rooms);
      expect(after.shouldRepaint(before), isFalse);
    });
  });
}
