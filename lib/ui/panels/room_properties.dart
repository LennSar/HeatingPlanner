import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/geometry_engine.dart';
import '../../core/theme/app_theme.dart';
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
              if (value.isNotEmpty) {
                ref
                    .read(editorStateProvider.notifier)
                    .updateRoom(room.copyWith(name: value));
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
            onChanged: (value) {
              ref
                  .read(editorStateProvider.notifier)
                  .updateRoom(
                    room.copyWith(targetTempC: value),
                  );
            },
          ),
          const Divider(height: Spacing.lg),

          // Read-only info.
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
        ],
      ),
    );
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
