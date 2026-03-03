import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/door.dart';
import '../../data/models/window_element.dart';
import '../canvas/tools/undo_redo_service.dart';
import '../providers/editor_state_provider.dart';
import '../providers/selection_provider.dart';

// ================================================================
// WindowProperties
// ================================================================

/// Editable properties panel for a selected window element.
///
/// Allows editing width, height, sill height, and U-value.
/// A type toggle converts the element to a door.
class WindowProperties extends ConsumerStatefulWidget {
  /// Creates [WindowProperties] for [windowId].
  const WindowProperties({required this.windowId, super.key});

  /// The ID of the window to display/edit.
  final String windowId;

  @override
  ConsumerState<WindowProperties> createState() =>
      _WindowPropertiesState();
}

class _WindowPropertiesState
    extends ConsumerState<WindowProperties> {
  late TextEditingController _widthCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _sillCtrl;
  late TextEditingController _uValueCtrl;

  /// ID tracked to reset controllers on element change.
  String? _lastWindowId;

  @override
  void initState() {
    super.initState();
    _widthCtrl = TextEditingController();
    _heightCtrl = TextEditingController();
    _sillCtrl = TextEditingController();
    _uValueCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _sillCtrl.dispose();
    _uValueCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(WindowElement w) {
    if (_lastWindowId == widget.windowId) return;
    _lastWindowId = widget.windowId;
    _widthCtrl.text = w.widthMm.toString();
    _heightCtrl.text = w.heightMm.toString();
    _sillCtrl.text = w.sillHeightMm.toString();
    _uValueCtrl.text = w.uValue.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context, ) {
    final textTheme = Theme.of(context).textTheme;
    final editorState = ref.watch(editorStateProvider);
    final window = editorState.windows
        .where((w) => w.id == widget.windowId)
        .firstOrNull;

    if (window == null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text('Window not found', style: textTheme.bodyMedium),
      );
    }

    _syncControllers(window);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Properties', style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),

          // Type toggle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type', style: textTheme.bodyMedium),
              const SizedBox(height: Spacing.xs),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Window'),
                      ),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Door'),
                      ),
                    ),
                  ],
                  selected: const {true},
                  onSelectionChanged: (sel) =>
                      _convertToDoor(window),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          const Divider(),
          const SizedBox(height: Spacing.sm),

          Text('Window', style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),

          _NumericField(
            label: 'Width',
            unit: 'mm',
            controller: _widthCtrl,
            onSubmit: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null &&
                  parsed >= 300 &&
                  parsed <= 5000 &&
                  parsed != window.widthMm) {
                _updateWindow(
                    window, window.copyWith(widthMm: parsed));
              } else {
                _widthCtrl.text = window.widthMm.toString();
              }
            },
          ),
          _NumericField(
            label: 'Height',
            unit: 'mm',
            controller: _heightCtrl,
            onSubmit: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null &&
                  parsed >= 300 &&
                  parsed <= 3000 &&
                  parsed != window.heightMm) {
                _updateWindow(
                    window, window.copyWith(heightMm: parsed));
              } else {
                _heightCtrl.text = window.heightMm.toString();
              }
            },
          ),
          _NumericField(
            label: 'Sill Height',
            unit: 'mm',
            controller: _sillCtrl,
            onSubmit: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null &&
                  parsed >= 0 &&
                  parsed <= 2500 &&
                  parsed != window.sillHeightMm) {
                _updateWindow(window,
                    window.copyWith(sillHeightMm: parsed));
              } else {
                _sillCtrl.text =
                    window.sillHeightMm.toString();
              }
            },
          ),
          _NumericField(
            label: 'U-Value',
            unit: 'W/(m²K)',
            controller: _uValueCtrl,
            isDecimal: true,
            onSubmit: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null &&
                  parsed >= 0.5 &&
                  parsed <= 6.0 &&
                  parsed != window.uValue) {
                _updateWindow(
                    window, window.copyWith(uValue: parsed));
              } else {
                _uValueCtrl.text =
                    window.uValue.toStringAsFixed(2);
              }
            },
          ),
        ],
      ),
    );
  }

  void _updateWindow(
    WindowElement oldWindow,
    WindowElement newWindow,
  ) {
    final notifier =
        ref.read(editorStateProvider.notifier);
    ref.read(undoRedoProvider).execute(
          _UpdateOpeningCommand<WindowElement>(
            oldValue: oldWindow,
            newValue: newWindow,
            update: notifier.updateWindow,
            label: 'Update window',
          ),
        );
  }

  void _convertToDoor(WindowElement window) {
    final newDoor = Door(
      id: IdGenerator.newId(),
      wallSegmentId: window.wallSegmentId,
      positionOnWallMm: window.positionOnWallMm,
      widthMm: window.widthMm,
      heightMm: window.heightMm,
      sillHeightMm: window.sillHeightMm,
      uValue: window.uValue,
    );
    final notifier = ref.read(editorStateProvider.notifier);
    final selNotifier =
        ref.read(selectedElementProvider.notifier);
    ref.read(undoRedoProvider).execute(
          _ConvertWindowToDoorCommand(
            window: window,
            door: newDoor,
            notifier: notifier,
            selectionNotifier: selNotifier,
          ),
        );
  }
}

// ================================================================
// DoorProperties
// ================================================================

/// Editable properties panel for a selected door element.
///
/// Allows editing width, height, sill height, and U-value.
/// A type toggle converts the element to a window.
class DoorProperties extends ConsumerStatefulWidget {
  /// Creates [DoorProperties] for [doorId].
  const DoorProperties({required this.doorId, super.key});

  /// The ID of the door to display/edit.
  final String doorId;

  @override
  ConsumerState<DoorProperties> createState() =>
      _DoorPropertiesState();
}

class _DoorPropertiesState
    extends ConsumerState<DoorProperties> {
  late TextEditingController _widthCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _sillCtrl;
  late TextEditingController _uValueCtrl;

  String? _lastDoorId;

  @override
  void initState() {
    super.initState();
    _widthCtrl = TextEditingController();
    _heightCtrl = TextEditingController();
    _sillCtrl = TextEditingController();
    _uValueCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _sillCtrl.dispose();
    _uValueCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(Door d) {
    if (_lastDoorId == widget.doorId) return;
    _lastDoorId = widget.doorId;
    _widthCtrl.text = d.widthMm.toString();
    _heightCtrl.text = d.heightMm.toString();
    _sillCtrl.text = d.sillHeightMm.toString();
    _uValueCtrl.text = d.uValue.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final editorState = ref.watch(editorStateProvider);
    final door = editorState.doors
        .where((d) => d.id == widget.doorId)
        .firstOrNull;

    if (door == null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text('Door not found', style: textTheme.bodyMedium),
      );
    }

    _syncControllers(door);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Properties', style: textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),

          // Type toggle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type', style: textTheme.bodyMedium),
              const SizedBox(height: Spacing.xs),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Window'),
                      ),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Door'),
                      ),
                    ),
                  ],
                  selected: const {false},
                  onSelectionChanged: (sel) =>
                      _convertToWindow(door),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          const Divider(),
          const SizedBox(height: Spacing.sm),

          Text('Door', style: textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),

          _NumericField(
            label: 'Width',
            unit: 'mm',
            controller: _widthCtrl,
            onSubmit: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null &&
                  parsed >= 300 &&
                  parsed <= 5000 &&
                  parsed != door.widthMm) {
                _updateDoor(door, door.copyWith(widthMm: parsed));
              } else {
                _widthCtrl.text = door.widthMm.toString();
              }
            },
          ),
          _NumericField(
            label: 'Height',
            unit: 'mm',
            controller: _heightCtrl,
            onSubmit: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null &&
                  parsed >= 300 &&
                  parsed <= 3000 &&
                  parsed != door.heightMm) {
                _updateDoor(
                    door, door.copyWith(heightMm: parsed));
              } else {
                _heightCtrl.text = door.heightMm.toString();
              }
            },
          ),
          _NumericField(
            label: 'Sill Height',
            unit: 'mm',
            controller: _sillCtrl,
            onSubmit: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null &&
                  parsed >= 0 &&
                  parsed <= 2500 &&
                  parsed != door.sillHeightMm) {
                _updateDoor(
                    door, door.copyWith(sillHeightMm: parsed));
              } else {
                _sillCtrl.text =
                    door.sillHeightMm.toString();
              }
            },
          ),
          _NumericField(
            label: 'U-Value',
            unit: 'W/(m²K)',
            controller: _uValueCtrl,
            isDecimal: true,
            onSubmit: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null &&
                  parsed >= 0.5 &&
                  parsed <= 6.0 &&
                  parsed != door.uValue) {
                _updateDoor(
                    door, door.copyWith(uValue: parsed));
              } else {
                _uValueCtrl.text =
                    door.uValue.toStringAsFixed(2);
              }
            },
          ),
        ],
      ),
    );
  }

  void _updateDoor(Door oldDoor, Door newDoor) {
    final notifier = ref.read(editorStateProvider.notifier);
    ref.read(undoRedoProvider).execute(
          _UpdateOpeningCommand<Door>(
            oldValue: oldDoor,
            newValue: newDoor,
            update: notifier.updateDoor,
            label: 'Update door',
          ),
        );
  }

  void _convertToWindow(Door door) {
    final newWindow = WindowElement(
      id: IdGenerator.newId(),
      wallSegmentId: door.wallSegmentId,
      positionOnWallMm: door.positionOnWallMm,
      widthMm: door.widthMm,
      heightMm: door.heightMm,
      sillHeightMm: door.sillHeightMm,
      uValue: door.uValue,
    );
    final notifier = ref.read(editorStateProvider.notifier);
    final selNotifier =
        ref.read(selectedElementProvider.notifier);
    ref.read(undoRedoProvider).execute(
          _ConvertDoorToWindowCommand(
            door: door,
            window: newWindow,
            notifier: notifier,
            selectionNotifier: selNotifier,
          ),
        );
  }
}

// ================================================================
// Shared numeric input widget
// ================================================================

/// A labelled text field for numeric property input.
class _NumericField extends StatelessWidget {
  const _NumericField({
    required this.label,
    required this.unit,
    required this.controller,
    required this.onSubmit,
    this.isDecimal = false,
  });

  final String label;
  final String unit;
  final TextEditingController controller;
  final void Function(String) onSubmit;
  final bool isDecimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.end,
              keyboardType: isDecimal
                  ? const TextInputType.numberWithOptions(
                      decimal: true)
                  : TextInputType.number,
              inputFormatters: [
                if (isDecimal)
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[\d.]'),
                  )
                else
                  FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                suffixText: unit,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: Spacing.xs,
                ),
              ),
              onSubmitted: onSubmit,
              // Also commit on focus loss.
              onTapOutside: (_) => onSubmit(controller.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// Command classes
// ================================================================

/// Generic command for updating a window or door property.
class _UpdateOpeningCommand<T> extends Command {
  _UpdateOpeningCommand({
    required this.oldValue,
    required this.newValue,
    required this.update,
    required this.label,
  });

  final T oldValue;
  final T newValue;
  final void Function(T) update;

  @override
  final String label;

  @override
  void execute() => update(newValue);

  @override
  void undo() => update(oldValue);
}

/// Command: convert a window to a door.
class _ConvertWindowToDoorCommand extends Command {
  _ConvertWindowToDoorCommand({
    required this.window,
    required this.door,
    required this.notifier,
    required this.selectionNotifier,
  });

  final WindowElement window;
  final Door door;
  final EditorStateNotifier notifier;
  final SelectedElementNotifier selectionNotifier;

  @override
  String get label => 'Convert window to door';

  @override
  void execute() {
    notifier.removeWindow(window.id);
    notifier.addDoor(door);
    selectionNotifier
        .select(SelectedElement(type: 'door', id: door.id));
  }

  @override
  void undo() {
    notifier.removeDoor(door.id);
    notifier.addWindow(window);
    selectionNotifier.select(
        SelectedElement(type: 'window', id: window.id));
  }
}

/// Command: convert a door to a window.
class _ConvertDoorToWindowCommand extends Command {
  _ConvertDoorToWindowCommand({
    required this.door,
    required this.window,
    required this.notifier,
    required this.selectionNotifier,
  });

  final Door door;
  final WindowElement window;
  final EditorStateNotifier notifier;
  final SelectedElementNotifier selectionNotifier;

  @override
  String get label => 'Convert door to window';

  @override
  void execute() {
    notifier.removeDoor(door.id);
    notifier.addWindow(window);
    selectionNotifier.select(
        SelectedElement(type: 'window', id: window.id));
  }

  @override
  void undo() {
    notifier.removeWindow(window.id);
    notifier.addDoor(door);
    selectionNotifier
        .select(SelectedElement(type: 'door', id: door.id));
  }
}
