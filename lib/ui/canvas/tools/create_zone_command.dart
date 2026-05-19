import '../../../data/models/heating_zone.dart';
import 'undo_redo_service.dart';

/// Command: create a heating zone (floor or wall).
///
/// Shared by [ZoneDrawTool] (polygon close, Ctrl-drag rectangle, and
/// the ADR-013 Ctrl+Shift+click "fill room as one zone" gesture) and
/// [WallZonePlaceTool], so every zone-creation path produces exactly
/// one undo entry. See `DECISIONS.md` ADR-014.
///
/// [execute] adds the zone via [add] (also used for redo); [undo]
/// removes it via [remove] using the zone's id. The [zone] object is
/// captured so a redo restores the identical record (same `id`). A
/// freshly created zone has no circuit, so removing it by id is a
/// complete inverse — no circuit-detachment bookkeeping is needed.
class CreateZoneCommand extends Command {
  /// Creates a [CreateZoneCommand].
  CreateZoneCommand({
    required this.zone,
    required this.add,
    required this.remove,
    required this.label,
  });

  /// The zone added on [execute] / redo and removed on [undo].
  final HeatingZone zone;

  /// Adds [zone] to editor state (typically `EditorCallbacks.commitZone`).
  final void Function(HeatingZone) add;

  /// Removes a zone by id (typically `EditorCallbacks.removeZone`).
  final void Function(String) remove;

  @override
  final String label;

  @override
  void execute() => add(zone);

  @override
  void undo() => remove(zone.id);
}
