import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/validation_limits.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/material_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/custom_material_library_service.dart';
import '../../repositories/material_repository.dart';

/// Opens the Add Custom Material dialog (UI/UX §5.7.2 add mode).
///
/// Returns the freshly-created [MaterialEntry] on save, or `null` on cancel.
Future<MaterialEntry?> showAddCustomMaterialDialog(BuildContext context) {
  return showDialog<MaterialEntry>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const CustomMaterialDialog(),
  );
}

/// Opens the Edit Custom Material dialog (UI/UX §5.7.2 edit mode).
///
/// Returns the updated [MaterialEntry] on save, or `null` on cancel.
Future<MaterialEntry?> showEditCustomMaterialDialog(
  BuildContext context,
  MaterialEntry entry,
) {
  return showDialog<MaterialEntry>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CustomMaterialDialog(initialEntry: entry),
  );
}

/// Add / Edit dialog for a custom [MaterialEntry] (UI/UX §5.7.2).
///
/// When [initialEntry] is null the dialog is in **Add** mode; otherwise it
/// pre-fills the fields and is in **Edit** mode. On Save the dialog
/// calls [CustomMaterialLibraryService.create] / `.update` and pops with
/// the resulting entry. On a file-write failure the dialog stays open
/// with the user's values intact and surfaces a toast.
class CustomMaterialDialog extends ConsumerStatefulWidget {
  /// Creates a [CustomMaterialDialog].
  const CustomMaterialDialog({super.key, this.initialEntry});

  /// When non-null the dialog is in Edit mode pre-filled with this entry.
  final MaterialEntry? initialEntry;

  @override
  ConsumerState<CustomMaterialDialog> createState() =>
      _CustomMaterialDialogState();
}

/// Two-segment toggle state for category / subcategory rows.
enum _PickMode { pickExisting, createNew }

class _CustomMaterialDialogState
    extends ConsumerState<CustomMaterialDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryNewCtrl;
  late final TextEditingController _subcategoryNewCtrl;
  late final TextEditingController _manufacturerCtrl;
  late final TextEditingController _lambdaCtrl;
  late final TextEditingController _densityCtrl;
  late final TextEditingController _specificHeatCtrl;
  late final TextEditingController _sourceCtrl;

  _PickMode _categoryMode = _PickMode.createNew;
  _PickMode _subcategoryMode = _PickMode.createNew;
  String? _categoryPicked;
  String? _subcategoryPicked;
  bool _saving = false;

  bool get _isEdit => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEntry;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _categoryNewCtrl = TextEditingController(text: e?.category ?? '');
    _subcategoryNewCtrl = TextEditingController(text: e?.subcategory ?? '');
    _manufacturerCtrl = TextEditingController();
    _lambdaCtrl = TextEditingController(
      text: e != null ? e.lambdaDefault.toStringAsFixed(3) : '',
    );
    // 0.0 is the in-database sentinel for "unknown" (UI/UX §5.7.2).
    // Edit mode renders it as a blank field so the user can leave it
    // empty without having to delete a misleading "0".
    _densityCtrl = TextEditingController(
      text: e != null && e.densityDefault != 0.0
          ? e.densityDefault.toStringAsFixed(0)
          : '',
    );
    _specificHeatCtrl = TextEditingController(
      text: e != null && e.specificHeatDefault != 0.0
          ? e.specificHeatDefault.toStringAsFixed(0)
          : '',
    );
    _sourceCtrl = TextEditingController();

    for (final c in [
      _nameCtrl,
      _categoryNewCtrl,
      _subcategoryNewCtrl,
      _manufacturerCtrl,
      _lambdaCtrl,
      _densityCtrl,
      _specificHeatCtrl,
      _sourceCtrl,
    ]) {
      c.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _categoryNewCtrl,
      _subcategoryNewCtrl,
      _manufacturerCtrl,
      _lambdaCtrl,
      _densityCtrl,
      _specificHeatCtrl,
      _sourceCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _rebuild() => setState(() {});

  // ── Derived values ──────────────────────────────────────────────────────

  String get _name => _nameCtrl.text.trim();

  String get _category => switch (_categoryMode) {
        _PickMode.pickExisting => _categoryPicked ?? '',
        _PickMode.createNew => _categoryNewCtrl.text.trim(),
      };

  String get _subcategory => switch (_subcategoryMode) {
        _PickMode.pickExisting => _subcategoryPicked ?? '',
        _PickMode.createNew => _subcategoryNewCtrl.text.trim(),
      };

  double? get _lambda => double.tryParse(_lambdaCtrl.text.trim());
  double? get _density => double.tryParse(_densityCtrl.text.trim());
  double? get _specificHeat =>
      double.tryParse(_specificHeatCtrl.text.trim());

  /// `true` when the field is empty or parses to a value equal to `0`.
  ///
  /// UI/UX §5.7.2: a user-typed `0` is treated identically to blank for
  /// the optional density / specific-heat fields — both map to the
  /// in-database `0.0` sentinel on save.
  bool _isBlankOrZero(TextEditingController ctrl) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return true;
    final v = double.tryParse(text);
    return v != null && v == 0;
  }

  // ── Validation ──────────────────────────────────────────────────────────

  String? _validateName(
    AppLocalizations l10n,
    List<MaterialEntry> customs,
  ) {
    if (_name.isEmpty) return l10n.customMaterialValidationRequired;
    if (_name.length > 200) {
      return l10n.customMaterialValidationMaxChars(200);
    }
    final lower = _name.toLowerCase();
    final clash = customs.any(
      (m) =>
          m.id != widget.initialEntry?.id &&
          m.name.toLowerCase() == lower,
    );
    if (clash) {
      return l10n.customMaterialValidationDuplicateName;
    }
    return null;
  }

  String? _validateText(
    AppLocalizations l10n,
    String value, {
    int max = 100,
  }) {
    if (value.isEmpty) return l10n.customMaterialValidationRequired;
    if (value.length > max) {
      return l10n.customMaterialValidationMaxChars(max);
    }
    return null;
  }

  String? _validateLambda(AppLocalizations l10n) {
    final v = _lambda;
    if (v == null) return l10n.customMaterialValidationRequired;
    if (v < minLambda || v > maxLambda) {
      return l10n.customMaterialValidationRange(
        minLambda.toString(),
        maxLambda.toString(),
      );
    }
    return null;
  }

  /// Density and specific heat are optional (UI/UX §5.7.2 "Why
  /// density and specific heat are optional"). Blank or a typed `0`
  /// is accepted and persists as the `0.0` sentinel; a non-blank,
  /// non-zero value must still fall inside the allowed range.
  String? _validateDensity(AppLocalizations l10n) {
    if (_isBlankOrZero(_densityCtrl)) return null;
    final v = _density;
    if (v == null) {
      return l10n.customMaterialValidationRange(
        minDensity.toString(),
        maxDensity.toString(),
      );
    }
    if (v < minDensity || v > maxDensity) {
      return l10n.customMaterialValidationRange(
        minDensity.toString(),
        maxDensity.toString(),
      );
    }
    return null;
  }

  String? _validateSpecificHeat(AppLocalizations l10n) {
    if (_isBlankOrZero(_specificHeatCtrl)) return null;
    final v = _specificHeat;
    if (v == null) {
      return l10n.customMaterialValidationRange(
        minSpecificHeat.toString(),
        maxSpecificHeat.toString(),
      );
    }
    if (v < minSpecificHeat || v > maxSpecificHeat) {
      return l10n.customMaterialValidationRange(
        minSpecificHeat.toString(),
        maxSpecificHeat.toString(),
      );
    }
    return null;
  }

  bool _canSave(AppLocalizations l10n, List<MaterialEntry> customs) {
    if (_saving) return false;
    if (_validateName(l10n, customs) != null) return false;
    if (_validateText(l10n, _category) != null) return false;
    if (_validateText(l10n, _subcategory) != null) return false;
    if (_validateLambda(l10n) != null) return false;
    if (_validateDensity(l10n) != null) return false;
    if (_validateSpecificHeat(l10n) != null) return false;
    return true;
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _onSave() async {
    setState(() => _saving = true);
    final service = ref.read(customMaterialLibraryServiceProvider);
    final initial = widget.initialEntry;
    // Blank or typed-0 → 0.0 sentinel (UI/UX §5.7.2). Non-blank values
    // have already been range-checked by `_canSave`, so `!` is safe.
    final density =
        _isBlankOrZero(_densityCtrl) ? 0.0 : _density!;
    final specificHeat =
        _isBlankOrZero(_specificHeatCtrl) ? 0.0 : _specificHeat!;
    try {
      MaterialEntry result;
      if (initial == null) {
        result = await service.create(
          MaterialEntry(
            id: 'placeholder',
            name: _name,
            category: _category,
            subcategory: _subcategory,
            lambdaDefault: _lambda!,
            densityDefault: density,
            specificHeatDefault: specificHeat,
            isBuiltIn: false,
          ),
        );
      } else {
        result = initial.copyWith(
          name: _name,
          category: _category,
          subcategory: _subcategory,
          lambdaDefault: _lambda!,
          densityDefault: density,
          specificHeatDefault: specificHeat,
        );
        await service.update(result);
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context)
              .extension<HeatingPlannerColors>()!
              .errorRed,
          content: Text(l10n.customMaterialFileWriteFailedToast),
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final customs =
        ref.watch(customMaterialsProvider).asData?.value ?? const [];
    final allEntries =
        ref.watch(materialEntriesProvider).asData?.value ?? const [];

    final categoriesAvailable =
        allEntries.map((m) => m.category).toSet().toList()..sort();
    if (_categoryMode == _PickMode.pickExisting &&
        _categoryPicked != null &&
        !categoriesAvailable.contains(_categoryPicked)) {
      _categoryPicked = null;
    }

    final subcategoriesAvailable = allEntries
        .where((m) => m.category == _category)
        .map((m) => m.subcategory)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (_subcategoryMode == _PickMode.pickExisting &&
        _subcategoryPicked != null &&
        !subcategoriesAvailable.contains(_subcategoryPicked)) {
      _subcategoryPicked = null;
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit
                          ? l10n.customMaterialDialogEditTitle
                          : l10n.customMaterialDialogAddTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.customMaterialButtonCancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),

              // Name
              _LabelRow(
                label: l10n.customMaterialFieldName,
                required: true,
                child: TextField(
                  controller: _nameCtrl,
                  key: const Key('custom-material-name'),
                  decoration: InputDecoration(
                    errorText: _validateName(l10n, customs),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),

              // Category
              _TaxonomyRow(
                label: l10n.customMaterialFieldCategory,
                mode: _categoryMode,
                onModeChanged: (m) {
                  setState(() {
                    _categoryMode = m;
                    if (m == _PickMode.pickExisting) {
                      _categoryNewCtrl.clear();
                    } else {
                      _categoryPicked = null;
                    }
                  });
                },
                pickedValue: _categoryPicked,
                onPickedChanged: (v) =>
                    setState(() => _categoryPicked = v),
                newController: _categoryNewCtrl,
                availableValues: categoriesAvailable,
                newKey: const Key('custom-material-category-new'),
                pickKey: const Key('custom-material-category-pick'),
                errorText: _validateText(l10n, _category),
              ),
              const SizedBox(height: Spacing.md),

              // Subcategory
              _TaxonomyRow(
                label: l10n.customMaterialFieldSubcategory,
                mode: _subcategoryMode,
                onModeChanged: (m) {
                  setState(() {
                    _subcategoryMode = m;
                    if (m == _PickMode.pickExisting) {
                      _subcategoryNewCtrl.clear();
                    } else {
                      _subcategoryPicked = null;
                    }
                  });
                },
                pickedValue: _subcategoryPicked,
                onPickedChanged: (v) =>
                    setState(() => _subcategoryPicked = v),
                newController: _subcategoryNewCtrl,
                availableValues: subcategoriesAvailable,
                newKey: const Key('custom-material-subcategory-new'),
                pickKey: const Key('custom-material-subcategory-pick'),
                errorText: _validateText(l10n, _subcategory),
              ),
              const SizedBox(height: Spacing.md),

              // Manufacturer (optional)
              _LabelRow(
                label: l10n.customMaterialFieldManufacturer,
                required: false,
                child: TextField(
                  controller: _manufacturerCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.customMaterialManufacturerHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),

              // λ
              _LabelRow(
                label: l10n.customMaterialFieldLambda,
                required: true,
                child: TextField(
                  controller: _lambdaCtrl,
                  key: const Key('custom-material-lambda'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9.]'),
                    ),
                  ],
                  decoration: InputDecoration(
                    errorText: _validateLambda(l10n),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),

              // Density (optional — UI/UX §5.7.2)
              _LabelRow(
                label: l10n.customMaterialFieldDensity,
                required: false,
                child: TextField(
                  controller: _densityCtrl,
                  key: const Key('custom-material-density'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9.]'),
                    ),
                  ],
                  decoration: InputDecoration(
                    errorText: _validateDensity(l10n),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),

              // Specific heat (optional — UI/UX §5.7.2)
              _LabelRow(
                label: l10n.customMaterialFieldSpecificHeat,
                required: false,
                child: TextField(
                  controller: _specificHeatCtrl,
                  key: const Key('custom-material-specific-heat'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9.]'),
                    ),
                  ],
                  decoration: InputDecoration(
                    errorText: _validateSpecificHeat(l10n),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),

              // Source URL (optional)
              _LabelRow(
                label: l10n.customMaterialFieldSourceUrl,
                required: false,
                child: TextField(
                  controller: _sourceCtrl,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.customMaterialButtonCancel),
                  ),
                  const SizedBox(width: Spacing.sm),
                  FilledButton(
                    key: const Key('custom-material-save'),
                    onPressed:
                        _canSave(l10n, customs) ? _onSave : null,
                    child: Text(
                      _isEdit
                          ? l10n.customMaterialButtonSave
                          : l10n.customMaterialButtonAdd,
                    ),
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

// ── Sub-widgets ───────────────────────────────────────────────────────────

/// A label-on-the-left, child-on-the-right form row.
class _LabelRow extends StatelessWidget {
  const _LabelRow({
    required this.label,
    required this.required,
    required this.child,
  });

  final String label;
  final bool required;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Padding(
            padding: const EdgeInsets.only(top: Spacing.sm + 2),
            child: Text(
              required ? '$label *' : label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// The two-segment "Pick existing" / "Create new" toggle row used for
/// Category and Subcategory.
class _TaxonomyRow extends StatelessWidget {
  const _TaxonomyRow({
    required this.label,
    required this.mode,
    required this.onModeChanged,
    required this.pickedValue,
    required this.onPickedChanged,
    required this.newController,
    required this.availableValues,
    required this.newKey,
    required this.pickKey,
    required this.errorText,
  });

  final String label;
  final _PickMode mode;
  final ValueChanged<_PickMode> onModeChanged;
  final String? pickedValue;
  final ValueChanged<String?> onPickedChanged;
  final TextEditingController newController;
  final List<String> availableValues;
  final Key newKey;
  final Key pickKey;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final emptyAvailable = availableValues.isEmpty;
    final effectiveMode =
        emptyAvailable ? _PickMode.createNew : mode;

    return _LabelRow(
      label: label,
      required: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<_PickMode>(
            segments: [
              ButtonSegment(
                value: _PickMode.pickExisting,
                label:
                    Text(l10n.customMaterialTogglePickExisting),
                tooltip: emptyAvailable
                    ? l10n
                        .customMaterialTogglePickExistingDisabledTooltip
                    : null,
                enabled: !emptyAvailable,
              ),
              ButtonSegment(
                value: _PickMode.createNew,
                label: Text(l10n.customMaterialToggleCreateNew),
              ),
            ],
            selected: {effectiveMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onModeChanged(s.first),
          ),
          const SizedBox(height: Spacing.xs),
          if (effectiveMode == _PickMode.pickExisting)
            DropdownButtonFormField<String>(
              key: pickKey,
              initialValue: pickedValue,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                errorText: errorText,
              ),
              items: [
                for (final v in availableValues)
                  DropdownMenuItem(value: v, child: Text(v)),
              ],
              onChanged: onPickedChanged,
            )
          else
            TextField(
              key: newKey,
              controller: newController,
              maxLength: 100,
              decoration: InputDecoration(
                isDense: true,
                errorText: errorText,
                counterText: '',
              ),
            ),
        ],
      ),
    );
  }
}
