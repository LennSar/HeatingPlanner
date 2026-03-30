import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import '../../../core/utils/id_generator.dart';
import '../../../data/models/distributor.dart';
import '../../../data/models/point2d.dart';
import '../painters/interaction_data.dart';
import 'editor_callbacks.dart';
import 'snap_service.dart';
import 'tool_base.dart';
import 'undo_redo_service.dart';

/// Tool for placing a [Distributor] on the floor plan.
///
/// Clicking places the distributor snapped to the grid.
/// Only one distributor per floor is allowed; if one already
/// exists the user is shown a "Move / Replace / Cancel" dialog.
/// After placement the properties panel opens automatically
/// (via [EditorCallbacks.selectElement]) to edit supply
/// temperature, return temperature, and pump head.
class DistributorPlaceTool extends CanvasTool {
  /// Creates a [DistributorPlaceTool].
  DistributorPlaceTool({
    required super.callbacks,
    required super.onStateChanged,
    required this.undoRedo,
  });

  /// Shared undo/redo service.
  final UndoRedoService undoRedo;

  /// Current grid-snapped cursor position (world mm).
  Point2D? _ghostPosition;

  /// Current wall-snapped rotation in degrees (0, 90, 180, or 270).
  int _ghostRotationDeg = 0;

  @override
  String get name => 'Place Distributor';

  @override
  void onPointerMove(Point2D worldPoint) {
    _ghostPosition = SnapService.snapToGrid(worldPoint);
    _ghostRotationDeg = _wallSnapRotation(_ghostPosition!);
    onStateChanged();
  }

  @override
  void onTap(
    Point2D worldPoint,
    PointerDeviceKind deviceKind,
  ) {
    final snapped = SnapService.snapToGrid(worldPoint);
    final existing = callbacks.currentDistributor;

    if (existing == null) {
      _placeNew(snapped);
    } else {
      callbacks.requestDistributorReplaceDialog(
        onMove: () => _moveExisting(existing, snapped),
        onReplace: () => _replaceNew(existing, snapped),
      );
    }
  }

  @override
  void cancel() {
    _ghostPosition = null;
    onStateChanged();
  }

  @override
  InteractionData? getInteractionData() {
    if (_ghostPosition == null) return null;
    return DistributorGhostData(
      position: _ghostPosition!,
      widthMm: 500.0,
      rotationDeg: _ghostRotationDeg,
    );
  }

  // ── Private helpers ────────────────────────────────────────

  /// Returns the rotation (in degrees, 0–359) that aligns the distributor
  /// parallel to the nearest wall within [SnapService.wallHoverThresholdMm].
  ///
  /// Uses the exact wall angle so the distributor aligns for walls at any
  /// orientation, not just horizontal and vertical.
  /// Returns [_ghostRotationDeg] unchanged when no wall is nearby.
  int _wallSnapRotation(Point2D position) {
    final nearest = SnapService.nearestWall(
      position,
      callbacks.currentWalls,
    );
    if (nearest == null) return _ghostRotationDeg;

    final dx = nearest.endPoint.x - nearest.startPoint.x;
    final dy = nearest.endPoint.y - nearest.startPoint.y;
    double angleDeg = math.atan2(dy, dx) * 180.0 / math.pi;
    if (angleDeg < 0) angleDeg += 360.0;
    return angleDeg.round() % 360;
  }

  void _placeNew(Point2D position) {
    final d = Distributor(
      id: IdGenerator.newId(),
      floorId: callbacks.currentFloorId,
      position: position,
      rotationDeg: _ghostRotationDeg,
    );
    undoRedo.execute(
      _PlaceDistributorCommand(
        distributor: d,
        add: callbacks.commitDistributor,
        remove: callbacks.removeDistributor,
      ),
    );
    callbacks.selectElement('distributor', d.id);
  }

  /// Move the existing distributor to [position], preserving all
  /// other properties (temperatures, pump head).
  void _moveExisting(Distributor existing, Point2D position) {
    final updated = existing.copyWith(position: position);
    undoRedo.execute(
      _UpdateDistributorCommand(
        oldDistributor: existing,
        newDistributor: updated,
        update: callbacks.updateDistributor,
      ),
    );
    callbacks.selectElement('distributor', updated.id);
  }

  /// Remove the existing distributor and place a new one with
  /// default properties at [position].
  void _replaceNew(Distributor existing, Point2D position) {
    final d = Distributor(
      id: IdGenerator.newId(),
      floorId: callbacks.currentFloorId,
      position: position,
    );
    undoRedo.execute(
      _ReplaceDistributorCommand(
        oldDistributor: existing,
        newDistributor: d,
        add: callbacks.commitDistributor,
        remove: callbacks.removeDistributor,
      ),
    );
    callbacks.selectElement('distributor', d.id);
  }
}

// ── Command classes ────────────────────────────────────────────

/// Command: place the first distributor on the floor.
class _PlaceDistributorCommand extends Command {
  _PlaceDistributorCommand({
    required this.distributor,
    required this.add,
    required this.remove,
  });

  final Distributor distributor;
  final void Function(Distributor) add;
  final void Function() remove;

  @override
  String get label => 'Place distributor';

  @override
  void execute() => add(distributor);

  @override
  void undo() => remove();
}

/// Command: move or update an existing distributor in-place.
class _UpdateDistributorCommand extends Command {
  _UpdateDistributorCommand({
    required this.oldDistributor,
    required this.newDistributor,
    required this.update,
  });

  final Distributor oldDistributor;
  final Distributor newDistributor;
  final void Function(Distributor) update;

  @override
  String get label => 'Move distributor';

  @override
  void execute() => update(newDistributor);

  @override
  void undo() => update(oldDistributor);
}

/// Command: replace an existing distributor with a fresh one.
class _ReplaceDistributorCommand extends Command {
  _ReplaceDistributorCommand({
    required this.oldDistributor,
    required this.newDistributor,
    required this.add,
    required this.remove,
  });

  final Distributor oldDistributor;
  final Distributor newDistributor;
  final void Function(Distributor) add;
  final void Function() remove;

  @override
  String get label => 'Replace distributor';

  @override
  void execute() => add(newDistributor);

  @override
  void undo() => add(oldDistributor);
}
