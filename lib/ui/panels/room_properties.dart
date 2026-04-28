import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/thermal_engine.dart';
import '../../calculation/providers/heat_demand_providers.dart';
import '../../calculation/providers/project_settings_provider.dart';
import '../../calculation/providers/u_value_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/room.dart';
import '../../data/models/wall_construction.dart';
import '../canvas/tools/undo_redo_service.dart';
import '../providers/editor_state_provider.dart';
import 'wall_construction_editor.dart';

/// Air change rate preset identifiers.
enum _AcrPreset {
  standardRoom,
  kitchen,
  bathroom,
  utilityRoom,
  serverRoom,
}

/// Air change rate values (h⁻¹) per agent-hvac.md §4.
const Map<_AcrPreset, double> _kAcrValues = {
  _AcrPreset.standardRoom: 0.5,
  _AcrPreset.kitchen: 1.0,
  _AcrPreset.bathroom: 1.5,
  _AcrPreset.utilityRoom: 2.0,
  _AcrPreset.serverRoom: 3.0,
};

/// Returns the localized display name for an ACR preset.
String _acrPresetLabel(_AcrPreset preset, AppLocalizations l10n) {
  switch (preset) {
    case _AcrPreset.standardRoom:
      return l10n.acrStandardRoom;
    case _AcrPreset.kitchen:
      return l10n.acrKitchen;
    case _AcrPreset.bathroom:
      return l10n.acrBathroom;
    case _AcrPreset.utilityRoom:
      return l10n.acrUtilityRoom;
    case _AcrPreset.serverRoom:
      return l10n.acrServerRoom;
  }
}

/// Returns the preset whose value matches [acr], or `null`
/// when no preset matches (within 0.001 tolerance).
_AcrPreset? _presetFor(double acr) {
  for (final e in _kAcrValues.entries) {
    if ((e.value - acr).abs() < 0.001) return e.key;
  }
  return null;
}

/// Editable properties panel for a selected room.
///
/// Shows room name (editable), target temperature slider,
/// air change rate dropdown (with custom numeric entry), and
/// computed geometry + heat demand values.
/// Watches [roomHeatDemandProvider] for the total; shows
/// "—" whenever the value is unavailable (NaN).
class RoomProperties extends ConsumerStatefulWidget {
  /// Creates [RoomProperties] for [roomId].
  const RoomProperties({required this.roomId, super.key});

  /// The ID of the room to display/edit.
  final String roomId;

  @override
  ConsumerState<RoomProperties> createState() =>
      _RoomPropertiesState();
}

class _RoomPropertiesState
    extends ConsumerState<RoomProperties> {
  late TextEditingController _nameController;

  /// Controller for the free-entry ACR text field shown when
  /// the user selects the "Custom" dropdown option.
  late TextEditingController _acrController;

  /// Currently selected preset, or `null` for custom input.
  /// Derived from the room model on first load of each room;
  /// kept in sync with external changes (undo/redo) via [ref.listen].
  _AcrPreset? _selectedAcrPreset;

  /// Last room ID that was synced into [_selectedAcrPreset] /
  /// [_acrController]. Used to detect room selection changes.
  String? _lastSyncedAcrRoomId;

  String? _lastRoomId;

  /// Snapshot of the room taken when the temperature slider
  /// drag starts — used to build the undo command on drag end.
  Room? _roomAtSliderStart;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _acrController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _acrController.dispose();
    super.dispose();
  }

  void _syncController(String name) {
    if (_lastRoomId != widget.roomId ||
        _nameController.text != name) {
      _lastRoomId = widget.roomId;
      _nameController.text = name;
    }
  }

  /// Syncs [_selectedAcrKey] and [_acrController] from the model
  /// when the selected room changes. Called from [build] before
  /// the dropdown is rendered — safe because no setState is needed
  /// (the values are read later in the same build call).
  void _syncAcrOnRoomChange(String roomId, double acr) {
    if (_lastSyncedAcrRoomId == roomId) return;
    _lastSyncedAcrRoomId = roomId;
    _selectedAcrPreset = _presetFor(acr);
    _acrController.text = _selectedAcrPreset == null
        ? acr.toStringAsFixed(1)
        : '';
  }

  /// Commits an air change rate update via the undo/redo stack.
  void _commitAcr(Room room, double newAcr) {
    if ((newAcr - room.airChangeRate).abs() < 0.001) return;
    ref.read(undoRedoProvider).execute(
          _UpdateRoomCommand(
            oldRoom: room,
            newRoom: room.copyWith(airChangeRate: newAcr),
            update:
                ref.read(editorStateProvider.notifier).updateRoom,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final editorState = ref.watch(editorStateProvider);

    // Keep dropdown in sync when ACR changes externally (undo/redo).
    // Must be called before any early return so the listener is always
    // registered in the same position.
    ref.listen<EditorState>(editorStateProvider, (prev, next) {
      if (!mounted) return;
      final prevAcr = prev?.rooms
          .where((r) => r.id == widget.roomId)
          .firstOrNull
          ?.airChangeRate;
      final nextRoom = next.rooms
          .where((r) => r.id == widget.roomId)
          .firstOrNull;
      if (nextRoom == null || prevAcr == nextRoom.airChangeRate) {
        return;
      }
      final preset = _presetFor(nextRoom.airChangeRate);
      setState(() {
        _selectedAcrPreset = preset;
        _acrController.text = preset == null
            ? nextRoom.airChangeRate.toStringAsFixed(1)
            : '';
      });
    });

    final room = editorState.rooms
        .where((r) => r.id == widget.roomId)
        .firstOrNull;

    final l10n = AppLocalizations.of(context)!;

    if (room == null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          l10n.roomNotFound,
          style: textTheme.bodyMedium,
        ),
      );
    }

    _syncController(room.name);
    _syncAcrOnRoomChange(widget.roomId, room.airChangeRate);

    final areaM2 = room.polygon.length >= 3
        ? GeometryEngine.polygonAreaM2(room.polygon)
        : 0.0;

    const ceilingHeightMm = 2600.0;
    final volumeM3 = areaM2 > 0
        ? ThermalEngine.roomVolumeM3(
            floorAreaM2: areaM2,
            ceilingHeightMm: ceilingHeightMm,
          )
        : double.nan;

    // Watch outdoor temp directly so this widget rebuilds when
    // the project setting changes, even while roomProvider is
    // a stub (the provider chain's early-return prevents the
    // indirect dependency from being established).
    final tOutdoor = ref.watch(designOutdoorTempCProvider);

    // Provider-backed total heat demand (NaN while repository
    // stubs are unconnected; will auto-update when wired).
    final totalDemandW =
        ref.watch(roomHeatDemandProvider(widget.roomId));

    final wallCount = editorState.walls
        .where((w) => w.roomId == widget.roomId)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.properties, style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text(l10n.room, style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),

          // Editable name.
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.nameLabel,
              isDense: true,
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty && value != room.name) {
                final oldRoom = room;
                final newRoom = room.copyWith(name: value);
                ref.read(undoRedoProvider).execute(
                  _UpdateRoomCommand(
                    oldRoom: oldRoom,
                    newRoom: newRoom,
                    update: ref
                        .read(editorStateProvider.notifier)
                        .updateRoom,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: Spacing.md),

          // Temperature slider.
          Text(
            l10n.targetTemperatureValue(
              room.targetTempC.toStringAsFixed(0),
            ),
            style: textTheme.bodyMedium,
          ),
          Slider(
            value: room.targetTempC,
            min: 15,
            max: 30,
            divisions: 30,
            label: '${room.targetTempC.toStringAsFixed(1)} \u00B0C',
            onChangeStart: (_) {
              _roomAtSliderStart = room;
            },
            onChanged: (value) {
              ref
                  .read(editorStateProvider.notifier)
                  .updateRoom(
                    room.copyWith(targetTempC: value),
                  );
            },
            onChangeEnd: (value) {
              final start = _roomAtSliderStart;
              _roomAtSliderStart = null;
              if (start != null &&
                  start.targetTempC != value) {
                ref.read(undoRedoProvider).execute(
                  _UpdateRoomCommand(
                    oldRoom: start,
                    newRoom: start.copyWith(
                      targetTempC: value,
                    ),
                    update: ref
                        .read(editorStateProvider.notifier)
                        .updateRoom,
                  ),
                );
              }
            },
          ),

          // Air change rate — preset dropdown + optional custom input.
          const SizedBox(height: Spacing.xs),
          _AcrField(
            selectedPreset: _selectedAcrPreset,
            customController: _acrController,
            onPresetSelected: (preset) {
              final newAcr = _kAcrValues[preset]!;
              setState(() => _selectedAcrPreset = preset);
              _commitAcr(room, newAcr);
            },
            onCustomSelected: () {
              setState(() {
                _selectedAcrPreset = null;
                _acrController.text =
                    room.airChangeRate.toStringAsFixed(1);
              });
            },
            onCustomSubmitted: (raw) {
              final parsed = double.tryParse(raw);
              if (parsed != null &&
                  parsed >= 0.1 &&
                  parsed <= 5.0) {
                _commitAcr(room, parsed);
              } else {
                // Reset to current value on invalid input.
                _acrController.text =
                    room.airChangeRate.toStringAsFixed(1);
              }
            },
          ),

          const Divider(height: Spacing.lg),

          // Read-only geometry.
          _readOnlyRow(
            l10n.floorArea,
            areaM2 > 0
                ? '${areaM2.toStringAsFixed(2)} m\u00B2'
                : '\u2014',
            textTheme,
          ),
          _readOnlyRow(
            l10n.roomVolume,
            !volumeM3.isNaN
                ? '${volumeM3.toStringAsFixed(1)} m\u00B3'
                : '\u2014',
            textTheme,
          ),
          _readOnlyRow(
            l10n.wallsCount,
            '$wallCount',
            textTheme,
          ),
          const Divider(height: Spacing.lg),

          // Heat demand breakdown (inline, from editorState).
          Text(
            l10n.heatDemand,
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.xs),
          ..._heatDemandRows(
            context,
            ref,
            room,
            areaM2,
            totalDemandW,
            tOutdoor,
            textTheme,
            l10n,
          ),
          const SizedBox(height: Spacing.xs),
          _EnvelopeSection(room: room),
        ],
      ),
    );
  }

  /// Computes and returns heat demand display rows.
  ///
  /// [totalDemandW] comes from [roomHeatDemandProvider].
  /// When it is [double.nan] the total and specific heat
  /// demand rows show "—". The transmission and ventilation
  /// breakdown is computed inline from [editorStateProvider]
  /// (no separate providers exist for these components yet).
  List<Widget> _heatDemandRows(
    BuildContext context,
    WidgetRef ref,
    Room room,
    double areaM2,
    double totalDemandW,
    double tOutdoor,
    TextTheme textTheme,
    AppLocalizations l10n,
  ) {
    const ceilingHeightMm = 2600.0;
    final tIndoor = room.targetTempC;

    final editorState = ref.read(editorStateProvider);
    final roomWalls = editorState.walls
        .where((w) => w.roomId == room.id)
        .toList();

    var qTransmission = 0.0;
    var hasAnyConstruction = false;

    for (final wall in roomWalls) {
      if (wall.constructionId == null) continue;
      final construction = editorState.constructions
          .where((c) => c.id == wall.constructionId)
          .firstOrNull;
      if (construction == null) continue;

      final layers = editorState.materialLayers
          .where((l) => l.constructionId == construction.id)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (layers.isEmpty) continue;

      final u = ThermalEngine.uValue(
        layerThicknessesMm:
            layers.map((l) => l.thicknessMm).toList(),
        layerLambdas:
            layers.map((l) => l.thermalConductivity).toList(),
        rsi: construction.rsi,
        rse: construction.rse,
      );
      if (u.isNaN) continue;
      hasAnyConstruction = true;

      final wallLengthMm = GeometryEngine.distanceMm(
        wall.startPoint,
        wall.endPoint,
      );

      final wallWindows = editorState.windows
          .where((w) => w.wallSegmentId == wall.id)
          .toList();
      final wallDoors = editorState.doors
          .where((d) => d.wallSegmentId == wall.id)
          .toList();

      final openings = <({int widthMm, int heightMm})>[
        for (final w in wallWindows)
          (widthMm: w.widthMm, heightMm: w.heightMm),
        for (final d in wallDoors)
          (widthMm: d.widthMm, heightMm: d.heightMm),
      ];

      final netAreaM2 = ThermalEngine.netWallAreaM2(
        wallLengthMm: wallLengthMm,
        wallHeightMm: ceilingHeightMm,
        openings: openings,
      );

      double corrF = 1.0;
      if (wall.adjacentRoomId != null &&
          wall.adjacentRoomId!.isNotEmpty) {
        final adjRoom = editorState.rooms
            .where((r) => r.id == wall.adjacentRoomId)
            .firstOrNull;
        final tAdj = adjRoom?.targetTempC ?? tIndoor;
        corrF = ThermalEngine.interiorCorrectionFactor(
          tThisRoomC: tIndoor,
          tAdjacentRoomC: tAdj,
          tOutdoorC: tOutdoor,
        );
        if (corrF.isNaN) corrF = 0.0;
      }

      if (!netAreaM2.isNaN && netAreaM2 > 0) {
        final loss = ThermalEngine.transmissionLoss(
          uValue: u,
          areaM2: netAreaM2,
          correctionF: corrF,
          tIndoorC: tIndoor,
          tOutdoorC: tOutdoor,
        );
        if (!loss.isNaN) qTransmission += loss;
      }

      for (final w in wallWindows) {
        final q = ThermalEngine.transmissionLoss(
          uValue: w.uValue,
          areaM2: w.widthMm * w.heightMm / 1e6,
          correctionF: corrF,
          tIndoorC: tIndoor,
          tOutdoorC: tOutdoor,
        );
        if (!q.isNaN) qTransmission += q;
      }

      for (final d in wallDoors) {
        final q = ThermalEngine.transmissionLoss(
          uValue: d.uValue,
          areaM2: d.widthMm * d.heightMm / 1e6,
          correctionF: corrF,
          tIndoorC: tIndoor,
          tOutdoorC: tOutdoor,
        );
        if (!q.isNaN) qTransmission += q;
      }
    }

    final volumeM3 = ThermalEngine.roomVolumeM3(
      floorAreaM2: areaM2,
      ceilingHeightMm: ceilingHeightMm,
    );
    final qVent = ThermalEngine.ventilationLoss(
      roomVolumeM3: volumeM3,
      airChangeRate: room.airChangeRate,
      tIndoorC: tIndoor,
      tOutdoorC: tOutdoor,
    );

    final tUnheatedDefault =
        ref.read(unheatedSpaceTempCProvider);
    final tIndoorDefault = ref.read(defaultIndoorTempCProvider);

    // Floor transmission loss (inline from editorState).
    double? qFloor;
    if (room.floorConstructionId != null && areaM2 > 0) {
      final floorConstruction = editorState.constructions
          .where((c) => c.id == room.floorConstructionId)
          .firstOrNull;
      if (floorConstruction != null) {
        final floorLayers = editorState.materialLayers
            .where(
              (l) => l.constructionId == room.floorConstructionId,
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (floorLayers.isNotEmpty) {
          final uFloor = ThermalEngine.uValue(
            layerThicknessesMm:
                floorLayers.map((l) => l.thicknessMm).toList(),
            layerLambdas: floorLayers
                .map((l) => l.thermalConductivity)
                .toList(),
            rsi: floorConstruction.rsi,
            rse: floorConstruction.rse,
          );
          if (!uFloor.isNaN) {
            final tFloorAdj = room.floorAdjacentTempC ??
                (room.floorBoundary == BoundaryCondition.interior
                    ? tIndoorDefault
                    : tUnheatedDefault);
            final fFloor =
                ThermalEngine.boundaryCorrectionFactor(
              condition: room.floorBoundary,
              tRoomC: tIndoor,
              tOutdoorC: tOutdoor,
              tAdjacentC: tFloorAdj,
            );
            if (!fFloor.isNaN) {
              final loss = ThermalEngine.transmissionLoss(
                uValue: uFloor,
                areaM2: areaM2,
                correctionF: fFloor,
                tIndoorC: tIndoor,
                tOutdoorC: tOutdoor,
              );
              if (!loss.isNaN) qFloor = loss;
            }
          }
        }
      }
    }

    // Ceiling transmission loss (same pattern).
    double? qCeiling;
    if (room.ceilingConstructionId != null && areaM2 > 0) {
      final ceilConstruction = editorState.constructions
          .where((c) => c.id == room.ceilingConstructionId)
          .firstOrNull;
      if (ceilConstruction != null) {
        final ceilLayers = editorState.materialLayers
            .where(
              (l) =>
                  l.constructionId == room.ceilingConstructionId,
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (ceilLayers.isNotEmpty) {
          final uCeiling = ThermalEngine.uValue(
            layerThicknessesMm:
                ceilLayers.map((l) => l.thicknessMm).toList(),
            layerLambdas: ceilLayers
                .map((l) => l.thermalConductivity)
                .toList(),
            rsi: ceilConstruction.rsi,
            rse: ceilConstruction.rse,
          );
          if (!uCeiling.isNaN) {
            final tCeilAdj = room.ceilingAdjacentTempC ??
                (room.ceilingBoundary == BoundaryCondition.interior
                    ? tIndoorDefault
                    : tUnheatedDefault);
            final fCeiling =
                ThermalEngine.boundaryCorrectionFactor(
              condition: room.ceilingBoundary,
              tRoomC: tIndoor,
              tOutdoorC: tOutdoor,
              tAdjacentC: tCeilAdj,
            );
            if (!fCeiling.isNaN) {
              final loss = ThermalEngine.transmissionLoss(
                uValue: uCeiling,
                areaM2: areaM2,
                correctionF: fCeiling,
                tIndoorC: tIndoor,
                tOutdoorC: tOutdoor,
              );
              if (!loss.isNaN) qCeiling = loss;
            }
          }
        }
      }
    }

    // Specific heat demand: use provider total if available,
    // fall back to inline total.
    final inlineTotal =
        (hasAnyConstruction ? qTransmission : 0.0) +
            (qVent.isNaN ? 0.0 : qVent) +
            (qFloor ?? 0.0) +
            (qCeiling ?? 0.0);
    final effectiveTotal =
        totalDemandW.isNaN ? inlineTotal : totalDemandW;
    final specificW =
        (areaM2 > 0 && effectiveTotal > 0)
            ? effectiveTotal / areaM2
            : double.nan;

    final colorScheme = Theme.of(context).colorScheme;
    final demandTooltip = _roomDemandMissingPrereqs(
      room,
      editorState,
    );

    return [
      if (hasAnyConstruction)
        _readOnlyRow(
          l10n.transmissionQt,
          '${qTransmission.round()} W',
          textTheme,
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.xs,
          ),
          child: Text(
            l10n.assignConstructionsHint,
            style: textTheme.bodySmall,
          ),
        ),
      _readOnlyRow(
        l10n.transmissionFloor,
        qFloor != null ? '${qFloor.round()} W' : '\u2014',
        textTheme,
      ),
      _readOnlyRow(
        l10n.transmissionCeiling,
        qCeiling != null ? '${qCeiling.round()} W' : '\u2014',
        textTheme,
      ),
      if (!qVent.isNaN)
        _readOnlyRow(
          l10n.ventilationQv,
          '${qVent.round()} W',
          textTheme,
        ),
      const SizedBox(height: Spacing.xs),
      // Total: bold, from provider when available.
      Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                l10n.totalHeatDemand,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (totalDemandW.isNaN && demandTooltip != null)
              Tooltip(
                message: demandTooltip,
                child: Text(
                  '\u2014',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Text(
                totalDemandW.isNaN
                    ? '\u2014'
                    : '${totalDemandW.round()} W',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
      // Specific heat demand (W/m²).
      _readOnlyRow(
        l10n.specificHeatDemand,
        specificW.isNaN
            ? '\u2014'
            : '${specificW.toStringAsFixed(1)} W/m\u00B2',
        textTheme,
        context: context,
        tooltipMessage: specificW.isNaN ? demandTooltip : null,
      ),
    ];
  }
}

// ================================================================
// Air change rate field
// ================================================================

/// Dropdown for selecting an air change rate preset, with an
/// optional free-entry text field revealed when 'Custom' is chosen.
///
/// All state and callbacks are owned by the parent widget so this
/// can remain a simple [StatelessWidget].
class _AcrField extends StatelessWidget {
  const _AcrField({
    required this.selectedPreset,
    required this.customController,
    required this.onPresetSelected,
    required this.onCustomSelected,
    required this.onCustomSubmitted,
  });

  /// Currently active preset, or `null` for custom input.
  final _AcrPreset? selectedPreset;

  /// Controller for the free-entry text field (only visible when
  /// [selectedPreset] is `null`).
  final TextEditingController customController;

  /// Fired when the user picks a named preset.
  final void Function(_AcrPreset preset) onPresetSelected;

  /// Fired when the user picks 'Custom' from the dropdown.
  final VoidCallback onCustomSelected;

  /// Fired when the user submits the custom numeric text field.
  final void Function(String raw) onCustomSubmitted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    // Use int index for dropdown value; -1 = custom.
    final selectedIndex =
        selectedPreset != null ? selectedPreset!.index : -1;

    final items = [
      ..._kAcrValues.entries.map(
        (e) => DropdownMenuItem<int>(
          value: e.key.index,
          child: Text(
            '${_acrPresetLabel(e.key, l10n)}'
            ' \u2014 ${e.value} h\u207B\u00B9',
            style: textTheme.bodyMedium,
          ),
        ),
      ),
      DropdownMenuItem<int>(
        value: -1,
        child: Text(l10n.custom, style: textTheme.bodyMedium),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.airChangeRate, style: textTheme.bodyMedium),
        const SizedBox(height: Spacing.xs),
        InputDecorator(
          decoration: const InputDecoration(isDense: true),
          child: DropdownButton<int>(
            value: selectedIndex,
            isDense: true,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: items,
            onChanged: (idx) {
              if (idx == null) return;
              if (idx == -1) {
                onCustomSelected();
              } else {
                onPresetSelected(_AcrPreset.values[idx]);
              }
            },
          ),
        ),
        if (selectedPreset == null) ...[
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: customController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: l10n.rateLabel,
              suffixText: 'h\u207B\u00B9',
              helperText: '0.1 – 5.0',
              isDense: true,
            ),
            onSubmitted: onCustomSubmitted,
          ),
        ],
      ],
    );
  }
}

// ================================================================
// Shared helpers
// ================================================================

Widget _readOnlyRow(
  String label,
  String value,
  TextTheme textTheme, {
  BuildContext? context,
  String? tooltipMessage,
}) {
  final valueStyle =
      textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

  Widget valueWidget;
  if (value == '\u2014' &&
      tooltipMessage != null &&
      context != null) {
    final secondaryColor =
        Theme.of(context).colorScheme.onSurfaceVariant;
    valueWidget = Tooltip(
      message: tooltipMessage,
      child: Text(
        value,
        style: valueStyle?.copyWith(
          color: secondaryColor,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: secondaryColor,
        ),
      ),
    );
  } else {
    valueWidget = Text(value, style: valueStyle);
  }

  return Padding(
    padding: const EdgeInsets.symmetric(
      vertical: Spacing.xs,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: textTheme.bodyMedium)),
        valueWidget,
      ],
    ),
  );
}

/// Returns a newline-separated list of unmet prerequisites for
/// room heat demand, or null when all prerequisites are met.
String? _roomDemandMissingPrereqs(Room room, EditorState state) {
  final roomWalls =
      state.walls.where((w) => w.roomId == room.id).toList();

  final missing = <String>[];

  if (roomWalls.isEmpty) {
    missing.add('No exterior walls defined');
    return missing.join('\n');
  }

  final hasExterior =
      roomWalls.any((w) => w.wallType == WallType.exterior);
  if (!hasExterior) {
    missing.add('No exterior walls defined');
  } else {
    final hasConstruction = roomWalls
        .where((w) => w.wallType == WallType.exterior)
        .any((w) => w.constructionId != null);
    if (!hasConstruction) {
      missing.add('No wall construction assigned to exterior walls');
    }
  }

  return missing.isEmpty ? null : missing.join('\n');
}

// ================================================================
// Envelope — Floor & Ceiling section
// ================================================================

/// Floor boundary conditions in dropdown order.
const _kFloorConditions = <BoundaryCondition>[
  BoundaryCondition.ground,
  BoundaryCondition.unheatedSpace,
  BoundaryCondition.interior,
];

/// Ceiling boundary conditions in dropdown order.
const _kCeilingConditions = <BoundaryCondition>[
  BoundaryCondition.exterior,
  BoundaryCondition.unheatedSpace,
  BoundaryCondition.interior,
];

/// Returns the localized label for a floor boundary condition.
String _floorBoundaryLabel(
  BoundaryCondition condition,
  AppLocalizations l10n,
) {
  switch (condition) {
    case BoundaryCondition.ground:
      return l10n.boundaryGround;
    case BoundaryCondition.unheatedSpace:
      return l10n.boundaryUnheatedBelow;
    case BoundaryCondition.interior:
      return l10n.boundaryAdjacentBelow;
    case BoundaryCondition.exterior:
      return l10n.boundaryExteriorRoof;
  }
}

/// Returns the localized label for a ceiling boundary condition.
String _ceilingBoundaryLabel(
  BoundaryCondition condition,
  AppLocalizations l10n,
) {
  switch (condition) {
    case BoundaryCondition.exterior:
      return l10n.boundaryExteriorRoof;
    case BoundaryCondition.unheatedSpace:
      return l10n.boundaryUnheatedAbove;
    case BoundaryCondition.interior:
      return l10n.boundaryAdjacentAbove;
    case BoundaryCondition.ground:
      return l10n.boundaryGround;
  }
}

/// Collapsible "Envelope — Floor & Ceiling" section shown in the
/// room properties panel.
///
/// Provides boundary condition dropdowns, construction assignment
/// buttons, and correction factor sliders for both the floor slab
/// and the ceiling/roof slab.
class _EnvelopeSection extends ConsumerStatefulWidget {
  const _EnvelopeSection({required this.room});

  final Room room;

  @override
  ConsumerState<_EnvelopeSection> createState() =>
      _EnvelopeSectionState();
}

class _EnvelopeSectionState
    extends ConsumerState<_EnvelopeSection> {

  void _updateRoom(Room updated) {
    ref.read(editorStateProvider.notifier).updateRoom(updated);
  }

  void _onFloorBoundaryChanged(BoundaryCondition condition) {
    _updateRoom(
      widget.room.copyWith(
        floorBoundary: condition,
        floorAdjacentTempC: null,
      ),
    );
  }

  void _onCeilingBoundaryChanged(BoundaryCondition condition) {
    _updateRoom(
      widget.room.copyWith(
        ceilingBoundary: condition,
        ceilingAdjacentTempC: null,
      ),
    );
  }

  void _openFloorEditor() {
    final l10n = AppLocalizations.of(context)!;
    final room = widget.room;
    showSlabConstructionEditor(
      context,
      constructionId: room.floorConstructionId,
      title: l10n.floorConstruction,
      onSaved: (id) =>
          _updateRoom(room.copyWith(floorConstructionId: id)),
    );
  }

  void _openCeilingEditor() {
    final l10n = AppLocalizations.of(context)!;
    final room = widget.room;
    showSlabConstructionEditor(
      context,
      constructionId: room.ceilingConstructionId,
      title: l10n.roofCeilingConstruction,
      onSaved: (id) =>
          _updateRoom(room.copyWith(ceilingConstructionId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final room = widget.room;
    final editorState = ref.watch(editorStateProvider);

    final floorConstruction = room.floorConstructionId == null
        ? null
        : editorState.constructions
            .where((c) => c.id == room.floorConstructionId)
            .firstOrNull;
    final ceilConstruction = room.ceilingConstructionId == null
        ? null
        : editorState.constructions
            .where((c) => c.id == room.ceilingConstructionId)
            .firstOrNull;

    final floorUVal = floorConstruction == null
        ? double.nan
        : ref.watch(uValueProvider(floorConstruction.id));
    final ceilUVal = ceilConstruction == null
        ? double.nan
        : ref.watch(uValueProvider(ceilConstruction.id));

    return ExpansionTile(
      title: Text(
        l10n.envelopeFloorCeiling,
        style: textTheme.titleSmall,
      ),
      initiallyExpanded: false,
      childrenPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      children: [
        // ── Floor subsection ────────────────────────────────
        Text(l10n.floorLabel, style: textTheme.labelLarge),
        const SizedBox(height: Spacing.xs),
        _boundaryDropdown(
          label: l10n.whatsBelow,
          conditions: _kFloorConditions,
          selectedCondition: room.floorBoundary,
          labelFn: (c) => _floorBoundaryLabel(c, l10n),
          onChanged: _onFloorBoundaryChanged,
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xs),
        _constructionButton(
          context: context,
          l10n: l10n,
          construction: floorConstruction,
          uVal: floorUVal,
          onTap: _openFloorEditor,
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xs),
        _adjacentTempRow(
          context: context,
          l10n: l10n,
          condition: room.floorBoundary,
          adjacentTempC: room.floorAdjacentTempC,
          onChanged: (v) => _updateRoom(
            room.copyWith(floorAdjacentTempC: v),
          ),
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.sm),
        const Divider(height: Spacing.sm),

        // ── Ceiling subsection ──────────────────────────────
        Text(l10n.ceilingLabel, style: textTheme.labelLarge),
        const SizedBox(height: Spacing.xs),
        _boundaryDropdown(
          label: l10n.whatsAbove,
          conditions: _kCeilingConditions,
          selectedCondition: room.ceilingBoundary,
          labelFn: (c) => _ceilingBoundaryLabel(c, l10n),
          onChanged: _onCeilingBoundaryChanged,
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xs),
        _constructionButton(
          context: context,
          l10n: l10n,
          construction: ceilConstruction,
          uVal: ceilUVal,
          onTap: _openCeilingEditor,
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xs),
        _adjacentTempRow(
          context: context,
          l10n: l10n,
          condition: room.ceilingBoundary,
          adjacentTempC: room.ceilingAdjacentTempC,
          onChanged: (v) => _updateRoom(
            room.copyWith(ceilingAdjacentTempC: v),
          ),
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xs),
      ],
    );
  }

  Widget _boundaryDropdown({
    required String label,
    required List<BoundaryCondition> conditions,
    required BoundaryCondition selectedCondition,
    required String Function(BoundaryCondition) labelFn,
    required void Function(BoundaryCondition) onChanged,
    required TextTheme textTheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodyMedium),
        const SizedBox(height: Spacing.xs),
        InputDecorator(
          decoration: const InputDecoration(isDense: true),
          child: DropdownButton<BoundaryCondition>(
            value: selectedCondition,
            isDense: true,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: conditions
                .map(
                  (c) => DropdownMenuItem<BoundaryCondition>(
                    value: c,
                    child: Text(
                      labelFn(c),
                      style: textTheme.bodyMedium,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }

  Widget _constructionButton({
    required BuildContext context,
    required AppLocalizations l10n,
    required WallConstruction? construction,
    required double uVal,
    required VoidCallback onTap,
    required TextTheme textTheme,
  }) {
    final label = construction == null
        ? l10n.notAssigned
        : uVal.isNaN
            ? construction.name
            : '${construction.name} \u2014 '
                'U ${uVal.toStringAsFixed(2)}'
                ' W/(m\u00B2\u00B7K)';
    final actionLabel =
        construction == null ? l10n.assignAction : l10n.editAction;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              actionLabel,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adjacentTempRow({
    required BuildContext context,
    required AppLocalizations l10n,
    required BoundaryCondition condition,
    required double? adjacentTempC,
    required void Function(double?) onChanged,
    required TextTheme textTheme,
  }) {
    if (condition == BoundaryCondition.exterior ||
        condition == BoundaryCondition.ground) {
      return const SizedBox.shrink();
    }

    final tUnheated = ref.read(unheatedSpaceTempCProvider);
    final tIndoor = ref.read(defaultIndoorTempCProvider);
    final projectDefault = condition == BoundaryCondition.interior
        ? tIndoor
        : tUnheated;

    final label = condition == BoundaryCondition.interior
        ? l10n.adjacentRoomTemp
        : l10n.unheatedSpaceTempShort;

    final controller = TextEditingController(
      text: adjacentTempC?.toStringAsFixed(1) ?? '',
    );

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: l10n.defaultHint(
                projectDefault.toStringAsFixed(1),
              ),
              suffixText: '\u00B0C',
              isDense: true,
            ),
            style: textTheme.bodyMedium,
            onSubmitted: (raw) {
              final parsed = double.tryParse(raw);
              onChanged(parsed);
            },
          ),
        ),
        if (adjacentTempC != null)
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            tooltip: l10n.resetToProjectDefault,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}

// ================================================================
// Command classes
// ================================================================

/// Command: update a room property (name, temperature, ACR, etc.).
class _UpdateRoomCommand extends Command {
  _UpdateRoomCommand({
    required this.oldRoom,
    required this.newRoom,
    required this.update,
  });

  final Room oldRoom;
  final Room newRoom;

  /// Callback that applies a room update to the editor state.
  final void Function(Room room) update;

  @override
  String get label => 'Update room';

  @override
  void execute() => update(newRoom);

  @override
  void undo() => update(oldRoom);
}
