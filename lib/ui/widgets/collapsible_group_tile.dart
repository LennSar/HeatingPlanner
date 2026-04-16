import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A non-selectable, expand/collapse group header for use in hierarchical
/// picker dropdowns (e.g. the 3-level material picker).
///
/// Renders a tappable header row with an animated [chevron_right] icon.
/// Tapping the row toggles visibility of [children]. The tile itself is never
/// selectable — it is purely a navigational grouping aid.
///
/// Two indent levels are supported:
/// - [indentLevel] == 0 — top-level category header.
///   Uses [bodyMedium] weight + [surfaceContainerHighest] background.
/// - [indentLevel] == 1 — subcategory header.
///   Uses [bodySmall] + transparent background, indented by [Spacing.md].
///
/// All colours and spacing come from the theme; no values are hard-coded.
///
/// ```dart
/// CollapsibleGroupTile(
///   title: 'Insulation boards',
///   indentLevel: 0,
///   initiallyExpanded: true,
///   children: [
///     CollapsibleGroupTile(
///       title: 'Stone wool board',
///       indentLevel: 1,
///       children: materialTiles,
///     ),
///   ],
/// )
/// ```
class CollapsibleGroupTile extends StatefulWidget {
  /// Creates a collapsible group tile.
  const CollapsibleGroupTile({
    super.key,
    required this.title,
    required this.indentLevel,
    this.initiallyExpanded = false,
    required this.children,
  }) : assert(
          indentLevel == 0 || indentLevel == 1,
          'indentLevel must be 0 (category) or 1 (subcategory)',
        );

  /// Display label for the group header.
  final String title;

  /// Nesting depth: 0 = top-level category, 1 = subcategory.
  final int indentLevel;

  /// Whether the tile starts expanded. Defaults to false.
  final bool initiallyExpanded;

  /// Widgets shown when the tile is expanded.
  final List<Widget> children;

  @override
  State<CollapsibleGroupTile> createState() => _CollapsibleGroupTileState();
}

class _CollapsibleGroupTileState extends State<CollapsibleGroupTile> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggle() => setState(() => _isExpanded = !_isExpanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isCategory = widget.indentLevel == 0;

    // ── Visual properties derived from indent level ─────────────────────────

    // Left padding: category flush at sm; subcategory indented an extra md.
    final leftPad = isCategory ? Spacing.sm : Spacing.sm + Spacing.md;

    // Vertical padding: category slightly taller for visual weight.
    final vertPad = isCategory ? Spacing.sm : Spacing.xs;

    // Category header gets a subtle filled background; subcategory is clear.
    final bgColor =
        isCategory ? colorScheme.surfaceContainerHighest : Colors.transparent;

    // Category: bodyMedium + semibold weight; subcategory: bodySmall.
    // Both use onSurfaceVariant so headers are visually distinct from
    // selectable material entries (which use onSurface).
    final textStyle = isCategory
        ? theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          )
        : theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          );

    // ── Header row ──────────────────────────────────────────────────────────

    // Material + InkWell ensures the ink ripple renders over the background.
    final header = Semantics(
      label: widget.title,
      expanded: _isExpanded,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: bgColor,
        child: InkWell(
          onTap: _toggle,
          child: Padding(
            padding: EdgeInsets.only(
              left: leftPad,
              right: Spacing.sm,
              top: vertPad,
              bottom: vertPad,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.chevron_right,
                    size: Spacing.md, // 16px — aligns with bodySmall cap height
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // ── Children panel — animates height on expand/collapse ─────────────────

    final body = AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _isExpanded
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            )
          : const SizedBox.shrink(),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, body],
    );
  }
}
