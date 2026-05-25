import 'package:flutter/material.dart';

import '../../data/models/material_entry.dart';
import '../widgets/material_picker.dart';

/// Shows the searchable, grouped [MaterialPicker] inside a centred dialog
/// and returns the chosen [MaterialEntry], or null if the user dismisses
/// the dialog without selecting.
///
/// Used by both the wall construction editor (per-layer material pick)
/// and the project settings dialog (ADR-020 per-wall-type material
/// defaults), so they share the same three-level Category →
/// Subcategory → Entry tree, search behaviour, and dialog dimensions.
Future<MaterialEntry?> showMaterialPickerDialog(BuildContext context) {
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
