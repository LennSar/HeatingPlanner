import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/providers/grouped_materials_provider.dart';
import '../../core/constants/validation_limits.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/material_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/custom_material_library_service.dart';

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
/// The taxonomy is controlled through the **path builder** (ADR-022
/// Rule 6 / UI/UX §5.7.2 "Path builder"): a "Start under" dropdown
/// listing every distinct existing `categoryPath` plus a pinned
/// "(root)" option, followed by a vertical stack of typed-extension
/// fields. Each typed field has a trailing ✕ that cascade-removes
/// every field below it. Save composes
/// `categoryPath = startPath + typedSegments`.
class CustomMaterialDialog extends ConsumerStatefulWidget {
  /// Creates a [CustomMaterialDialog].
  const CustomMaterialDialog({super.key, this.initialEntry});

  /// When non-null the dialog is in Edit mode pre-filled with this entry.
  final MaterialEntry? initialEntry;

  @override
  ConsumerState<CustomMaterialDialog> createState() =>
      _CustomMaterialDialogState();
}

/// Sentinel for "Start under = (root)" in the dropdown selection.
const List<String> _rootPath = <String>[];

class _CustomMaterialDialogState
    extends ConsumerState<CustomMaterialDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _manufacturerCtrl;
  late final TextEditingController _lambdaCtrl;
  late final TextEditingController _densityCtrl;
  late final TextEditingController _specificHeatCtrl;
  late final TextEditingController _sourceCtrl;

  /// Currently chosen "Start under" prefix.
  ///
  /// - `null` means "not yet selected" (Add mode initial state when at
  ///   least one existing path is available). Save surfaces inline
  ///   error *"Pick a starting location"*.
  /// - `_rootPath` (an empty list) means "(root)".
  /// - any other list is a copy of an existing `categoryPath`.
  List<String>? _startPath;

  /// Typed-extension segments. One entry per row. Always at least one
  /// element in Edit mode (the material's last segment). In Add mode
  /// starts empty.
  late List<TextEditingController> _typedCtrls;

  /// Set to `true` while a save is in flight.
  bool _saving = false;

  /// Focus node attached to the most recently added typed-extension
  /// row so "+ Add subcategory" focuses the new field.
  FocusNode? _pendingFocus;

  bool get _isEdit => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEntry;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _manufacturerCtrl = TextEditingController();
    _lambdaCtrl = TextEditingController(
      text: e != null ? e.lambdaDefault.toStringAsFixed(3) : '',
    );
    // 0.0 is the in-database sentinel for "unknown" (UI/UX §5.7.2);
    // render as a blank field so the user can leave it empty.
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

    if (e != null) {
      // Edit mode: pre-fill "Start under" with categoryPath[:-1] (or
      // "(root)" when length is 1); typed extensions has the last
      // segment.
      _startPath = e.categoryPath.length == 1
          ? _rootPath
          : List.unmodifiable(e.categoryPath.sublist(0, e.categoryPath.length - 1));
      _typedCtrls = [TextEditingController(text: e.categoryPath.last)];
    } else {
      _typedCtrls = [];
    }

    for (final c in [
      _nameCtrl,
      _manufacturerCtrl,
      _lambdaCtrl,
      _densityCtrl,
      _specificHeatCtrl,
      _sourceCtrl,
    ]) {
      c.addListener(_rebuild);
    }
    for (final c in _typedCtrls) {
      c.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _manufacturerCtrl,
      _lambdaCtrl,
      _densityCtrl,
      _specificHeatCtrl,
      _sourceCtrl,
    ]) {
      c.dispose();
    }
    for (final c in _typedCtrls) {
      c.dispose();
    }
    _pendingFocus?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  // ── Derived values ──────────────────────────────────────────────────────

  String get _name => _nameCtrl.text.trim();

  /// Final composed `categoryPath` per ADR-022 Rule 6.
  ///
  /// Returns `null` when "Start under" hasn't been picked yet — used
  /// by [_canSave] to surface the inline error.
  List<String>? _composedPath() {
    final start = _startPath;
    if (start == null) return null;
    final typed = [for (final c in _typedCtrls) c.text.trim()];
    return [...start, ...typed];
  }

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

  /// Returns the inline error for a typed extension at [index], or
  /// `null` when valid. Errors surface eagerly (matching the rest of
  /// the dialog's "Required"-on-open behaviour for blank required
  /// fields).
  String? _validateTypedSegment(int index, AppLocalizations l10n) {
    final raw = _typedCtrls[index].text;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return l10n.customMaterialPathSegmentRequired;
    }
    if (trimmed.contains('/')) {
      return l10n.customMaterialPathSegmentNoSlash;
    }
    if (trimmed.length > 100) {
      return l10n.customMaterialValidationMaxChars(100);
    }
    return null;
  }

  /// Inline error on the "Start under" dropdown.
  String? _validateStartPath(AppLocalizations l10n) {
    return _startPath == null ? l10n.customMaterialPathStartUnderHint : null;
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

  String? _validateDensity(AppLocalizations l10n) {
    if (_isBlankOrZero(_densityCtrl)) return null;
    final v = _density;
    if (v == null || v < minDensity || v > maxDensity) {
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
    if (v == null || v < minSpecificHeat || v > maxSpecificHeat) {
      return l10n.customMaterialValidationRange(
        minSpecificHeat.toString(),
        maxSpecificHeat.toString(),
      );
    }
    return null;
  }

  /// `true` when every required field validates. Save uses this to
  /// gate the button; inline errors are still surfaced (after the
  /// first Save attempt) for whichever fields are wrong.
  bool _isValid(AppLocalizations l10n, List<MaterialEntry> customs) {
    if (_validateName(l10n, customs) != null) return false;
    if (_startPath == null) return false;
    for (var i = 0; i < _typedCtrls.length; i++) {
      final raw = _typedCtrls[i].text.trim();
      if (raw.isEmpty) return false;
      if (raw.contains('/')) return false;
      if (raw.length > 100) return false;
    }
    if (_composedPath()!.isEmpty) return false;
    if (_validateLambda(l10n) != null) return false;
    if (_validateDensity(l10n) != null) return false;
    if (_validateSpecificHeat(l10n) != null) return false;
    return true;
  }

  // ── Path-builder actions ────────────────────────────────────────────────

  void _onStartChanged(List<String>? next) {
    setState(() {
      _startPath = next;
    });
  }

  void _addTypedSegment() {
    final focus = FocusNode();
    final ctrl = TextEditingController();
    ctrl.addListener(_rebuild);
    setState(() {
      _typedCtrls.add(ctrl);
      _pendingFocus?.dispose();
      _pendingFocus = focus;
    });
    // Defer the focus request so the field is mounted first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus.requestFocus();
    });
  }

  /// Removes [index] and every segment below it (cascade). Disposes
  /// the removed controllers.
  void _removeFrom(int index) {
    final removed = _typedCtrls.sublist(index);
    setState(() {
      _typedCtrls = _typedCtrls.sublist(0, index);
    });
    for (final c in removed) {
      c.dispose();
    }
  }

  /// Whether "+ Add subcategory" is enabled. Disabled while the
  /// current last segment is empty (UI/UX §5.7.2: "finish the
  /// in-progress segment first").
  bool get _canAddSubcategory {
    if (_typedCtrls.isEmpty) return true;
    return _typedCtrls.last.text.trim().isNotEmpty;
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _onSave(List<MaterialEntry> customs) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final service = ref.read(customMaterialLibraryServiceProvider);
    final initial = widget.initialEntry;
    final path = _composedPath()!;
    final density = _isBlankOrZero(_densityCtrl) ? 0.0 : _density!;
    final specificHeat =
        _isBlankOrZero(_specificHeatCtrl) ? 0.0 : _specificHeat!;
    try {
      MaterialEntry result;
      if (initial == null) {
        result = await service.create(
          MaterialEntry(
            id: 'placeholder',
            name: _name,
            categoryPath: path,
            lambdaDefault: _lambda!,
            densityDefault: density,
            specificHeatDefault: specificHeat,
            isBuiltIn: false,
          ),
        );
      } else {
        result = initial.copyWith(
          name: _name,
          categoryPath: path,
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
    final catalogPaths = ref.watch(distinctCategoryPathsProvider);
    // Edit mode: ensure the material's parent path is offered in the
    // dropdown even when no other material lives at that prefix —
    // otherwise [DropdownMenu.initialSelection] can't match the pre-fill
    // and the field renders empty (ADR-022 Rule 7).
    final availablePaths = <List<String>>[
      ...catalogPaths,
      if (_startPath != null &&
          _startPath!.isNotEmpty &&
          !catalogPaths.any(
              (p) => breadcrumbFor(p) == breadcrumbFor(_startPath!)))
        _startPath!,
    ]..sort((a, b) => breadcrumbFor(a).compareTo(breadcrumbFor(b)));

    // In Add mode default to "(root)" when no existing paths exist
    // (otherwise leave unset so the user makes an explicit choice).
    if (!_isEdit && _startPath == null && availablePaths.isEmpty) {
      _startPath = _rootPath;
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

              // Location — path builder (UI/UX §5.7.2)
              _LabelRow(
                label: l10n.customMaterialFieldLocation,
                required: true,
                child: _PathBuilder(
                  l10n: l10n,
                  availablePaths: availablePaths,
                  startPath: _startPath,
                  onStartChanged: _onStartChanged,
                  startError: _validateStartPath(l10n),
                  typedControllers: _typedCtrls,
                  typedErrorFor: (i) => _validateTypedSegment(i, l10n),
                  onRemoveFrom: _removeFrom,
                  onAddSubcategory:
                      _canAddSubcategory ? _addTypedSegment : null,
                ),
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
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    errorText: _validateLambda(l10n),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),

              // Density (optional)
              _LabelRow(
                label: l10n.customMaterialFieldDensity,
                required: false,
                child: TextField(
                  controller: _densityCtrl,
                  key: const Key('custom-material-density'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    errorText: _validateDensity(l10n),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),

              // Specific heat (optional)
              _LabelRow(
                label: l10n.customMaterialFieldSpecificHeat,
                required: false,
                child: TextField(
                  controller: _specificHeatCtrl,
                  key: const Key('custom-material-specific-heat'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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
                    onPressed: (_saving || !_isValid(l10n, customs))
                        ? null
                        : () => _onSave(customs),
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

/// Path builder per UI/UX §5.7.2 / ADR-022 Rule 6.
class _PathBuilder extends StatelessWidget {
  const _PathBuilder({
    required this.l10n,
    required this.availablePaths,
    required this.startPath,
    required this.onStartChanged,
    required this.startError,
    required this.typedControllers,
    required this.typedErrorFor,
    required this.onRemoveFrom,
    required this.onAddSubcategory,
  });

  final AppLocalizations l10n;
  final List<List<String>> availablePaths;
  final List<String>? startPath;
  final ValueChanged<List<String>?> onStartChanged;
  final String? startError;
  final List<TextEditingController> typedControllers;
  final String? Function(int) typedErrorFor;
  final ValueChanged<int> onRemoveFrom;
  final VoidCallback? onAddSubcategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Start under
        Text(
          l10n.customMaterialPathStartUnder,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: Spacing.xs),
        _StartUnderDropdown(
          l10n: l10n,
          availablePaths: availablePaths,
          value: startPath,
          onChanged: onStartChanged,
          errorText: startError,
        ),
        // Typed extensions stack
        for (var i = 0; i < typedControllers.length; i++) ...[
          const SizedBox(height: Spacing.xs),
          _TypedSegmentRow(
            depth: i,
            controller: typedControllers[i],
            errorText: typedErrorFor(i),
            onRemove: () => onRemoveFrom(i),
            keyPrefix: 'custom-material-path-segment-$i',
          ),
        ],
        // + Add subcategory
        const SizedBox(height: Spacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('custom-material-add-subcategory'),
            onPressed: onAddSubcategory,
            child: Text(l10n.customMaterialPathAddSubcategory),
          ),
        ),
      ],
    );
  }
}

/// Searchable dropdown listing every existing `categoryPath` plus a
/// pinned "(root)" option.
class _StartUnderDropdown extends StatelessWidget {
  const _StartUnderDropdown({
    required this.l10n,
    required this.availablePaths,
    required this.value,
    required this.onChanged,
    required this.errorText,
  });

  final AppLocalizations l10n;
  final List<List<String>> availablePaths;
  final List<String>? value;
  final ValueChanged<List<String>?> onChanged;
  final String? errorText;

  /// Pinned-root sentinel exposed through DropdownMenuEntry's value.
  static const String _rootKey = '__root__';

  String _keyFor(List<String> path) =>
      path.isEmpty ? _rootKey : breadcrumbFor(path);

  @override
  Widget build(BuildContext context) {
    final entries = <DropdownMenuEntry<String>>[
      DropdownMenuEntry(
        value: _rootKey,
        label: l10n.customMaterialPathRootOption,
      ),
      for (final p in availablePaths)
        DropdownMenuEntry(
          value: breadcrumbFor(p),
          label: breadcrumbFor(p),
        ),
    ];

    return DropdownMenu<String>(
      key: const Key('custom-material-path-start'),
      initialSelection: value == null ? null : _keyFor(value!),
      width: double.infinity,
      enableFilter: true,
      enableSearch: true,
      requestFocusOnTap: true,
      hintText: l10n.customMaterialPathStartUnderHint,
      errorText: errorText,
      menuStyle: const MenuStyle(
        alignment: AlignmentDirectional.bottomStart,
      ),
      onSelected: (selected) {
        if (selected == null) {
          onChanged(null);
          return;
        }
        if (selected == _rootKey) {
          onChanged(_rootPath);
          return;
        }
        final hit = availablePaths.firstWhere(
          (p) => breadcrumbFor(p) == selected,
          orElse: () => const <String>[],
        );
        onChanged(hit);
      },
      dropdownMenuEntries: entries,
    );
  }
}

/// One typed-extension row: depth-indented `└─` glyph + text field + ✕.
class _TypedSegmentRow extends StatelessWidget {
  const _TypedSegmentRow({
    required this.depth,
    required this.controller,
    required this.errorText,
    required this.onRemove,
    required this.keyPrefix,
  });

  /// Position in the typed stack (0 = first typed segment). Drives the
  /// left-indent so the `└─` glyph cascades visually.
  final int depth;
  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onRemove;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: Spacing.md * (depth + 1).toDouble()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '└─ ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: TextField(
              key: Key(keyPrefix),
              controller: controller,
              maxLength: 100,
              decoration: InputDecoration(
                isDense: true,
                errorText: errorText,
                counterText: '',
              ),
            ),
          ),
          IconButton(
            key: Key('$keyPrefix-remove'),
            icon: const Icon(Icons.close, size: 18),
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
