// Widget tests for SettingsScreen — the §9.2 Custom material library
// section.
//
// Covered scenarios:
//   - The section renders.
//   - With no stored path, the effective path display shows the
//     "(default)" chip and the "Reset to default" button is hidden.
//   - After a user-picked path is in effect, the "Reset to default"
//     button is visible and the "(default)" chip is gone.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/database/app_database.dart' as $db;
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/repositories/custom_material_library_service.dart';
import 'package:heating_planner/ui/screens/settings_screen.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FixedPathNotifier extends CustomMaterialLibraryPathNotifier {
  _FixedPathNotifier(this._value);
  final String? _value;

  @override
  String? build() => _value;
}

Widget _build({
  required Directory docsDir,
  required $db.AppDatabase db,
  required String? storedPath,
}) {
  return ProviderScope(
    overrides: [
      $db.appDatabaseProvider.overrideWithValue(db),
      customMaterialLibraryPathProvider.overrideWith(
        () => _FixedPathNotifier(storedPath),
      ),
      customMaterialLibraryServiceProvider.overrideWith(
        (ref) => CustomMaterialLibraryService(
          ref,
          appDocumentsDir: () async => docsDir,
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: const SettingsScreen(),
    ),
  );
}

/// Replaces the widget tree with a bare [SizedBox] and pumps enough
/// time for Drift's `QueryStream` cleanup timer to fire. Required
/// before `tearDown` closes the in-memory database, otherwise
/// `_verifyInvariants` aborts the test with "A Timer is still pending
/// even after the widget tree was disposed."
Future<void> _drainAndDispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late $db.AppDatabase db;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tempDir = await Directory.systemTemp.createTemp('settings-screen-test-');
    docsDir = await Directory(p.join(tempDir.path, 'docs')).create();
    db = $db.AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'section renders with the heading and the Manage materials button',
    (tester) async {
      await tester.pumpWidget(
        _build(docsDir: docsDir, db: db, storedPath: null),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('settings-custom-material-library-card')),
        findsOneWidget,
      );
      expect(find.text('Custom material library'), findsOneWidget);
      expect(
        find.byKey(const Key('settings-manage-materials')),
        findsOneWidget,
      );

      await _drainAndDispose(tester);
    },
  );

  testWidgets(
    'with no stored path: the path shows the (default) chip and the '
    'Reset-to-default button is hidden',
    (tester) async {
      await tester.pumpWidget(
        _build(docsDir: docsDir, db: db, storedPath: null),
      );
      // Let the FutureProvider for resolvedLibraryPath resolve.
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('settings-library-default-chip')),
        findsOneWidget,
      );
      expect(find.text('(default)'), findsOneWidget);
      expect(
        find.byKey(const Key('settings-reset-library')),
        findsNothing,
      );

      // The effective path matches the Rule 14 default location.
      final expectedPath = p.join(
        docsDir.path,
        'HeatingPlanner',
        'custom_materials.matlib.json',
      );
      expect(find.text(expectedPath), findsOneWidget);

      await _drainAndDispose(tester);
    },
  );

  testWidgets(
    'with a stored user path: the (default) chip is gone and '
    'Reset-to-default is visible',
    (tester) async {
      // Pre-create a user file at a different location. Real disk
      // I/O inside testWidgets needs runAsync so the future actually
      // completes (the default zone uses FakeAsync).
      final userPath = '${tempDir.path}/user-pick.matlib.json';
      await tester.runAsync(() async {
        await File(userPath)
            .writeAsString('{"version":"1.0","materials":[]}');
      });

      await tester.pumpWidget(
        _build(docsDir: docsDir, db: db, storedPath: userPath),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('settings-library-default-chip')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('settings-reset-library')),
        findsOneWidget,
      );
      expect(find.text(userPath), findsOneWidget);

      await _drainAndDispose(tester);
    },
  );
}
