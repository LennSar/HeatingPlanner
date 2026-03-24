import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/providers/flow_rate_providers.dart';
import '../../calculation/providers/hydraulic_balance_providers.dart';
import '../../calculation/providers/pressure_loss_providers.dart';
import '../../calculation/providers/tube_length_providers.dart';
import '../../core/theme/app_theme.dart';
import '../providers/editor_state_provider.dart';

// ---------------------------------------------------------------------------
// Status enum
// ---------------------------------------------------------------------------

/// Classification of a circuit's pressure loss against the pump head.
///
/// Pump head = [Distributor.pumpCapacityPa] when set by the user;
/// otherwise the maximum calculated circuit pressure loss is used.
enum _Status {
  /// Pressure loss ≤ 90 % of pump head.
  ok,

  /// Pressure loss 90–100 % of pump head.
  nearLimit,

  /// Pressure loss exceeds pump head.
  exceeded,

  /// Not enough data to determine status.
  unknown,
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Scrollable table listing every heating circuit with key hydraulic values.
///
/// One row per circuit showing:
/// - Circuit number
/// - Zone / room name
/// - Tube length (m)
/// - Flow rate (kg/h)
/// - Pressure loss (kPa)
/// - Required valve setting (kPa)
/// - Status icon
///
/// All values are read from existing providers; no new calculations are
/// performed inside this widget.
class CircuitOverviewPanel extends ConsumerWidget {
  /// Creates a [CircuitOverviewPanel].
  const CircuitOverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorStateProvider);
    final circuits = state.circuits;
    final distributor = state.distributor;
    final zones = state.zones;
    final rooms = state.rooms;

    if (circuits.isEmpty) {
      return const _EmptyState();
    }

    // Resolve valve settings for all circuits at once.
    final balanceAsync = distributor != null
        ? ref.watch(hydraulicBalanceProvider(distributor.id))
        : const AsyncData<Map<String, double>>({});
    final valveMap =
        balanceAsync.asData?.value ?? const <String, double>{};

    // Resolve all pressure losses so we can compute the pump head
    // (= max circuit loss) when pumpCapacityPa is not set.
    final lossAsyncs = [
      for (final c in circuits)
        ref.watch(pressureLossProvider(c.id)),
    ];
    final resolvedLosses = lossAsyncs
        .map((a) => a.asData?.value)
        .whereType<double>()
        .where((v) => !v.isNaN)
        .toList();
    final maxLossPa = resolvedLosses.isEmpty
        ? null
        : resolvedLosses.reduce(max);
    final pumpHeadPa =
        distributor?.pumpCapacityPa ?? maxLossPa;

    final rows = <DataRow>[];
    for (var i = 0; i < circuits.length; i++) {
      final circuit = circuits[i];

      // Resolve zone → room name.
      final zone = zones
          .where((z) => z.id == circuit.heatingZoneId)
          .firstOrNull;
      final room = zone != null
          ? rooms
              .where((r) => r.id == zone.roomId)
              .firstOrNull
          : null;
      final zoneName = room?.name ?? '—';

      final tubeLengthM =
          ref.watch(tubeLengthProvider(circuit.id));
      final flowRateKgH =
          ref.watch(flowRateProvider(circuit.id));
      final pressureAsync =
          lossAsyncs[i]; // already watched above
      final pressurePa = pressureAsync.asData?.value;
      final valvePa = valveMap[circuit.id];

      final status = _resolveStatus(
        pressureLossPa: pressurePa,
        pumpHeadPa: pumpHeadPa,
      );

      rows.add(DataRow(
        cells: [
          DataCell(Text('${i + 1}')),
          DataCell(
            ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 120),
              child: Text(
                zoneName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          DataCell(Text(
            tubeLengthM.isNaN
                ? '—'
                : tubeLengthM.toStringAsFixed(1),
          )),
          DataCell(Text(
            flowRateKgH.isNaN
                ? '—'
                : flowRateKgH.toStringAsFixed(2),
          )),
          DataCell(_AsyncDoubleCell(
            asyncValue: pressureAsync,
            formatter: (pa) => pa.isNaN
                ? '—'
                : (pa / 1000).toStringAsFixed(2),
          )),
          DataCell(Text(
            valvePa == null
                ? '—'
                : (valvePa / 1000).toStringAsFixed(2),
          )),
          DataCell(_StatusBadge(status: status)),
        ],
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(count: circuits.length),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: Spacing.md,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 36,
                  headingTextStyle:
                      Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                  dataTextStyle:
                      Theme.of(context).textTheme.bodySmall,
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(
                      label: Text('Zone / Room'),
                    ),
                    DataColumn(
                      label: Text('Length (m)'),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text('Flow (kg/h)'),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text('Δp (kPa)'),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text('Valve (kPa)'),
                      numeric: true,
                    ),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: rows,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static _Status _resolveStatus({
    required double? pressureLossPa,
    required double? pumpHeadPa,
  }) {
    if (pressureLossPa == null ||
        pressureLossPa.isNaN ||
        pumpHeadPa == null ||
        pumpHeadPa == 0) {
      return _Status.unknown;
    }
    if (pressureLossPa > pumpHeadPa) return _Status.exceeded;
    if (pressureLossPa > pumpHeadPa * 0.9) {
      return _Status.nearLimit;
    }
    return _Status.ok;
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<HeatingPlannerColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.gridLine),
        ),
      ),
      child: Text(
        'Circuits ($count)',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Async double cell
// ---------------------------------------------------------------------------

/// Displays the resolved value of an [AsyncValue<double>] in a [DataCell].
///
/// Shows a compact loading indicator while resolving, and calls
/// [formatter] with the resolved value.
class _AsyncDoubleCell extends StatelessWidget {
  const _AsyncDoubleCell({
    required this.asyncValue,
    required this.formatter,
  });

  final AsyncValue<double> asyncValue;
  final String Function(double) formatter;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: (v) => Text(formatter(v)),
      loading: () => const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
        ),
      ),
      error: (_, __) => const Text('—'),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

/// Coloured icon representing the hydraulic status of a circuit.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _Status status;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<HeatingPlannerColors>()!;
    switch (status) {
      case _Status.ok:
        return Icon(
          Icons.check_circle,
          size: 16,
          color: colors.zoneGreen,
        );
      case _Status.nearLimit:
        return Icon(
          Icons.warning_rounded,
          size: 16,
          color: colors.warningAmber,
        );
      case _Status.exceeded:
        return Icon(
          Icons.cancel,
          size: 16,
          color: colors.zoneRed,
        );
      case _Status.unknown:
        return Icon(
          Icons.remove,
          size: 16,
          color: colors.gridLine,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.device_hub_outlined,
              size: 32,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'No circuits',
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Add a distributor and draw heating zones '
              'to see circuit data here.',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
