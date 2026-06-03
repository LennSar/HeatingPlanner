import 'package:flutter/material.dart';

import '../../calculation/providers/grouped_materials_provider.dart';

/// Renders a `categoryPath` as a single-line breadcrumb (`"A › B › C"`).
///
/// Shared by the material-picker search-result subtitle (UI/UX §5.7.1
/// item 4) and the Custom Material dialog's "Start under" picker
/// (§5.7.2) so the `›` separator and styling stay consistent. The
/// separator and join logic live in [breadcrumbFor]; this widget only
/// adds the default styling (`bodySmall` in the `onSurfaceSecondary`
/// token) which callers may override via [style].
class MaterialPathBreadcrumb extends StatelessWidget {
  /// Creates a [MaterialPathBreadcrumb] for [path].
  const MaterialPathBreadcrumb({
    super.key,
    required this.path,
    this.style,
  });

  /// The `categoryPath` to render.
  final List<String> path;

  /// Optional style override. Defaults to `bodySmall` /
  /// `onSurfaceVariant`.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = style ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    return Text(
      breadcrumbFor(path),
      style: resolved,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
