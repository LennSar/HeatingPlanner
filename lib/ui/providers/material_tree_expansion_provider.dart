import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Expansion state for the wall-construction-editor material-picker tree
/// (UI/UX §5.7.1 item 4 / `DECISIONS.md` ADR-022 Rule 5).
///
/// Holds the **joined path** of every expanded node — each entry is a
/// node's `categoryPath` joined with `/`, e.g.
/// `"Insulation boards/Wood fibre"`. (Segments can never contain `/`
/// per ADR-022 Rule 1, so the join is unambiguous.)
///
/// The provider is scoped to the editor's lifetime: the wall / slab
/// construction editor calls [MaterialTreeExpansionNotifier.reset] when
/// it opens and when it closes, so closing the editor collapses every
/// node. The picker dropdown's own open/close lifecycle does **not**
/// reset the set — reopening the dropdown restores the prior expansion.
class MaterialTreeExpansionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  /// Toggles the expanded/collapsed state of the node identified by
  /// [joinedPath].
  void toggle(String joinedPath) {
    final next = Set<String>.from(state);
    if (!next.add(joinedPath)) {
      next.remove(joinedPath);
    }
    state = next;
  }

  /// Collapses every node. Called by the construction editor on open and
  /// close so expansion never leaks between editor sessions.
  void reset() => state = <String>{};
}

/// Editor-scoped expansion set for the material-picker inline-disclosure
/// tree. See [MaterialTreeExpansionNotifier].
final materialTreeExpansionProvider =
    NotifierProvider<MaterialTreeExpansionNotifier, Set<String>>(
  MaterialTreeExpansionNotifier.new,
);
