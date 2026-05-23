import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/validation_result.dart';

/// Notifier for transient [ValidationResult]s emitted at one-shot events
/// (e.g. ADR-017 Rule 8d shared-wall promotion conflicts) which the
/// validation service cannot derive from current state alone.
///
/// Entries persist until cleared explicitly or replaced. The validation
/// service includes them alongside its derived rules so the UI surfaces
/// the warning without blocking the originating operation.
class TransientWarningsNotifier extends Notifier<List<ValidationResult>> {
  @override
  List<ValidationResult> build() => const [];

  /// Append a warning to the list.
  void add(ValidationResult result) {
    state = [...state, result];
  }

  /// Remove all warnings whose [ValidationResult.elementId] equals [id].
  ///
  /// Called from the UI when the user resolves an emitted conflict
  /// (e.g. accepts the adopted construction).
  void clearForElement(String id) {
    state = state.where((r) => r.elementId != id).toList();
  }

  /// Drop every transient warning. Used when reloading a project.
  void clearAll() {
    state = const [];
  }
}

/// Holds one-shot [ValidationResult]s emitted at promotion-time events
/// (ADR-017 Rule 8d). [validationResultsProvider] folds these into its
/// derived results.
final transientWarningsProvider =
    NotifierProvider<TransientWarningsNotifier, List<ValidationResult>>(
  TransientWarningsNotifier.new,
);
