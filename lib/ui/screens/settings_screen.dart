import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/custom_material_library_service.dart';
import 'custom_material_library_picker.dart';
import 'manage_custom_materials_screen.dart';

/// Application Settings screen.
///
/// Currently only hosts the §9.2 Custom material library section.
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
/// Per ADR-021 Rule 14 a default library file always exists, so the
/// effective path is always defined. The status line, Reload, and
/// Manage actions are therefore always available. "Reset to default"
/// only shows when an explicit user path has been picked.
class CustomMaterialLibrarySection extends ConsumerWidget {
  /// Creates a [CustomMaterialLibrarySection].
  const CustomMaterialLibrarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final storedPath = ref.watch(customMaterialLibraryPathProvider);
    final theme = Theme.of(context);
    final extColors = theme.extension<HeatingPlannerColors>()!;

    return Card(
      key: const Key('settings-custom-material-library-card'),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.settingsCustomMaterialLibraryTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.md),
            _EffectivePathDisplay(storedPath: storedPath),
            const SizedBox(height: Spacing.sm),
            _ActionRow(
              storedPath: storedPath,
              onBrowse: () => pickAndConfigureCustomMaterialLibrary(
                ref,
                context: context,
              ),
              onResetToDefault: storedPath == null
                  ? null
                  : () => _confirmResetToDefault(context, ref),
              onReload: () => _reload(context, ref),
            ),
            const SizedBox(height: Spacing.sm),
            _StatusLine(colors: extColors),
            const SizedBox(height: Spacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('settings-manage-materials'),
                onPressed: () =>
                    openManageCustomMaterialsScreen(context),
                child: Text(
                  l10n.settingsCustomMaterialLibraryManageButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetToDefault(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsCustomMaterialLibraryResetTitle),
        content: Text(l10n.settingsCustomMaterialLibraryResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.customMaterialButtonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.manageCustomMaterialsResetToDefault),
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
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(l10n.manageCustomMaterialsReloadedToast(count)),
      ),
    );
  }
}

// ── Effective-path display ──────────────────────────────────────────────────

/// Resolves and displays the effective library path with a `(default)`
/// chip when no explicit user path is stored.
class _EffectivePathDisplay extends ConsumerWidget {
  const _EffectivePathDisplay({required this.storedPath});

  /// `null` ⇒ Rule 14 default is in effect.
  final String? storedPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resolved =
        ref.watch(resolvedLibraryPathProvider).asData?.value ?? '';
    return Tooltip(
      message: resolved,
      child: Row(
        children: [
          Expanded(
            child: Text(
              resolved,
              key: const Key('settings-library-path'),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (storedPath == null) ...[
            const SizedBox(width: Spacing.sm),
            const _DefaultChip(),
          ],
        ],
      ),
    );
  }
}

class _DefaultChip extends StatelessWidget {
  const _DefaultChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('settings-library-default-chip'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs + 2,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Spacing.xs),
      ),
      child: Text(
        AppLocalizations.of(context)!
            .settingsCustomMaterialLibraryDefaultChip,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Action row ──────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.storedPath,
    required this.onBrowse,
    required this.onResetToDefault,
    required this.onReload,
  });

  final String? storedPath;
  final VoidCallback onBrowse;
  final VoidCallback? onResetToDefault;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: [
        OutlinedButton(
          key: const Key('settings-browse-library'),
          onPressed: onBrowse,
          child: Text(l10n.manageCustomMaterialsBrowse),
        ),
        if (storedPath != null)
          OutlinedButton(
            key: const Key('settings-reset-library'),
            onPressed: onResetToDefault,
            child: Text(l10n.manageCustomMaterialsResetToDefault),
          ),
        OutlinedButton(
          key: const Key('settings-reload-library'),
          onPressed: onReload,
          child: Text(l10n.manageCustomMaterialsReload),
        ),
      ],
    );
  }
}

// ── Status line ─────────────────────────────────────────────────────────────

/// Two-state status line per UI/UX §9.2 (updated).
class _StatusLine extends ConsumerWidget {
  const _StatusLine({required this.colors});

  final HeatingPlannerColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final path =
        ref.watch(resolvedLibraryPathProvider).asData?.value;
    final customs =
        ref.watch(customMaterialsProvider).asData?.value ?? const [];

    if (path == null) return const SizedBox.shrink();

    if (!File(path).existsSync()) {
      return Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: colors.warningAmber),
          const SizedBox(width: Spacing.xs),
          Flexible(
            child: Text(
              l10n.settingsCustomMaterialLibraryStatusError,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.warningAmber),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.check_circle, size: 16, color: colors.zoneGreen),
        const SizedBox(width: Spacing.xs),
        Text(
          l10n.settingsCustomMaterialLibraryStatusLoaded(
            customs.length,
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
