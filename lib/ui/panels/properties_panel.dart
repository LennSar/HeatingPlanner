import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/thermal_engine.dart';
import '../../core/theme/app_theme.dart';
import '../providers/editor_state_provider.dart';
import 'room_properties.dart';
import 'wall_construction_editor.dart';

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
          ? const _ProjectSummary()
          : _ElementProperties(selection: selection),
    );
  }
}

/// Shows project-level summary when nothing is selected.
class _ProjectSummary extends ConsumerWidget {
  const _ProjectSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final editorState = ref.watch(editorStateProvider);
    final roomCount = editorState.rooms.length;
    final wallCount = editorState.walls.length;

    // Compute total area from all rooms.
    var totalAreaM2 = 0.0;
    for (final room in editorState.rooms) {
      if (room.polygon.length >= 3) {
        totalAreaM2 +=
            GeometryEngine.polygonAreaM2(room.polygon);
      }
    }

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
          _infoRow('Rooms', '$roomCount', textTheme),
          _infoRow('Walls', '$wallCount', textTheme),
          _infoRow(
            'Total Area',
            '${totalAreaM2.toStringAsFixed(1)} m\u00B2',
            textTheme,
          ),
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

/// Routes to the correct property widget based on
/// selection type.
class _ElementProperties extends ConsumerWidget {
  const _ElementProperties({required this.selection});

  final SelectedElement selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (selection.type) {
      'room' => RoomProperties(roomId: selection.id),
      'wall' => _WallInfo(wallId: selection.id),
      _ => _GenericInfo(selection: selection),
    };
  }
}

/// Wall info panel with construction editor access.
class _WallInfo extends ConsumerWidget {
  const _WallInfo({required this.wallId});

  final String wallId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final editorState = ref.watch(editorStateProvider);
    final wall = editorState.walls
        .where((w) => w.id == wallId)
        .firstOrNull;

    if (wall == null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          'Wall not found',
          style: textTheme.bodyMedium,
        ),
      );
    }

    final lengthMm = GeometryEngine.distanceMm(
      wall.startPoint,
      wall.endPoint,
    );

    // Look up construction and compute U-value inline.
    final construction = wall.constructionId != null
        ? editorState.constructions
            .where((c) => c.id == wall.constructionId)
            .firstOrNull
        : null;

    String uValueText = '\u2014';
    if (construction != null) {
      final layers = editorState.materialLayers
          .where((l) => l.constructionId == construction.id)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final u = ThermalEngine.uValue(
        layerThicknessesMm:
            layers.map((l) => l.thicknessMm).toList(),
        layerLambdas:
            layers.map((l) => l.thermalConductivity).toList(),
        rsi: construction.rsi,
        rse: construction.rse,
      );
      if (!u.isNaN) {
        uValueText = '${u.toStringAsFixed(3)} W/(m\u00B2K)';
      }
    }

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Properties', style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text('Wall Segment', style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),
          _infoRow(
            'Length',
            '${lengthMm.round()} mm',
            textTheme,
          ),
          _infoRow('Type', wall.wallType.name, textTheme),
          _infoRow(
            'Orientation',
            wall.orientation.name,
            textTheme,
          ),
          _infoRow('U-Value', uValueText, textTheme),
          if (construction != null)
            _infoRow(
              'Construction',
              construction.name,
              textTheme,
            ),
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.layers_outlined, size: 16),
              label: Text(
                construction == null
                    ? 'Add Construction'
                    : 'Edit Construction',
              ),
              onPressed: () => showWallConstructionEditor(
                context,
                wall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback for unsupported element types.
class _GenericInfo extends StatelessWidget {
  const _GenericInfo({required this.selection});

  final SelectedElement selection;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Properties', style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text(selection.type, style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),
          _infoRow('ID', selection.id, textTheme),
        ],
      ),
    );
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
        Flexible(
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
