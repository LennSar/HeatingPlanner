import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/data/models/wall_segment.dart';
import 'package:heating_planner/ui/providers/editor_state_provider.dart';
import 'package:heating_planner/ui/screens/editor_screen.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  /// Pump the editor screen inside a [ProviderScope] with
  /// the correct theme and a desktop-sized viewport.
  Widget buildEditorApp(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const EditorScreen(projectId: 'test-project'),
      ),
    );
  }

  group('EditorScreen — no Riverpod build-mutation errors', () {
    testWidgets('renders with empty state', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildEditorApp(container));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.textContaining('Zoom:'), findsOneWidget);
      expect(find.text('0 rooms'), findsOneWidget);
    });

    testWidgets('renders with pre-seeded walls', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(editorStateProvider.notifier)
        ..addWall(
          const WallSegment(
            id: 'wall-1',
            roomId: '',
            startPoint: Point2D(x: 0, y: 0),
            endPoint: Point2D(x: 5000, y: 0),
          ),
        )
        ..addWall(
          const WallSegment(
            id: 'wall-2',
            roomId: '',
            startPoint: Point2D(x: 5000, y: 0),
            endPoint: Point2D(x: 5000, y: 4000),
          ),
        );

      await tester.pumpWidget(buildEditorApp(container));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets(
      'Delete key does not throw provider-during-build error',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Seed a wall so the canvas has content.
        container.read(editorStateProvider.notifier).addWall(
          const WallSegment(
            id: 'wall-1',
            roomId: '',
            startPoint: Point2D(x: 0, y: 0),
            endPoint: Point2D(x: 5000, y: 0),
          ),
        );

        await tester.pumpWidget(buildEditorApp(container));
        await tester.pumpAndSettle();

        // Press Delete — increments toolDeleteProvider.
        // ref.listen fires the callback post-build, not during
        // build, so no Riverpod error should occur.
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pumpAndSettle();

        // Widget tree is still intact.
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'Backspace key does not throw provider-during-build error',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(editorStateProvider.notifier).addWall(
          const WallSegment(
            id: 'wall-1',
            roomId: '',
            startPoint: Point2D(x: 0, y: 0),
            endPoint: Point2D(x: 5000, y: 0),
          ),
        );

        await tester.pumpWidget(buildEditorApp(container));
        await tester.pumpAndSettle();

        // Backspace is also mapped to DeleteIntent.
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'Escape key does not throw provider-during-build error',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(buildEditorApp(container));
        await tester.pumpAndSettle();

        // Escape — increments toolCancelProvider.
        // ref.listen fires the callback post-build, not during
        // build, so no Riverpod error should occur.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'rapid Delete then Escape sequence does not throw',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(editorStateProvider.notifier).addWall(
          const WallSegment(
            id: 'wall-1',
            roomId: '',
            startPoint: Point2D(x: 0, y: 0),
            endPoint: Point2D(x: 5000, y: 0),
          ),
        );

        await tester.pumpWidget(buildEditorApp(container));
        await tester.pumpAndSettle();

        // Fire both signals in quick succession.
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  });
}
