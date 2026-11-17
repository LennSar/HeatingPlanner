import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/providers/room_summary_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../l10n/app_localizations.dart';

/// Opens the room summary (ADR-045) as a modal dialog.
Future<void> showRoomSummaryDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const RoomSummaryDialog(),
  );
}

/// Table of the open floor's rooms: heat demand, heat delivered at the
/// design flow rate and water temperatures, the difference between the
/// two, pressure loss and tube lengths (ADR-045).
///
/// One bold row per room, one row per heating zone / circuit below it,
/// and a totals row. The difference is marked green when the room is
/// covered and red when it is under-supplied.
///
/// Reads [floorSummaryProvider] only; no calculation happens here.
class RoomSummaryDialog extends ConsumerWidget {
  /// Creates a [RoomSummaryDialog].
  const RoomSummaryDialog({super.key});

  /// Largest dialog size; smaller windows shrink it.
  static const double _maxWidth = 1320;
  static const double _maxHeight = 820;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.extension<HeatingPlannerColors>()!;
    final summary = ref.watch(floorSummaryProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(Spacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _maxWidth,
          maxHeight: _maxHeight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.sm,
                Spacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.roomSummary_title,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: colors.gridLine),
            Flexible(
              child: summary.rooms.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Text(
                        l10n.roomSummary_empty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : _SummaryTable(summary: summary),
            ),
            Divider(height: 1, thickness: 1, color: colors.gridLine),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (summary.demandIncomplete) ...[
                    Text(
                      l10n.roomSummary_demandIncomplete,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.warningAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                  ],
                  Text(
                    l10n.roomSummary_notes,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

/// Placeholder for a value that cannot be calculated yet.
const String _none = '—';

String _number(double value, int digits) =>
    value.isFinite ? value.toStringAsFixed(digits) : _none;

String _signed(double value) {
  if (!value.isFinite) return _none;
  final rounded = value.round();
  return rounded > 0 ? '+$rounded' : '$rounded';
}

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.summary});

  final FloorSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.extension<HeatingPlannerColors>()!;
    final body = theme.textTheme.bodyMedium;
    final strong = body?.copyWith(fontWeight: FontWeight.w600);
    final muted = body?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final headers = <(String, String)>[
      (l10n.roomSummary_colRoom, ''),
      (l10n.roomSummary_colArea, 'm²'),
      (l10n.roomSummary_colDemand, 'W'),
      (l10n.roomSummary_colTemps, '°C'),
      (l10n.roomSummary_colFlow, 'kg/h'),
      (l10n.roomSummary_colSpecificOutput, 'W/m²'),
      (l10n.roomSummary_colOutput, 'W'),
      (l10n.roomSummary_colDifference, 'W'),
      (l10n.roomSummary_colSurfaceTemp, '°C'),
      (l10n.roomSummary_colTube, 'mm'),
      (l10n.roomSummary_colPressureLoss, 'kPa'),
      (l10n.roomSummary_colLengthInRoom, 'm'),
      (l10n.roomSummary_colLengthTotal, 'm'),
    ];

    final rows = <TableRow>[
      TableRow(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.gridLine)),
        ),
        children: [
          for (var i = 0; i < headers.length; i++)
            _HeaderCell(
              label: headers[i].$1,
              unit: headers[i].$2,
              alignEnd: i > 0,
            ),
        ],
      ),
    ];

    for (final room in summary.rooms) {
      final roomLabel = room.isHeated
          ? '${room.name} · ${_number(room.targetTempC, 0)} °C'
          : '${room.name} · ${l10n.roomSummary_unheated}';
      final areaM2 = room.zones
          .map((z) => z.areaM2)
          .where((v) => v.isFinite)
          .fold(0.0, (a, b) => a + b);
      // An unheated room without zones has nothing to balance.
      final showBalance = room.isHeated || room.zones.isNotEmpty;

      rows.add(
        TableRow(
          decoration: BoxDecoration(
            color: colors.gridLine.withValues(alpha: 0.35),
          ),
          children: [
            _Cell(roomLabel, style: strong, alignEnd: false),
            _Cell(
              room.zones.isEmpty ? _none : _number(areaM2, 1),
              style: strong,
            ),
            _Cell(
              room.isHeated ? _number(room.demandW, 0) : _none,
              style: strong,
            ),
            _Cell('', style: strong),
            _Cell(_number(room.flowRateKgH, 1), style: strong),
            _Cell('', style: strong),
            _Cell(_number(room.outputW, 0), style: strong),
            _BalanceCell(
              balanceW: showBalance ? room.balanceW : double.nan,
              style: strong,
            ),
            _Cell('', style: strong),
            _Cell('', style: strong),
            _Cell(_number(room.maxPressureLossPa / 1000, 2), style: strong),
            _Cell(_number(room.zoneTubeLengthM, 1), style: strong),
            _Cell(_number(room.totalTubeLengthM, 1), style: strong),
          ],
        ),
      );

      for (final zone in room.zones) {
        final number = zone.circuitNumber;
        final String label;
        if (number == null) {
          label = l10n.roomSummary_zoneNotConnected;
        } else if (zone.zoneType == ZoneType.wallHeating) {
          label = l10n.roomSummary_wallCircuit(number);
        } else {
          label = l10n.roomSummary_circuit(number);
        }
        final temps = zone.supplyTempC.isFinite && zone.returnTempC.isFinite
            ? '${_number(zone.supplyTempC, 0)} / '
                  '${_number(zone.returnTempC, 0)}'
            : _none;
        final tube =
            zone.tubeOuterDiameterMm.isFinite &&
                zone.tubeWallThicknessMm.isFinite
            ? '${_number(zone.tubeOuterDiameterMm, 0)} × '
                  '${_number(zone.tubeWallThicknessMm, 1)}'
            : _none;

        rows.add(
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.gridLine.withValues(alpha: 0.5),
                ),
              ),
            ),
            children: [
              _Cell(label, style: muted, alignEnd: false, indent: true),
              _Cell(_number(zone.areaM2, 1), style: body),
              _Cell('', style: body),
              _Cell(temps, style: body),
              _Cell(_number(zone.flowRateKgH, 1), style: body),
              _Cell(_number(zone.specificOutputWPerM2, 0), style: body),
              _Cell(_number(zone.outputW, 0), style: body),
              _Cell('', style: body),
              _Cell(_number(zone.surfaceTempC, 1), style: body),
              _Cell(tube, style: body),
              _Cell(_number(zone.pressureLossPa / 1000, 2), style: body),
              _Cell(_number(zone.zoneTubeLengthM, 1), style: body),
              _Cell(_number(zone.totalTubeLengthM, 1), style: body),
            ],
          ),
        );
      }
    }

    final totalAreaM2 = summary.rooms
        .expand((r) => r.zones)
        .map((z) => z.areaM2)
        .where((v) => v.isFinite)
        .fold(0.0, (a, b) => a + b);
    rows.add(
      TableRow(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.gridLine, width: 2)),
        ),
        children: [
          _Cell(l10n.roomSummary_total, style: strong, alignEnd: false),
          _Cell(_number(totalAreaM2, 1), style: strong),
          _Cell(_number(summary.demandW, 0), style: strong),
          _Cell('', style: strong),
          _Cell(_number(summary.flowRateKgH, 1), style: strong),
          _Cell('', style: strong),
          _Cell(_number(summary.outputW, 0), style: strong),
          _BalanceCell(balanceW: summary.balanceW, style: strong),
          _Cell('', style: strong),
          _Cell('', style: strong),
          _Cell(_number(summary.maxPressureLossPa / 1000, 2), style: strong),
          _Cell(_number(summary.zoneTubeLengthM, 1), style: strong),
          _Cell(_number(summary.totalTubeLengthM, 1), style: strong),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.unit,
    required this.alignEnd,
  });

  final String label;
  final String unit;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            unit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.text, {
    required this.style,
    this.alignEnd = true,
    this.indent = false,
  });

  final String text;
  final TextStyle? style;
  final bool alignEnd;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        indent ? Spacing.lg : Spacing.sm,
        Spacing.sm,
        Spacing.sm,
        Spacing.sm,
      ),
      child: Text(
        text,
        style: style,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        softWrap: false,
      ),
    );
  }
}

/// Difference between delivered heat and demand: green with an upward
/// arrow when the demand is covered, red with a downward arrow when the
/// room is under-supplied.
class _BalanceCell extends StatelessWidget {
  const _BalanceCell({required this.balanceW, required this.style});

  final double balanceW;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (!balanceW.isFinite) return _Cell(_none, style: style);
    final colors = Theme.of(context).extension<HeatingPlannerColors>()!;
    final covered = balanceW.round() >= 0;
    final color = covered ? colors.zoneGreen : colors.zoneRed;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs,
        vertical: Spacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(Spacing.xs),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  covered ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: Spacing.md,
                  color: color,
                ),
                Text(_signed(balanceW), style: style, softWrap: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
