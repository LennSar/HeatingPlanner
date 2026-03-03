import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a selected element on the canvas.
@immutable
class SelectedElement {
  /// Creates a [SelectedElement].
  const SelectedElement({
    required this.type,
    required this.id,
  });

  /// Element type (e.g. 'room', 'wall', 'window', 'door').
  final String type;

  /// Element ID.
  final String id;
}

/// Notifier for the currently selected element.
class SelectedElementNotifier
    extends Notifier<SelectedElement?> {
  @override
  SelectedElement? build() => null;

  /// Set the selected element.
  void select(SelectedElement? element) {
    state = element;
  }
}

/// Provider tracking the currently selected element.
final selectedElementProvider = NotifierProvider<
    SelectedElementNotifier, SelectedElement?>(
  SelectedElementNotifier.new,
);
