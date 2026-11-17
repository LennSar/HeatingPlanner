import '../../../data/models/heating_zone.dart';
import 'undo_redo_service.dart';

/// Command: change the tube path of a floor heating zone (ADR-046) —
/// a drag in the tube edit tool, a hand-drawn tube, or a reset to the
/// automatic layout.
///
/// [execute] (also redo) applies [newZone]; [undo] restores [oldZone],
/// so undoing the first edit of an automatic layout makes it automatic
/// again.
class UpdateTubePathCommand extends Command {
  /// Creates an [UpdateTubePathCommand].
  UpdateTubePathCommand({
    required this.oldZone,
    required this.newZone,
    required this.update,
    required this.label,
  });

  /// The zone before the change.
  final HeatingZone oldZone;

  /// The zone after the change.
  final HeatingZone newZone;

  /// Replaces a zone (typically `EditorCallbacks.updateZone`).
  final void Function(HeatingZone) update;

  @override
  final String label;

  @override
  void execute() => update(newZone);

  @override
  void undo() => update(oldZone);
}
