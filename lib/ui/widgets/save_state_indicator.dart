import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/save_state_notifier.dart';

/// Compact status-bar widget that reflects the current [SaveState].
///
/// | State | Visual |
/// |-------|--------|
/// | `lastExportPath == null` | Hidden (`SizedBox.shrink`) — data is safe in SQLite |
/// | `isAutoExporting == true` | Spinner (12 px) + "Saving…" label |
/// | `isDirty == true` | Amber 6 px dot; tooltip prompts Ctrl+S |
/// | clean | ✓ check icon + "Saved" label in `onSurfaceVariant` |
///
/// All colours and sizes come from [HeatingPlannerColors] tokens and the
/// active [ThemeData]; no hard-coded values are used.
class SaveStateIndicator extends ConsumerWidget {
  /// Creates a [SaveStateIndicator].
  const SaveStateIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveState = ref.watch(saveStateProvider);

    if (saveState.lastExportPath == null) return const SizedBox.shrink();
    if (saveState.isAutoExporting) return const _Saving();
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
      message: 'Changes not yet saved to file',
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
  const _Saved();

  @override
  Widget build(BuildContext context) {
    final onSurface =
        Theme.of(context).colorScheme.onSurfaceVariant;
    final textStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: onSurface);

    return Tooltip(
      message: 'All changes saved to file',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: onSurface),
          const SizedBox(width: Spacing.xs),
          Text('Saved', style: textStyle),
        ],
      ),
    );
  }
}
