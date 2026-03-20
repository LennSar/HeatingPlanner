import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';

/// A small chip badge indicating a [WarningSeverity] level.
///
/// Visual: 1px border, 4px border-radius, 15%-opacity background,
/// leading 6px filled dot — all derived from [HeatingPlannerColors]
/// tokens (`errorRed` / `warningAmber` / `infoBlue`).
///
/// Two constructors:
/// ```dart
/// SeverityBadge.label(severity: WarningSeverity.error)
/// SeverityBadge.count(severity: WarningSeverity.warning, count: 3)
/// ```
class SeverityBadge extends StatelessWidget {
  /// Badge showing the severity name ("Error" / "Warning" / "Info").
  const SeverityBadge.label({
    required this.severity,
    super.key,
  }) : _count = null;

  /// Badge showing a numeric count for the given severity.
  const SeverityBadge.count({
    required this.severity,
    required int count,
    super.key,
  }) : _count = count;

  /// The severity level to represent.
  final WarningSeverity severity;

  /// When non-null, the badge displays this count instead of a label.
  final int? _count;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<HeatingPlannerColors>()!;

    final (color, label) = switch (severity) {
      WarningSeverity.error => (colors.errorRed, 'Error'),
      WarningSeverity.warning => (colors.warningAmber, 'Warning'),
      WarningSeverity.info => (colors.infoBlue, 'Info'),
    };

    final text = _count != null ? '$_count' : label;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            text,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
          ),
        ],
      ),
    );
  }
}
