import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/providers/flow_rate_providers.dart';
import '../../calculation/providers/heat_demand_providers.dart';
import '../../calculation/providers/heat_output_providers.dart';
import '../../calculation/providers/hydraulic_balance_providers.dart';
import '../../calculation/providers/pressure_loss_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/heating_zone.dart';
import '../../data/models/validation_result.dart';
import '../../validation/validation_service.dart';
import '../providers/editor_state_provider.dart';
import '../providers/selection_provider.dart';
import '../widgets/severity_badge.dart';

// ---------------------------------------------------------------------------
// PerformanceDashboard
// ---------------------------------------------------------------------------

/// Width constants matching [PropertiesPanel].
abstract final class PerformanceDashboard {
  /// Fixed desktop panel width.
  static const double widthLarge = 280;

  /// Narrower desktop panel width.
  static const double widthMedium = 240;
}

/// Three-tab performance dashboard (Heat Balance | Hydraulic | Warnings).
///
/// Only the Warnings tab is implemented; the other two show a placeholder.
/// Use [initialIndex] to open on a specific tab (e.g. 2 for Warnings).
class PerformanceDashboardPanel extends ConsumerStatefulWidget {
  /// Creates a [PerformanceDashboardPanel].
  const PerformanceDashboardPanel({
    this.initialIndex = 0,
    super.key,
  });

  /// Tab to show on first render (0 = Heat Balance, 1 = Hydraulic,
  /// 2 = Warnings).
  final int initialIndex;

  @override
  ConsumerState<PerformanceDashboardPanel> createState() =>
      _PerformanceDashboardPanelState();
}

class _PerformanceDashboardPanelState
    extends ConsumerState<PerformanceDashboardPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void didUpdateWidget(PerformanceDashboardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _tabController.animateTo(widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<HeatingPlannerColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: colors.gridLine),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.gridLine),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              unselectedLabelStyle:
                  Theme.of(context).textTheme.bodySmall,
              tabs: const [
                Tab(text: 'Heat Balance'),
                Tab(text: 'Hydraulic'),
                Tab(text: 'Warnings'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _HeatBalanceTab(),
                _HydraulicTab(),
                _WarningsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Warnings tab
// ---------------------------------------------------------------------------

class _WarningsTab extends ConsumerStatefulWidget {
  const _WarningsTab();

  @override
  ConsumerState<_WarningsTab> createState() =>
      _WarningsTabState();
}

class _WarningsTabState extends ConsumerState<_WarningsTab> {
  /// null means "All".
  WarningSeverity? _filter;

  @override
  Widget build(BuildContext context) {
    final allResults =
        ref.watch(validationResultsProvider(''));

    final filtered = _filter == null
        ? allResults
        : allResults
            .where((r) => r.severity == _filter)
            .toList();

    return Column(
      children: [
        _WarningsHeader(
          count: filtered.length,
          filter: _filter,
          onFilterChanged: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => _Divider(),
                  itemBuilder: (context, index) =>
                      _WarningRow(result: filtered[index]),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header row
// ---------------------------------------------------------------------------

class _WarningsHeader extends StatelessWidget {
  const _WarningsHeader({
    required this.count,
    required this.filter,
    required this.onFilterChanged,
  });

  final int count;
  final WarningSeverity? filter;
  final ValueChanged<WarningSeverity?> onFilterChanged;

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
      child: Row(
        children: [
          Flexible(
            child: Text(
              'Warnings ($count)',
              style:
                  Theme.of(context).textTheme.headlineSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          _FilterDropdown(
            value: filter,
            onChanged: onFilterChanged,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter dropdown
// ---------------------------------------------------------------------------

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.onChanged,
  });

  final WarningSeverity? value;
  final ValueChanged<WarningSeverity?> onChanged;

  static const _items = [
    (null, 'All'),
    (WarningSeverity.error, 'Errors only'),
    (WarningSeverity.warning, 'Warnings only'),
    (WarningSeverity.info, 'Info only'),
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<WarningSeverity?>(
      value: value,
      isDense: true,
      underline: const SizedBox.shrink(),
      style: Theme.of(context).textTheme.bodySmall,
      hint: Text(
        'Filter',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      items: _items
          .map(
            (entry) => DropdownMenuItem<WarningSeverity?>(
              value: entry.$1,
              child: Text(entry.$2),
            ),
          )
          .toList(),
      onChanged: (v) => onChanged(v),
    );
  }
}

// ---------------------------------------------------------------------------
// Single warning row
// ---------------------------------------------------------------------------

class _WarningRow extends ConsumerStatefulWidget {
  const _WarningRow({required this.result});

  final ValidationResult result;

  @override
  ConsumerState<_WarningRow> createState() => _WarningRowState();
}

class _WarningRowState extends ConsumerState<_WarningRow> {
  bool _expanded = false;

  /// Timer used for the tablet long-press highlight (2 s auto-clear).
  Timer? _longPressTimer;

  bool get _expandable => widget.result.suggestedFix != null;

  void _highlight() {
    ref.read(hoveredElementProvider.notifier).set(
          SelectedElement(
            type: widget.result.elementType,
            id: widget.result.elementId,
          ),
        );
  }

  void _clearHighlight() {
    ref.read(hoveredElementProvider.notifier).clear();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final textTheme = Theme.of(context).textTheme;
    final onSurfaceSecondary =
        Theme.of(context).colorScheme.onSurfaceVariant;

    final rowContent = InkWell(
      onTap: _expandable
          ? () => setState(() => _expanded = !_expanded)
          : null,
      onLongPress: () {
        // Tablet fallback: highlight for 2 s, then auto-clear.
        _longPressTimer?.cancel();
        _highlight();
        _longPressTimer = Timer(
          const Duration(seconds: 2),
          _clearHighlight,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SeverityBadge.label(severity: result.severity),
                const SizedBox(width: Spacing.sm),
                Text(result.elementType,
                    style: textTheme.bodySmall),
                const Spacer(),
                if (_expandable)
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                    color: onSurfaceSecondary,
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(result.message, style: textTheme.bodyMedium),
            if (_expanded && result.suggestedFix != null) ...[
              const SizedBox(height: Spacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: Spacing.md),
                child: Text(
                  result.suggestedFix!,
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Desktop: wrap in MouseRegion for pointer enter/exit.
    return MouseRegion(
      onEnter: (_) => _highlight(),
      onExit: (_) => _clearHighlight(),
      child: rowContent,
    );
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 32,
            color:
                Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'No issues found',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Divider
// ---------------------------------------------------------------------------

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<HeatingPlannerColors>()!;
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.gridLine,
    );
  }
}

// ---------------------------------------------------------------------------
// Heat Balance tab (Tab 0)
// ---------------------------------------------------------------------------

/// Bar chart comparing heat demand vs output per room.
///
/// Demand bar: semi-transparent `onSurfaceVariant` colour.
/// Output bar: [HeatingPlannerColors.zoneGreen] when output ≥ demand,
/// [HeatingPlannerColors.zoneRed] when under-supplied.
///
/// X-axis: room names (truncated to 10 chars).
/// Y-axis: Watts.
///
/// Below the chart: summary row with total demand, total output, balance.
class _HeatBalanceTab extends ConsumerWidget {
  const _HeatBalanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorStateProvider);
    final rooms = state.rooms;
    final zones = state.zones;

    if (rooms.isEmpty) {
      return const _TabEmptyState(
        message: 'Draw rooms to see the heat balance.',
      );
    }

    final colors =
        Theme.of(context).extension<HeatingPlannerColors>()!;
    final textTheme = Theme.of(context).textTheme;

    var totalDemandW = 0.0;
    var totalOutputW = 0.0;
    final demandList = <double>[];
    final outputList = <double>[];
    final nameList = <String>[];

    for (final room in rooms) {
      final demand =
          ref.watch(roomHeatDemandProvider(room.id));
      final roomZones =
          zones.where((z) => z.roomId == room.id);

      var roomOutputW = 0.0;
      for (final zone in roomZones) {
        final spec =
            ref.watch(zoneHeatOutputProvider(zone.id));
        final area = _zoneAreaM2(zone);
        if (!spec.isNaN && !area.isNaN) {
          roomOutputW += spec * area;
        }
      }

      final demandVal = demand.isNaN ? 0.0 : demand;
      demandList.add(demandVal);
      outputList.add(roomOutputW);
      nameList.add(room.name);
      totalDemandW += demandVal;
      totalOutputW += roomOutputW;
    }

    final allPositive = [
      ...demandList.where((v) => v > 0),
      ...outputList.where((v) => v > 0),
    ];
    final maxY = allPositive.isEmpty
        ? 100.0
        : allPositive.reduce(max) * 1.2;

    final barGroups = <BarChartGroupData>[
      for (var i = 0; i < rooms.length; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: [
            // Demand bar — semi-transparent secondary colour.
            BarChartRodData(
              toY: demandList[i],
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.35),
              width: 12,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
            // Output bar — green / red based on adequacy.
            BarChartRodData(
              toY: outputList[i],
              color: outputList[i] >= demandList[i]
                  ? colors.zoneGreen
                  : colors.zoneRed,
              width: 12,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
          ],
        ),
    ];

    final balance = totalOutputW - totalDemandW;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sm,
              Spacing.md,
              Spacing.md,
              Spacing.sm,
            ),
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: barGroups,
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) =>
                          Text(
                        '${value.toInt()} W',
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 ||
                            i >= nameList.length) {
                          return const SizedBox.shrink();
                        }
                        final name = nameList[i];
                        return Padding(
                          padding: const EdgeInsets.only(
                            top: Spacing.xs,
                          ),
                          child: Text(
                            name.length > 10
                                ? name.substring(0, 10)
                                : name,
                            style: textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _HeatSummaryRow(
          totalDemandW: totalDemandW,
          totalOutputW: totalOutputW,
          balance: balance,
        ),
      ],
    );
  }

  /// Returns the heated area of [zone] in m².
  ///
  /// For floor-heating zones the polygon area is used.
  /// For wall-heating zones, [HeatingZone.widthMm] ×
  /// [HeatingZone.heightMm] / 1e6 is used; returns [double.nan] when
  /// either dimension is unset.
  static double _zoneAreaM2(HeatingZone zone) {
    if (zone.zoneType == ZoneType.wallHeating) {
      final w = zone.widthMm;
      final h = zone.heightMm;
      if (w == null || h == null) return double.nan;
      return w * h / 1e6;
    }
    return GeometryEngine.polygonAreaM2(zone.polygon);
  }
}

// ---------------------------------------------------------------------------
// Heat Balance summary row
// ---------------------------------------------------------------------------

class _HeatSummaryRow extends StatelessWidget {
  const _HeatSummaryRow({
    required this.totalDemandW,
    required this.totalOutputW,
    required this.balance,
  });

  final double totalDemandW;
  final double totalOutputW;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<HeatingPlannerColors>()!;
    final balanceColor =
        balance >= 0 ? colors.zoneGreen : colors.zoneRed;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.gridLine),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SummaryItem(
            label: 'Demand',
            value: '${totalDemandW.toStringAsFixed(0)} W',
          ),
          _SummaryItem(
            label: 'Output',
            value: '${totalOutputW.toStringAsFixed(0)} W',
          ),
          _SummaryItem(
            label: 'Balance',
            value: '${balance >= 0 ? "+" : ""}'
                '${balance.toStringAsFixed(0)} W',
            valueColor: balanceColor,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
        ),
        Text(
          value,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hydraulic tab (Tab 1)
// ---------------------------------------------------------------------------

/// Bar chart of pressure loss per circuit (stacked: pipe loss + throttling)
/// and a pie chart of flow rate distribution.
///
/// Each bar shows the full reference height (= max circuit loss).
/// The bottom portion is the circuit's actual pipe loss; the upper,
/// lighter portion is the valve throttling required to balance the system.
class _HydraulicTab extends ConsumerWidget {
  const _HydraulicTab();

  static const _pieColorCount = 6;

  /// Returns a colour for pie-chart slice [index] using theme tokens.
  static Color _pieColor(
    HeatingPlannerColors colors,
    int index,
  ) {
    const cycle = _pieColorCount;
    switch (index % cycle) {
      case 0:
        return colors.zoneGreen;
      case 1:
        return colors.infoBlue;
      case 2:
        return colors.warningAmber;
      case 3:
        return colors.zoneYellow;
      case 4:
        return colors.supplyPipe;
      case 5:
        return colors.returnPipe;
      default:
        return colors.zoneGrey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorStateProvider);
    final circuits = state.circuits;
    final distributor = state.distributor;

    if (circuits.isEmpty || distributor == null) {
      return const _TabEmptyState(
        message:
            'Add a distributor and connect heating zones '
            'to see hydraulic data.',
      );
    }

    final colors =
        Theme.of(context).extension<HeatingPlannerColors>()!;
    final textTheme = Theme.of(context).textTheme;

    // Pressure losses — FutureProvider; show spinner while loading.
    final lossAsyncs = [
      for (final c in circuits)
        ref.watch(pressureLossProvider(c.id)),
    ];
    if (lossAsyncs.any((a) => a.isLoading)) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    final lossesPa = lossAsyncs
        .map((a) => a.asData?.value ?? double.nan)
        .toList();

    final validLosses =
        lossesPa.where((v) => !v.isNaN).toList();
    final maxLossKPa = validLosses.isEmpty
        ? 10.0
        : validLosses.reduce(max) / 1000;

    // Hydraulic balance (valve settings Pa per circuit).
    final balanceAsync =
        ref.watch(hydraulicBalanceProvider(distributor.id));
    final valveMap =
        balanceAsync.asData?.value ?? const <String, double>{};

    // Flow rates.
    final flowRatesKgH = [
      for (final c in circuits)
        ref.watch(flowRateProvider(c.id)),
    ];
    final validFlows =
        flowRatesKgH.where((v) => !v.isNaN).toList();
    final totalFlowKgH = validFlows.isEmpty
        ? 0.0
        : validFlows.fold<double>(0, (a, b) => a + b);

    // Build stacked bar groups.
    // Bottom (zoneGreen): pipe loss. Top (gridLine): throttling.
    final barGroups = <BarChartGroupData>[
      for (var i = 0; i < circuits.length; i++)
        () {
          final lossKPa =
              lossesPa[i].isNaN ? 0.0 : lossesPa[i] / 1000;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: maxLossKPa,
                // Base colour = throttling section (top of bar).
                color: colors.gridLine,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
                rodStackItems: [
                  // Overpaints bottom portion with pipe-loss colour.
                  BarChartRodStackItem(
                    0,
                    lossKPa,
                    colors.zoneGreen,
                  ),
                ],
              ),
            ],
          );
        }(),
    ];

    // Build pie sections for flow distribution.
    final pieSections = <PieChartSectionData>[
      for (var i = 0; i < circuits.length; i++)
        () {
          final flow = flowRatesKgH[i].isNaN
              ? 0.0
              : flowRatesKgH[i];
          final pct = totalFlowKgH > 0
              ? flow / totalFlowKgH * 100
              : 0.0;
          return PieChartSectionData(
            value: flow,
            color: _pieColor(colors, i),
            title: 'C${i + 1}: ${pct.toStringAsFixed(0)}%',
            titleStyle: textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface,
            ),
            radius: 50,
          );
        }(),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pressure Loss by Circuit (kPa)',
            style: textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Spacing.sm),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxLossKPa * 1.1,
                barGroups: barGroups,
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, meta) => Text(
                        v.toStringAsFixed(1),
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 ||
                            i >= circuits.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          'C${i + 1}',
                          style: textTheme.bodySmall,
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex,
                        rod, rodIndex) {
                      final lossKPa = lossesPa[groupIndex]
                              .isNaN
                          ? 0.0
                          : lossesPa[groupIndex] / 1000;
                      final valvePa = valveMap[
                              circuits[groupIndex].id] ??
                          0;
                      final valveKPa = valvePa / 1000;
                      return BarTooltipItem(
                        'C${groupIndex + 1}\n'
                        'Loss: ${lossKPa.toStringAsFixed(2)} kPa\n'
                        'Valve: ${valveKPa.toStringAsFixed(2)} kPa',
                        textTheme.bodySmall ??
                            const TextStyle(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              _LegendDot(
                color: colors.zoneGreen,
                label: 'Pipe loss',
              ),
              const SizedBox(width: Spacing.md),
              _LegendDot(
                color: colors.gridLine,
                label: 'Valve throttling',
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Flow Rate Distribution',
            style: textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Spacing.sm),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sections: pieSections,
                sectionsSpace: 2,
                centerSpaceRadius: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legend dot
// ---------------------------------------------------------------------------

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: Spacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Generic empty state for tabs
// ---------------------------------------------------------------------------

class _TabEmptyState extends StatelessWidget {
  const _TabEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Text(
          message,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
