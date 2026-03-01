import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/engines/thermal_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/material_layer.dart';
import '../../data/models/wall_construction.dart';
import '../../data/models/wall_segment.dart';
import '../providers/editor_state_provider.dart';

// ---------------------------------------------------------------
// Built-in material catalogue (mirrors assets/materials.json)
// ---------------------------------------------------------------

@immutable
class _Mat {
  const _Mat(
    this.id,
    this.name,
    this.category,
    this.lambda,
    this.density,
    this.specificHeat,
  );

  final String id;
  final String name;
  final String category;
  final double lambda; // W/(m·K)
  final double density; // kg/m³
  final double specificHeat; // J/(kg·K)
}

const _kMats = <_Mat>[
  _Mat('mat-001', 'Solid brick', 'Masonry', 0.77, 1800, 900),
  _Mat('mat-002', 'Hollow brick', 'Masonry', 0.44, 1200, 900),
  _Mat('mat-003', 'Concrete block', 'Masonry', 1.05, 2000, 900),
  _Mat('mat-004', 'AAC block', 'Masonry', 0.12, 500, 1000),
  _Mat('mat-005', 'Normal concrete', 'Concrete', 1.65, 2300, 1000),
  _Mat('mat-006', 'Lightweight concrete', 'Concrete', 0.33, 800, 1000),
  _Mat('mat-007', 'Reinforced concrete', 'Concrete', 2.10, 2400, 1000),
  _Mat('mat-008', 'EPS', 'Insulation', 0.035, 20, 1450),
  _Mat('mat-009', 'XPS', 'Insulation', 0.034, 35, 1450),
  _Mat('mat-010', 'Mineral wool', 'Insulation', 0.038, 30, 1030),
  _Mat('mat-011', 'PUR/PIR rigid board', 'Insulation', 0.023, 32, 1400),
  _Mat('mat-012', 'Phenolic foam', 'Insulation', 0.020, 35, 1400),
  _Mat('mat-013', 'Softwood', 'Wood', 0.13, 450, 1600),
  _Mat('mat-014', 'Hardwood (oak)', 'Wood', 0.18, 700, 1600),
  _Mat('mat-015', 'Plywood', 'Wood', 0.14, 550, 1600),
  _Mat('mat-016', 'OSB', 'Wood', 0.13, 600, 1700),
  _Mat('mat-017', 'Cement render', 'Plaster', 1.00, 1800, 1000),
  _Mat('mat-018', 'Lime plaster', 'Plaster', 0.70, 1600, 1000),
  _Mat('mat-019', 'Gypsum plaster', 'Plaster', 0.40, 1200, 1000),
  _Mat('mat-020', 'Ceramic tile', 'Floor Covering', 1.30, 2300, 840),
  _Mat('mat-021', 'Parquet (oak)', 'Floor Covering', 0.18, 700, 1600),
  _Mat('mat-022', 'Laminate', 'Floor Covering', 0.13, 900, 1400),
  _Mat('mat-023', 'Carpet', 'Floor Covering', 0.05, 200, 1300),
  _Mat('mat-024', 'Vinyl', 'Floor Covering', 0.17, 1400, 900),
  _Mat('mat-025', 'Vapour barrier (PE)', 'Membrane', 0.50, 980, 1800),
  _Mat('mat-026', 'Breather membrane', 'Membrane', 0.17, 500, 1000),
];

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
  late TextEditingController _rsiCtrl;
  late TextEditingController _rseCtrl;

  @override
  void initState() {
    super.initState();
    _loadFromState();
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
        _rsiCtrl = TextEditingController(
          text: _construction.rsi.toStringAsFixed(2),
        );
        _rseCtrl = TextEditingController(
          text: _construction.rse.toStringAsFixed(2),
        );
        return;
      }
    }

    // New construction with empty layer stack.
    _construction = WallConstruction(
      id: IdGenerator.newId(),
      name: 'New Construction',
    );
    _layers = [];
    _nameCtrl = TextEditingController(text: 'New Construction');
    _rsiCtrl = TextEditingController(text: '0.13');
    _rseCtrl = TextEditingController(text: '0.04');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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

  double get _uVal => ThermalEngine.uValue(
        layerThicknessesMm: _thicknesses,
        layerLambdas: _lambdas,
        rsi: _rsi,
        rse: _rse,
      );

  double get _rTotal => ThermalEngine.totalResistance(
        layerThicknessesMm: _thicknesses,
        layerLambdas: _lambdas,
        rsi: _rsi,
        rse: _rse,
      );

  List<double> get _tempProfile => ThermalEngine.temperatureProfile(
        layerThicknessesMm: _thicknesses,
        layerLambdas: _lambdas,
        rsi: _rsi,
        rse: _rse,
        tIndoorC: 20.0,
        tOutdoorC: -12.0,
      );

  // ---- Mutations ----

  void _addLayer() {
    final mat = _kMats.first;
    setState(() {
      _layers = [
        ..._layers,
        MaterialLayer(
          id: IdGenerator.newId(),
          constructionId: _construction.id,
          sortOrder: _layers.length,
          materialId: mat.id,
          thicknessMm: 100.0,
          thermalConductivity: mat.lambda,
          density: mat.density,
          specificHeat: mat.specificHeat,
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
    final mat = await _showMaterialPicker(context);
    if (mat == null || !mounted) return;
    _updateLayer(
      index,
      _layers[index].copyWith(
        materialId: mat.id,
        thermalConductivity: mat.lambda,
        density: mat.density,
        specificHeat: mat.specificHeat,
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final rsi = double.tryParse(_rsiCtrl.text) ?? 0.13;
    final rse = double.tryParse(_rseCtrl.text) ?? 0.04;
    final updated = _construction.copyWith(
      name: name,
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
    final uVal = _uVal;
    final rTotal = _rTotal;
    final profile = _tempProfile;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 580,
          maxHeight: 700,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Title row ----
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Wall Construction',
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                  const SizedBox(width: Spacing.sm),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),

              // ---- Name field ----
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Construction name',
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
                          ? 'U-Value: —'
                          : 'U  ${uVal.toStringAsFixed(3)} W/(m²K)',
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      rTotal.isNaN
                          ? 'R: —'
                          : 'R  ${rTotal.toStringAsFixed(3)} m²K/W',
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
                'Layer Stack  (outside \u2192 inside)',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.xs),
              SizedBox(
                height: 220,
                child: ReorderableListView.builder(
                  itemCount: _layers.length,
                  onReorder: _onReorder,
                  footer: Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Layer'),
                      onPressed: _addLayer,
                    ),
                  ),
                  itemBuilder: (context, i) {
                    final layer = _layers[i];
                    final mat = _kMats
                        .where((m) => m.id == layer.materialId)
                        .firstOrNull;
                    return _LayerRow(
                      key: ValueKey(layer.id),
                      index: i,
                      layer: layer,
                      materialName: mat?.name ?? 'Unknown',
                      onPickMaterial: () => _pickMaterialForLayer(i),
                      onThicknessChanged: (v) =>
                          _updateLayer(i, layer.copyWith(thicknessMm: v)),
                      onLambdaChanged: (v) => _updateLayer(
                        i,
                        layer.copyWith(thermalConductivity: v),
                      ),
                      onDelete: () => _removeLayer(i),
                    );
                  },
                ),
              ),

              const Divider(height: Spacing.md),

              // ---- Temperature profile ----
              if (profile.length >= 2) ...[
                Text(
                  'Temperature Profile  '
                  '(20\u00B0C \u2192 \u221212\u00B0C)',
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
                    'Surface resistances (m\u00B2K/W):',
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
    required this.onDelete,
  });

  final int index;
  final MaterialLayer layer;
  final String materialName;
  final VoidCallback onPickMaterial;
  final ValueChanged<double> onThicknessChanged;
  final ValueChanged<double> onLambdaChanged;
  final VoidCallback onDelete;

  @override
  State<_LayerRow> createState() => _LayerRowState();
}

class _LayerRowState extends State<_LayerRow> {
  late TextEditingController _thicknessCtrl;
  late TextEditingController _lambdaCtrl;

  @override
  void initState() {
    super.initState();
    _thicknessCtrl = TextEditingController(
      text: widget.layer.thicknessMm.round().toString(),
    );
    _lambdaCtrl = TextEditingController(
      text: widget.layer.thermalConductivity.toString(),
    );
  }

  @override
  void didUpdateWidget(_LayerRow old) {
    super.didUpdateWidget(old);
    // Refresh controllers when material changes from outside.
    if (old.layer.materialId != widget.layer.materialId) {
      _thicknessCtrl.text =
          widget.layer.thicknessMm.round().toString();
      _lambdaCtrl.text =
          widget.layer.thermalConductivity.toString();
    }
  }

  @override
  void dispose() {
    _thicknessCtrl.dispose();
    _lambdaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          // Drag handle.
          ReorderableDragStartListener(
            index: widget.index,
            child: const Icon(Icons.drag_handle, size: 20),
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
                if (d != null && d > 0) {
                  widget.onThicknessChanged(d);
                }
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
                if (d != null && d > 0) {
                  widget.onLambdaChanged(d);
                }
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
        ],
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
// Material picker dialog
// ---------------------------------------------------------------

/// Shows a searchable list of built-in materials and returns
/// the selected [_Mat], or null if cancelled.
Future<_Mat?> _showMaterialPicker(BuildContext context) {
  return showDialog<_Mat>(
    context: context,
    builder: (ctx) {
      var filter = '';
      return StatefulBuilder(
        builder: (ctx, setInner) {
          final filtered = filter.isEmpty
              ? _kMats
              : _kMats
                  .where(
                    (m) =>
                        m.name
                            .toLowerCase()
                            .contains(filter.toLowerCase()) ||
                        m.category
                            .toLowerCase()
                            .contains(filter.toLowerCase()),
                  )
                  .toList();

          return AlertDialog(
            title: const Text('Select Material'),
            content: SizedBox(
              width: 320,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search\u2026',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setInner(() => filter = v),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        return ListTile(
                          title: Text(m.name),
                          subtitle: Text(
                            '${m.category}  '
                            '\u03BB\u202F${m.lambda}\u00A0W/(m\u00B7K)',
                          ),
                          dense: true,
                          onTap: () =>
                              Navigator.of(ctx).pop(m),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    },
  );
}
