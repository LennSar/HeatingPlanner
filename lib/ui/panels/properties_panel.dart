import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/thermal_engine.dart';
import '../../calculation/providers/heat_demand_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/project_repository.dart';
import '../providers/editor_state_provider.dart';
import '../providers/selection_provider.dart';
import 'circuit_properties.dart';
import 'distributor_properties.dart';
import 'heating_zone_properties.dart';
import 'opening_properties.dart';
import 'room_properties.dart';
import 'wall_construction_editor.dart';

export '../providers/selection_provider.dart'
    show
        SelectedElement,
        SelectedElementNotifier,
        selectedElementProvider;

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

    // Wrap with a Focus that absorbs key events whenever a
    // text field inside the panel has keyboard focus.  This
    // prevents events (Backspace, Delete, tool-switch keys,
    // etc.) from propagating up to the canvas Shortcuts
    // handler while the user is editing a property field.
    return Focus(
      onKeyEvent: (node, event) {
        final primary = FocusManager.instance.primaryFocus;
        if (primary?.context
                ?.findAncestorWidgetOfExactType<EditableText>() !=
            null) {
          return KeyEventResult.skipRemainingHandlers;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
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
      ),
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

    var totalAreaM2 = 0.0;
    for (final room in editorState.rooms) {
      if (room.polygon.length >= 3) {
        totalAreaM2 +=
            GeometryEngine.polygonAreaM2(room.polygon);
      }
    }

    final projectId =
        ref.watch(currentProjectIdProvider);
    final buildingDemandW = projectId.isNotEmpty
        ? ref.watch(buildingHeatDemandProvider(projectId))
        : double.nan;

    final demandText = buildingDemandW.isNaN
        ? '\u2014'
        : '${buildingDemandW.round()} W';

    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.properties,
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            l10n.projectSummary,
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.md),
          _infoRow(l10n.rooms, '$roomCount', textTheme),
          _infoRow(l10n.walls, '$wallCount', textTheme),
          _infoRow(
            l10n.totalArea,
            '${totalAreaM2.toStringAsFixed(1)} m\u00B2',
            textTheme,
          ),
          _infoRow(l10n.totalHeatDemand, demandText, textTheme),
          const SizedBox(height: Spacing.md),
          Text(
            l10n.selectElementHint,
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
      'window' =>
        WindowProperties(windowId: selection.id),
      'door' => DoorProperties(doorId: selection.id),
      'zone' => HeatingZoneProperties(zoneId: selection.id),
      'distributor' =>
        DistributorProperties(distributorId: selection.id),
      'circuit' =>
        CircuitProperties(circuitId: selection.id),
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

    final l10n = AppLocalizations.of(context)!;

    if (wall == null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          l10n.wallNotFound,
          style: textTheme.bodyMedium,
        ),
      );
    }

    final lengthMm = GeometryEngine.distanceMm(
      wall.startPoint,
      wall.endPoint,
    );

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
        uValueText =
            '${u.toStringAsFixed(3)} W/(m\u00B2K)';
      }
    }

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.properties, style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text(l10n.wallSegment, style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),
          _infoRow(
            l10n.lengthLabel,
            '${lengthMm.round()} mm',
            textTheme,
          ),
          _infoRow(l10n.typeWallLabel, wall.wallType.name, textTheme),
          _infoRow(
            l10n.orientationLabel,
            wall.orientation.name,
            textTheme,
          ),
          _infoRow(l10n.uValueLabel, uValueText, textTheme),
          if (construction != null)
            _infoRow(
              l10n.constructionLabel,
              ref
                      .watch(localizedWallConstructionsProvider)
                      .where((lr) => lr.row.id == construction.id)
                      .firstOrNull
                      ?.displayName ??
                  construction.name,
              textTheme,
            ),
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.layers_outlined,
                  size: 16),
              label: Text(
                construction == null
                    ? l10n.addConstruction
                    : l10n.editConstruction,
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.properties, style: textTheme.headlineMedium),
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
