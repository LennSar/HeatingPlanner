import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/app_preferences.dart';

/// Application-level settings screen.
///
/// Contains global preferences that are not tied to a specific
/// project: UI language and drawing grid spacing.
class SettingsScreen extends ConsumerWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLanguageLabel)),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          // ── Language ─────────────────────────────────
          _LanguageRow(l10n: l10n),

          const SizedBox(height: Spacing.lg),

          // ── Drawing grid size ────────────────────────
          const _GridSpacingRow(),
        ],
      ),
    );
  }
}

/// Dropdown for selecting the UI language.
class _LanguageRow extends ConsumerWidget {
  const _LanguageRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(languageCodeProvider).maybeWhen(
              data: (v) => v,
              orElse: () => 'en',
            );

    return Row(
      children: [
        Text(
          l10n.settingsLanguageLabel,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(width: Spacing.md),
        DropdownButton<String>(
          value: current,
          items: [
            DropdownMenuItem(
              value: 'en',
              child: Text(l10n.languageEnglish),
            ),
            DropdownMenuItem(
              value: 'de',
              child: Text(l10n.languageGerman),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(languageCodeProvider.notifier)
                  .set(value);
            }
          },
        ),
      ],
    );
  }
}

/// Dropdown for selecting the drawing grid spacing.
class _GridSpacingRow extends ConsumerWidget {
  const _GridSpacingRow();

  static const _options = [5, 10, 25, 50, 100];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(gridSpacingMmProvider).maybeWhen(
              data: (v) => v,
              orElse: () => 100,
            );
    final value =
        _options.contains(current) ? current : 100;

    return Row(
      children: [
        Text(
          'Drawing Grid Size',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(width: Spacing.md),
        DropdownButton<int>(
          value: value,
          items: _options
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text('$v mm'),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              ref
                  .read(gridSpacingMmProvider.notifier)
                  .set(v);
            }
          },
        ),
      ],
    );
  }
}
