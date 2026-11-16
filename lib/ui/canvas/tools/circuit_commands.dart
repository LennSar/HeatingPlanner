import '../../../data/models/heating_circuit.dart';
import '../../../data/models/heating_zone.dart';
import 'undo_redo_service.dart';

/// Command: connect a heating zone with a newly drawn circuit (ADR-042
/// Rule 1).
///
/// [execute] (also redo) adds [circuit] and sets the zone's
/// `circuitId`; [undo] removes the circuit and restores [zoneBefore].
/// The captured objects are re-used on redo, so the circuit comes back
/// with the same id and geometry.
class CreateCircuitCommand extends Command {
  /// Creates a [CreateCircuitCommand].
  CreateCircuitCommand({
    required this.circuit,
    required this.zoneBefore,
    required this.add,
    required this.remove,
    required this.updateZone,
    required this.label,
  });

  /// The circuit added on [execute] and removed on [undo].
  final HeatingCircuit circuit;

  /// The zone as it was before it was connected (no `circuitId`).
  final HeatingZone zoneBefore;

  /// Adds a circuit (typically `EditorCallbacks.commitCircuit`).
  final void Function(HeatingCircuit) add;

  /// Removes a circuit by id (typically `EditorCallbacks.removeCircuit`).
  final void Function(String) remove;

  /// Replaces a zone (typically `EditorCallbacks.updateZone`).
  final void Function(HeatingZone) updateZone;

  @override
  final String label;

  @override
  void execute() {
    add(circuit);
    updateZone(zoneBefore.copyWith(circuitId: circuit.id));
  }

  @override
  void undo() {
    remove(circuit.id);
    updateZone(zoneBefore);
  }
}

/// Command: change a circuit — its connection-pipe route, distances,
/// supply/return sides or insulation type (ADR-042 Rule 1).
class UpdateCircuitCommand extends Command {
  /// Creates an [UpdateCircuitCommand].
  UpdateCircuitCommand({
    required this.oldCircuit,
    required this.newCircuit,
    required this.update,
    required this.label,
  });

  /// The circuit before the change — restored on [undo].
  final HeatingCircuit oldCircuit;

  /// The circuit after the change — applied on [execute] / redo.
  final HeatingCircuit newCircuit;

  /// Replaces a circuit (typically `EditorCallbacks.updateCircuit`).
  final void Function(HeatingCircuit) update;

  @override
  final String label;

  @override
  void execute() => update(newCircuit);

  @override
  void undo() => update(oldCircuit);
}

/// Command: delete a circuit and disconnect its zone (ADR-042 Rule 1).
///
/// [undo] re-adds the circuit and restores [connectedZone] with its
/// `circuitId`.
class DeleteCircuitCommand extends Command {
  /// Creates a [DeleteCircuitCommand].
  DeleteCircuitCommand({
    required this.circuit,
    required this.connectedZone,
    required this.remove,
    required this.add,
    required this.updateZone,
    required this.label,
  });

  /// The circuit removed on [execute] and re-added on [undo].
  final HeatingCircuit circuit;

  /// The zone connected to [circuit] before the delete, or null.
  final HeatingZone? connectedZone;

  /// Removes a circuit by id.
  final void Function(String) remove;

  /// Adds a circuit.
  final void Function(HeatingCircuit) add;

  /// Replaces a zone.
  final void Function(HeatingZone) updateZone;

  @override
  final String label;

  @override
  void execute() {
    remove(circuit.id);
    final zone = connectedZone;
    if (zone != null) updateZone(zone.copyWith(circuitId: null));
  }

  @override
  void undo() {
    add(circuit);
    final zone = connectedZone;
    if (zone != null) updateZone(zone);
  }
}
