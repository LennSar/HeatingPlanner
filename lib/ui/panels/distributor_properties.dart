import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/validation_limits.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/distributor.dart';
import '../providers/editor_state_provider.dart';

/// Properties panel content for a selected [Distributor].
///
/// Shows editable fields for:
/// - Supply temperature (°C) — range [minSupplyTempC, maxSupplyTempC]
/// - Return temperature (°C) — range [minReturnTempC, max < supplyTempC]
/// - Pump head (Pa) — range [minPumpHeadPa, maxPumpHeadPa]
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
  late TextEditingController _pumpCtrl;

  Distributor? _last;

  @override
  void initState() {
    super.initState();
    _supplyCtrl = TextEditingController();
    _returnCtrl = TextEditingController();
    _pumpCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _supplyCtrl.dispose();
    _returnCtrl.dispose();
    _pumpCtrl.dispose();
    super.dispose();
  }

  /// Sync text controllers when the distributor object changes
  /// externally (e.g. undo/redo).
  void _syncControllers(Distributor d) {
    if (d == _last) return;
    _last = d;
    final supply = d.supplyTempC.toStringAsFixed(1);
    final ret = d.returnTempC.toStringAsFixed(1);
    final pump = d.pumpHeadPa.round().toString();

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
    if (_pumpCtrl.text != pump) {
      _pumpCtrl.value = _pumpCtrl.value.copyWith(
        text: pump,
        selection: TextSelection.collapsed(
          offset: pump.length,
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

    if (distributor == null ||
        distributor.id != widget.distributorId) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          'Distributor not found.',
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
          Text('Properties', style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text(
            'Distributor',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Position: (${distributor.position.x.round()} mm, '
            '${distributor.position.y.round()} mm)',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.lg),

          // ── Supply temperature ─────────────────────────────
          _SectionLabel(
            label: 'Supply Temperature',
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
            label: 'Return Temperature',
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

          // ── Pump head ──────────────────────────────────────
          _SectionLabel(
            label: 'Pump Head',
            unit: 'Pa',
            textTheme: textTheme,
          ),
          const SizedBox(height: Spacing.xs),
          Slider(
            value: distributor.pumpHeadPa.clamp(
              minPumpHeadPa,
              maxPumpHeadPa,
            ),
            min: minPumpHeadPa,
            max: maxPumpHeadPa,
            divisions: 99,
            label:
                '${(distributor.pumpHeadPa / 1000).toStringAsFixed(1)} kPa',
            onChanged: (v) => _update(
              distributor.copyWith(pumpHeadPa: v),
            ),
          ),
          _NumericField(
            controller: _pumpCtrl,
            min: minPumpHeadPa,
            max: maxPumpHeadPa,
            onCommit: (v) {
              final clamped =
                  v.clamp(minPumpHeadPa, maxPumpHeadPa);
              _update(
                distributor.copyWith(pumpHeadPa: clamped),
              );
            },
          ),
          const SizedBox(height: Spacing.md),

          // ── Read-only info ─────────────────────────────────
          _infoRow(
            'Width',
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
        Text(label, style: textTheme.bodyMedium),
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
        Text(label, style: textTheme.bodyMedium),
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
