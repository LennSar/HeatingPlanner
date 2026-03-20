import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';

/// A small coloured badge indicating a [WarningSeverity] level.
///
/// Used in the Warnings tab of the Performance Dashboard and anywhere else
/// a compact severity indicator is needed.
///
/// ```dart
/// SeverityBadge(severity: WarningSeverity.error)
/// SeverityBadge.label(severity: WarningSeverity.warning)
/// ```
class SeverityBadge extends StatelessWidget {
  /// Icon-only badge.
  const SeverityBadge({required this.severity, super.key})
      : _showLabel = false;

  /// Badge with icon and text label.
  const SeverityBadge.label({required this.severity, super.key})
      : _showLabel = true;

  /// The severity level to represent.
  final WarningSeverity severity;

  final bool _showLabel;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<HeatingPlannerColors>()!;

    final (icon, color, label) = switch (severity) {
      WarningSeverity.error => (
          Icons.error_rounded,
          colors.zoneRed,
          'Error',
        ),
      WarningSeverity.warning => (
          Icons.warning_amber_rounded,
          colors.zoneYellow,
          'Warning',
        ),
      WarningSeverity.info => (
          Icons.info_rounded,
          Theme.of(context).colorScheme.primary,
          'Info',
        ),
    };

    if (!_showLabel) {
      return Icon(icon, size: 16, color: color);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: Spacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
