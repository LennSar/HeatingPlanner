// Tests for LanguageCodeNotifier and languageCodeProvider.
//
// Per agent-test.md §3.1. Uses InMemorySharedPreferencesAsync
// so no real platform channel is needed.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/repositories/app_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  ProviderContainer buildContainer() {
    return ProviderContainer();
  }

  test(
    'defaults to en when no stored value',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final code = await container
          .read(languageCodeProvider.future);
      expect(code, 'en');
    },
  );

  test(
    'set de persists and subsequent reads return de',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      await container
          .read(languageCodeProvider.notifier)
          .set('de');

      final code = await container
          .read(languageCodeProvider.future);
      expect(code, 'de');

      // Verify persistence via a fresh AppPreferences
      // read.
      final stored =
          await AppPreferences().getLanguageCode();
      expect(stored, 'de');
    },
  );

  test(
    'set en after de switches back correctly',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      await container
          .read(languageCodeProvider.notifier)
          .set('de');
      expect(
        await container
            .read(languageCodeProvider.future),
        'de',
      );

      await container
          .read(languageCodeProvider.notifier)
          .set('en');
      expect(
        await container
            .read(languageCodeProvider.future),
        'en',
      );

      final stored =
          await AppPreferences().getLanguageCode();
      expect(stored, 'en');
    },
  );

  test(
    'unsupported code is stored as-is — no validation',
    () async {
      // LanguageCodeNotifier does NOT validate language
      // codes. Validation happens at the MaterialApp
      // level via supportedLocales. The notifier blindly
      // persists whatever string is passed in.
      final container = buildContainer();
      addTearDown(container.dispose);

      await container
          .read(languageCodeProvider.notifier)
          .set('fr');

      final code = await container
          .read(languageCodeProvider.future);
      expect(code, 'fr');

      final stored =
          await AppPreferences().getLanguageCode();
      expect(stored, 'fr');
    },
  );
}
