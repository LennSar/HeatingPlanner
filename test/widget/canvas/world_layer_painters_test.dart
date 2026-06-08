// Tests for the split non-interactive world layers (agent-frontend.md §4.3).
//
// The floor plan's static world is painted as three stacked layers —
// GridLayerPainter, GeometryLayerPainter, PipeAnnotationLayerPainter — each
// behind its own RepaintBoundary with a tight shouldRepaint keyed only on its
// real inputs. The central guarantee verified here: a geometry edit (which
// mints fresh walls/rooms list identities every drag frame) must NOT repaint
// the grid layer, because the grid depends only on transform / spacing /
// visibleRect / dot colour.
//
// Naming: WLP-Gnn grid layer, WLP-GEnn geometry layer, WLP-PAnn pipe/annotation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
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

  group('PipeAnnotationLayerPainter.shouldRepaint', () {
    PipeAnnotationLayerPainter pipes({
      required List<WallSegment> walls,
      required List<Room> rooms,
      String? selectedWallId,
    }) {
      return PipeAnnotationLayerPainter(
        transform: transform,
        colors: colors,
        onSurface: onSurface,
        walls: walls,
        rooms: rooms,
        circuits: const [],
        selectedWallId: selectedWallId,
      );
    }

    test('WLP-PA01: repaints when wall geometry changes (annotation labels)',
        () {
      final rooms = [createTestRoom()];
      final before = pipes(walls: [createTestWall()], rooms: rooms);
      final after = pipes(walls: [createTestWall()], rooms: rooms);
      // Fresh walls list identity each frame → annotation labels may change.
      expect(after.shouldRepaint(before), isTrue);
    });

    test('WLP-PA02: repaints when the selected wall changes', () {
      final walls = [createTestWall()];
      final rooms = [createTestRoom()];
      final before = pipes(walls: walls, rooms: rooms);
      final after = pipes(walls: walls, rooms: rooms, selectedWallId: 'wall-1');
      expect(after.shouldRepaint(before), isTrue);
    });

    test('WLP-PA03: does NOT repaint when nothing changed', () {
      final walls = [createTestWall()];
      final rooms = [createTestRoom()];
      final before = pipes(walls: walls, rooms: rooms);
      final after = pipes(walls: walls, rooms: rooms);
      expect(after.shouldRepaint(before), isFalse);
    });
  });
}
