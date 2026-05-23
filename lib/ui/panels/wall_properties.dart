import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/thermal_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/wall_segment.dart';
import '../../l10n/app_localizations.dart';
import '../providers/editor_state_provider.dart';
import 'wall_construction_editor.dart';

/// Properties panel for a selected [WallSegment] (UI/UX §7.3).
///
/// Surfaces ADR-017 fields on top of the legacy wall info:
/// - Length (inner clear) — sourced from
///   [wallInnerEdgeLengthProvider]; the *Lichtmaß* length consumed by
///   heat-demand. Displayed as the primary length.
/// - Length (centerline) — small secondary line below.
/// - Thickness — read-only; suffix "(project default)" when
///   `constructionId == null`, "(from construction)" otherwise.
/// - Anchor face — dropdown over [WallAnchorMode] values. Disabled
///   with the documented tooltip when the wall is shared
///   (`mirrorId != null`, ADR-017 Rule 3).
class WallProperties extends ConsumerWidget {
  /// Creates a [WallProperties] panel for [wallId].
  const WallProperties({super.key, required this.wallId});

  /// UUID of the [WallSegment] to display.
  final String wallId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final secondaryColor =
        Theme.of(context).colorScheme.onSurfaceVariant;
    final l10n = AppLocalizations.of(context)!;
    final editorState = ref.watch(editorStateProvider);
    final wall = editorState.walls
        .where((w) => w.id == wallId)
        .firstOrNull;

    if (wall == null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          l10n.wallNotFound,
          style: textTheme.bodyMedium,
        ),
      );
    }

    // Inner-edge length is computed locally from the editor state
    // (room polygon + the room's walls) rather than via
    // `wallInnerEdgeLengthProvider` so the panel does not pull in
    // Drift-backed `wallSegmentProvider`. The painter uses the same
    // `GeometryEngine.roomFaceEdges` call internally.
    double innerEdgeMm = double.nan;
    final room = editorState.rooms
        .where((r) => r.id == wall.roomId)
        .firstOrNull;
    if (room != null && room.polygon.length >= 3) {
      final roomWalls = editorState.walls
          .where((w) => w.roomId == room.id)
          .toList();
      final edges = GeometryEngine.roomFaceEdges(
        walls: roomWalls,
        roomPolygon: room.polygon,
        side: RoomFaceSide.inner,
      );
      final edge = edges[wallId];
      if (edge != null) {
        innerEdgeMm =
            GeometryEngine.distanceMm(edge.start, edge.end);
      }
    }
    final centerlineMm = GeometryEngine.distanceMm(
      wall.startPoint,
      wall.endPoint,
    );

    final construction = wall.constructionId != null
        ? editorState.constructions
            .where((c) => c.id == wall.constructionId)
            .firstOrNull
        : null;

    String uValueText = '—';
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
        uValueText = '${u.toStringAsFixed(3)} W/(m²K)';
      }
    }

    final thicknessSuffix = wall.constructionId == null
        ? '(project default)'
        : '(from construction)';
    final thicknessText =
        '${wall.thicknessMm.round()} mm $thicknessSuffix';

    final isShared = wall.mirrorId != null;

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
            'Length (inner clear)',
            innerEdgeMm.isNaN
                ? '—'
                : '${innerEdgeMm.round()} mm',
            textTheme,
          ),
          _SecondaryRow(
            label: 'Length (centerline)',
            value: '${centerlineMm.round()} mm',
            secondaryColor: secondaryColor,
          ),
          _infoRow(l10n.typeWallLabel, wall.wallType.name, textTheme),
          _infoRow('Thickness', thicknessText, textTheme),
          const SizedBox(height: Spacing.sm),
          _AnchorFaceDropdown(
            wall: wall,
            disabled: isShared,
            onChanged: (mode) {
              if (mode == null || mode == wall.anchorMode) return;
              ref
                  .read(editorStateProvider.notifier)
                  .updateWall(wall.copyWith(anchorMode: mode));
            },
          ),
          const SizedBox(height: Spacing.sm),
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
              icon: const Icon(Icons.layers_outlined, size: 16),
              label: Text(
                construction == null
                    ? l10n.addConstruction
                    : l10n.editConstruction,
              ),
              onPressed: () =>
                  showWallConstructionEditor(context, wall),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anchor face dropdown — disabled with tooltip when [disabled] is
/// true (the wall is part of an ADR-001 shared pair). The disabled
/// state always shows `WallAnchorMode.centerline` because Rule 3
/// forces shared walls to that value.
class _AnchorFaceDropdown extends StatelessWidget {
  const _AnchorFaceDropdown({
    required this.wall,
    required this.disabled,
    required this.onChanged,
  });

  final WallSegment wall;
  final bool disabled;
  final ValueChanged<WallAnchorMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dropdown = DropdownButtonFormField<WallAnchorMode>(
      initialValue: wall.anchorMode,
      isDense: true,
      decoration: const InputDecoration(
        labelText: 'Anchor face',
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(
          value: WallAnchorMode.centerline,
          child: Text('Centerline'),
        ),
        DropdownMenuItem(
          value: WallAnchorMode.innerFace,
          child: Text('Inner face'),
        ),
        DropdownMenuItem(
          value: WallAnchorMode.outerFace,
          child: Text('Outer face'),
        ),
      ],
      onChanged: disabled ? null : onChanged,
      style: textTheme.bodyMedium,
    );
    if (!disabled) return dropdown;
    return Tooltip(
      message:
          'Shared interior walls always pivot on the centerline.',
      child: dropdown,
    );
  }
}

/// Small-text secondary info row used for the centerline length
/// sub-label per UI/UX §7.3.
class _SecondaryRow extends StatelessWidget {
  const _SecondaryRow({
    required this.label,
    required this.value,
    required this.secondaryColor,
  });

  final String label;
  final String value;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: secondaryColor),
          ),
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(color: secondaryColor),
          ),
        ],
      ),
    );
  }
}

Widget _infoRow(String label, String value, TextTheme textTheme) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
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
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}
