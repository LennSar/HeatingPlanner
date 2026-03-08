import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/providers/project_settings_provider.dart';
import '../../core/theme/app_theme.dart';

/// Opens the project settings dialog as a modal.
///
/// Covers outdoor design temperature and default indoor
/// temperature. Both update immediately (no Apply button,
/// per UI/UX Section 2.3).
Future<void> showProjectSettingsDialog(
  BuildContext context,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const ProjectSettingsDialog(),
  );
}

/// Modal dialog for editing project-level temperature settings.
///
/// Fields:
/// - Design outdoor temperature (−50…+10 °C)
/// - Default indoor temperature (15…30 °C)
///
/// Changes take effect immediately via [projectSettingsProvider]
/// and cascade to all [roomHeatDemandProvider] computations.
class ProjectSettingsDialog extends ConsumerStatefulWidget {
  /// Creates a [ProjectSettingsDialog].
  const ProjectSettingsDialog({super.key});

  @override
  ConsumerState<ProjectSettingsDialog> createState() =>
      _ProjectSettingsDialogState();
}

class _ProjectSettingsDialogState
    extends ConsumerState<ProjectSettingsDialog> {
  late TextEditingController _outdoorController;
  late TextEditingController _indoorController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(projectSettingsProvider);
    _outdoorController = TextEditingController(
      text: settings.designOutdoorTempC.toStringAsFixed(1),
    );
    _indoorController = TextEditingController(
      text: settings.defaultIndoorTempC.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _outdoorController.dispose();
    _indoorController.dispose();
    super.dispose();
  }

  void _applyOutdoor(String raw) {
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      // Reset to current value on invalid input.
      _outdoorController.text = ref
          .read(projectSettingsProvider)
          .designOutdoorTempC
          .toStringAsFixed(1);
      return;
    }
    ref
        .read(projectSettingsProvider.notifier)
        .setDesignOutdoorTempC(parsed);
    // Clamp displayed value if out of range.
    final clamped = parsed.clamp(-50.0, 10.0);
    if (clamped != parsed) {
      _outdoorController.text = clamped.toStringAsFixed(1);
    }
  }

  void _applyIndoor(String raw) {
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      _indoorController.text = ref
          .read(projectSettingsProvider)
          .defaultIndoorTempC
          .toStringAsFixed(1);
      return;
    }
    ref
        .read(projectSettingsProvider.notifier)
        .setDefaultIndoorTempC(parsed);
    final clamped = parsed.clamp(15.0, 30.0);
    if (clamped != parsed) {
      _indoorController.text = clamped.toStringAsFixed(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(projectSettingsProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Keep text fields in sync with external state changes
    // (e.g. slider moving while text field is not focused).
    final outdoorText =
        settings.designOutdoorTempC.toStringAsFixed(1);
    final indoorText =
        settings.defaultIndoorTempC.toStringAsFixed(1);
    if (_outdoorController.text != outdoorText &&
        !_outdoorController.selection.isValid) {
      _outdoorController.text = outdoorText;
    }
    if (_indoorController.text != indoorText &&
        !_indoorController.selection.isValid) {
      _indoorController.text = indoorText;
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Project Settings',
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.lg),

              // ── Design outdoor temperature ──────────────────
              Text(
                'Design Outdoor Temperature',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Used in all heat-demand calculations (EN 12831).',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              _TempRow(
                controller: _outdoorController,
                sliderValue: settings.designOutdoorTempC,
                min: -50.0,
                max: 10.0,
                divisions: 60,
                onSliderChanged: (v) {
                  ref
                      .read(projectSettingsProvider.notifier)
                      .setDesignOutdoorTempC(v);
                  _outdoorController.text =
                      v.toStringAsFixed(1);
                },
                onFieldSubmitted: _applyOutdoor,
                rangeLabel: '−50 to +10 °C',
              ),

              const SizedBox(height: Spacing.lg),
              const Divider(),
              const SizedBox(height: Spacing.md),

              // ── Default indoor temperature ──────────────────
              Text(
                'Default Indoor Temperature',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Applied to new rooms when they are created.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              _TempRow(
                controller: _indoorController,
                sliderValue: settings.defaultIndoorTempC,
                min: 15.0,
                max: 30.0,
                divisions: 30,
                onSliderChanged: (v) {
                  ref
                      .read(projectSettingsProvider.notifier)
                      .setDefaultIndoorTempC(v);
                  _indoorController.text =
                      v.toStringAsFixed(1);
                },
                onFieldSubmitted: _applyIndoor,
                rangeLabel: '15 to 30 °C',
              ),

              const SizedBox(height: Spacing.lg),

              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A slider + numeric text field row for a single temperature.
class _TempRow extends StatelessWidget {
  const _TempRow({
    required this.controller,
    required this.sliderValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onSliderChanged,
    required this.onFieldSubmitted,
    required this.rangeLabel,
  });

  final TextEditingController controller;
  final double sliderValue;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<String> onFieldSubmitted;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Slider fills available width.
            Expanded(
              child: Slider(
                value: sliderValue,
                min: min,
                max: max,
                divisions: divisions,
                label:
                    '${sliderValue.toStringAsFixed(1)} \u00B0C',
                onChanged: onSliderChanged,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            // Numeric text field.
            SizedBox(
              width: 80,
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^-?\d*\.?\d*',),
                  ),
                ],
                decoration: const InputDecoration(
                  suffixText: '\u00B0C',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.sm,
                  ),
                ),
                style: textTheme.bodyMedium,
                onSubmitted: onFieldSubmitted,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: Spacing.md),
          child: Text(
            rangeLabel,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
