import 'package:flutter/gestures.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/heating_zone.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../painters/interaction_data.dart';
import 'create_zone_command.dart';
import 'editor_callbacks.dart';
import 'modifier_draw_tool.dart';
import 'snap_service.dart';
import 'split_zone_command.dart';
import 'tool_base.dart';
import 'undo_redo_service.dart';

/// Tool for drawing heating zone polygons by successive clicks,
/// or — with Ctrl held — by dragging a rectangle corner to corner.
///
/// Interaction flow (UI/UX §5.3 + ADR-006):
///  1. First click is only accepted inside a room polygon. That
///     room becomes the primary room for the zone.
///  2. Each subsequent click adds a vertex (snapped to grid) if
///     the point is inside the primary room OR inside an adjacent
///     room sharing a door-connected wall with it (ADR-006).
///     Clicks outside all valid rooms are silently rejected.
///  3. Clicking within 15 screen-px of the first vertex, or
///     double-clicking, closes and commits the polygon.
///  4. Escape cancels and resets.
///  5. While the cursor is outside all valid placement areas, a
///     red prohibition indicator is painted near the cursor.
///
/// Desktop modifier vocabulary (shared [ModifierDrawTool] flags,
/// mirroring [WallDrawTool] — see `DECISIONS.md` ADR-013):
/// - **Shift** ([orthoSnap]): constrain the ghost edge from the
///   previous vertex (polygon mode) or the rect drag endpoint to
///   0° or 90°.
/// - **Ctrl** ([rectMode]): drag from corner A to corner B to
///   commit a four-vertex rectangular zone in one gesture.
/// - **Alt** ([freePlacement]): skip grid snap for the current
///   vertex / corner; the raw world coordinate is used instead.
///
/// **Ctrl+Shift+click — "fill room as one zone"** (UI/UX §5.3,
/// ADR-013 rule 4): with Ctrl **and** Shift held, a plain click
/// with *no drag* resolves the room under the cursor and commits
/// one heating zone whose polygon equals that room's polygon, with
/// the spec defaults. Single room only — the ADR-006 doorway-
/// spanning relaxation does **not** apply. If the room already has
/// a zone it is a no-op with a transient toast; clicking outside
/// any room is a silent no-op. A Ctrl+Shift *drag* still falls
/// through to the ortho-constrained rect commit ([onDragEnd]).
///
/// Per ADR-013 the rectangle corners are **not** passed through
/// [SnapService.snapRectCorner] / [SnapService.snapRectDimension]
/// (those are wall/room-graph features). The §5.3 / ADR-006
/// vertex-in-room validation applies to every rectangle corner,
/// and both polygon and rectangle closes commit through the same
/// [_commitZone] path.
///
/// On close the tool calls [EditorCallbacks.commitZone] with a
/// [HeatingZone] filled with defaults (tubeSpacingMm 150,
/// meander, borderDistanceMm 100, floorHeating).
class ZoneDrawTool extends CanvasTool with ModifierDrawTool {
  /// Creates a [ZoneDrawTool].
  ZoneDrawTool({
    required super.callbacks,
    required super.onStateChanged,
    required this.undoRedo,
  });

  /// Undo/redo service. Every zone created by this tool is committed
  /// through a [CreateZoneCommand] so it is revertible (ADR-014).
  final UndoRedoService undoRedo;

  final List<Point2D> _vertices = [];
  Point2D? _current;

  /// Most recent raw (un-snapped, un-ortho'd) cursor world point. Used
  /// for the ADR-018 Rule 8 hover preview hit-test, which must operate
  /// on the literal pointer location.
  Point2D? _rawCursor;
  bool _hasValidationError = false;

  /// True when the cursor is outside all valid placement areas.
  bool _cursorOutsideValidArea = false;

  DateTime? _lastTapTime;

  /// World-coordinate position of the most recent tap. A "double-tap" is
  /// only recognised when the second tap arrives both within the 300 ms
  /// time window **and** within [_doubleTapDistanceMm] of the prior tap —
  /// two clicks at distinctly different positions in quick succession
  /// (e.g. polygon-vertex drawing) must not be treated as a double-tap.
  Point2D? _lastTapPos;

  /// Max separation between successive taps still treated as a
  /// double-tap. Roughly the size of a touch target at default zoom.
  static const double _doubleTapDistanceMm = 200.0;

  /// The room where the first vertex was placed (ADR-006).
  Room? _primaryRoom;

  // ---- Rect-mode drag state (Ctrl, ADR-013) ----

  /// Snapped drag-start corner of the current rectangle, or null.
  Point2D? _rectDragStart;

  /// Snapped (and ortho-constrained) opposite corner during the
  /// current rectangle drag, or null.
  Point2D? _rectDragCurrent;

  /// Minimum number of vertices needed to close a polygon.
  static const int _minVertices = 3;

  /// Minimum rectangle side length in mm (ADR-013, mirrors
  /// [WallDrawTool]'s wall-length minimum).
  static const double _minRectSideMm = 100.0;

  @override
  String get name => 'Draw Zone';

  /// Close-to-first-vertex threshold converted to world mm.
  ///
  /// 15 screen-px / zoom (px per mm) = world-space mm threshold.
  double get _closeThresholdMm => 15.0 / callbacks.currentZoom;

  /// Grid-snap [raw] unless Alt ([freePlacement]) is held, in which
  /// case the raw world coordinate is used.
  ///
  /// Zones never snap to wall endpoints/interiors (unlike
  /// [WallDrawTool]'s `_snap`), so this uses pure grid snap.
  Point2D _snapZone(Point2D raw) => freePlacement
      ? raw
      : SnapService.snapToGrid(raw, callbacks.currentGridSpacingMm);

  @override
  void onTap(Point2D worldPoint, PointerDeviceKind deviceKind) {
    if (rectMode) return; // rect mode uses drag, not tap

    // Detect double-tap by both time *and* position proximity. Two taps
    // at distinctly different positions in quick succession (e.g. fast
    // polygon-vertex drawing) are NOT a double-tap; only repeated taps
    // at roughly the same spot are.
    final now = DateTime.now();
    final withinTime = _lastTapTime != null &&
        now.difference(_lastTapTime!) <
            const Duration(milliseconds: 300);
    final withinDistance = _lastTapPos != null &&
        GeometryEngine.distanceMm(worldPoint, _lastTapPos!) <=
            _doubleTapDistanceMm;
    final isDoubleTap = withinTime && withinDistance;
    _lastTapTime = now;
    _lastTapPos = worldPoint;

    // Clear any previous validation error on new user action.
    _hasValidationError = false;

    // Grid snap (Alt-aware), then ortho-constrain from the previous
    // vertex when Shift is held.
    var snapped = _snapZone(worldPoint);
    if (_vertices.isNotEmpty) {
      snapped = applyOrtho(_vertices.last, snapped);
    }

    // Double-tap routing (ADR-018 Rule 1.1 + Rule 11):
    //
    // - ≥ 3 committed vertices → close the polygon (unchanged).
    // - 0 or 1 vertices → the polygon buffer was effectively empty
    //   when this double-click started (a stray first-tap vertex
    //   from this same double-click counts as "empty"). Roll back
    //   that stray vertex and route to the zone-or-room actions:
    //     • cursor over a rectangular floor zone → split.
    //     • cursor over a non-rectangular floor zone → toast.
    //     • cursor over an empty room interior → fill-room
    //       (same code path as Ctrl+Shift+click, ADR-014).
    // - exactly 2 vertices → fall through; the next tap will add a
    //   third vertex and a subsequent double-tap can then close.
    if (isDoubleTap) {
      if (_vertices.length >= _minVertices) {
        _closeZone();
        return;
      }
      if (_vertices.length <= 1) {
        _vertices.clear();
        _primaryRoom = null;
        _hasValidationError = false;
        _handleEmptyBufferDoubleClick(worldPoint);
        return;
      }
    }

    // Single-click near the first vertex also closes.
    if (_vertices.length >= _minVertices) {
      final dist =
          GeometryEngine.distanceMm(snapped, _vertices.first);
      if (dist <= _closeThresholdMm) {
        _closeZone();
        return;
      }
    }

    // First vertex: find and lock the primary room.
    if (_vertices.isEmpty) {
      final room = _findRoomAt(snapped);
      if (room == null) return; // silently reject outside any room
      _primaryRoom = room;
      _vertices.add(snapped);
      onStateChanged();
      return;
    }

    // Subsequent vertices: validate against primary + door-adjacent.
    if (!_isValidPosition(snapped)) return; // silently reject

    _vertices.add(snapped);
    onStateChanged();
  }

  // ---- Rect-mode drag (Ctrl, ADR-013) ----

  @override
  void onPointerDown(Point2D worldPoint, int buttons) {
    if (!rectMode) return;
    // Grid snap only — ADR-013 does NOT apply snapRectCorner.
    _rectDragStart = _snapZone(worldPoint);
    _rectDragCurrent = _rectDragStart;
    onStateChanged();
  }

  @override
  void onDragUpdate(Point2D worldPoint) {
    if (!rectMode || _rectDragStart == null) return;
    // Grid snap → ortho. No snapRectCorner / snapRectDimension.
    _rectDragCurrent =
        applyOrtho(_rectDragStart!, _snapZone(worldPoint));
    onStateChanged();
  }

  @override
  void onDragEnd(Point2D worldPoint) {
    if (!rectMode) return;
    final start = _rectDragStart;
    if (start == null) return;

    // Grid snap → ortho (ADR-013: no snapRectCorner/Dimension).
    final end = applyOrtho(start, _snapZone(worldPoint));

    final w = (end.x - start.x).abs();
    final h = (end.y - start.y).abs();
    if (w < _minRectSideMm || h < _minRectSideMm) {
      callbacks.showToast(
        'Zone rectangle too small — both sides must be ≥ 100 mm',
      );
      _reset();
      return;
    }

    // Primary room = the room containing the drag-start corner
    // (§5.3: "the room where the first vertex was placed").
    final primaryRoom = _findRoomAt(start);
    if (primaryRoom == null) {
      callbacks.showToast('Draw the zone inside a room.');
      _reset();
      return;
    }
    _primaryRoom = primaryRoom;

    final minX = start.x < end.x ? start.x : end.x;
    final minY = start.y < end.y ? start.y : end.y;
    final maxX = start.x > end.x ? start.x : end.x;
    final maxY = start.y > end.y ? start.y : end.y;
    final corners = <Point2D>[
      Point2D(x: minX, y: minY),
      Point2D(x: maxX, y: minY),
      Point2D(x: maxX, y: maxY),
      Point2D(x: minX, y: maxY),
    ];

    // §5.3 / ADR-006: every corner must lie inside the primary
    // room or a door-connected adjacent room.
    if (!corners.every(_isValidPosition)) {
      callbacks.showToast(
        'Zone rectangle must stay inside the room '
        '(or a door-connected room).',
      );
      _reset();
      return;
    }

    _commitZone(corners, primaryRoom);
    _reset();
  }

  /// Ctrl+Shift+click (no drag) — "fill room as one zone".
  ///
  /// Per UI/UX §5.3 "Fill room as one zone" and `DECISIONS.md`
  /// ADR-013 rule 4: resolve the room under the cursor and commit
  /// one heating zone whose polygon equals that room's polygon,
  /// with the spec defaults. Single room only — the ADR-006
  /// doorway-spanning relaxation does **not** apply here, so the
  /// polygon is exactly `room.polygon` (an open ring, first != last,
  /// the same convention zone polygons use).
  ///
  /// The canvas only calls [onPointerUp] when the pointer is
  /// released *without* a drag (`_isDragging == false`), so a
  /// Ctrl+Shift *drag* still commits via the ortho-constrained
  /// rect path in [onDragEnd] (ADR-013 rule 2).
  @override
  void onPointerUp(Point2D worldPoint) {
    // Trigger is Ctrl+Shift held (rectMode = Ctrl, orthoSnap = Shift).
    // Any other state (plain click, Ctrl-only, polygon mode) is left
    // to the existing onTap path — onPointerUp is a no-op there.
    if (!(rectMode && orthoSnap)) return;

    // onPointerDown set a transient rect-drag ghost when Ctrl went
    // down; fill-room is a click, not a drag, so clear it.
    _rectDragStart = null;
    _rectDragCurrent = null;

    // Resolve the room directly under the cursor. Raw point, no grid
    // snap: the zone mirrors the room exactly and snapping could
    // nudge the hit out of a small room or across a wall.
    final room = _findRoomAt(worldPoint);
    if (room == null) {
      // Click outside any room: silent no-op.
      onStateChanged();
      return;
    }

    // One zone per room (single-room attribution via roomId,
    // ADR-006 rule 2). If the room already has one: no-op + toast.
    final alreadyZoned =
        callbacks.currentZones.any((z) => z.roomId == room.id);
    if (alreadyZoned) {
      callbacks.showToast('Room already has a heating zone.');
      onStateChanged();
      return;
    }

    // Single room only: the zone polygon is exactly the room
    // polygon. Shared commit path → one undo entry (ADR-013 rule 5).
    _commitZone(List<Point2D>.from(room.polygon), room);
    _reset();
  }

  @override
  void onPointerMove(Point2D worldPoint) {
    _rawCursor = worldPoint;
    if (rectMode) {
      // Keep the rect ghost fresh; the active drag is driven by
      // onDragUpdate (defensive parity with WallDrawTool).
      if (_rectDragStart != null) {
        _rectDragCurrent =
            applyOrtho(_rectDragStart!, _snapZone(worldPoint));
      }
      _cursorOutsideValidArea = !_isValidPosition(worldPoint);
      onStateChanged();
      return;
    }
    // Polygon mode: preview the snapped (and ortho-constrained)
    // vertex so the ghost edge matches where the click will land.
    _current = _vertices.isEmpty
        ? worldPoint
        : applyOrtho(_vertices.last, _snapZone(worldPoint));
    _cursorOutsideValidArea = !_isValidPosition(worldPoint);
    onStateChanged();
  }

  @override
  void cancel() {
    _reset();
  }

  @override
  InteractionData? getInteractionData() {
    // Rect-mode ghost reuses the WallDrawTool rectangle painter.
    if (rectMode &&
        _rectDragStart != null &&
        _rectDragCurrent != null) {
      return RectDrawData(
        corner1: _rectDragStart!,
        corner2: _rectDragCurrent!,
      );
    }

    // ADR-018 Rule 8: with an empty polygon buffer and the raw cursor
    // inside an existing rectangular floor zone, preview the bisector
    // line a double-click would cut along.
    if (_vertices.isEmpty && _rawCursor != null) {
      final zone = _rectangularZoneUnder(_rawCursor!);
      if (zone != null) {
        final line =
            SplitZoneCommand.bisectorForDoubleClick(zone.polygon);
        if (line != null) {
          return ZoneSplitPreviewData(
            start: line.start,
            end: line.end,
          );
        }
      }
    }

    // Show the prohibition indicator even before any vertex is placed,
    // but don't return data when the cursor is inside a valid area and
    // no polygon has started yet (nothing useful to draw).
    if (_vertices.isEmpty) {
      if (!_cursorOutsideValidArea || _current == null) return null;
    }
    return ZoneDrawData(
      vertices: List.unmodifiable(_vertices),
      currentPoint: _current,
      hasValidationError: _hasValidationError,
      cursorOutsideValidArea: _cursorOutsideValidArea,
    );
  }

  // ----------------------------------------------------------------
  // Private helpers
  // ----------------------------------------------------------------

  /// Returns the first room whose polygon contains [point], or null.
  Room? _findRoomAt(Point2D point) {
    for (final room in callbacks.currentRooms) {
      if (room.polygon.length >= 3 &&
          GeometryEngine.isPointInPolygon(point, room.polygon)) {
        return room;
      }
    }
    return null;
  }

  /// True if [point] lies inside a valid placement area.
  ///
  /// Before the primary room is established (no vertices yet), any
  /// room is valid. After the first vertex, only the primary room
  /// and its door-adjacent neighbours (ADR-006) are valid.
  bool _isValidPosition(Point2D point) {
    final rooms = _primaryRoom != null
        ? _validRooms()
        : callbacks.currentRooms;
    return rooms.any(
      (r) =>
          r.polygon.length >= 3 &&
          GeometryEngine.isPointInPolygon(point, r.polygon),
    );
  }

  /// Returns the primary room plus any rooms that share a
  /// door-connected wall with it (ADR-006).
  List<Room> _validRooms() {
    if (_primaryRoom == null) return [];
    final result = <Room>[_primaryRoom!];

    // Wall IDs belonging to the primary room.
    final primaryWallIds = callbacks.currentWalls
        .where((w) => w.roomId == _primaryRoom!.id)
        .map((w) => w.id)
        .toSet();

    // Which of those walls carry at least one door?
    final doorWallIds = callbacks.currentDoors
        .where((d) => primaryWallIds.contains(d.wallSegmentId))
        .map((d) => d.wallSegmentId)
        .toSet();

    // Collect adjacent room IDs from those door-bearing walls.
    final adjacentRoomIds = callbacks.currentWalls
        .where(
          (w) =>
              doorWallIds.contains(w.id) && w.adjacentRoomId != null,
        )
        .map((w) => w.adjacentRoomId!)
        .toSet();

    // Add the matching room objects.
    result.addAll(
      callbacks.currentRooms
          .where((r) => adjacentRoomIds.contains(r.id)),
    );

    return result;
  }

  void _closeZone() {
    if (_vertices.length < _minVertices) return;

    // Use the locked primary room (established at first vertex).
    final parentRoom = _primaryRoom;
    if (parentRoom == null) {
      _hasValidationError = true;
      onStateChanged();
      callbacks.showToast('Draw the zone inside a room.');
      return;
    }

    _commitZone(List<Point2D>.from(_vertices), parentRoom);
    _reset();
  }

  /// Commits a zone [polygon] for [parentRoom] with the spec-required
  /// defaults. Shared by the polygon-close and rectangle-commit paths
  /// (ADR-013: "both commit through the existing zone-commit path").
  void _commitZone(List<Point2D> polygon, Room parentRoom) {
    final zone = HeatingZone(
      id: IdGenerator.newId(),
      roomId: parentRoom.id,
      polygon: polygon,
      tubeSpacingMm: 150,
      tubeTypeId: callbacks.defaultTubeTypeId,
      flooringMaterialId: callbacks.defaultFlooringMaterialId,
      borderDistanceMm: 100,
      layoutPattern: LayoutPattern.meander,
      zoneType: ZoneType.floorHeating,
    );

    // ADR-014: route every zone-creation gesture (polygon close,
    // Ctrl-drag rectangle, ADR-013 Ctrl+Shift+click fill-room)
    // through the shared command so one Ctrl+Z reverts it.
    undoRedo.execute(CreateZoneCommand(
      zone: zone,
      add: callbacks.commitZone,
      remove: callbacks.removeZone,
      label: callbacks.l10n.undo_createZone,
    ));
  }

  void _reset() {
    _vertices.clear();
    _current = null;
    _rawCursor = null;
    _hasValidationError = false;
    _cursorOutsideValidArea = false;
    _primaryRoom = null;
    _lastTapTime = null;
    _lastTapPos = null;
    _rectDragStart = null;
    _rectDragCurrent = null;
    onStateChanged();
  }

  // ----------------------------------------------------------------
  // ADR-018: double-click on empty buffer
  // ----------------------------------------------------------------

  /// Returns the first floor zone whose polygon contains [point] and
  /// is rectangle-eligible per [SplitZoneCommand.isRectangularZone],
  /// or null. Used by both the hover preview ([getInteractionData])
  /// and the double-click routing path.
  HeatingZone? _rectangularZoneUnder(Point2D point) {
    for (final z in callbacks.currentZones) {
      if (z.zoneType != ZoneType.floorHeating) continue;
      if (z.polygon.length < 3) continue;
      if (!GeometryEngine.isPointInPolygon(point, z.polygon)) {
        continue;
      }
      if (!SplitZoneCommand.isRectangularZone(z.polygon)) continue;
      return z;
    }
    return null;
  }

  /// Returns the first floor zone whose polygon contains [point]
  /// regardless of rectangle eligibility, or null. Used by the
  /// double-click routing path so we can show the "non-rectangular"
  /// toast when the user double-clicks a non-rect zone.
  HeatingZone? _anyZoneUnder(Point2D point) {
    for (final z in callbacks.currentZones) {
      if (z.zoneType != ZoneType.floorHeating) continue;
      if (z.polygon.length < 3) continue;
      if (GeometryEngine.isPointInPolygon(point, z.polygon)) return z;
    }
    return null;
  }

  /// Routes a buffer-empty double-click per ADR-018 Rule 1.1 + Rule 11.
  ///
  /// Uses the raw [worldPoint] (no grid snap) so the hit-test matches
  /// where the user clicked, not where a vertex would have landed.
  void _handleEmptyBufferDoubleClick(Point2D worldPoint) {
    // 1. Zone under cursor.
    final zone = _anyZoneUnder(worldPoint);
    if (zone != null) {
      final direction =
          SplitZoneCommand.doubleClickDirection(zone.polygon);
      if (direction == null) {
        // Non-rectangular zone — Rule 1.1 / Rule 9 toast, no mutation.
        callbacks.showToast(
          callbacks.l10n.zone_splitNonRectangularToast,
        );
        _reset();
        return;
      }
      _dispatchSplit(zone, direction);
      _reset();
      return;
    }

    // 2. Empty room interior under cursor → fill-room (Rule 11).
    final room = _findRoomAt(worldPoint);
    if (room == null) {
      // Outside any room and any zone — silent no-op.
      _reset();
      return;
    }
    final alreadyZoned =
        callbacks.currentZones.any((z) => z.roomId == room.id);
    if (alreadyZoned) {
      callbacks.showToast('Room already has a heating zone.');
      _reset();
      return;
    }
    _commitZone(List<Point2D>.from(room.polygon), room);
    _reset();
  }

  /// Dispatches a [SplitZoneCommand] for [zone] in [direction],
  /// emitting the appropriate toast on rejection (ADR-018 Rule 4).
  /// Shared with [SelectTool]'s right-click handler.
  void _dispatchSplit(HeatingZone zone, SplitDirection direction) {
    final result = SplitZoneCommand.tryBuild(
      parent: zone,
      direction: direction,
      circuits: callbacks.currentCircuits,
      label: callbacks.l10n.undo_splitZone,
      add: callbacks.commitZone,
      remove: callbacks.removeZone,
      updateCircuit: callbacks.updateCircuit,
    );
    switch (result) {
      case SplitBuildOk(:final command):
        undoRedo.execute(command);
      case SplitBuildRejectedTooSmall():
        callbacks.showToast(callbacks.l10n.zone_splitTooSmallToast);
      case SplitBuildRejectedNonRectangular():
        callbacks.showToast(
          callbacks.l10n.zone_splitNonRectangularToast,
        );
    }
  }
}
