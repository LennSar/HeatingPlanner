import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/providers/flow_rate_providers.dart';
import '../../calculation/providers/heat_output_providers.dart';
import '../../calculation/providers/pressure_loss_providers.dart';
import '../../calculation/providers/tube_length_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/heating_circuit.dart';
import '../../data/models/point2d.dart';
import '../../l10n/app_localizations.dart';
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

    final supplyM = _routeLengthM(circuit.supplyRoutePath);
    final returnM = _routeLengthM(circuit.returnRoutePath);
    final zoneM = zone != null
        ? ref.watch(zoneTubeLengthProvider(zone.id))
        : double.nan;
    final totalM =
        zoneM.isNaN ? double.nan : supplyM + returnM + zoneM;

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
            ? GeometryEngine.polygonAreaM2(zone.polygon)
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
                ref
                    .read(editorStateProvider.notifier)
                    .removeCircuit(circuitId);
                for (final zone in ref
                    .read(editorStateProvider)
                    .zones) {
                  if (zone.circuitId == circuitId) {
                    ref
                        .read(editorStateProvider.notifier)
                        .updateZone(
                          zone.copyWith(circuitId: null),
                        );
                  }
                }
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
