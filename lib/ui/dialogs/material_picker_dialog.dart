import 'package:flutter/material.dart';

import '../../data/models/material_entry.dart';
import '../screens/manage_custom_materials_screen.dart';
import '../widgets/material_picker.dart';

/// Shows the searchable, grouped [MaterialPicker] inside a centred dialog
/// and returns the chosen [MaterialEntry], or null if the user dismisses
/// the dialog without selecting.
///
/// When the user picks the "Manage custom materials…" row the dialog
/// closes and the Manage Custom Materials screen is pushed on top of
/// the caller; the future resolves to `null` in that case.
Future<MaterialEntry?> showMaterialPickerDialog(BuildContext context) async {
  final navigator = Navigator.of(context);
  final result = await showDialog<_PickerResult>(
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
            onSelected: (m) =>
                Navigator.of(ctx).pop(_PickerResult.selected(m)),
            onManageRequested: () =>
                Navigator.of(ctx).pop(const _PickerResult.manage()),
          ),
        ),
      ),
    ),
  );

  if (result is _PickerSelected) return result.entry;
  if (result is _PickerManage) {
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => const ManageCustomMaterialsScreen(),
      ),
    );
  }
  return null;
}

sealed class _PickerResult {
  const _PickerResult();
  const factory _PickerResult.selected(MaterialEntry entry) =
      _PickerSelected;
  const factory _PickerResult.manage() = _PickerManage;
}

class _PickerSelected extends _PickerResult {
  const _PickerSelected(this.entry);
  final MaterialEntry entry;
}

class _PickerManage extends _PickerResult {
  const _PickerManage();
}
