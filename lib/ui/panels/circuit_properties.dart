import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/providers/flow_rate_providers.dart';
import '../../calculation/providers/heat_output_providers.dart';
import '../../calculation/providers/pipe_layout_providers.dart';
import '../../calculation/providers/pressure_loss_providers.dart';
import '../../calculation/providers/tube_length_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/heating_circuit.dart';
import '../../l10n/app_localizations.dart';
import '../canvas/tools/circuit_commands.dart';
import '../canvas/tools/undo_redo_service.dart';
import '../providers/editor_state_provider.dart';
import '../providers/selection_provider.dart';

/// Properties panel for a selected [HeatingCircuit].
///
/// Shows:
/// - Insulation type radio group (editable, required per ADR-008)
/// - Supply and return route lengths (read-only)
/// - Zone tube length, total tube length (read-only)
/// - Placeholder hydraulic results until engine is implemented
class CircuitProperties extends ConsumerWidget {
  /// Creates [CircuitProperties] for the given [circuitId].
  const CircuitProperties({
    required this.circuitId,
    super.key,
  });

  /// ID of the circuit to display.
  final String circuitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final editorState = ref.watch(editorStateProvider);

    final circuit = editorState.circuits
        .where((c) => c.id == circuitId)
        .firstOrNull;

    if (circuit == null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(l10n.circuitNotFound, style: textTheme.bodyMedium),
      );
    }

    final zone = editorState.zones
        .where((z) => z.id == circuit.heatingZoneId)
        .firstOrNull;

    // ADR-042 Rule 4: all lengths are measured along the drawing.
    final pipes = connectionPipeLengthsM(
      circuit,
      zone: zone,
      bendRadiusMm: ref.watch(zoneBendRadiiMmProvider)[zone?.id] ??
          ref.watch(defaultBendRadiusMmProvider),
    );
    final supplyM = pipes.supplyM;
    final returnM = pipes.returnM;
    final zoneM = zone != null
        ? ref.watch(zoneTubeLengthProvider(zone.id))
        : double.nan;
    final totalM = ref.watch(tubeLengthProvider(circuitId));

    final flowRateKgH = ref.watch(flowRateProvider(circuitId));
    final flowVelocityMs =
        ref.watch(flowVelocityProvider(circuitId));
    final pressureLossPa =
        ref.watch(pressureLossProvider(circuitId)).asData?.value ??
            double.nan;
    final zoneId = zone?.id;
    final specificOutputWPerM2 = zoneId != null
        ? ref.watch(zoneHeatOutputProvider(zoneId))
        : double.nan;
    final heatOutputAreaM2 =
        (zone != null && zone.polygon.length >= 3)
            ? ref.watch(zoneEffectiveAreaM2Provider(zone.id))
            : double.nan;
    final heatOutputW =
        !specificOutputWPerM2.isNaN && !heatOutputAreaM2.isNaN
            ? specificOutputWPerM2 * heatOutputAreaM2
            : double.nan;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.properties, style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text(l10n.heatingCircuit, style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),

          // ── Insulation type ─────────────────────────────────────
          Text(
            l10n.supplyPipeInsulation,
            style: textTheme.labelLarge,
          ),
          const SizedBox(height: Spacing.xs),
          _InsulationRadioGroup(
            circuit: circuit,
            onChanged: (value) => _commit(
              ref,
              circuit,
              circuit.copyWith(supplyPipeInsulationType: value),
              l10n.undo_editConnectionPipe,
            ),
          ),

          const Divider(height: Spacing.xl),

          // ── Connection pipe distances (ADR-040) ──────────────────
          Text(l10n.connectionPipes, style: textTheme.labelLarge),
          const SizedBox(height: Spacing.sm),
          _DistanceField(
            key: const ValueKey('circuit-pipe-spacing'),
            label: l10n.circuit_pipeSpacing,
            valueMm: circuit.pipeSpacingMm,
            minMm: minPipeSpacingMm,
            maxMm: maxPipeSpacingMm,
            onCommitted: (v) =>
                _applyDistances(ref, circuit, pipeSpacingMm: v),
          ),
          const SizedBox(height: Spacing.sm),
          _DistanceField(
            key: const ValueKey('circuit-zone-clearance'),
            label: l10n.circuit_zoneClearance,
            valueMm: circuit.zoneClearanceMm,
            minMm: 0,
            maxMm: maxPipeClearanceMm,
            onCommitted: (v) =>
                _applyDistances(ref, circuit, zoneClearanceMm: v),
          ),
          const SizedBox(height: Spacing.sm),
          _DistanceField(
            key: const ValueKey('circuit-wall-clearance'),
            label: l10n.circuit_wallClearance,
            valueMm: circuit.wallClearanceMm,
            minMm: 0,
            maxMm: maxPipeClearanceMm,
            onCommitted: (v) =>
                _applyDistances(ref, circuit, wallClearanceMm: v),
          ),
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('circuit-swap-supply-return'),
              icon: const Icon(Icons.swap_horiz),
              label: Text(l10n.circuit_swapSupplyReturn),
              onPressed: () => _commit(
                ref,
                circuit,
                withSupplyAndReturnSwapped(
                  circuit,
                  ref.read(editorStateProvider).walls,
                ),
                l10n.undo_editConnectionPipe,
              ),
            ),
          ),

          const Divider(height: Spacing.xl),

          // ── Route lengths ────────────────────────────────────────
          Text(l10n.pipeLengths, style: textTheme.labelLarge),
          const SizedBox(height: Spacing.xs),
          _infoRow(
            l10n.supplyRoute,
            '${supplyM.toStringAsFixed(1)} m',
            textTheme,
          ),
          _infoRow(
            l10n.returnRoute,
            '${returnM.toStringAsFixed(1)} m',
            textTheme,
          ),
          _infoRow(
            l10n.zoneTube,
            !zoneM.isNaN && zoneM > 0
                ? '${zoneM.toStringAsFixed(1)} m'
                : '\u2014',
            textTheme,
          ),
          _infoRow(
            l10n.totalTube,
            !totalM.isNaN
                ? '${totalM.toStringAsFixed(1)} m'
                : '\u2014',
            textTheme,
          ),

          const Divider(height: Spacing.xl),

          // ── Hydraulic results (placeholders) ─────────────────────
          Text(l10n.hydraulics, style: textTheme.labelLarge),
          const SizedBox(height: Spacing.xs),
          _infoRow(
            l10n.flowRate,
            !flowRateKgH.isNaN && flowRateKgH > 0
                ? '${flowRateKgH.toStringAsFixed(1)} kg/h'
                : '\u2014',
            textTheme,
          ),
          _infoRow(
            l10n.flowVelocity,
            !flowVelocityMs.isNaN && flowVelocityMs > 0
                ? '${flowVelocityMs.toStringAsFixed(2)} m/s'
                : '\u2014',
            textTheme,
          ),
          _infoRow(
            l10n.pressureLossLabel,
            !pressureLossPa.isNaN && pressureLossPa > 0
                ? '${pressureLossPa.round()} Pa'
                : '\u2014',
            textTheme,
          ),
          _infoRow(
            l10n.heatOutput,
            !heatOutputW.isNaN && heatOutputW > 0
                ? '${heatOutputW.round()} W'
                : '\u2014',
            textTheme,
          ),

          const Divider(height: Spacing.xl),

          // ── Delete ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onPressed: () {
                final notifier = ref.read(editorStateProvider.notifier);
                ref.read(undoRedoProvider).execute(
                      DeleteCircuitCommand(
                        circuit: circuit,
                        connectedZone: ref
                            .read(editorStateProvider)
                            .zones
                            .where((z) => z.circuitId == circuitId)
                            .firstOrNull,
                        remove: notifier.removeCircuit,
                        add: notifier.addCircuit,
                        updateZone: notifier.updateZone,
                        label: l10n.undo_deleteCircuit,
                      ),
                    );
                ref
                    .read(selectedElementProvider.notifier)
                    .select(null);
              },
              child: Text(l10n.deleteCircuit),
            ),
          ),
        ],
      ),
    );
  }

  /// Stores new connection-pipe distances and applies them right away:
  /// the pipes are laid out again from the circuit's route (ADR-040
  /// Rule 4).
  void _applyDistances(
    WidgetRef ref,
    HeatingCircuit circuit, {
    int? pipeSpacingMm,
    int? zoneClearanceMm,
    int? wallClearanceMm,
  }) {
    final walls = ref.read(editorStateProvider).walls;
    _commit(
      ref,
      circuit,
      withConnectionPipeDistances(
        circuit,
        walls,
        pipeSpacingMm: pipeSpacingMm,
        zoneClearanceMm: zoneClearanceMm,
        wallClearanceMm: wallClearanceMm,
      ),
      AppLocalizations.of(ref.context)!.undo_editConnectionPipe,
    );
  }

  /// Applies a circuit change as one undo entry (ADR-042 Rule 1).
  void _commit(
    WidgetRef ref,
    HeatingCircuit before,
    HeatingCircuit after,
    String label,
  ) {
    if (before == after) return;
    ref.read(undoRedoProvider).execute(
          UpdateCircuitCommand(
            oldCircuit: before,
            newCircuit: after,
            update: ref.read(editorStateProvider.notifier).updateCircuit,
            label: label,
          ),
        );
  }

}

/// Radio group for selecting [SupplyPipeInsulationType].
class _InsulationRadioGroup extends StatelessWidget {
  const _InsulationRadioGroup({
    required this.circuit,
    required this.onChanged,
  });

  final HeatingCircuit circuit;
  final ValueChanged<SupplyPipeInsulationType> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (
        value: SupplyPipeInsulationType.none,
        label: l10n.insulationNone,
        subtitle: l10n.circuit_fullHeatOutputToTransitRoom,
      ),
      (
        value: SupplyPipeInsulationType.corrugatedConduit,
        label: l10n.insulationConduit,
        subtitle: '~25–30\u202f% residual heat output',
      ),
      (
        value: SupplyPipeInsulationType.insulationLayer,
        label: l10n.insulationLayer,
        subtitle: l10n.circuit_noHeatOutputToTransitRoom,
      ),
    ];

    return RadioGroup<SupplyPipeInsulationType>(
      groupValue: circuit.supplyPipeInsulationType,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      child: Column(
        children: options.map((opt) {
          final selected =
              circuit.supplyPipeInsulationType == opt.value;
          return InkWell(
            onTap: () => onChanged(opt.value),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Spacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<SupplyPipeInsulationType>(
                    value: opt.value,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          opt.label,
                          style:
                              textTheme.bodyMedium?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        Text(
                          opt.subtitle,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Label–value row used throughout this panel.
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
        Flexible(
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Whole-millimetre distance input for a connection pipe (ADR-040).
///
/// Commits on Enter and when the field loses focus. A value outside
/// [minMm]–[maxMm] is not committed; the range is shown instead.
class _DistanceField extends StatefulWidget {
  const _DistanceField({
    required this.label,
    required this.valueMm,
    required this.minMm,
    required this.maxMm,
    required this.onCommitted,
    super.key,
  });

  final String label;
  final int valueMm;
  final int minMm;
  final int maxMm;
  final ValueChanged<int> onCommitted;

  @override
  State<_DistanceField> createState() => _DistanceFieldState();
}

class _DistanceFieldState extends State<_DistanceField> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.valueMm}');
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);
  bool _invalid = false;

  @override
  void didUpdateWidget(_DistanceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow outside changes (undo, another circuit) unless being typed.
    if (oldWidget.valueMm != widget.valueMm && !_focus.hasFocus) {
      _controller.text = '${widget.valueMm}';
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    final value = int.tryParse(_controller.text.trim());
    final ok =
        value != null && value >= widget.minMm && value <= widget.maxMm;
    setState(() => _invalid = !ok);
    if (ok && value != widget.valueMm) widget.onCommitted(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: 'mm',
        isDense: true,
        errorText: _invalid
            ? l10n.circuit_distanceRange(widget.minMm, widget.maxMm)
            : null,
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}
