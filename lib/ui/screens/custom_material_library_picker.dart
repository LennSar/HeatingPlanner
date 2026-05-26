import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/custom_material_library_service.dart';

/// Skeleton content written when the user picks a path that does not yet
/// exist on disk (UI/UX §9.2).
const _emptySkeleton = '{"version":"1.0","materials":[]}';

/// Opens a "save-or-open" file picker that lets the user point the
/// custom material library at any `*.json` / `*.matlib.json` path.
///
/// Behaviour per UI/UX §9.2:
/// - If the chosen path does not yet exist, an empty skeleton file is
///   written before [CustomMaterialLibraryService.setLibraryPath] runs.
/// - If the user cancels, nothing happens.
Future<void> pickAndConfigureCustomMaterialLibrary(WidgetRef ref) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Pick custom material library',
    fileName: 'heating_planner.matlib.json',
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (path == null) return;

  final file = File(path);
  if (!file.existsSync()) {
    await file.create(recursive: true);
    await file.writeAsString(_emptySkeleton, flush: true);
  }

  await ref
      .read(customMaterialLibraryServiceProvider)
      .setLibraryPath(path);
}
