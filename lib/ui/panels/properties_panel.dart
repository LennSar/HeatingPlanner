import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';

/// Represents a selected element on the canvas.
@immutable
class SelectedElement {
  /// Creates a [SelectedElement].
  const SelectedElement({
    required this.type,
    required this.id,
  });

  /// Element type (e.g. 'room', 'wall', 'window').
  final String type;

  /// Element ID.
  final String id;
}

/// Notifier for the currently selected element.
class SelectedElementNotifier
    extends Notifier<SelectedElement?> {
  @override
  SelectedElement? build() => null;

  /// Set the selected element.
  void select(SelectedElement? element) {
    state = element;
  }
}

/// Provider tracking the currently selected element.
final selectedElementProvider = NotifierProvider<
    SelectedElementNotifier, SelectedElement?>(
  SelectedElementNotifier.new,
);

/// Context-sensitive properties panel (right side, 280px).
///
/// Shows properties of the currently selected element, or
/// a project summary when nothing is selected. See UI/UX
/// Section 4.2 and Frontend Section 5.1.
class PropertiesPanel extends ConsumerWidget {
  /// Creates a [PropertiesPanel].
  const PropertiesPanel({super.key});

  /// Desktop width at viewport >= 1200dp.
  static const double widthLarge = 280;

  /// Desktop width at viewport 900-1199dp.
  static const double widthMedium = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedElementProvider);
    final colors = Theme.of(context)
        .extension<HeatingPlannerColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        border: Border(
          left: BorderSide(color: colors.gridLine),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(-1, 0),
          ),
        ],
      ),
      child: selection == null
          ? _ProjectSummary(textTheme: textTheme)
          : _ElementProperties(
              selection: selection,
              textTheme: textTheme,
            ),
    );
  }
}

/// Shows project-level summary when nothing is selected.
class _ProjectSummary extends StatelessWidget {
  const _ProjectSummary({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Properties',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Project Summary',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.md),
          _infoRow('Rooms', '0', textTheme),
          _infoRow('Total Area', '0 m\u00B2', textTheme),
          _infoRow('Heat Demand', '0 W', textTheme),
          const SizedBox(height: Spacing.md),
          Text(
            'Select an element on the canvas to see '
            'its properties.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Shows properties for the currently selected element.
class _ElementProperties extends StatelessWidget {
  const _ElementProperties({
    required this.selection,
    required this.textTheme,
  });

  final SelectedElement selection;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Properties',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            _typeLabel(selection.type),
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.md),
          _infoRow('ID', selection.id, textTheme),
          _infoRow('Type', selection.type, textTheme),
          const Divider(height: Spacing.lg),
          Text(
            'Properties for this ${selection.type} '
            'will appear here once data providers '
            'are connected.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'room' => 'Room',
      'wall' => 'Wall Segment',
      'window' => 'Window',
      'door' => 'Door',
      'zone' => 'Heating Zone',
      'distributor' => 'Distributor',
      'circuit' => 'Circuit',
      _ => 'Element',
    };
  }
}

Widget _infoRow(
  String label,
  String value,
  TextTheme textTheme,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      vertical: Spacing.xs,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodyMedium),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
