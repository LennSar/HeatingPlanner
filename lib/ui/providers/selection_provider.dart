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

/// Notifier for the element currently highlighted via hover.
class HoveredElementNotifier
    extends Notifier<SelectedElement?> {
  @override
  SelectedElement? build() => null;

  /// Highlight [element] (called on pointer enter / long-press).
  void set(SelectedElement element) {
    state = element;
  }

  /// Clear the hover highlight (called on pointer exit or after
  /// the tablet long-press timer expires).
  void clear() {
    state = null;
  }
}

/// Provider tracking the element currently highlighted by the
/// cursor hovering over a warning row in the Warnings panel.
///
/// Purely visual — does not affect [selectedElementProvider].
final hoveredElementProvider = NotifierProvider<
    HoveredElementNotifier, SelectedElement?>(
  HoveredElementNotifier.new,
);
