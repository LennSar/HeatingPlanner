import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/thermal_engine.dart';
import '../../calculation/providers/heat_demand_providers.dart';
import '../../calculation/providers/project_settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/room.dart';
import '../canvas/tools/undo_redo_service.dart';
import '../providers/editor_state_provider.dart';

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

    return Padding(
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

    // Specific heat demand: use provider total if available,
    // fall back to inline total.
    final inlineTotal =
        (hasAnyConstruction ? qTransmission : 0.0) +
            (qVent.isNaN ? 0.0 : qVent);
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
