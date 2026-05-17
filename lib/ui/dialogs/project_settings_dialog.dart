import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/providers/project_settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/app_preferences.dart';
import '../providers/editor_state_provider.dart';

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
  late TextEditingController _heightController;
  late TextEditingController _unheatedController;

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
    _heightController = TextEditingController(
      text: settings.floorHeightMm.toString(),
    );
    _unheatedController = TextEditingController(
      text: settings.unheatedSpaceTempC.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _outdoorController.dispose();
    _indoorController.dispose();
    _heightController.dispose();
    _unheatedController.dispose();
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

  void _applyUnheated(String raw) {
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      _unheatedController.text = ref
          .read(projectSettingsProvider)
          .unheatedSpaceTempC
          .toStringAsFixed(1);
      return;
    }
    ref
        .read(projectSettingsProvider.notifier)
        .setUnheatedSpaceTempC(parsed);
    final clamped = parsed.clamp(0.0, 25.0);
    if (clamped != parsed) {
      _unheatedController.text = clamped.toStringAsFixed(1);
    }
  }

  void _applyHeight(String raw) {
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      _heightController.text = ref
          .read(projectSettingsProvider)
          .floorHeightMm
          .toString();
      return;
    }
    final oldHeight =
        ref.read(projectSettingsProvider).floorHeightMm;
    final clamped = parsed.clamp(2000, 6000);
    ref
        .read(projectSettingsProvider.notifier)
        .setFloorHeightMm(clamped);
    if (clamped != parsed) {
      _heightController.text = clamped.toString();
    }
    ref
        .read(editorStateProvider.notifier)
        .updateWallZoneHeightsForFloor(oldHeight, clamped);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(projectSettingsProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Keep text fields in sync with external state changes
    // (e.g. slider moving while text field is not focused).
    final outdoorText =
        settings.designOutdoorTempC.toStringAsFixed(1);
    final indoorText =
        settings.defaultIndoorTempC.toStringAsFixed(1);
    final heightText = settings.floorHeightMm.toString();
    if (_outdoorController.text != outdoorText &&
        !_outdoorController.selection.isValid) {
      _outdoorController.text = outdoorText;
    }
    if (_indoorController.text != indoorText &&
        !_indoorController.selection.isValid) {
      _indoorController.text = indoorText;
    }
    if (_heightController.text != heightText &&
        !_heightController.selection.isValid) {
      _heightController.text = heightText;
    }
    final unheatedText =
        settings.unheatedSpaceTempC.toStringAsFixed(1);
    if (_unheatedController.text != unheatedText &&
        !_unheatedController.selection.isValid) {
      _unheatedController.text = unheatedText;
    }

    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          // Never taller than 90 % of the screen.
          maxHeight: screenHeight * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Fixed title row (never scrolls) ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.lg,
                Spacing.sm,
                Spacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.projectSettings,
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    tooltip: l10n.close,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            // ── Scrollable body ───────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  0,
                  Spacing.lg,
                  Spacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Design outdoor temperature ──────────
                    Text(
                      l10n.designOutdoorTemperature,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      l10n.designOutdoorTempDesc,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    _TempRow(
                      controller: _outdoorController,
                      sliderValue:
                          settings.designOutdoorTempC,
                      min: -50.0,
                      max: 10.0,
                      divisions: 60,
                      onSliderChanged: (v) {
                        ref
                            .read(
                              projectSettingsProvider
                                  .notifier,
                            )
                            .setDesignOutdoorTempC(v);
                        _outdoorController.text =
                            v.toStringAsFixed(1);
                      },
                      onFieldSubmitted: _applyOutdoor,
                      rangeLabel: l10n.designOutdoorTempRange,
                    ),

                    const SizedBox(height: Spacing.lg),
                    const Divider(),
                    const SizedBox(height: Spacing.md),

                    // ── Default indoor temperature ───────────
                    Text(
                      l10n.defaultIndoorTemperature,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      l10n.defaultIndoorTempDesc,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    _TempRow(
                      controller: _indoorController,
                      sliderValue:
                          settings.defaultIndoorTempC,
                      min: 15.0,
                      max: 30.0,
                      divisions: 30,
                      onSliderChanged: (v) {
                        ref
                            .read(
                              projectSettingsProvider
                                  .notifier,
                            )
                            .setDefaultIndoorTempC(v);
                        _indoorController.text =
                            v.toStringAsFixed(1);
                      },
                      onFieldSubmitted: _applyIndoor,
                      rangeLabel: l10n.defaultIndoorTempRange,
                    ),

                    const SizedBox(height: Spacing.lg),
                    const Divider(),
                    const SizedBox(height: Spacing.md),

                    // ── Default room height ──────────────────
                    Text(
                      l10n.defaultRoomHeight,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      l10n.defaultRoomHeightDesc,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    _HeightRow(
                      controller: _heightController,
                      sliderValue: settings.floorHeightMm,
                      onSliderChanged: (v) {
                        final oldHeight = ref
                            .read(projectSettingsProvider)
                            .floorHeightMm;
                        ref
                            .read(
                              projectSettingsProvider
                                  .notifier,
                            )
                            .setFloorHeightMm(v);
                        _heightController.text =
                            v.toString();
                        ref
                            .read(
                              editorStateProvider.notifier,
                            )
                            .updateWallZoneHeightsForFloor(
                              oldHeight,
                              v,
                            );
                      },
                      onFieldSubmitted: _applyHeight,
                      rangeLabel: l10n.defaultRoomHeightRange,
                    ),

                    const SizedBox(height: Spacing.lg),
                    const Divider(),
                    const SizedBox(height: Spacing.md),

                    // ── Unheated space temperature ───────────
                    Text(
                      l10n.unheatedSpaceTemp,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      l10n.unheatedSpaceTempDesc,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    _TempRow(
                      controller: _unheatedController,
                      sliderValue:
                          settings.unheatedSpaceTempC,
                      min: 0.0,
                      max: 25.0,
                      divisions: 25,
                      onSliderChanged: (v) {
                        ref
                            .read(
                              projectSettingsProvider
                                  .notifier,
                            )
                            .setUnheatedSpaceTempC(v);
                        _unheatedController.text =
                            v.toStringAsFixed(1);
                      },
                      onFieldSubmitted: _applyUnheated,
                      rangeLabel: l10n.unheatedSpaceTempRange,
                    ),

                    const SizedBox(height: Spacing.lg),
                    const Divider(),
                    const SizedBox(height: Spacing.md),

                    // ── Drawing grid size ────────────────────
                    Text(
                      l10n.settingsDrawingGridSize,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      l10n.drawingGridSizeDesc,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    _GridSpacingRow(),

                    const SizedBox(height: Spacing.lg),
                    const Divider(),
                    const SizedBox(height: Spacing.md),

                    // ── Language ─────────────────────────────
                    Text(
                      l10n.settingsLanguageLabel,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Spacing.sm),
                    const _LanguageRow(),

                    const SizedBox(height: Spacing.lg),

                    // Close button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(),
                        child: Text(l10n.close),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown row for selecting the drawing grid spacing.
class _GridSpacingRow extends ConsumerWidget {
  static const _options = [5, 10, 25, 50, 100];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(gridSpacingMmProvider).maybeWhen(
          data: (v) => v,
          orElse: () => 100,
        );
    final value = _options.contains(current) ? current : 100;

    return DropdownButton<int>(
      value: value,
      items: _options
          .map((v) => DropdownMenuItem(value: v, child: Text('$v mm')))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          ref.read(gridSpacingMmProvider.notifier).set(v);
        }
      },
    );
  }
}

/// Dropdown row for selecting the UI language.
class _LanguageRow extends ConsumerWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(languageCodeProvider).maybeWhen(
          data: (v) => v,
          orElse: () => 'en',
        );

    return DropdownButton<String>(
      value: current,
      items: [
        DropdownMenuItem(
          value: 'en',
          child: Text(l10n.languageEnglish),
        ),
        DropdownMenuItem(
          value: 'de',
          child: Text(l10n.languageGerman),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          ref.read(languageCodeProvider.notifier).set(value);
        }
      },
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

/// A slider + numeric text field row for an integer millimetre value.
class _HeightRow extends StatelessWidget {
  const _HeightRow({
    required this.controller,
    required this.sliderValue,
    required this.onSliderChanged,
    required this.onFieldSubmitted,
    required this.rangeLabel,
  });

  final TextEditingController controller;
  final int sliderValue;
  final ValueChanged<int> onSliderChanged;
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
            Expanded(
              child: Slider(
                value: sliderValue.toDouble(),
                min: 2000,
                max: 6000,
                divisions: 40,
                label: '$sliderValue mm',
                onChanged: (v) => onSliderChanged(v.round()),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            SizedBox(
              width: 80,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  suffixText: 'mm',
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
