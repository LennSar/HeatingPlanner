import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/custom_material_library_service.dart';
import 'custom_material_library_picker.dart';
import 'manage_custom_materials_screen.dart';

/// Application Settings screen.
///
/// Currently only hosts the §9.2 Custom material library section.
/// Other settings (general, units, etc.) can be added to this scaffold
/// without restructuring.
class SettingsScreen extends StatelessWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomMaterialLibrarySection(),
          ],
        ),
      ),
    );
  }
}

/// §9.2 Custom material library section.
///
/// Shows the current library path, the four-state status line, and the
/// Browse / Clear / Reload / Manage actions.
class CustomMaterialLibrarySection extends ConsumerWidget {
  /// Creates a [CustomMaterialLibrarySection].
  const CustomMaterialLibrarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(customMaterialLibraryPathProvider);
    final customs =
        ref.watch(customMaterialsProvider).asData?.value ?? const [];
    final theme = Theme.of(context);
    final extColors = theme.extension<HeatingPlannerColors>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Custom material library',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.md),
            _PathDisplay(path: path),
            const SizedBox(height: Spacing.sm),
            _ActionRow(
              path: path,
              onBrowse: () =>
                  pickAndConfigureCustomMaterialLibrary(ref),
              onClear: path == null
                  ? null
                  : () => _confirmClear(context, ref),
              onReload: path == null
                  ? null
                  : () => _reload(context, ref),
            ),
            const SizedBox(height: Spacing.sm),
            _StatusLine(
              path: path,
              customCount: customs.length,
              colors: extColors,
            ),
            const SizedBox(height: Spacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('settings-manage-materials'),
                onPressed: path == null
                    ? null
                    : () =>
                        openManageCustomMaterialsScreen(context),
                child: const Text('Manage materials…'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink custom material library?'),
        content: const Text(
          'The file on disk will not be deleted, but your custom '
          'materials will disappear from the app until you pick the '
          'file again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(customMaterialLibraryServiceProvider)
        .setLibraryPath(null);
  }

  Future<void> _reload(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref
        .read(customMaterialLibraryServiceProvider)
        .reloadFromFile();
    if (!context.mounted) return;
    final count =
        ref.read(customMaterialsProvider).asData?.value.length ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reloaded $count custom materials')),
    );
  }
}

// ── Path display ────────────────────────────────────────────────────────────

class _PathDisplay extends StatelessWidget {
  const _PathDisplay({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (path == null) {
      return Text(
        'No library configured — pick a file to enable custom materials',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Tooltip(
      message: path!,
      child: Text(
        path!,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

// ── Action row ──────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.path,
    required this.onBrowse,
    required this.onClear,
    required this.onReload,
  });

  final String? path;
  final VoidCallback onBrowse;
  final VoidCallback? onClear;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: [
        OutlinedButton(
          key: const Key('settings-browse-library'),
          onPressed: onBrowse,
          child: const Text('Browse…'),
        ),
        OutlinedButton(
          key: const Key('settings-clear-library'),
          onPressed: onClear,
          child: const Text('Clear'),
        ),
        OutlinedButton(
          key: const Key('settings-reload-library'),
          onPressed: onReload,
          child: const Text('Reload from file'),
        ),
      ],
    );
  }
}

// ── Status line ─────────────────────────────────────────────────────────────

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.path,
    required this.customCount,
    required this.colors,
  });

  final String? path;
  final int customCount;
  final HeatingPlannerColors colors;

  @override
  Widget build(BuildContext context) {
    if (path == null) return const SizedBox.shrink();

    final file = File(path!);
    final exists = file.existsSync();
    final theme = Theme.of(context);

    if (!exists) {
      return Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: colors.warningAmber),
          const SizedBox(width: Spacing.xs),
          Text(
            'File missing — pick a new path or restore the file',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.warningAmber),
          ),
        ],
      );
    }

    // Heuristic: when the file exists but the sync pass ended up with
    // zero materials AND the file is non-empty, treat it as a parse
    // failure. (Empty skeleton + zero customs is a legitimate state.)
    final isLikelyParseError = customCount == 0 &&
        file.lengthSync() > _emptySkeletonByteCount;

    if (isLikelyParseError) {
      return Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: colors.warningAmber),
          const SizedBox(width: Spacing.xs),
          Text(
            'File could not be parsed — check the JSON syntax',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.warningAmber),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.check_circle, size: 16, color: colors.zoneGreen),
        const SizedBox(width: Spacing.xs),
        Text(
          'Loaded $customCount custom material'
          '${customCount == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

const int _emptySkeletonByteCount =
    32; // '{"version":"1.0","materials":[]}' = 32 bytes
