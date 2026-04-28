import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/validation_limits.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/distributor.dart';
import '../../l10n/app_localizations.dart';
import '../providers/editor_state_provider.dart';

/// Properties panel content for a selected [Distributor].
///
/// Shows editable fields for:
/// - Supply temperature (°C) — range [minSupplyTempC, maxSupplyTempC]
/// - Return temperature (°C) — range [minReturnTempC, max < supplyTempC]
/// - Pump capacity (Pa) — optional, user's pump rating (ADR-007)
///
/// Read-only fields:
/// - Min. required pump pressure (Pa) — computed; shows "—" until circuits
///   are connected.
///
/// Values take effect immediately (no Apply button) — see
/// UI/UX Section 2 "Immediate feedback".
class DistributorProperties
    extends ConsumerStatefulWidget {
  /// Creates [DistributorProperties] for [distributorId].
  const DistributorProperties({
    required this.distributorId,
    super.key,
  });

  /// ID of the distributor to display.
  final String distributorId;

  @override
  ConsumerState<DistributorProperties> createState() =>
      _DistributorPropertiesState();
}

class _DistributorPropertiesState
    extends ConsumerState<DistributorProperties> {
  late TextEditingController _supplyCtrl;
  late TextEditingController _returnCtrl;
  late TextEditingController _capacityCtrl;

  Distributor? _last;

  @override
  void initState() {
    super.initState();
    _supplyCtrl = TextEditingController();
    _returnCtrl = TextEditingController();
    _capacityCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _supplyCtrl.dispose();
    _returnCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  /// Sync text controllers when the distributor object changes
  /// externally (e.g. undo/redo).
  void _syncControllers(Distributor d) {
    if (d == _last) return;
    _last = d;
    final supply = d.supplyTempC.toStringAsFixed(1);
    final ret = d.returnTempC.toStringAsFixed(1);
    final capacity = d.pumpCapacityPa != null
        ? d.pumpCapacityPa!.round().toString()
        : '';

    if (_supplyCtrl.text != supply) {
      _supplyCtrl.value = _supplyCtrl.value.copyWith(
        text: supply,
        selection: TextSelection.collapsed(
          offset: supply.length,
        ),
      );
    }
    if (_returnCtrl.text != ret) {
      _returnCtrl.value = _returnCtrl.value.copyWith(
        text: ret,
        selection: TextSelection.collapsed(
          offset: ret.length,
        ),
      );
    }
    if (_capacityCtrl.text != capacity) {
      _capacityCtrl.value = _capacityCtrl.value.copyWith(
        text: capacity,
        selection: TextSelection.collapsed(
          offset: capacity.length,
        ),
      );
    }
  }

  void _update(Distributor updated) {
    ref
        .read(editorStateProvider.notifier)
        .updateDistributor(updated);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final editorState = ref.watch(editorStateProvider);
    final distributor = editorState.distributor;

    final l10n = AppLocalizations.of(context)!;

    if (distributor == null ||
        distributor.id != widget.distributorId) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          l10n.distributor,
          style: textTheme.bodyMedium,
        ),
      );
    }

    _syncControllers(distributor);

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.properties, style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text(
            l10n.distributor,
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.positionLabel(
              distributor.position.x.round(),
              distributor.position.y.round(),
            ),
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.lg),

          // ── Supply temperature ─────────────────────────────
          _SectionLabel(
            label: l10n.supplyTemperature,
            unit: '°C',
            textTheme: textTheme,
          ),
          const SizedBox(height: Spacing.xs),
          Slider(
            value: distributor.supplyTempC.clamp(
              minSupplyTempC,
              maxSupplyTempC,
            ),
            min: minSupplyTempC,
            max: maxSupplyTempC,
            divisions: ((maxSupplyTempC - minSupplyTempC) /
                    0.5)
                .round(),
            label:
                '${distributor.supplyTempC.toStringAsFixed(1)}°C',
            onChanged: (v) {
              final newReturn = distributor.returnTempC
                  .clamp(minReturnTempC, v - 1.0);
              _update(
                distributor.copyWith(
                  supplyTempC: v,
                  returnTempC: newReturn,
                ),
              );
            },
          ),
          _NumericField(
            controller: _supplyCtrl,
            min: minSupplyTempC,
            max: maxSupplyTempC,
            onCommit: (v) {
              final clamped =
                  v.clamp(minSupplyTempC, maxSupplyTempC);
              final newReturn = distributor.returnTempC
                  .clamp(minReturnTempC, clamped - 1.0);
              _update(
                distributor.copyWith(
                  supplyTempC: clamped,
                  returnTempC: newReturn,
                ),
              );
            },
          ),
          const SizedBox(height: Spacing.md),

          // ── Return temperature ─────────────────────────────
          _SectionLabel(
            label: l10n.returnTemperature,
            unit: '°C',
            textTheme: textTheme,
          ),
          const SizedBox(height: Spacing.xs),
          Slider(
            value: distributor.returnTempC.clamp(
              minReturnTempC,
              distributor.supplyTempC - 1.0,
            ),
            min: minReturnTempC,
            max: distributor.supplyTempC - 1.0,
            divisions: ((distributor.supplyTempC -
                        1.0 -
                        minReturnTempC) /
                    0.5)
                .round()
                .clamp(1, 9999),
            label:
                '${distributor.returnTempC.toStringAsFixed(1)}°C',
            onChanged: (v) => _update(
              distributor.copyWith(returnTempC: v),
            ),
          ),
          _NumericField(
            controller: _returnCtrl,
            min: minReturnTempC,
            max: distributor.supplyTempC - 1.0,
            onCommit: (v) {
              final clamped = v.clamp(
                minReturnTempC,
                distributor.supplyTempC - 1.0,
              );
              _update(
                distributor.copyWith(returnTempC: clamped),
              );
            },
          ),
          const SizedBox(height: Spacing.md),

          // ── Read-only info ─────────────────────────────────
          _infoRow(
            l10n.widthLabel,
            '${distributor.widthMm} mm',
            textTheme,
          ),
          const SizedBox(height: Spacing.xs),

          // ── Computed info ──────────────────────────────────
          _infoRow(
            '\u0394T',
            '${(distributor.supplyTempC - distributor.returnTempC).toStringAsFixed(1)}\u00B0C',
            textTheme,
          ),
          const SizedBox(height: Spacing.lg),

          // ── Pump section ───────────────────────────────────
          Text(
            l10n.pump,
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.sm),

          // Min. required pump pressure — read-only, computed
          _infoRow(
            l10n.minPumpPressure,
            '— Pa',
            textTheme,
          ),
          const SizedBox(height: Spacing.md),

          // Pump capacity — optional user input
          _SectionLabel(
            label: l10n.pumpCapacityOptional,
            unit: 'Pa',
            textTheme: textTheme,
          ),
          const SizedBox(height: Spacing.xs),
          _NumericField(
            controller: _capacityCtrl,
            min: minPumpHeadPa,
            max: maxPumpHeadPa,
            onCommit: (v) {
              final clamped =
                  v.clamp(minPumpHeadPa, maxPumpHeadPa);
              _update(
                distributor.copyWith(
                  pumpCapacityPa: clamped,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.unit,
    required this.textTheme,
  });

  final String label;
  final String unit;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: textTheme.bodyMedium)),
        Text(
          unit,
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A text field that accepts numeric input and fires [onCommit]
/// on submit or focus-loss.
class _NumericField extends StatelessWidget {
  const _NumericField({
    required this.controller,
    required this.min,
    required this.max,
    required this.onCommit,
  });

  final TextEditingController controller;
  final double min;
  final double max;
  final void Function(double) onCommit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'[\d.]'),
        ),
      ],
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        border: OutlineInputBorder(),
      ),
      onSubmitted: _tryCommit,
      onTapOutside: (_) => _tryCommit(controller.text),
    );
  }

  void _tryCommit(String text) {
    final v = double.tryParse(text);
    if (v != null) onCommit(v);
  }
}

Widget _infoRow(
  String label,
  String value,
  TextTheme textTheme,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: textTheme.bodyMedium)),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
