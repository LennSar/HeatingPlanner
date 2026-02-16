import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'validation_result.freezed.dart';
part 'validation_result.g.dart';

/// A single diagnostic message produced by the validation service.
@freezed
abstract class ValidationResult with _$ValidationResult {
  const factory ValidationResult({
    /// Error, warning, or informational classification.
    required WarningSeverity severity,

    /// UUID of the element that triggered this result.
    required String elementId,

    /// Domain type of the element (e.g. "room", "circuit", "zone").
    required String elementType,

    /// Human-readable description of the issue.
    required String message,

    /// Optional remediation hint shown in the UI.
    String? suggestedFix,
  }) = _ValidationResult;

  factory ValidationResult.fromJson(Map<String, dynamic> json) =>
      _$ValidationResultFromJson(json);
}
