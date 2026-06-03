import 'package:flutter/material.dart';

import '../../calculation/providers/grouped_materials_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/localized_catalog_row.dart';
import '../../data/models/material_entry.dart';
import 'material_path_breadcrumb.dart';

/// A selectable row for an individual [MaterialEntry] inside a picker dropdown.
///
/// Displays [LocalizedCatalogRow.displayName] (locale-resolved) as primary
/// text and the λ value as secondary text styled in
/// [ColorScheme.onSurfaceVariant] (the `onSurfaceSecondary` design token).
/// Tapping the row invokes [onTap].
///
/// [indentLevel] controls left-padding depth so material rows nest cleanly
/// below breadcrumb group headers:
/// - 0 → [Spacing.sm] (8 px) — flat/ungrouped use
/// - 1 → [Spacing.sm] + [Spacing.md] (24 px) — under a path-group header (default
///   for the picker post-ADR-022)
///
/// **Note:** `MaterialEntry` does not currently store the manufacturer string
/// (it is present in `assets/materials.json` but was not mapped into the
/// database schema). The secondary line therefore shows only the λ value
/// ("λ 0.035 W/(m·K)"), which matches UI/UX spec §5.7.1. Add `manufacturer`
/// to the model and update [_secondaryText] when the field is available.
class MaterialEntryTile extends StatelessWidget {
  /// Creates a material entry tile.
  const MaterialEntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.indentLevel = 2,
    this.breadcrumbPath,
  });

  /// The material to display, paired with its locale-resolved display name.
  final LocalizedCatalogRow<MaterialEntry> entry;

  /// Called when the user taps the tile.
  final VoidCallback onTap;

  /// Nesting depth that determines left padding.
  ///
  /// 0 = top-level / flat list; 1 = under a breadcrumb group header
  /// (the new default post-ADR-022 picker rendering).
  final int indentLevel;

  /// When non-null the secondary line renders this `categoryPath` as a
  /// breadcrumb (`"A › B › C"`) instead of the λ value. Used by the
  /// search-result list per UI/UX §5.7.1 item 4.
  final List<String>? breadcrumbPath;

  /// Secondary label: λ value formatted to 3 d.p. with unit.
  ///
  /// When `manufacturer` is added to [MaterialEntry], prefix it here:
  /// `'${entry.row.manufacturer} · λ ...'`
  String get _secondaryText =>
      'λ ${entry.row.lambdaDefault.toStringAsFixed(3)} W/(m·K)';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Left padding grows by Spacing.md per indent level, anchored at Spacing.sm.
    final leftPad = Spacing.sm + indentLevel * Spacing.md;
    final path = breadcrumbPath;
    final semanticSecondary =
        path != null ? breadcrumbFor(path) : _secondaryText;

    return Semantics(
      label: '${entry.displayName}, $semanticSecondary',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(
            left: leftPad,
            right: Spacing.sm,
            top: Spacing.sm,
            bottom: Spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.displayName,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (path != null)
                MaterialPathBreadcrumb(path: path)
              else
                Text(
                  _secondaryText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
