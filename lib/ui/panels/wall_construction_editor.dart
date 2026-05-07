import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/thermal_engine.dart';
import '../../calculation/providers/project_settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/material_layer.dart';
import '../../data/models/wall_construction.dart';
import '../../data/models/wall_segment.dart';
import '../providers/editor_state_provider.dart';
import '../../data/models/material_entry.dart';
import '../../repositories/material_repository.dart';
import '../widgets/material_picker.dart';

// ---------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------

/// Opens the wall construction editor as a modal dialog.
///
/// If [wall] already has a [WallSegment.constructionId] the
/// existing [WallConstruction] and its layers are loaded for
/// editing. Changes are only committed to [editorStateProvider]
/// when "Save" is pressed.
Future<void> showWallConstructionEditor(
  BuildContext context,
  WallSegment wall,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WallConstructionDialog(wall: wall),
  );
}

/// Opens the construction editor for a floor or ceiling slab.
///
/// [constructionId] is the existing construction to load, or null
/// to create a new one. [title] is displayed in the dialog header.
/// [onSaved] is called with the construction ID after the user saves.
Future<void> showSlabConstructionEditor(
  BuildContext context, {
  String? constructionId,
  required String title,
  required void Function(String constructionId) onSaved,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SlabConstructionDialog(
      constructionId: constructionId,
      title: title,
      onSaved: onSaved,
    ),
  );
}

// ---------------------------------------------------------------
// Slab construction dialog (floor / ceiling variant)
// ---------------------------------------------------------------

class _SlabConstructionDialog extends ConsumerStatefulWidget {
  const _SlabConstructionDialog({
    required this.constructionId,
    required this.title,
    required this.onSaved,
  });

  final String? constructionId;
  final String title;
  final void Function(String constructionId) onSaved;

  @override
  ConsumerState<_SlabConstructionDialog> createState() =>
      _SlabConstructionDialogState();
}

class _SlabConstructionDialogState
    extends ConsumerState<_SlabConstructionDialog> {
  late WallConstruction _construction;
  late List<MaterialLayer> _layers;
  late TextEditingController _nameCtrl;
  late TextEditingController _nameDeCtrl;
  late TextEditingController _rsiCtrl;
  late TextEditingController _rseCtrl;

  @override
  void initState() {
    super.initState();
    _loadFromState();
  }

  void _loadFromState() {
    final state = ref.read(editorStateProvider);
    final cid = widget.constructionId;

    if (cid != null) {
      final existing =
          state.constructions.where((c) => c.id == cid).firstOrNull;
      if (existing != null) {
        _construction = existing;
        _layers = state.materialLayers
            .where((l) => l.constructionId == cid)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _nameCtrl =
            TextEditingController(text: _construction.name);
        _nameDeCtrl = TextEditingController(
          text: _construction.nameDe ?? '',
        );
        _rsiCtrl = TextEditingController(
          text: _construction.rsi.toStringAsFixed(2),
        );
        _rseCtrl = TextEditingController(
          text: _construction.rse.toStringAsFixed(2),
        );
        return;
      }
    }

    _construction = WallConstruction(
      id: IdGenerator.newId(),
      name: widget.title,
    );
    _layers = [];
    _nameCtrl = TextEditingController(text: widget.title);
    _nameDeCtrl = TextEditingController();
    _rsiCtrl = TextEditingController(text: '0.13');
    _rseCtrl = TextEditingController(text: '0.04');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameDeCtrl.dispose();
    _rsiCtrl.dispose();
    _rseCtrl.dispose();
    super.dispose();
  }

  double get _rsi =>
      double.tryParse(_rsiCtrl.text) ?? _construction.rsi;
  double get _rse =>
      double.tryParse(_rseCtrl.text) ?? _construction.rse;
  List<double> get _thicknesses =>
      _layers.map((l) => l.thicknessMm).toList();
  List<double> get _lambdas =>
      _layers.map((l) => l.thermalConductivity).toList();

  List<LayerSpec> get _layerSpecs => _layers.map((l) {
        if (l.studWidthMm != null &&
            l.studClearGapMm != null &&
            l.studLambda != null) {
          return InhomogeneousLayerSpec(
            thicknessMm: l.thicknessMm,
            lambdaMain: l.thermalConductivity,
            studWidthMm: l.studWidthMm!,
            studClearGapMm: l.studClearGapMm!,
            lambdaStud: l.studLambda!,
          );
        }
        return HomogeneousLayerSpec(
          thicknessMm: l.thicknessMm,
          lambda: l.thermalConductivity,
        );
      }).toList();

  double get _uVal => ThermalEngine.uValueCombined(
        layers: _layerSpecs,
        rsi: _rsi,
        rse: _rse,
      );

  double get _rTotal => ThermalEngine.totalResistance(
        layerThicknessesMm: _thicknesses,
        layerLambdas: _lambdas,
        rsi: _rsi,
        rse: _rse,
      );

  List<double> _tempProfile(double tIndoorC, double tOutdoorC) =>
      ThermalEngine.temperatureProfile(
        layerThicknessesMm: _thicknesses,
        layerLambdas: _lambdas,
        rsi: _rsi,
        rse: _rse,
        tIndoorC: tIndoorC,
        tOutdoorC: tOutdoorC,
      );

  void _addLayer() {
    final entries =
        ref.read(materialEntriesProvider).asData?.value ?? [];
    final mat = entries.firstOrNull;
    if (mat == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noMaterialsAvailable)),
      );
      return;
    }
    setState(() {
      _layers = [
        ..._layers,
        MaterialLayer(
          id: IdGenerator.newId(),
          constructionId: _construction.id,
          sortOrder: _layers.length,
          materialId: mat.id,
          thicknessMm: 100.0,
          thermalConductivity: mat.lambdaDefault,
          density: mat.densityDefault,
          specificHeat: mat.specificHeatDefault,
        ),
      ];
    });
  }

  void _removeLayer(int index) {
    setState(() {
      final list = List<MaterialLayer>.from(_layers)
        ..removeAt(index);
      _layers = list
          .asMap()
          .entries
          .map((e) => e.value.copyWith(sortOrder: e.key))
          .toList();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final list = List<MaterialLayer>.from(_layers);
      list.insert(newIndex, list.removeAt(oldIndex));
      _layers = list
          .asMap()
          .entries
          .map((e) => e.value.copyWith(sortOrder: e.key))
          .toList();
    });
  }

  void _updateLayer(int index, MaterialLayer updated) {
    setState(() {
      final list = List<MaterialLayer>.from(_layers);
      list[index] = updated.copyWith(sortOrder: index);
      _layers = list;
    });
  }

  Future<void> _pickMaterial(int index) async {
    final mat = await _showMaterialPickerDialog(context);
    if (mat == null || !mounted) return;
    _updateLayer(
      index,
      _layers[index].copyWith(
        materialId: mat.id,
        thermalConductivity: mat.lambdaDefault,
        density: mat.densityDefault,
        specificHeat: mat.specificHeatDefault,
      ),
    );
  }

  Future<void> _saveAsPreset() async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl =
        TextEditingController(text: _nameCtrl.text.trim());
    final nameDeCtrl =
        TextEditingController(text: _nameDeCtrl.text.trim());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveAsPreset),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.presetName,
              ),
              autofocus: true,
            ),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: nameDeCtrl,
              decoration: InputDecoration(
                labelText: l10n.presetNameDe,
                helperText: l10n.presetNameDeHelp,
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    final presetName = nameCtrl.text.trim();
    final presetNameDeRaw = nameDeCtrl.text.trim();
    final presetNameDe = presetNameDeRaw.isEmpty ? null : presetNameDeRaw;
    nameCtrl.dispose();
    nameDeCtrl.dispose();
    if (confirmed != true || !mounted) return;
    if (presetName.isEmpty) return;

    final notifier = ref.read(editorStateProvider.notifier);
    final editorState = ref.read(editorStateProvider);
    final isNew = !editorState.constructions
        .any((c) => c.id == _construction.id);
    final rsi = double.tryParse(_rsiCtrl.text) ?? 0.13;
    final rse = double.tryParse(_rseCtrl.text) ?? 0.04;
    final editorNameDeRaw = _nameDeCtrl.text.trim();
    final current = _construction.copyWith(
      name: _nameCtrl.text.trim(),
      nameDe: editorNameDeRaw.isEmpty ? null : editorNameDeRaw,
      rsi: rsi,
      rse: rse,
    );
    if (isNew) {
      notifier.addConstruction(current);
    } else {
      notifier.updateConstruction(current);
    }
    notifier.replaceLayersForConstruction(
        current.id, _layers);

    notifier.saveConstructionAsPreset(
      _construction.id,
      presetName,
      presetNameDe: presetNameDe,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.savedAsPreset)),
    );
  }

  Future<void> _loadPreset() async {
    final l10n = AppLocalizations.of(context)!;
    final presets = ref
        .read(editorStateProvider)
        .constructions
        .where((c) => c.isPreset)
        .toList();
    if (presets.isEmpty) return;

    final localizedById = {
      for (final lr in ref.read(localizedWallConstructionsProvider))
        lr.row.id: lr.displayName,
    };

    final selected = await showDialog<WallConstruction>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.loadPreset),
        children: presets.map((p) {
          final layers = ref
              .read(editorStateProvider)
              .materialLayers
              .where((l) => l.constructionId == p.id)
              .toList();
          final specs = layers.map((l) {
            if (l.studWidthMm != null &&
                l.studClearGapMm != null &&
                l.studLambda != null) {
              return InhomogeneousLayerSpec(
                thicknessMm: l.thicknessMm,
                lambdaMain: l.thermalConductivity,
                studWidthMm: l.studWidthMm!,
                studClearGapMm: l.studClearGapMm!,
                lambdaStud: l.studLambda!,
              );
            }
            return HomogeneousLayerSpec(
              thicknessMm: l.thicknessMm,
              lambda: l.thermalConductivity,
            );
          }).toList();
          final u = ThermalEngine.uValueCombined(
            layers: specs,
            rsi: p.rsi,
            rse: p.rse,
          );
          final uLabel = u.isNaN
              ? '—'
              : '${u.toStringAsFixed(3)} W/(m²K)';
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(p),
            child: ListTile(
              title: Text(localizedById[p.id] ?? p.name),
              subtitle: Text(l10n.presetUValueLine(uLabel)),
              dense: true,
            ),
          );
        }).toList(),
      ),
    );
    if (selected == null || !mounted) return;

    final srcLayers = ref
        .read(editorStateProvider)
        .materialLayers
        .where((l) => l.constructionId == selected.id)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final newId = _construction.id;
    setState(() {
      _construction = selected.copyWith(
        id: newId,
        isPreset: false,
      );
      _layers = srcLayers
          .asMap()
          .entries
          .map(
            (e) => e.value.copyWith(
              id: IdGenerator.newId(),
              constructionId: newId,
              sortOrder: e.key,
            ),
          )
          .toList();
      _nameCtrl.text = selected.name;
      _nameDeCtrl.text = selected.nameDe ?? '';
      _rsiCtrl.text = selected.rsi.toStringAsFixed(2);
      _rseCtrl.text = selected.rse.toStringAsFixed(2);
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final nameDeRaw = _nameDeCtrl.text.trim();
    final nameDe = nameDeRaw.isEmpty ? null : nameDeRaw;
    final rsi = double.tryParse(_rsiCtrl.text) ?? 0.13;
    final rse = double.tryParse(_rseCtrl.text) ?? 0.04;
    final updated = _construction.copyWith(
      name: name,
      nameDe: nameDe,
      rsi: rsi,
      rse: rse,
    );
    final notifier = ref.read(editorStateProvider.notifier);
    final state = ref.read(editorStateProvider);
    final isNew =
        !state.constructions.any((c) => c.id == updated.id);
    if (isNew) {
      notifier.addConstruction(updated);
    } else {
      notifier.updateConstruction(updated);
    }
    notifier.replaceLayersForConstruction(updated.id, _layers);
    widget.onSaved(updated.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(projectSettingsProvider);
    final materials = ref.watch(localizedMaterialEntriesProvider);
    final tOutdoorC = settings.designOutdoorTempC;
    final tIndoorC = settings.defaultIndoorTempC;
    final uVal = _uVal;
    final rTotal = _rTotal;
    final profile = _tempProfile(tIndoorC, tOutdoorC);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 660,
          maxHeight: 700,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Title row ----
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  FilledButton(
                    onPressed: _save,
                    child: Text(l10n.save),
                  ),
                  const SizedBox(width: Spacing.sm),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              // ---- Preset row ----
              _PresetRow(
                onSaveAsPreset: _saveAsPreset,
                onLoadPreset: _loadPreset,
                hasPresets: ref
                    .watch(editorStateProvider)
                    .constructions
                    .any((c) => c.isPreset),
              ),
              const SizedBox(height: Spacing.sm),

              // ---- Name field ----
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.constructionName,
                  isDense: true,
                ),
                style: textTheme.bodyLarge,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.xs),

              // ---- German name field (optional) ----
              TextField(
                controller: _nameDeCtrl,
                decoration: InputDecoration(
                  labelText: l10n.constructionNameDe,
                  helperText: l10n.constructionNameDeHelp,
                  helperMaxLines: 2,
                  isDense: true,
                ),
                style: textTheme.bodyLarge,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.sm),

              // ---- U-value summary ----
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      uVal.isNaN
                          ? l10n.uValueEmpty
                          : l10n.uValueDisplay(uVal.toStringAsFixed(3)),
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      rTotal.isNaN
                          ? l10n.rValueEmpty
                          : l10n.rValueDisplay(rTotal.toStringAsFixed(3)),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.sm),

              // ---- Layer stack ----
              Text(
                l10n.layerStack,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.xs),
              Flexible(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: _layers.length,
                  onReorder: _onReorder,
                  footer: Padding(
                    padding: const EdgeInsets.only(
                      top: Spacing.xs,
                    ),
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addLayer),
                      onPressed: _addLayer,
                    ),
                  ),
                  itemBuilder: (context, i) {
                    final layer = _layers[i];
                    final mat = materials
                        .where((m) => m.row.id == layer.materialId)
                        .firstOrNull;
                    return _LayerRow(
                      key: ValueKey(layer.id),
                      index: i,
                      layer: layer,
                      materialName: mat?.displayName ?? layer.materialId,
                      onPickMaterial: () => _pickMaterial(i),
                      onThicknessChanged: (v) => _updateLayer(
                        i,
                        layer.copyWith(thicknessMm: v),
                      ),
                      onLambdaChanged: (v) => _updateLayer(
                        i,
                        layer.copyWith(thermalConductivity: v),
                      ),
                      onStudChanged: (updated) => _updateLayer(i, updated),
                      onDelete: () => _removeLayer(i),
                    );
                  },
                ),
              ),

              const Divider(height: Spacing.md),

              // ---- Temperature profile ----
              if (profile.length >= 2) ...[
                Text(
                  l10n.temperatureProfileWithRange(
                    tIndoorC.toStringAsFixed(1),
                    tOutdoorC.toStringAsFixed(1),
                  ),
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: Spacing.xs),
                SizedBox(
                  height: 48,
                  child: CustomPaint(
                    painter: _TempProfilePainter(
                      profile: profile,
                      textColor: colorScheme.onSurface,
                    ),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
              ],

              // ---- Surface resistances ----
              Row(
                children: [
                  Text(
                    l10n.surfaceResistances,
                    style: textTheme.bodySmall,
                  ),
                  const Spacer(),
                  _ResistanceField(
                    label: 'Rsi',
                    controller: _rsiCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(width: Spacing.md),
                  _ResistanceField(
                    label: 'Rse',
                    controller: _rseCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Dialog widget
// ---------------------------------------------------------------

class _WallConstructionDialog extends ConsumerStatefulWidget {
  const _WallConstructionDialog({required this.wall});

  final WallSegment wall;

  @override
  ConsumerState<_WallConstructionDialog> createState() =>
      _WallConstructionDialogState();
}

class _WallConstructionDialogState
    extends ConsumerState<_WallConstructionDialog> {
  late WallConstruction _construction;
  late List<MaterialLayer> _layers;
  late TextEditingController _nameCtrl;
  late TextEditingController _nameDeCtrl;
  late TextEditingController _rsiCtrl;
  late TextEditingController _rseCtrl;
  bool _isNewConstruction = false;
  bool _defaultNameApplied = false;

  @override
  void initState() {
    super.initState();
    _loadFromState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isNewConstruction && !_defaultNameApplied) {
      final defaultName =
          AppLocalizations.of(context)!.newConstructionDefault;
      _nameCtrl.text = defaultName;
      _construction = _construction.copyWith(name: defaultName);
      _defaultNameApplied = true;
    }
  }

  void _loadFromState() {
    final state = ref.read(editorStateProvider);
    final cid = widget.wall.constructionId;

    if (cid != null) {
      final existing =
          state.constructions.where((c) => c.id == cid).firstOrNull;
      if (existing != null) {
        _construction = existing;
        _layers = state.materialLayers
            .where((l) => l.constructionId == cid)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _nameCtrl = TextEditingController(text: _construction.name);
        _nameDeCtrl = TextEditingController(
          text: _construction.nameDe ?? '',
        );
        _rsiCtrl = TextEditingController(
          text: _construction.rsi.toStringAsFixed(2),
        );
        _rseCtrl = TextEditingController(
          text: _construction.rse.toStringAsFixed(2),
        );
        return;
      }
    }

    // New construction with empty layer stack. The localized default name
    // is applied in didChangeDependencies once a BuildContext is available.
    _isNewConstruction = true;
    _construction = WallConstruction(
      id: IdGenerator.newId(),
      name: '',
    );
    _layers = [];
    _nameCtrl = TextEditingController();
    _nameDeCtrl = TextEditingController();
    _rsiCtrl = TextEditingController(text: '0.13');
    _rseCtrl = TextEditingController(text: '0.04');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameDeCtrl.dispose();
    _rsiCtrl.dispose();
    _rseCtrl.dispose();
    super.dispose();
  }

  // ---- Derived values ----

  double get _rsi =>
      double.tryParse(_rsiCtrl.text) ?? _construction.rsi;

  double get _rse =>
      double.tryParse(_rseCtrl.text) ?? _construction.rse;

  List<double> get _thicknesses =>
      _layers.map((l) => l.thicknessMm).toList();

  List<double> get _lambdas =>
      _layers.map((l) => l.thermalConductivity).toList();

  List<LayerSpec> get _layerSpecs => _layers.map((l) {
        if (l.studWidthMm != null &&
            l.studClearGapMm != null &&
            l.studLambda != null) {
          return InhomogeneousLayerSpec(
            thicknessMm: l.thicknessMm,
            lambdaMain: l.thermalConductivity,
            studWidthMm: l.studWidthMm!,
            studClearGapMm: l.studClearGapMm!,
            lambdaStud: l.studLambda!,
          );
        }
        return HomogeneousLayerSpec(
          thicknessMm: l.thicknessMm,
          lambda: l.thermalConductivity,
        );
      }).toList();

  double get _uVal => ThermalEngine.uValueCombined(
        layers: _layerSpecs,
        rsi: _rsi,
        rse: _rse,
      );

  double get _rTotal => ThermalEngine.totalResistance(
        layerThicknessesMm: _thicknesses,
        layerLambdas: _lambdas,
        rsi: _rsi,
        rse: _rse,
      );

  List<double> _tempProfile(double tIndoorC, double tOutdoorC) =>
      ThermalEngine.temperatureProfile(
        layerThicknessesMm: _thicknesses,
        layerLambdas: _lambdas,
        rsi: _rsi,
        rse: _rse,
        tIndoorC: tIndoorC,
        tOutdoorC: tOutdoorC,
      );

  // ---- Mutations ----

  void _addLayer() {
    final entries =
        ref.read(materialEntriesProvider).asData?.value ?? [];
    final mat = entries.firstOrNull;
    if (mat == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noMaterialsAvailable)),
      );
      return;
    }
    setState(() {
      _layers = [
        ..._layers,
        MaterialLayer(
          id: IdGenerator.newId(),
          constructionId: _construction.id,
          sortOrder: _layers.length,
          materialId: mat.id,
          thicknessMm: 100.0,
          thermalConductivity: mat.lambdaDefault,
          density: mat.densityDefault,
          specificHeat: mat.specificHeatDefault,
        ),
      ];
    });
  }

  void _removeLayer(int index) {
    setState(() {
      final list = List<MaterialLayer>.from(_layers)..removeAt(index);
      _layers = list
          .asMap()
          .entries
          .map((e) => e.value.copyWith(sortOrder: e.key))
          .toList();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final list = List<MaterialLayer>.from(_layers);
      list.insert(newIndex, list.removeAt(oldIndex));
      _layers = list
          .asMap()
          .entries
          .map((e) => e.value.copyWith(sortOrder: e.key))
          .toList();
    });
  }

  void _updateLayer(int index, MaterialLayer updated) {
    setState(() {
      final list = List<MaterialLayer>.from(_layers);
      list[index] = updated.copyWith(sortOrder: index);
      _layers = list;
    });
  }

  Future<void> _pickMaterialForLayer(int index) async {
    final mat = await _showMaterialPickerDialog(context);
    if (mat == null || !mounted) return;
    _updateLayer(
      index,
      _layers[index].copyWith(
        materialId: mat.id,
        thermalConductivity: mat.lambdaDefault,
        density: mat.densityDefault,
        specificHeat: mat.specificHeatDefault,
      ),
    );
  }

  Future<void> _saveAsPreset() async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl =
        TextEditingController(text: _nameCtrl.text.trim());
    final nameDeCtrl =
        TextEditingController(text: _nameDeCtrl.text.trim());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveAsPreset),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.presetName,
              ),
              autofocus: true,
            ),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: nameDeCtrl,
              decoration: InputDecoration(
                labelText: l10n.presetNameDe,
                helperText: l10n.presetNameDeHelp,
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    final presetName = nameCtrl.text.trim();
    final presetNameDeRaw = nameDeCtrl.text.trim();
    final presetNameDe = presetNameDeRaw.isEmpty ? null : presetNameDeRaw;
    nameCtrl.dispose();
    nameDeCtrl.dispose();
    if (confirmed != true || !mounted) return;
    if (presetName.isEmpty) return;

    // Ensure the current construction exists in state so the
    // notifier can find it for the deep copy.
    final notifier = ref.read(editorStateProvider.notifier);
    final editorState = ref.read(editorStateProvider);
    final isNew = !editorState.constructions
        .any((c) => c.id == _construction.id);
    final rsi = double.tryParse(_rsiCtrl.text) ?? 0.13;
    final rse = double.tryParse(_rseCtrl.text) ?? 0.04;
    final editorNameDeRaw = _nameDeCtrl.text.trim();
    final current = _construction.copyWith(
      name: _nameCtrl.text.trim(),
      nameDe: editorNameDeRaw.isEmpty ? null : editorNameDeRaw,
      rsi: rsi,
      rse: rse,
    );
    if (isNew) {
      notifier.addConstruction(current);
    } else {
      notifier.updateConstruction(current);
    }
    notifier.replaceLayersForConstruction(
        current.id, _layers);

    notifier.saveConstructionAsPreset(
      _construction.id,
      presetName,
      presetNameDe: presetNameDe,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.savedAsPreset)),
    );
  }

  Future<void> _loadPreset() async {
    final l10n = AppLocalizations.of(context)!;
    final presets = ref
        .read(editorStateProvider)
        .constructions
        .where((c) => c.isPreset)
        .toList();
    if (presets.isEmpty) return;

    final localizedById = {
      for (final lr in ref.read(localizedWallConstructionsProvider))
        lr.row.id: lr.displayName,
    };

    final selected = await showDialog<WallConstruction>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.loadPreset),
        children: presets.map((p) {
          final layers = ref
              .read(editorStateProvider)
              .materialLayers
              .where((l) => l.constructionId == p.id)
              .toList();
          final specs = layers.map((l) {
            if (l.studWidthMm != null &&
                l.studClearGapMm != null &&
                l.studLambda != null) {
              return InhomogeneousLayerSpec(
                thicknessMm: l.thicknessMm,
                lambdaMain: l.thermalConductivity,
                studWidthMm: l.studWidthMm!,
                studClearGapMm: l.studClearGapMm!,
                lambdaStud: l.studLambda!,
              );
            }
            return HomogeneousLayerSpec(
              thicknessMm: l.thicknessMm,
              lambda: l.thermalConductivity,
            );
          }).toList();
          final u = ThermalEngine.uValueCombined(
            layers: specs,
            rsi: p.rsi,
            rse: p.rse,
          );
          final uLabel = u.isNaN
              ? '—'
              : '${u.toStringAsFixed(3)} W/(m²K)';
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(p),
            child: ListTile(
              title: Text(localizedById[p.id] ?? p.name),
              subtitle: Text(l10n.presetUValueLine(uLabel)),
              dense: true,
            ),
          );
        }).toList(),
      ),
    );
    if (selected == null || !mounted) return;

    final srcLayers = ref
        .read(editorStateProvider)
        .materialLayers
        .where((l) => l.constructionId == selected.id)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final newId = _construction.id;
    setState(() {
      _construction = selected.copyWith(
        id: newId,
        isPreset: false,
      );
      _layers = srcLayers
          .asMap()
          .entries
          .map(
            (e) => e.value.copyWith(
              id: IdGenerator.newId(),
              constructionId: newId,
              sortOrder: e.key,
            ),
          )
          .toList();
      _nameCtrl.text = selected.name;
      _nameDeCtrl.text = selected.nameDe ?? '';
      _rsiCtrl.text = selected.rsi.toStringAsFixed(2);
      _rseCtrl.text = selected.rse.toStringAsFixed(2);
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final nameDeRaw = _nameDeCtrl.text.trim();
    final nameDe = nameDeRaw.isEmpty ? null : nameDeRaw;
    final rsi = double.tryParse(_rsiCtrl.text) ?? 0.13;
    final rse = double.tryParse(_rseCtrl.text) ?? 0.04;
    final updated = _construction.copyWith(
      name: name,
      nameDe: nameDe,
      rsi: rsi,
      rse: rse,
    );

    final notifier = ref.read(editorStateProvider.notifier);
    final state = ref.read(editorStateProvider);
    final isNew =
        !state.constructions.any((c) => c.id == updated.id);

    if (isNew) {
      notifier.addConstruction(updated);
    } else {
      notifier.updateConstruction(updated);
    }
    notifier.replaceLayersForConstruction(updated.id, _layers);

    if (widget.wall.constructionId != updated.id) {
      notifier.updateWall(
        widget.wall.copyWith(constructionId: updated.id),
      );
    }

    Navigator.of(context).pop();
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(projectSettingsProvider);
    final materials = ref.watch(localizedMaterialEntriesProvider);
    final tOutdoorC = settings.designOutdoorTempC;
    final editorState = ref.watch(editorStateProvider);
    final room = editorState.rooms
        .where((r) => r.id == widget.wall.roomId)
        .firstOrNull;
    final tIndoorC = room?.targetTempC ?? settings.defaultIndoorTempC;
    final uVal = _uVal;
    final rTotal = _rTotal;
    final profile = _tempProfile(tIndoorC, tOutdoorC);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 660,
          maxHeight: 700,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Title row ----
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.wallConstructionTitle,
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  FilledButton(
                    onPressed: _save,
                    child: Text(l10n.save),
                  ),
                  const SizedBox(width: Spacing.sm),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              // ---- Preset row ----
              _PresetRow(
                onSaveAsPreset: _saveAsPreset,
                onLoadPreset: _loadPreset,
                hasPresets: ref
                    .watch(editorStateProvider)
                    .constructions
                    .any((c) => c.isPreset),
              ),
              const SizedBox(height: Spacing.sm),

              // ---- Name field ----
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.constructionName,
                  isDense: true,
                ),
                style: textTheme.bodyLarge,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.xs),

              // ---- German name field (optional) ----
              TextField(
                controller: _nameDeCtrl,
                decoration: InputDecoration(
                  labelText: l10n.constructionNameDe,
                  helperText: l10n.constructionNameDeHelp,
                  helperMaxLines: 2,
                  isDense: true,
                ),
                style: textTheme.bodyLarge,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.sm),

              // ---- U-value summary ----
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      uVal.isNaN
                          ? l10n.uValueEmpty
                          : l10n.uValueDisplay(uVal.toStringAsFixed(3)),
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      rTotal.isNaN
                          ? l10n.rValueEmpty
                          : l10n.rValueDisplay(rTotal.toStringAsFixed(3)),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.sm),

              // ---- Layer stack ----
              Text(
                l10n.layerStack,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.xs),
              Flexible(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: _layers.length,
                  onReorder: _onReorder,
                  footer: Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addLayer),
                      onPressed: _addLayer,
                    ),
                  ),
                  itemBuilder: (context, i) {
                    final layer = _layers[i];
                    final mat = materials
                        .where((m) => m.row.id == layer.materialId)
                        .firstOrNull;
                    return _LayerRow(
                      key: ValueKey(layer.id),
                      index: i,
                      layer: layer,
                      materialName: mat?.displayName ?? layer.materialId,
                      onPickMaterial: () => _pickMaterialForLayer(i),
                      onThicknessChanged: (v) =>
                          _updateLayer(i, layer.copyWith(thicknessMm: v)),
                      onLambdaChanged: (v) => _updateLayer(
                        i,
                        layer.copyWith(thermalConductivity: v),
                      ),
                      onStudChanged: (updated) => _updateLayer(i, updated),
                      onDelete: () => _removeLayer(i),
                    );
                  },
                ),
              ),

              const Divider(height: Spacing.md),

              // ---- Temperature profile ----
              if (profile.length >= 2) ...[
                Text(
                  l10n.temperatureProfileWithRange(
                    tIndoorC.toStringAsFixed(1),
                    tOutdoorC.toStringAsFixed(1),
                  ),
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: Spacing.xs),
                SizedBox(
                  height: 48,
                  child: CustomPaint(
                    painter: _TempProfilePainter(
                      profile: profile,
                      textColor: colorScheme.onSurface,
                    ),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
              ],

              // ---- Surface resistances ----
              Row(
                children: [
                  Text(
                    l10n.surfaceResistances,
                    style: textTheme.bodySmall,
                  ),
                  const Spacer(),
                  _ResistanceField(
                    label: 'Rsi',
                    controller: _rsiCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(width: Spacing.md),
                  _ResistanceField(
                    label: 'Rse',
                    controller: _rseCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Layer row
// ---------------------------------------------------------------

class _LayerRow extends StatefulWidget {
  const _LayerRow({
    super.key,
    required this.index,
    required this.layer,
    required this.materialName,
    required this.onPickMaterial,
    required this.onThicknessChanged,
    required this.onLambdaChanged,
    required this.onStudChanged,
    required this.onDelete,
  });

  final int index;
  final MaterialLayer layer;
  final String materialName;
  final VoidCallback onPickMaterial;
  final ValueChanged<double> onThicknessChanged;
  final ValueChanged<double> onLambdaChanged;

  /// Called whenever the stud sub-row changes. Receives the full updated
  /// [MaterialLayer] with stud fields set (expand) or all null (collapse).
  final ValueChanged<MaterialLayer> onStudChanged;
  final VoidCallback onDelete;

  @override
  State<_LayerRow> createState() => _LayerRowState();
}

class _LayerRowState extends State<_LayerRow> {
  // Main layer controllers.
  late TextEditingController _thicknessCtrl;
  late TextEditingController _lambdaCtrl;

  // Stud sub-row controllers.
  late TextEditingController _studWidthCtrl;
  late TextEditingController _studGapCtrl;
  late TextEditingController _studLambdaCtrl;

  bool _studExpanded = false;

  // 3px accent colour matching UI/UX §3.1 primaryLight.
  static const _accentColor = Color(0xFF2E86C1);

  bool get _hasStud =>
      widget.layer.studWidthMm != null &&
      widget.layer.studClearGapMm != null &&
      widget.layer.studLambda != null;

  @override
  void initState() {
    super.initState();
    _thicknessCtrl = TextEditingController(
      text: widget.layer.thicknessMm.round().toString(),
    );
    _lambdaCtrl = TextEditingController(
      text: widget.layer.thermalConductivity.toString(),
    );
    _studWidthCtrl = TextEditingController(
      text: (widget.layer.studWidthMm ?? 60.0).round().toString(),
    );
    _studGapCtrl = TextEditingController(
      text: (widget.layer.studClearGapMm ?? 300.0).round().toString(),
    );
    _studLambdaCtrl = TextEditingController(
      text: (widget.layer.studLambda ?? 0.13).toString(),
    );
    _studExpanded = _hasStud;
  }

  @override
  void didUpdateWidget(_LayerRow old) {
    super.didUpdateWidget(old);
    if (old.layer.materialId != widget.layer.materialId) {
      _thicknessCtrl.text = widget.layer.thicknessMm.round().toString();
      _lambdaCtrl.text = widget.layer.thermalConductivity.toString();
    }
    // Sync stud controllers when stud fields change from outside.
    // Only overwrite the controller text when the *parsed* value in the
    // controller differs from the new widget value.  This prevents cursor
    // jumps while the user is actively typing (each valid keystroke triggers
    // a persist → rebuild → didUpdateWidget round-trip, and unconditionally
    // setting controller.text resets the cursor to the end of the field).
    if (old.layer.studWidthMm != widget.layer.studWidthMm ||
        old.layer.studClearGapMm != widget.layer.studClearGapMm ||
        old.layer.studLambda != widget.layer.studLambda) {
      _studExpanded = _hasStud;
      final newWidth = widget.layer.studWidthMm;
      if (newWidth != null &&
          double.tryParse(_studWidthCtrl.text)?.round() != newWidth.round()) {
        _studWidthCtrl.text = newWidth.round().toString();
      }
      final newGap = widget.layer.studClearGapMm;
      if (newGap != null &&
          double.tryParse(_studGapCtrl.text)?.round() != newGap.round()) {
        _studGapCtrl.text = newGap.round().toString();
      }
      final newLambda = widget.layer.studLambda;
      if (newLambda != null &&
          double.tryParse(_studLambdaCtrl.text) != newLambda) {
        _studLambdaCtrl.text = newLambda.toString();
      }
    }
  }

  @override
  void dispose() {
    _thicknessCtrl.dispose();
    _lambdaCtrl.dispose();
    _studWidthCtrl.dispose();
    _studGapCtrl.dispose();
    _studLambdaCtrl.dispose();
    super.dispose();
  }

  void _toggleStud() {
    if (_studExpanded) {
      // Collapse: remove stud definition.
      setState(() => _studExpanded = false);
      widget.onStudChanged(
        widget.layer.copyWith(
          studWidthMm: null,
          studClearGapMm: null,
          studLambda: null,
        ),
      );
    } else {
      // Expand: apply defaults.
      setState(() => _studExpanded = true);
      final width = double.tryParse(_studWidthCtrl.text) ?? 60.0;
      final gap = double.tryParse(_studGapCtrl.text) ?? 300.0;
      final lambda = double.tryParse(_studLambdaCtrl.text) ?? 0.13;
      widget.onStudChanged(
        widget.layer.copyWith(
          studWidthMm: width,
          studClearGapMm: gap,
          studLambda: lambda,
        ),
      );
    }
  }

  void _removeStud() {
    setState(() => _studExpanded = false);
    widget.onStudChanged(
      widget.layer.copyWith(
        studWidthMm: null,
        studClearGapMm: null,
        studLambda: null,
      ),
    );
  }

  void _notifyStudChange() {
    final width = double.tryParse(_studWidthCtrl.text);
    final gap = double.tryParse(_studGapCtrl.text);
    final lambda = double.tryParse(_studLambdaCtrl.text);
    if (width != null && width > 0 && gap != null && gap > 0 &&
        lambda != null && lambda > 0) {
      widget.onStudChanged(
        widget.layer.copyWith(
          studWidthMm: width,
          studClearGapMm: gap,
          studLambda: lambda,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final showAccent = _studExpanded || _hasStud;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Container(
        decoration: showAccent
            ? const BoxDecoration(
                border: Border(
                  left: BorderSide(color: _accentColor, width: 3),
                ),
              )
            : null,
        padding: showAccent
            ? const EdgeInsets.only(left: Spacing.xs)
            : EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main layer row ──
            Row(
              children: [
                // Drag handle.
                MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: ReorderableDragStartListener(
                    index: widget.index,
                    child: const Icon(Icons.drag_handle, size: 20),
                  ),
                ),
                const SizedBox(width: Spacing.sm),

                // Material picker button.
                Expanded(
                  flex: 3,
                  child: OutlinedButton(
                    onPressed: widget.onPickMaterial,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                        vertical: Spacing.xs,
                      ),
                    ),
                    child: Text(
                      widget.materialName,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),

                // Thickness field.
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _thicknessCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      suffixText: 'mm',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                    ),
                    style: textTheme.labelSmall,
                    onChanged: (v) {
                      final d = double.tryParse(v);
                      if (d != null && d > 0) widget.onThicknessChanged(d);
                    },
                  ),
                ),
                const SizedBox(width: Spacing.sm),

                // Lambda field (editable override).
                SizedBox(
                  width: 68,
                  child: TextField(
                    controller: _lambdaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixText: '\u03BB ',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                    ),
                    style: textTheme.labelSmall,
                    onChanged: (v) {
                      final d = double.tryParse(v);
                      if (d != null && d > 0) widget.onLambdaChanged(d);
                    },
                  ),
                ),
                const SizedBox(width: Spacing.xs),

                // Delete button.
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: widget.onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),

                // ⊕ / toggle-stud button.
                Tooltip(
                  message: _studExpanded
                      ? l10n.removeStudTooltip
                      : l10n.addStudTooltip,
                  child: IconButton(
                    icon: Icon(
                      _studExpanded ? Icons.remove_circle_outline : Icons.add_circle_outline,
                      size: 18,
                      color: _studExpanded ? _accentColor : null,
                    ),
                    onPressed: _toggleStud,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            // ── Stud sub-row ──
            if (_studExpanded)
              Padding(
                padding: const EdgeInsets.only(
                  left: 28,
                  top: Spacing.xs,
                  bottom: Spacing.xs,
                ),
                child: Row(
                  children: [
                    Text(
                      l10n.timberStudLabel,
                      style: textTheme.labelSmall?.copyWith(
                        color: _accentColor,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),

                    // Stud width.
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _studWidthCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          suffixText: 'mm',
                          hintText: l10n.studWidthHint,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                        ),
                        style: textTheme.labelSmall,
                        onChanged: (_) => _notifyStudChange(),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(l10n.studWidthLabel, style: textTheme.labelSmall),
                    const SizedBox(width: Spacing.sm),

                    // Clear gap with tooltip.
                    Tooltip(
                      message: l10n.clearGapTooltip,
                      child: SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _studGapCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: 'mm',
                            hintText: l10n.studGapHint,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                          ),
                          style: textTheme.labelSmall,
                          onChanged: (_) => _notifyStudChange(),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(l10n.clearGapLabel, style: textTheme.labelSmall),
                    const SizedBox(width: Spacing.sm),

                    // Stud lambda.
                    SizedBox(
                      width: 68,
                      child: TextField(
                        controller: _studLambdaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixText: '\u03BB ',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                        ),
                        style: textTheme.labelSmall,
                        onChanged: (_) => _notifyStudChange(),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),

                    // ✕ remove stud.
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: _removeStud,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      tooltip: l10n.removeStudTooltip,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Surface resistance field
// ---------------------------------------------------------------

class _ResistanceField extends StatelessWidget {
  const _ResistanceField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: textTheme.bodySmall),
        const SizedBox(width: Spacing.xs),
        SizedBox(
          width: 56,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
            ),
            style: textTheme.labelSmall,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// Temperature profile painter
// ---------------------------------------------------------------

/// Draws a warm-to-cool gradient bar for the wall assembly with
/// inside and outside surface temperatures labelled.
class _TempProfilePainter extends CustomPainter {
  const _TempProfilePainter({
    required this.profile,
    required this.textColor,
  });

  final List<double> profile;
  final Color textColor;

  static const _barFraction = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2) return;

    final barH = size.height * _barFraction;
    final barRect = Rect.fromLTWH(0, 0, size.width, barH);

    // Gradient: warm (inside) → cool (outside).
    final shader = const LinearGradient(
      colors: [Color(0xFFEF4444), Color(0xFF93C5FD)],
    ).createShader(barRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
      Paint()..shader = shader,
    );

    // Draw temperature labels at inside and outside surfaces.
    _paintLabel(
      canvas,
      size,
      0,
      '${profile.first.toStringAsFixed(1)}\u00B0C',
      alignRight: false,
    );
    _paintLabel(
      canvas,
      size,
      size.width,
      '${profile.last.toStringAsFixed(1)}\u00B0C',
      alignRight: true,
    );

    // Draw a mid-point label if we have enough layers.
    if (profile.length >= 4) {
      final mid = profile.length ~/ 2;
      _paintLabel(
        canvas,
        size,
        size.width / 2,
        '${profile[mid].toStringAsFixed(1)}\u00B0C',
        alignRight: false,
        center: true,
      );
    }
  }

  void _paintLabel(
    Canvas canvas,
    Size size,
    double x,
    String text, {
    bool alignRight = false,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double labelX;
    if (center) {
      labelX = x - tp.width / 2;
    } else if (alignRight) {
      labelX = x - tp.width;
    } else {
      labelX = x;
    }
    tp.paint(canvas, Offset(labelX, size.height * 0.62));
  }

  @override
  bool shouldRepaint(_TempProfilePainter old) =>
      old.profile != profile || old.textColor != textColor;
}

// ---------------------------------------------------------------
// Preset action row
// ---------------------------------------------------------------

/// A compact row with "Save as preset" and "Load ▾" buttons.
///
/// [onLoadPreset] button is disabled when [hasPresets] is false.
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.onSaveAsPreset,
    required this.onLoadPreset,
    required this.hasPresets,
  });

  final VoidCallback onSaveAsPreset;
  final VoidCallback onLoadPreset;
  final bool hasPresets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        TextButton.icon(
          icon: const Icon(Icons.upload, size: 16),
          label: Text(l10n.saveAsPreset),
          onPressed: onSaveAsPreset,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        TextButton.icon(
          icon: const Icon(Icons.download, size: 16),
          label: Text(l10n.load),
          onPressed: hasPresets ? onLoadPreset : null,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// Material picker dialog
// ---------------------------------------------------------------

/// Shows a [MaterialPicker] inside a dialog and returns the chosen
/// [MaterialEntry], or null if the user dismisses without selecting.
Future<MaterialEntry?> _showMaterialPickerDialog(BuildContext context) {
  return showDialog<MaterialEntry>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: 400,
        height: 560,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MaterialPicker(
            onSelected: (m) => Navigator.of(ctx).pop(m),
          ),
        ),
      ),
    ),
  );
}

