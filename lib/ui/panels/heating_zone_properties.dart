import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/providers/heat_output_providers.dart';
import '../../calculation/providers/project_settings_provider.dart';
import '../../calculation/providers/tube_length_providers.dart';
import '../../core/constants/validation_limits.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/flooring_material.dart';
import '../../data/models/heating_zone.dart';
import '../../data/models/localized_catalog_row.dart';
import '../../data/models/tube_type.dart';
import '../../repositories/heating_repository.dart';
import '../canvas/tools/undo_redo_service.dart';
import '../providers/editor_state_provider.dart';

/// Properties panel shown when a [HeatingZone] is selected.
///
/// Editable fields: zone type, tube spacing, border distance,
/// layout pattern, tube type, flooring material.
/// Computed read-only fields: zone area, tube length (stub),
/// specific output (stub), total output (stub).
///
/// Every change goes through [undoRedoProvider] and immediately
/// updates [editorStateProvider] so the canvas repaints.
class HeatingZoneProperties extends ConsumerStatefulWidget {
  /// Creates [HeatingZoneProperties] for [zoneId].
  const HeatingZoneProperties({
    required this.zoneId,
    super.key,
  });

  /// ID of the zone to display/edit.
  final String zoneId;

  @override
  ConsumerState<HeatingZoneProperties> createState() =>
      _HeatingZonePropertiesState();
}

class _HeatingZonePropertiesState
    extends ConsumerState<HeatingZoneProperties> {
  // Text controllers for numeric text inputs (spacing, border, height,
  // and custom R value).
  late TextEditingController _spacingController;
  late TextEditingController _borderController;
  late TextEditingController _heightController;
  late TextEditingController _customRController;

  /// Snapshot taken when a slider drag starts for undo grouping.
  HeatingZone? _zoneAtSliderStart;

  /// Last zone ID synced into the text controllers.
  String? _lastSyncedZoneId;

  @override
  void initState() {
    super.initState();
    _spacingController = TextEditingController();
    _borderController = TextEditingController();
    _heightController = TextEditingController();
    _customRController = TextEditingController();
  }

  @override
  void dispose() {
    _spacingController.dispose();
    _borderController.dispose();
    _heightController.dispose();
    _customRController.dispose();
    super.dispose();
  }

  /// Syncs text controllers from the model when the zone or its
  /// parameter values change externally (undo/redo).
  void _syncControllers(HeatingZone zone, int defaultHeightMm) {
    final heightStr =
        (zone.heightMm ?? defaultHeightMm).toString();
    final customRStr =
        (zone.customFlooringResistance ?? 0.0)
            .toStringAsFixed(3);
    if (_lastSyncedZoneId == zone.id &&
        _spacingController.text ==
            zone.tubeSpacingMm.toString() &&
        _borderController.text ==
            zone.borderDistanceMm.toString() &&
        _heightController.text == heightStr &&
        _customRController.text == customRStr) {
      return;
    }
    _lastSyncedZoneId = zone.id;
    _spacingController.text = zone.tubeSpacingMm.toString();
    _borderController.text = zone.borderDistanceMm.toString();
    _heightController.text = heightStr;
    _customRController.text = customRStr;
  }

  /// Commits a zone update via the undo stack.
  void _commit(HeatingZone oldZone, HeatingZone newZone) {
    if (oldZone == newZone) return;
    ref.read(undoRedoProvider).execute(
          _UpdateZoneCommand(
            oldZone: oldZone,
            newZone: newZone,
            update: ref
                .read(editorStateProvider.notifier)
                .updateZone,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final editorState = ref.watch(editorStateProvider);
    final floorHeightMm = ref.watch(floorHeightMmProvider);
    final zone = editorState.zones
        .where((z) => z.id == widget.zoneId)
        .firstOrNull;

    if (zone == null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          'Zone not found',
          style: textTheme.bodyMedium,
        ),
      );
    }

    // Resolve the parent wall (for wall zones) to get the wall length
    // for the effective width display and area calculation.
    final isWallZone = zone.zoneType == ZoneType.wallHeating;
    final parentWall = isWallZone && zone.wallSegmentId != null
        ? editorState.walls
            .where((w) => w.id == zone.wallSegmentId)
            .firstOrNull
        : null;
    final wallLengthMm = parentWall != null
        ? GeometryEngine.distanceMm(
            parentWall.startPoint,
            parentWall.endPoint,
          ).round()
        : (zone.polygon.length >= 2
            ? GeometryEngine.distanceMm(
                zone.polygon[0],
                zone.polygon[1],
              ).round()
            : maxOpeningWidthMm);
    final effectiveWidthMm = zone.widthMm ?? wallLengthMm;

    // Keep text controllers in sync with external changes (undo/redo).
    ref.listen<EditorState>(editorStateProvider, (prev, next) {
      if (!mounted) return;
      final z = next.zones
          .where((z) => z.id == widget.zoneId)
          .firstOrNull;
      if (z == null) return;
      final prevZ = prev?.zones
          .where((z) => z.id == widget.zoneId)
          .firstOrNull;
      if (prevZ == null ||
          prevZ.tubeSpacingMm != z.tubeSpacingMm) {
        _spacingController.text = z.tubeSpacingMm.toString();
      }
      if (prevZ == null ||
          prevZ.borderDistanceMm != z.borderDistanceMm) {
        _borderController.text = z.borderDistanceMm.toString();
      }
      if (prevZ == null || prevZ.heightMm != z.heightMm) {
        _heightController.text =
            (z.heightMm ?? ref.read(floorHeightMmProvider))
                .toString();
      }
      if (prevZ == null ||
          prevZ.customFlooringResistance !=
              z.customFlooringResistance) {
        _customRController.text =
            (z.customFlooringResistance ?? 0.0)
                .toStringAsFixed(3);
      }
    });

    _syncControllers(zone, floorHeightMm);

    // For wall zones, display the heated wall surface area:
    //   zoneWidth × heightMm / 1e6  (m²).
    // For floor zones, use the polygon area (shoelace formula).
    final double areaM2;
    if (isWallZone) {
      final heightMm =
          (zone.heightMm ?? floorHeightMm).toDouble();
      areaM2 = effectiveWidthMm * heightMm / 1e6;
    } else if (zone.polygon.length >= 3) {
      areaM2 = GeometryEngine.polygonAreaM2(zone.polygon);
    } else {
      areaM2 = double.nan;
    }

    final tubeTypes = ref.watch(localizedTubeTypesProvider);
    final flooringMaterials = ref.watch(localizedFlooringMaterialsProvider);

    final specificOutputWPerM2 =
        ref.watch(zoneHeatOutputProvider(widget.zoneId));
    final totalOutputW =
        !specificOutputWPerM2.isNaN && !areaM2.isNaN
            ? specificOutputWPerM2 * areaM2
            : double.nan;
    final surfaceTempC =
        ref.watch(zoneSurfaceTempProvider(widget.zoneId));

    final outputTooltip = specificOutputWPerM2.isNaN
        ? _zoneMissingPrereqs(
            zone,
            editorState,
            tubeTypes.map((lr) => lr.row).toList(growable: false),
            flooringMaterials.map((lr) => lr.row).toList(growable: false),
          )
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.properties, style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text(l10n.heatingZone, style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),

          // ── Tube spacing ─────────────────────────────────────────
          Text(
            l10n.tubeSpacingValue(zone.tubeSpacingMm),
            style: textTheme.bodyMedium,
          ),
          Slider(
            value: zone.tubeSpacingMm.toDouble(),
            min: minTubeSpacingMm.toDouble(),
            max: maxTubeSpacingMm.toDouble(),
            divisions:
                (maxTubeSpacingMm - minTubeSpacingMm) ~/ 10,
            label: '${zone.tubeSpacingMm}\u202Fmm',
            onChangeStart: (_) => _zoneAtSliderStart = zone,
            onChanged: (value) {
              final mm = value.round();
              _spacingController.text = mm.toString();
              ref
                  .read(editorStateProvider.notifier)
                  .updateZone(zone.copyWith(tubeSpacingMm: mm));
            },
            onChangeEnd: (value) {
              final start = _zoneAtSliderStart;
              _zoneAtSliderStart = null;
              if (start == null) return;
              final mm = value.round();
              if (start.tubeSpacingMm != mm) {
                _commit(start, start.copyWith(tubeSpacingMm: mm));
              }
            },
          ),
          _NumericMmField(
            controller: _spacingController,
            min: minTubeSpacingMm,
            max: maxTubeSpacingMm,
            suffix: 'mm',
            helperText:
                '$minTubeSpacingMm\u2013$maxTubeSpacingMm mm',
            onSubmitted: (mm) {
              if (mm == zone.tubeSpacingMm) return;
              _commit(zone, zone.copyWith(tubeSpacingMm: mm));
            },
          ),

          // ── Wall zone height ─────────────────────────────────────
          // Shown only for wall heating zones.
          if (isWallZone) ...[
            Text(
              l10n.heightValue(zone.heightMm ?? floorHeightMm),
              style: textTheme.bodyMedium,
            ),
            Slider(
              value: (zone.heightMm ?? floorHeightMm)
                  .toDouble()
                  .clamp(
                    minWallZoneHeightMm.toDouble(),
                    maxRoomHeightMm.toDouble(),
                  ),
              min: minWallZoneHeightMm.toDouble(),
              max: maxRoomHeightMm.toDouble(),
              divisions: (maxRoomHeightMm - minWallZoneHeightMm) ~/
                  10,
              label:
                  '${zone.heightMm ?? floorHeightMm}\u202Fmm',
              onChangeStart: (_) => _zoneAtSliderStart = zone,
              onChanged: (value) {
                final mm = value.round();
                _heightController.text = mm.toString();
                ref
                    .read(editorStateProvider.notifier)
                    .updateZone(zone.copyWith(heightMm: mm));
              },
              onChangeEnd: (value) {
                final start = _zoneAtSliderStart;
                _zoneAtSliderStart = null;
                if (start == null) return;
                final mm = value.round();
                final prev = start.heightMm ?? floorHeightMm;
                if (prev != mm) {
                  _commit(
                    start,
                    start.copyWith(heightMm: mm),
                  );
                }
              },
            ),
            _NumericMmField(
              controller: _heightController,
              min: minWallZoneHeightMm,
              max: maxRoomHeightMm,
              suffix: 'mm',
              helperText:
                  '$minWallZoneHeightMm\u2013$maxRoomHeightMm mm',
              onSubmitted: (mm) {
                final prev = zone.heightMm ?? floorHeightMm;
                if (prev == mm) return;
                _commit(zone, zone.copyWith(heightMm: mm));
              },
            ),
            const SizedBox(height: Spacing.md),

            // ── Width along wall (read-only) ──────────────────────
            _readOnlyRow(
              'Width',
              '$effectiveWidthMm\u202Fmm',
              textTheme,
            ),
            const SizedBox(height: Spacing.md),
          ],

          // ── Border distance (floor zones only) ───────────────────
          if (!isWallZone) ...[
            Text(
              l10n.borderDistanceValue(zone.borderDistanceMm),
              style: textTheme.bodyMedium,
            ),
            Slider(
              value: zone.borderDistanceMm.toDouble(),
              min: minBorderDistanceMm.toDouble(),
              max: maxBorderDistanceMm.toDouble(),
              divisions:
                  (maxBorderDistanceMm - minBorderDistanceMm) ~/
                      10,
              label: '${zone.borderDistanceMm}\u202Fmm',
              onChangeStart: (_) => _zoneAtSliderStart = zone,
              onChanged: (value) {
                final mm = value.round();
                _borderController.text = mm.toString();
                ref
                    .read(editorStateProvider.notifier)
                    .updateZone(
                      zone.copyWith(borderDistanceMm: mm),
                    );
              },
              onChangeEnd: (value) {
                final start = _zoneAtSliderStart;
                _zoneAtSliderStart = null;
                if (start == null) return;
                final mm = value.round();
                if (start.borderDistanceMm != mm) {
                  _commit(
                    start,
                    start.copyWith(borderDistanceMm: mm),
                  );
                }
              },
            ),
            _NumericMmField(
              controller: _borderController,
              min: minBorderDistanceMm,
              max: maxBorderDistanceMm,
              suffix: 'mm',
              helperText:
                  '$minBorderDistanceMm\u2013$maxBorderDistanceMm mm',
              onSubmitted: (mm) {
                if (mm == zone.borderDistanceMm) return;
                _commit(
                  zone,
                  zone.copyWith(borderDistanceMm: mm),
                );
              },
            ),
            const SizedBox(height: Spacing.md),
          ],

          const Divider(height: Spacing.lg),

          // ── Layout pattern ───────────────────────────────────────
          Text(l10n.layoutPattern, style: textTheme.bodyMedium),
          const SizedBox(height: Spacing.xs),
          RadioGroup<LayoutPattern>(
            groupValue: zone.layoutPattern,
            onChanged: (value) {
              if (value == null || value == zone.layoutPattern) {
                return;
              }
              _commit(zone, zone.copyWith(layoutPattern: value));
            },
            child: Column(
              children: LayoutPattern.values
                  .map(
                    (pattern) => RadioListTile<LayoutPattern>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        _patternLabel(pattern),
                        style: textTheme.bodyMedium,
                      ),
                      value: pattern,
                    ),
                  )
                  .toList(),
            ),
          ),

          const Divider(height: Spacing.lg),

          // ── Tube type dropdown ───────────────────────────────────
          Text(l10n.tubeType, style: textTheme.bodyMedium),
          const SizedBox(height: Spacing.xs),
          _TubeTypeDropdown(
            tubes: tubeTypes,
            selectedId: zone.tubeTypeId,
            onChanged: (id) {
              if (id == zone.tubeTypeId) return;
              _commit(zone, zone.copyWith(tubeTypeId: id));
            },
          ),

          const SizedBox(height: Spacing.md),

          // ── Surface material dropdown ────────────────────────────
          Text(
            isWallZone ? l10n.surfaceMaterial : l10n.flooringMaterial,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.xs),
          Builder(
            builder: (_) {
              // Filter to zone-appropriate materials; the Custom
              // sentinel is appended manually below.
              final filtered = flooringMaterials.where((m) {
                if (m.row.id == kCustomFlooringMaterialId) {
                  return false;
                }
                if (isWallZone) {
                  return m.row.surfaceType == SurfaceType.wall ||
                      m.row.surfaceType == SurfaceType.both;
                }
                return m.row.surfaceType == SurfaceType.floor ||
                    m.row.surfaceType == SurfaceType.both;
              }).toList();

              final isCustom = zone.flooringMaterialId ==
                  kCustomFlooringMaterialId;
              final effectiveId = isCustom
                  ? kCustomFlooringMaterialId
                  : (filtered.any(
                        (m) => m.row.id == zone.flooringMaterialId,
                      )
                        ? zone.flooringMaterialId
                        : (filtered.isEmpty
                            ? kCustomFlooringMaterialId
                            : filtered.first.row.id));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InputDecorator(
                    decoration:
                        const InputDecoration(isDense: true),
                    child: DropdownButton<String>(
                      value: effectiveId,
                      isDense: true,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [
                        ...filtered.map(
                          (m) => DropdownMenuItem(
                            value: m.row.id,
                            child: Text(
                              '${m.displayName}'
                              ' (R\u03BB\u202F'
                              '${m.row.thermalResistance.toStringAsFixed(3)}'
                              '\u202Fm\u00B2K/W)',
                              style: textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: kCustomFlooringMaterialId,
                          child: Text(
                            l10n.customEllipsis,
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      onChanged: (id) {
                        if (id == null ||
                            id == zone.flooringMaterialId) {
                          return;
                        }
                        _commit(
                          zone,
                          zone.copyWith(flooringMaterialId: id),
                        );
                      },
                    ),
                  ),
                  if (isCustom) ...[
                    const SizedBox(height: Spacing.xs),
                    _CustomRValueField(
                      controller: _customRController,
                      onSubmitted: (r) {
                        if (r ==
                            zone.customFlooringResistance) {
                          return;
                        }
                        _commit(
                          zone,
                          zone.copyWith(
                            customFlooringResistance: r,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),

          const Divider(height: Spacing.lg),

          // ── Computed read-only fields ────────────────────────────
          Text(l10n.zoneOutput, style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.xs),
          _readOnlyRow(
            l10n.zoneArea,
            areaM2.isNaN
                ? '\u2014'
                : '${areaM2.toStringAsFixed(2)}\u202Fm\u00B2',
            textTheme,
          ),
          _readOnlyRow(
            l10n.tubeLengthLabel,
            _tubeLengthText(
              ref.watch(zoneTubeLengthProvider(widget.zoneId)),
            ),
            textTheme,
          ),
          _readOnlyRow(
            l10n.specificOutput,
            specificOutputWPerM2.isNaN
                ? '\u2014'
                : '${specificOutputWPerM2.toStringAsFixed(1)}\u202FW/m\u00B2',
            textTheme,
            context: context,
            tooltipMessage: outputTooltip,
          ),
          _readOnlyRow(
            l10n.totalOutput,
            totalOutputW.isNaN
                ? '\u2014'
                : '${totalOutputW.round()}\u202FW',
            textTheme,
            context: context,
            tooltipMessage: outputTooltip,
          ),
          _readOnlyRow(
            l10n.surfaceTemperature,
            surfaceTempC.isNaN
                ? '\u2014'
                : '${surfaceTempC.toStringAsFixed(1)}\u202F\u00B0C',
            textTheme,
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _tubeLengthText(double lengthM) {
  if (lengthM.isNaN) return '\u2014';
  return '${lengthM.toStringAsFixed(1)}\u202Fm';
}

String _patternLabel(LayoutPattern p) => switch (p) {
      LayoutPattern.meander => 'Meander',
      LayoutPattern.spiral => 'Spiral',
      LayoutPattern.bifilar => 'Bifilar',
      LayoutPattern.counterflow => 'Counterflow',
    };

Widget _readOnlyRow(
  String label,
  String value,
  TextTheme textTheme, {
  BuildContext? context,
  String? tooltipMessage,
}) {
  final valueStyle =
      textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

  Widget valueWidget;
  if (value == '\u2014' &&
      tooltipMessage != null &&
      context != null) {
    final secondaryColor =
        Theme.of(context).colorScheme.onSurfaceVariant;
    valueWidget = Tooltip(
      message: tooltipMessage,
      child: Text(
        value,
        style: valueStyle?.copyWith(
          color: secondaryColor,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: secondaryColor,
        ),
      ),
    );
  } else {
    valueWidget = Text(value, style: valueStyle);
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodyMedium),
        valueWidget,
      ],
    ),
  );
}

/// Returns a newline-separated list of unmet prerequisites for
/// zone heat output, or null when all prerequisites are met.
///
/// Checks: circuit connection, distributor, supply/return temperature
/// spread, tube type availability, flooring material availability.
String? _zoneMissingPrereqs(
  HeatingZone zone,
  EditorState state,
  List<TubeType>? loadedTubeTypes,
  List<FlooringMaterial>? loadedMaterials,
) {
  final missing = <String>[];

  if (zone.circuitId == null) {
    missing.add('No circuit connected');
  }

  if (state.distributor == null) {
    missing.add('No distributor placed');
  } else {
    final d = state.distributor!;
    if ((d.supplyTempC - d.returnTempC).abs() < 0.5) {
      missing.add('Supply/return temperature not set');
    }
  }

  if (loadedTubeTypes != null &&
      loadedTubeTypes.isNotEmpty &&
      !loadedTubeTypes.any((t) => t.id == zone.tubeTypeId)) {
    missing.add('No tube type selected');
  }

  if (loadedMaterials != null &&
      loadedMaterials.isNotEmpty &&
      zone.flooringMaterialId != kCustomFlooringMaterialId &&
      !loadedMaterials.any((m) => m.id == zone.flooringMaterialId)) {
    missing.add('No flooring material selected');
  }

  return missing.isEmpty ? null : missing.join('\n');
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Compact numeric mm input field with range clamping.
class _NumericMmField extends StatelessWidget {
  const _NumericMmField({
    required this.controller,
    required this.min,
    required this.max,
    required this.suffix,
    required this.helperText,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final int min;
  final int max;
  final String suffix;
  final String helperText;
  final void Function(int mm) onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        suffixText: suffix,
        helperText: helperText,
        isDense: true,
      ),
      onSubmitted: (raw) {
        final parsed = int.tryParse(raw.trim());
        if (parsed == null) {
          // Reset to last valid value on bad input.
          controller.text = controller.text;
          return;
        }
        final clamped = parsed.clamp(min, max);
        controller.text = clamped.toString();
        onSubmitted(clamped);
      },
    );
  }
}

/// Dropdown for selecting a [TubeType] by ID.
class _TubeTypeDropdown extends StatelessWidget {
  const _TubeTypeDropdown({
    required this.tubes,
    required this.selectedId,
    required this.onChanged,
  });

  final List<LocalizedCatalogRow<TubeType>> tubes;
  final String selectedId;
  final void Function(String id) onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (tubes.isEmpty) {
      return Text(
        'No tube types available',
        style: textTheme.bodySmall,
      );
    }

    // Ensure selectedId is a valid option; fall back to first.
    final effectiveId = tubes.any((t) => t.row.id == selectedId)
        ? selectedId
        : tubes.first.row.id;

    return InputDecorator(
      decoration: const InputDecoration(isDense: true),
      child: DropdownButton<String>(
        value: effectiveId,
        isDense: true,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: tubes
            .map(
              (t) => DropdownMenuItem(
                value: t.row.id,
                child: Text(
                  '${t.displayName} \u2300${t.row.outerDiameterMm.toStringAsFixed(0)}\u202Fmm',
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (id) {
          if (id != null) onChanged(id);
        },
      ),
    );
  }
}

/// Numeric input for a custom surface covering R value (m²·K/W).
///
/// Range: [minCustomFlooringResistance]–[maxCustomFlooringResistance].
class _CustomRValueField extends StatelessWidget {
  const _CustomRValueField({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final void Function(double r) onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.rValueLabel,
        suffixText: 'm\u00B2K/W',
        helperText:
            '${minCustomFlooringResistance.toStringAsFixed(3)}'
            '\u2013'
            '${maxCustomFlooringResistance.toStringAsFixed(3)}'
            '\u202Fm\u00B2K/W',
        isDense: true,
      ),
      onSubmitted: (raw) {
        final parsed = double.tryParse(
          raw.trim().replaceAll(',', '.'),
        );
        if (parsed == null) return;
        final clamped = parsed.clamp(
          minCustomFlooringResistance,
          maxCustomFlooringResistance,
        );
        controller.text = clamped.toStringAsFixed(3);
        onSubmitted(clamped);
      },
    );
  }
}

// ── Command ───────────────────────────────────────────────────────────────────

/// Undoable command: update a zone property.
class _UpdateZoneCommand extends Command {
  _UpdateZoneCommand({
    required this.oldZone,
    required this.newZone,
    required this.update,
  });

  final HeatingZone oldZone;
  final HeatingZone newZone;
  final void Function(HeatingZone zone) update;

  @override
  String get label => 'Update zone';

  @override
  void execute() => update(newZone);

  @override
  void undo() => update(oldZone);
}
