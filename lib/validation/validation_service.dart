import '../data/models/validation_result.dart';

/// Runs all validation rules for a project and returns a flat list
/// of [ValidationResult] items.
///
/// Consumed by [validationResultsProvider(projectId)].
abstract final class ValidationService {
  // TODO(architect): implement rule checks for:
  //  - Room polygon has ≥ 3 vertices
  //  - WallSegment constructionId set for exterior walls
  //  - HeatingZone polygon inside parent room polygon
  //  - Circuit pressureLossPa ≤ distributor pumpHeadPa
  //  - Floor surface temperature ≤ EN 1264-2 limit
  //  - All required FK references are non-null

  /// Placeholder — returns an empty list until rules are implemented.
  static List<ValidationResult> validate(String projectId) => const [];
}
