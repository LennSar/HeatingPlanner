import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/thermal_engine.dart';
import '../../calculation/providers/heat_demand_providers.dart';
import '../../calculation/providers/project_settings_provider.dart';
import '../../calculation/providers/u_value_providers.dart';
import '../../core/constants/thermal_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/room.dart';
import '../../data/models/wall_construction.dart';
import '../canvas/tools/undo_redo_service.dart';
import '../providers/editor_state_provider.dart';
import 'wall_construction_editor.dart';

/// Air change rate presets (h⁻¹) per agent-hvac.md §4.
const Map<String, double> _kAirChangePresets = {
  'Standard room': 0.5,
  'Kitchen': 1.0,
  'Bathroom': 1.5,
  'Utility room': 2.0,
  'Server room': 3.0,
};

const _kCustomKey = 'Custom';

/// Returns the preset label whose value matches [acr], or
/// [_kCustomKey] when no preset matches (within 0.001 tolerance).
String _presetKeyFor(double acr) {
  for (final e in _kAirChangePresets.entries) {
    if ((e.value - acr).abs() < 0.001) return e.key;
  }
  return _kCustomKey;
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

  /// Currently selected dropdown label. Derived from the room
  /// model on first load of each room; kept in sync with
  /// external changes (undo/redo) via [ref.listen].
  String _selectedAcrKey = _kCustomKey;

  /// Last room ID that was synced into [_selectedAcrKey] /
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
    _selectedAcrKey = _presetKeyFor(acr);
    _acrController.text = _selectedAcrKey == _kCustomKey
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
      final key = _presetKeyFor(nextRoom.airChangeRate);
      setState(() {
        _selectedAcrKey = key;
        _acrController.text = key == _kCustomKey
            ? nextRoom.airChangeRate.toStringAsFixed(1)
            : '';
      });
    });

    final room = editorState.rooms
        .where((r) => r.id == widget.roomId)
        .firstOrNull;

    if (room == null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          'Room not found',
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
          Text('Properties', style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          Text('Room', style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),

          // Editable name.
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
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
            'Target Temperature: '
            '${room.targetTempC.toStringAsFixed(0)} \u00B0C',
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
            selectedKey: _selectedAcrKey,
            customController: _acrController,
            onPresetSelected: (key) {
              final newAcr = _kAirChangePresets[key]!;
              setState(() => _selectedAcrKey = key);
              _commitAcr(room, newAcr);
            },
            onCustomSelected: () {
              setState(() {
                _selectedAcrKey = _kCustomKey;
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
            'Floor Area',
            areaM2 > 0
                ? '${areaM2.toStringAsFixed(2)} m\u00B2'
                : '\u2014',
            textTheme,
          ),
          _readOnlyRow(
            'Room Volume',
            !volumeM3.isNaN
                ? '${volumeM3.toStringAsFixed(1)} m\u00B3'
                : '\u2014',
            textTheme,
          ),
          _readOnlyRow(
            'Walls',
            '$wallCount',
            textTheme,
          ),
          const Divider(height: Spacing.lg),

          // Heat demand breakdown (inline, from editorState).
          Text(
            'Heat Demand',
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
            final fFloor =
                ThermalEngine.boundaryCorrectionFactor(
              condition: room.floorBoundary,
              unheatedCorrectionFactor:
                  room.floorUnheatedCorrectionFactor,
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
            final fCeiling =
                ThermalEngine.boundaryCorrectionFactor(
              condition: room.ceilingBoundary,
              unheatedCorrectionFactor:
                  room.ceilingUnheatedCorrectionFactor,
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
          'Transmission Q\u1D40',
          '${qTransmission.round()} W',
          textTheme,
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.xs,
          ),
          child: Text(
            'Assign constructions to walls for '
            'transmission loss.',
            style: textTheme.bodySmall,
          ),
        ),
      _readOnlyRow(
        'Transmission \u2014 floor',
        qFloor != null ? '${qFloor.round()} W' : '\u2014',
        textTheme,
      ),
      _readOnlyRow(
        'Transmission \u2014 ceiling',
        qCeiling != null ? '${qCeiling.round()} W' : '\u2014',
        textTheme,
      ),
      if (!qVent.isNaN)
        _readOnlyRow(
          'Ventilation Q\u1D20',
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
            Text(
              'Total Heat Demand',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
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
        'Specific Heat Demand',
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
    required this.selectedKey,
    required this.customController,
    required this.onPresetSelected,
    required this.onCustomSelected,
    required this.onCustomSubmitted,
  });

  /// Currently active dropdown label (one of [_kAirChangePresets]
  /// keys or [_kCustomKey]).
  final String selectedKey;

  /// Controller for the free-entry text field (only visible when
  /// [selectedKey] == [_kCustomKey]).
  final TextEditingController customController;

  /// Fired when the user picks a named preset. Provides the preset
  /// label; the caller maps it to its numeric value.
  final void Function(String key) onPresetSelected;

  /// Fired when the user picks 'Custom' from the dropdown.
  final VoidCallback onCustomSelected;

  /// Fired when the user submits the custom numeric text field.
  final void Function(String raw) onCustomSubmitted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final items = [
      ..._kAirChangePresets.entries.map(
        (e) => DropdownMenuItem<String>(
          value: e.key,
          child: Text(
            '${e.key} \u2014 ${e.value} h\u207B\u00B9',
            style: textTheme.bodyMedium,
          ),
        ),
      ),
      DropdownMenuItem<String>(
        value: _kCustomKey,
        child: Text('Custom', style: textTheme.bodyMedium),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Air Change Rate', style: textTheme.bodyMedium),
        const SizedBox(height: Spacing.xs),
        InputDecorator(
          decoration: const InputDecoration(isDense: true),
          child: DropdownButton<String>(
            value: selectedKey,
            isDense: true,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: items,
            onChanged: (key) {
              if (key == null) return;
              if (key == _kCustomKey) {
                onCustomSelected();
              } else {
                onPresetSelected(key);
              }
            },
          ),
        ),
        if (selectedKey == _kCustomKey) ...[
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: customController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Rate',
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
        Text(label, style: textTheme.bodyMedium),
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

/// Dropdown option combining display label, BoundaryCondition value,
/// and the default correction factor to pre-fill.
@immutable
class _BoundaryOption {
  const _BoundaryOption({
    required this.label,
    required this.condition,
    required this.presetFactor,
  });

  final String label;
  final BoundaryCondition condition;

  /// The factor pre-filled when this option is selected.
  /// Double.nan for conditions with a fixed, non-configurable factor.
  final double presetFactor;
}

const _kFloorOptions = <_BoundaryOption>[
  _BoundaryOption(
    label: 'Ground (slab on grade)',
    condition: BoundaryCondition.ground,
    presetFactor: groundCorrectionFactorDefault,
  ),
  _BoundaryOption(
    label: 'Unheated basement / garage',
    condition: BoundaryCondition.unheatedSpace,
    presetFactor: unheatedBasementCorrectionFactor,
  ),
  _BoundaryOption(
    label: 'Unheated crawlspace',
    condition: BoundaryCondition.unheatedSpace,
    presetFactor: unheatedCrawlspaceCorrectionFactor,
  ),
  _BoundaryOption(
    label: 'Adjacent heated room',
    condition: BoundaryCondition.interior,
    presetFactor: 0.0,
  ),
];

const _kCeilingOptions = <_BoundaryOption>[
  _BoundaryOption(
    label: 'Exterior / Roof',
    condition: BoundaryCondition.exterior,
    presetFactor: 1.0,
  ),
  _BoundaryOption(
    label: 'Unheated attic',
    condition: BoundaryCondition.unheatedSpace,
    presetFactor: unheatedAtticCorrectionFactor,
  ),
  _BoundaryOption(
    label: 'Unheated basement / garage',
    condition: BoundaryCondition.unheatedSpace,
    presetFactor: unheatedBasementCorrectionFactor,
  ),
  _BoundaryOption(
    label: 'Unheated crawlspace',
    condition: BoundaryCondition.unheatedSpace,
    presetFactor: unheatedCrawlspaceCorrectionFactor,
  ),
  _BoundaryOption(
    label: 'Adjacent heated room',
    condition: BoundaryCondition.interior,
    presetFactor: 0.0,
  ),
];

/// Returns the label from [options] matching [condition] and [factor].
///
/// For [BoundaryCondition.unheatedSpace], also matches the stored
/// factor against the option's preset (within 0.01 tolerance).
/// Falls back to the first matching condition label.
String _boundaryLabel(
  List<_BoundaryOption> options,
  BoundaryCondition condition,
  double? factor,
) {
  if (condition == BoundaryCondition.unheatedSpace) {
    for (final opt in options) {
      if (opt.condition != BoundaryCondition.unheatedSpace) {
        continue;
      }
      if (factor == null) return opt.label;
      if ((opt.presetFactor - factor).abs() < 0.01) return opt.label;
    }
  }
  return options
      .firstWhere(
        (o) => o.condition == condition,
        orElse: () => options.first,
      )
      .label;
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
  Room? _roomAtFloorSliderStart;
  Room? _roomAtCeilingSliderStart;

  void _updateRoom(Room updated) {
    ref.read(editorStateProvider.notifier).updateRoom(updated);
  }

  void _onFloorBoundaryChanged(String label) {
    final opt =
        _kFloorOptions.firstWhere((o) => o.label == label);
    final room = widget.room;
    _updateRoom(
      room.copyWith(
        floorBoundary: opt.condition,
        floorUnheatedCorrectionFactor:
            opt.condition == BoundaryCondition.unheatedSpace
                ? opt.presetFactor
                : null,
      ),
    );
  }

  void _onCeilingBoundaryChanged(String label) {
    final opt =
        _kCeilingOptions.firstWhere((o) => o.label == label);
    final room = widget.room;
    _updateRoom(
      room.copyWith(
        ceilingBoundary: opt.condition,
        ceilingUnheatedCorrectionFactor:
            opt.condition == BoundaryCondition.unheatedSpace
                ? opt.presetFactor
                : null,
      ),
    );
  }

  void _openFloorEditor() {
    final room = widget.room;
    showSlabConstructionEditor(
      context,
      constructionId: room.floorConstructionId,
      title: 'Floor construction',
      onSaved: (id) =>
          _updateRoom(room.copyWith(floorConstructionId: id)),
    );
  }

  void _openCeilingEditor() {
    final room = widget.room;
    showSlabConstructionEditor(
      context,
      constructionId: room.ceilingConstructionId,
      title: 'Roof / ceiling construction',
      onSaved: (id) =>
          _updateRoom(room.copyWith(ceilingConstructionId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final room = widget.room;
    final editorState = ref.watch(editorStateProvider);

    final floorLabel = _boundaryLabel(
      _kFloorOptions,
      room.floorBoundary,
      room.floorUnheatedCorrectionFactor,
    );
    final ceilingLabel = _boundaryLabel(
      _kCeilingOptions,
      room.ceilingBoundary,
      room.ceilingUnheatedCorrectionFactor,
    );

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
        'Envelope \u2014 Floor & Ceiling',
        style: textTheme.titleSmall,
      ),
      initiallyExpanded: false,
      childrenPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      children: [
        // ── Floor subsection ────────────────────────────────
        Text('Floor', style: textTheme.labelLarge),
        const SizedBox(height: Spacing.xs),
        _boundaryDropdown(
          label: 'What\'s below?',
          options: _kFloorOptions,
          selectedLabel: floorLabel,
          onChanged: _onFloorBoundaryChanged,
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xs),
        _constructionButton(
          context: context,
          construction: floorConstruction,
          uVal: floorUVal,
          onTap: _openFloorEditor,
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xs),
        _correctionFactorRow(
          context: context,
          condition: room.floorBoundary,
          factor: room.floorUnheatedCorrectionFactor,
          onChanged: (v) => _updateRoom(
            room.copyWith(floorUnheatedCorrectionFactor: v),
          ),
          onChangeStart: () {
            _roomAtFloorSliderStart = room;
          },
          onChangeEnd: (v) {
            final start = _roomAtFloorSliderStart;
            _roomAtFloorSliderStart = null;
            if (start != null &&
                start.floorUnheatedCorrectionFactor != v) {
              ref.read(undoRedoProvider).execute(
                    _UpdateRoomCommand(
                      oldRoom: start,
                      newRoom: start.copyWith(
                        floorUnheatedCorrectionFactor: v,
                      ),
                      update: ref
                          .read(editorStateProvider.notifier)
                          .updateRoom,
                    ),
                  );
            }
          },
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.sm),
        const Divider(height: Spacing.sm),

        // ── Ceiling subsection ──────────────────────────────
        Text('Ceiling', style: textTheme.labelLarge),
        const SizedBox(height: Spacing.xs),
        _boundaryDropdown(
          label: 'What\'s above?',
          options: _kCeilingOptions,
          selectedLabel: ceilingLabel,
          onChanged: _onCeilingBoundaryChanged,
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xs),
        _constructionButton(
          context: context,
          construction: ceilConstruction,
          uVal: ceilUVal,
          onTap: _openCeilingEditor,
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xs),
        _correctionFactorRow(
          context: context,
          condition: room.ceilingBoundary,
          factor: room.ceilingUnheatedCorrectionFactor,
          onChanged: (v) => _updateRoom(
            room.copyWith(ceilingUnheatedCorrectionFactor: v),
          ),
          onChangeStart: () {
            _roomAtCeilingSliderStart = room;
          },
          onChangeEnd: (v) {
            final start = _roomAtCeilingSliderStart;
            _roomAtCeilingSliderStart = null;
            if (start != null &&
                start.ceilingUnheatedCorrectionFactor != v) {
              ref.read(undoRedoProvider).execute(
                    _UpdateRoomCommand(
                      oldRoom: start,
                      newRoom: start.copyWith(
                        ceilingUnheatedCorrectionFactor: v,
                      ),
                      update: ref
                          .read(editorStateProvider.notifier)
                          .updateRoom,
                    ),
                  );
            }
          },
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xs),
      ],
    );
  }

  Widget _boundaryDropdown({
    required String label,
    required List<_BoundaryOption> options,
    required String selectedLabel,
    required void Function(String) onChanged,
    required TextTheme textTheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodyMedium),
        const SizedBox(height: Spacing.xs),
        InputDecorator(
          decoration: const InputDecoration(isDense: true),
          child: DropdownButton<String>(
            value: selectedLabel,
            isDense: true,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: options
                .map(
                  (o) => DropdownMenuItem<String>(
                    value: o.label,
                    child: Text(
                      o.label,
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
    required WallConstruction? construction,
    required double uVal,
    required VoidCallback onTap,
    required TextTheme textTheme,
  }) {
    final label = construction == null
        ? 'Not assigned'
        : uVal.isNaN
            ? construction.name
            : '${construction.name} \u2014 '
                'U ${uVal.toStringAsFixed(2)}'
                ' W/(m\u00B2\u00B7K)';
    final actionLabel =
        construction == null ? '+ Assign' : 'Edit';

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

  Widget _correctionFactorRow({
    required BuildContext context,
    required BoundaryCondition condition,
    required double? factor,
    required void Function(double) onChanged,
    required VoidCallback onChangeStart,
    required void Function(double) onChangeEnd,
    required TextTheme textTheme,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (condition != BoundaryCondition.unheatedSpace) {
      final fixedValue =
          condition == BoundaryCondition.exterior
              ? 1.0
              : condition == BoundaryCondition.ground
                  ? groundCorrectionFactorDefault
                  : 0.0;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Correction f.', style: textTheme.bodyMedium),
          Text(
            fixedValue.toStringAsFixed(2),
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final current =
        factor ?? unheatedBasementCorrectionFactor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Correction f.',
              style: textTheme.bodyMedium,
            ),
            Text(
              current.toStringAsFixed(2),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: Slider(
            value: current,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChangeStart: (_) => onChangeStart(),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
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
