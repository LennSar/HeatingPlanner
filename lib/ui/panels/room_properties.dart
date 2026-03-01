import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../calculation/engines/thermal_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/room.dart';
import '../canvas/tools/undo_redo_service.dart';
import '../providers/editor_state_provider.dart';

/// Editable properties panel for a selected room.
///
/// Shows room name (editable), target temperature slider,
/// and computed area.
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
  String? _lastRoomId;

  /// Snapshot of the room taken when the temperature slider
  /// drag starts — used to build the undo command on drag end.
  Room? _roomAtSliderStart;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncController(String name) {
    if (_lastRoomId != widget.roomId ||
        _nameController.text != name) {
      _lastRoomId = widget.roomId;
      _nameController.text = name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final editorState = ref.watch(editorStateProvider);
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

    final areaM2 = room.polygon.length >= 3
        ? GeometryEngine.polygonAreaM2(room.polygon)
        : 0.0;

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
              // Capture the room state before the drag begins.
              _roomAtSliderStart = room;
            },
            onChanged: (value) {
              // Live preview — update state directly without
              // pushing a command (intermediate positions are
              // not individually undoable).
              ref
                  .read(editorStateProvider.notifier)
                  .updateRoom(
                    room.copyWith(targetTempC: value),
                  );
            },
            onChangeEnd: (value) {
              // Push one undo command for the whole drag.
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
          const Divider(height: Spacing.lg),

          // Read-only geometry.
          _readOnlyRow(
            'Area',
            '${areaM2.toStringAsFixed(2)} m\u00B2',
            textTheme,
          ),
          _readOnlyRow(
            'Walls',
            '$wallCount',
            textTheme,
          ),
          _readOnlyRow(
            'Air Change Rate',
            '${room.airChangeRate} h\u207B\u00B9',
            textTheme,
          ),
          const Divider(height: Spacing.lg),

          // Heat demand breakdown.
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
            textTheme,
          ),
        ],
      ),
    );
  }

  /// Computes and returns heat demand display rows.
  ///
  /// Uses default design outdoor temperature -12°C and
  /// ceiling height 2600 mm per EN 12831 reference case.
  List<Widget> _heatDemandRows(
    BuildContext context,
    WidgetRef ref,
    dynamic room,
    double areaM2,
    TextTheme textTheme,
  ) {
    const tOutdoor = -12.0;
    const ceilingHeightMm = 2600.0;
    final tIndoor = (room.targetTempC as double);

    final editorState = ref.read(editorStateProvider);
    final roomWalls = editorState.walls
        .where((w) => w.roomId == room.id)
        .toList();

    // Sum transmission losses across all walls that have
    // a construction assigned.
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

      final wallLengthMm = GeometryEngine.distanceMm(
        wall.startPoint,
        wall.endPoint,
      );
      final areaM2Wall =
          wallLengthMm * ceilingHeightMm / 1e6;

      // Correction factor: 1.0 for exterior walls,
      // interior correction for walls shared with another room.
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

      final loss = ThermalEngine.transmissionLoss(
        uValue: u,
        areaM2: areaM2Wall,
        correctionF: corrF,
        tIndoorC: tIndoor,
        tOutdoorC: tOutdoor,
      );
      if (!loss.isNaN) {
        qTransmission += loss;
        hasAnyConstruction = true;
      }
    }

    // Ventilation loss.
    final volumeM3 = ThermalEngine.roomVolumeM3(
      floorAreaM2: areaM2,
      ceilingHeightMm: ceilingHeightMm,
    );
    final qVent = ThermalEngine.ventilationLoss(
      roomVolumeM3: volumeM3,
      airChangeRate: room.airChangeRate as double,
      tIndoorC: tIndoor,
      tOutdoorC: tOutdoor,
    );

    final qTotal = (hasAnyConstruction ? qTransmission : 0.0) +
        (qVent.isNaN ? 0.0 : qVent);

    final colorScheme = Theme.of(context).colorScheme;

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
      Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Q',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${qTotal.round()} W',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

Widget _readOnlyRow(
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

// ================================================================
// Command classes
// ================================================================

/// Command: update a room property (name, temperature, etc.).
///
/// [update] is the notifier method — captured once so the
/// command does not need to hold a [WidgetRef].
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
