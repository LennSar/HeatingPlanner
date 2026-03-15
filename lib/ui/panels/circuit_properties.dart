import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/providers/tube_length_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/heating_circuit.dart';
import '../../data/models/point2d.dart';
import '../providers/editor_state_provider.dart';

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
    final editorState = ref.watch(editorStateProvider);

    final circuit = editorState.circuits
        .where((c) => c.id == circuitId)
        .firstOrNull;

    if (circuit == null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text('Circuit not found', style: textTheme.bodyMedium),
      );
    }

    final zone = editorState.zones
        .where((z) => z.id == circuit.heatingZoneId)
        .firstOrNull;

    final supplyM = _routeLengthM(circuit.supplyRoutePath);
    final returnM = _routeLengthM(circuit.returnRoutePath);
    final zoneM = zone != null
        ? ref.watch(zoneTubeLengthProvider(zone.id))
        : double.nan;
    final totalM =
        zoneM.isNaN ? double.nan : supplyM + returnM + zoneM;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Properties', style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text('Heating Circuit', style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),

          // ── Insulation type ─────────────────────────────────────
          Text(
            'Supply pipe insulation',
            style: textTheme.labelLarge,
          ),
          const SizedBox(height: Spacing.xs),
          _InsulationRadioGroup(
            circuit: circuit,
            onChanged: (value) {
              ref
                  .read(editorStateProvider.notifier)
                  .updateCircuit(
                    circuit.copyWith(
                      supplyPipeInsulationType: value,
                    ),
                  );
            },
          ),

          const Divider(height: Spacing.xl),

          // ── Route lengths ────────────────────────────────────────
          Text('Pipe lengths', style: textTheme.labelLarge),
          const SizedBox(height: Spacing.xs),
          _infoRow(
            'Supply route',
            '${supplyM.toStringAsFixed(1)} m',
            textTheme,
          ),
          _infoRow(
            'Return route',
            '${returnM.toStringAsFixed(1)} m',
            textTheme,
          ),
          _infoRow(
            'Zone tube',
            !zoneM.isNaN && zoneM > 0
                ? '${zoneM.toStringAsFixed(1)} m'
                : '\u2014',
            textTheme,
          ),
          _infoRow(
            'Total tube',
            !totalM.isNaN
                ? '${totalM.toStringAsFixed(1)} m'
                : '\u2014',
            textTheme,
          ),

          const Divider(height: Spacing.xl),

          // ── Hydraulic results (placeholders) ─────────────────────
          Text('Hydraulics', style: textTheme.labelLarge),
          const SizedBox(height: Spacing.xs),
          _infoRow(
            'Flow rate',
            circuit.flowRateKgH > 0
                ? '${circuit.flowRateKgH.toStringAsFixed(1)} kg/h'
                : '\u2014',
            textTheme,
          ),
          _infoRow('Flow velocity', '\u2014', textTheme),
          _infoRow(
            'Pressure loss',
            circuit.pressureLossPa > 0
                ? '${circuit.pressureLossPa.round()} Pa'
                : '\u2014',
            textTheme,
          ),
          _infoRow('Heat output', '\u2014', textTheme),
        ],
      ),
    );
  }

  /// Total length of [path] in metres.
  static double _routeLengthM(List<Point2D> path) {
    var total = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      total += GeometryEngine.distanceMm(path[i], path[i + 1]);
    }
    return total / 1000.0;
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
    final options = [
      (
        value: SupplyPipeInsulationType.none,
        label: 'None (in screed)',
        subtitle: 'Full heat output to transit room',
      ),
      (
        value: SupplyPipeInsulationType.corrugatedConduit,
        label: 'Corrugated conduit',
        subtitle: '~25–30\u202f% residual heat output',
      ),
      (
        value: SupplyPipeInsulationType.insulationLayer,
        label: 'Insulation layer',
        subtitle: 'No heat output to transit room',
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
