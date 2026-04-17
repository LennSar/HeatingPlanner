import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/save_state_notifier.dart';
import 'save_flash_notifier.dart';

/// Compact status-bar widget that reflects the current [SaveState].
///
/// | State | Visual |
/// |-------|--------|
/// | `lastExportPath == null` (and no flash) | Hidden — data is safe in SQLite |
/// | `isAutoExporting == true` | Spinner (12 px) + "Saving…" label |
/// | `saveFlashProvider == true` | "✓ Saved" in `tertiary` (green) for 2 s |
/// | `isDirty == true` | Amber 6 px dot; tooltip prompts Ctrl+S |
/// | clean | ✓ check icon + "Saved" in `onSurfaceVariant` |
///
/// All colours come from [HeatingPlannerColors] tokens and the active
/// [ThemeData]; no hard-coded values are used.
class SaveStateIndicator extends ConsumerWidget {
  /// Creates a [SaveStateIndicator].
  const SaveStateIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveState = ref.watch(saveStateProvider);
    final isFlashing = ref.watch(saveFlashProvider);

    // Auto-export spinner takes priority.
    if (saveState.isAutoExporting) return const _Saving();

    // Manual-save flash: show highlighted "✓ Saved" for 2 s (§12.7).
    if (isFlashing) return const _Saved(highlighted: true);

    // No file path established yet — hide indicator.
    if (saveState.lastExportPath == null) {
      return const SizedBox.shrink();
    }

    if (saveState.isDirty) return const _UnsavedDot();
    return const _Saved();
  }
}

// ── Internal state widgets ────────────────────────────────────────────────────

class _Saving extends StatelessWidget {
  const _Saving();

  @override
  Widget build(BuildContext context) {
    final onSurface =
        Theme.of(context).colorScheme.onSurfaceVariant;
    final textStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: onSurface);

    return Tooltip(
      message: 'Saving to file…',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: onSurface,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Text('Saving…', style: textStyle),
        ],
      ),
    );
  }
}

class _UnsavedDot extends StatelessWidget {
  const _UnsavedDot();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<HeatingPlannerColors>()!;

    return Tooltip(
      message:
          'File export out of date — press Ctrl+S to update',
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: colors.warningAmber,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Saved extends StatelessWidget {
  const _Saved({this.highlighted = false});

  /// When `true`, renders in [ColorScheme.tertiary] (green) as tactile
  /// feedback for a manual save (agent-ui-ux.md §12.7). Reverts to
  /// the quiet `onSurfaceVariant` colour after 2 seconds.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final textStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: color);

    return Tooltip(
      message: 'All changes saved to file',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: color),
          const SizedBox(width: Spacing.xs),
          Text('Saved', style: textStyle),
        ],
      ),
    );
  }
}
