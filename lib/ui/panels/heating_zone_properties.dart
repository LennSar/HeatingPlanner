import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/providers/tube_length_providers.dart';
import '../../core/constants/validation_limits.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/flooring_material.dart';
import '../../data/models/heating_zone.dart';
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
  // Text controllers for numeric text inputs (spacing, border).
  late TextEditingController _spacingController;
  late TextEditingController _borderController;

  /// Snapshot taken when a slider drag starts for undo grouping.
  HeatingZone? _zoneAtSliderStart;

  /// Last zone ID synced into the text controllers.
  String? _lastSyncedZoneId;

  @override
  void initState() {
    super.initState();
    _spacingController = TextEditingController();
    _borderController = TextEditingController();
  }

  @override
  void dispose() {
    _spacingController.dispose();
    _borderController.dispose();
    super.dispose();
  }

  /// Syncs text controllers from the model when the zone
  /// or its spacing/border values change externally (undo/redo).
  void _syncControllers(HeatingZone zone) {
    if (_lastSyncedZoneId == zone.id &&
        _spacingController.text ==
            zone.tubeSpacingMm.toString() &&
        _borderController.text ==
            zone.borderDistanceMm.toString()) {
      return;
    }
    _lastSyncedZoneId = zone.id;
    _spacingController.text = zone.tubeSpacingMm.toString();
    _borderController.text = zone.borderDistanceMm.toString();
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
    final colorScheme = Theme.of(context).colorScheme;

    // Keep text controllers in sync with external changes (undo/redo).
    ref.listen<EditorState>(editorStateProvider, (prev, next) {
      if (!mounted) return;
      final zone = next.zones
          .where((z) => z.id == widget.zoneId)
          .firstOrNull;
      if (zone == null) return;
      final prevZone = prev?.zones
          .where((z) => z.id == widget.zoneId)
          .firstOrNull;
      if (prevZone == null ||
          prevZone.tubeSpacingMm != zone.tubeSpacingMm) {
        _spacingController.text = zone.tubeSpacingMm.toString();
      }
      if (prevZone == null ||
          prevZone.borderDistanceMm != zone.borderDistanceMm) {
        _borderController.text = zone.borderDistanceMm.toString();
      }
    });

    final editorState = ref.watch(editorStateProvider);
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

    _syncControllers(zone);

    final areaM2 = zone.polygon.length >= 3
        ? GeometryEngine.polygonAreaM2(zone.polygon)
        : double.nan;

    final tubeTypesAsync = ref.watch(tubeTypesProvider);
    final flooringAsync = ref.watch(flooringMaterialsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Properties', style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text('Heating Zone', style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),

          // ── Zone type toggle ─────────────────────────────────────
          Text('Zone Type', style: textTheme.bodyMedium),
          const SizedBox(height: Spacing.xs),
          SegmentedButton<ZoneType>(
            segments: const [
              ButtonSegment(
                value: ZoneType.floorHeating,
                label: Text('Floor'),
                icon: Icon(Icons.horizontal_rule, size: 16),
              ),
              ButtonSegment(
                value: ZoneType.wallHeating,
                label: Text('Wall'),
                icon: Icon(Icons.vertical_align_center, size: 16),
              ),
            ],
            selected: {zone.zoneType},
            onSelectionChanged: (set) {
              final newType = set.first;
              if (newType == zone.zoneType) return;
              _commit(zone, zone.copyWith(zoneType: newType));
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),

          const Divider(height: Spacing.lg),

          // ── Tube spacing ─────────────────────────────────────────
          Text(
            'Tube Spacing: ${zone.tubeSpacingMm}\u202Fmm',
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

          const SizedBox(height: Spacing.md),

          // ── Border distance ──────────────────────────────────────
          Text(
            'Border Distance: ${zone.borderDistanceMm}\u202Fmm',
            style: textTheme.bodyMedium,
          ),
          Slider(
            value: zone.borderDistanceMm.toDouble(),
            min: minBorderDistanceMm.toDouble(),
            max: maxBorderDistanceMm.toDouble(),
            divisions:
                (maxBorderDistanceMm - minBorderDistanceMm) ~/ 10,
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

          const Divider(height: Spacing.lg),

          // ── Layout pattern ───────────────────────────────────────
          Text('Layout Pattern', style: textTheme.bodyMedium),
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
          Text('Tube Type', style: textTheme.bodyMedium),
          const SizedBox(height: Spacing.xs),
          tubeTypesAsync.when(
            data: (tubes) => _TubeTypeDropdown(
              tubes: tubes,
              selectedId: zone.tubeTypeId,
              onChanged: (id) {
                if (id == zone.tubeTypeId) return;
                _commit(zone, zone.copyWith(tubeTypeId: id));
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(
              'Error loading tube types',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),

          const SizedBox(height: Spacing.md),

          // ── Flooring material dropdown ───────────────────────────
          Text('Flooring Material', style: textTheme.bodyMedium),
          const SizedBox(height: Spacing.xs),
          flooringAsync.when(
            data: (materials) => _FlooringMaterialDropdown(
              materials: materials,
              selectedId: zone.flooringMaterialId,
              onChanged: (id) {
                if (id == zone.flooringMaterialId) return;
                _commit(
                  zone,
                  zone.copyWith(flooringMaterialId: id),
                );
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(
              'Error loading flooring materials',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),

          const Divider(height: Spacing.lg),

          // ── Computed read-only fields ────────────────────────────
          Text('Zone Output', style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.xs),
          _readOnlyRow(
            'Zone Area',
            areaM2.isNaN
                ? '\u2014'
                : '${areaM2.toStringAsFixed(2)}\u202Fm\u00B2',
            textTheme,
          ),
          _readOnlyRow(
            'Tube Length',
            _tubeLengthText(
              ref.watch(zoneTubeLengthProvider(widget.zoneId)),
            ),
            textTheme,
          ),
          _readOnlyRow(
            'Specific Output',
            '\u2014', // TODO(hvac): wire zoneHeatOutputProvider
            textTheme,
          ),
          _readOnlyRow(
            'Total Output',
            '\u2014', // TODO(hvac): wire zoneHeatOutputProvider
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
  TextTheme textTheme,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodyMedium),
        Text(
          value,
          style: textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
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

  final List<TubeType> tubes;
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
    final effectiveId = tubes.any((t) => t.id == selectedId)
        ? selectedId
        : tubes.first.id;

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
                value: t.id,
                child: Text(
                  '${t.name} \u2300${t.outerDiameterMm.toStringAsFixed(0)}\u202Fmm',
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

/// Dropdown for selecting a [FlooringMaterial] by ID.
class _FlooringMaterialDropdown extends StatelessWidget {
  const _FlooringMaterialDropdown({
    required this.materials,
    required this.selectedId,
    required this.onChanged,
  });

  final List<FlooringMaterial> materials;
  final String selectedId;
  final void Function(String id) onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (materials.isEmpty) {
      return Text(
        'No flooring materials available',
        style: textTheme.bodySmall,
      );
    }

    final effectiveId =
        materials.any((m) => m.id == selectedId)
            ? selectedId
            : materials.first.id;

    return InputDecorator(
      decoration: const InputDecoration(isDense: true),
      child: DropdownButton<String>(
        value: effectiveId,
        isDense: true,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: materials
            .map(
              (m) => DropdownMenuItem(
                value: m.id,
                child: Text(
                  '${m.name} (R\u03BB\u202F'
                  '${m.thermalResistance.toStringAsFixed(3)}\u202F'
                  'm\u00B2K/W)',
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
