import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract command for the undo/redo system.
///
/// Each user action that mutates editor state creates a
/// [Command] and pushes it onto the undo stack.
abstract class Command {
  /// Human-readable label for debugging / UI display.
  String get label;

  /// Apply the command (first time or redo).
  void execute();

  /// Reverse the command.
  void undo();
}

/// Manages undo and redo stacks of [Command] objects.
///
/// Stack limit is 100 entries. Pushing a new command clears
/// the redo stack. Thread-safe for single-isolate Flutter use.
class UndoRedoService {
  /// Maximum number of commands on the undo stack.
  static const int stackLimit = 100;

  final _undoStack = ListQueue<Command>();
  final _redoStack = ListQueue<Command>();

  /// Lets the active tool take an undo for a step of its own that is not
  /// on the stack yet — a corner of a tube still being drawn (ADR-046).
  /// Returns true when the tool handled it; [undo] then leaves the stack
  /// alone. Set by the canvas.
  bool Function()? toolUndo;

  /// Counterpart of [toolUndo] for [redo].
  bool Function()? toolRedo;

  /// Bumped after every [execute], [undo], [redo] and [clear], so views
  /// that show derived state — the active tool's overlay — can refresh.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Whether an undo operation is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether a redo operation is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Execute [command] and push it onto the undo stack.
  ///
  /// Clears the redo stack. Trims undo stack to [stackLimit].
  void execute(Command command) {
    command.execute();
    _undoStack.addLast(command);
    _redoStack.clear();

    while (_undoStack.length > stackLimit) {
      _undoStack.removeFirst();
    }
    revision.value++;
  }

  /// Undo the most recent command.
  ///
  /// The active tool gets the first chance through [toolUndo].
  void undo() {
    if (toolUndo?.call() ?? false) {
      revision.value++;
      return;
    }
    if (_undoStack.isEmpty) return;
    final command = _undoStack.removeLast();
    command.undo();
    _redoStack.addLast(command);
    revision.value++;
  }

  /// Redo the most recently undone command.
  ///
  /// The active tool gets the first chance through [toolRedo].
  void redo() {
    if (toolRedo?.call() ?? false) {
      revision.value++;
      return;
    }
    if (_redoStack.isEmpty) return;
    final command = _redoStack.removeLast();
    command.execute();
    _undoStack.addLast(command);
    revision.value++;
  }

  /// Clear both stacks.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    revision.value++;
  }
}

/// Singleton provider for the [UndoRedoService].
final undoRedoProvider = Provider<UndoRedoService>((ref) {
  return UndoRedoService();
});
