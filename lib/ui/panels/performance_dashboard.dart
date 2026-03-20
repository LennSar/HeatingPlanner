import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/validation_result.dart';
import '../../validation/validation_service.dart';
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
                _ComingSoonPlaceholder(),
                _ComingSoonPlaceholder(),
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
// Coming-soon placeholder
// ---------------------------------------------------------------------------

class _ComingSoonPlaceholder extends StatelessWidget {
  const _ComingSoonPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Coming soon',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
          Text(
            'Warnings ($count)',
            style:
                Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
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

class _WarningRow extends StatefulWidget {
  const _WarningRow({required this.result});

  final ValidationResult result;

  @override
  State<_WarningRow> createState() => _WarningRowState();
}

class _WarningRowState extends State<_WarningRow> {
  bool _expanded = false;

  bool get _expandable =>
      widget.result.suggestedFix != null;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final textTheme = Theme.of(context).textTheme;
    final onSurfaceSecondary =
        Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: _expandable
          ? () => setState(() => _expanded = !_expanded)
          : null,
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
                SeverityBadge.label(
                  severity: result.severity,
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  result.elementType,
                  style: textTheme.bodySmall,
                ),
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
            Text(
              result.message,
              style: textTheme.bodyMedium,
            ),
            if (_expanded && result.suggestedFix != null) ...[
              const SizedBox(height: Spacing.xs),
              Padding(
                padding: const EdgeInsets.only(
                  left: Spacing.md,
                ),
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
