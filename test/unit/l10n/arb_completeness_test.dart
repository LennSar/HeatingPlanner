// Verifies that the English and German ARB files are
// complete and consistent.
//
// Per agent-test.md §3.1. Pure Dart test — no Flutter
// dependencies required.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> enArb;
  late Map<String, dynamic> deArb;

  /// User-visible translation keys (no `@@` or `@`
  /// prefix).
  late Set<String> enKeys;
  late Set<String> deKeys;

  /// `@`-prefixed metadata keys from the template ARB.
  late Set<String> enMetaKeys;

  setUpAll(() {
    final enFile =
        File('lib/l10n/app_en.arb').readAsStringSync();
    final deFile =
        File('lib/l10n/app_de.arb').readAsStringSync();

    enArb = jsonDecode(enFile) as Map<String, dynamic>;
    deArb = jsonDecode(deFile) as Map<String, dynamic>;

    enKeys = enArb.keys
        .where((k) => !k.startsWith('@@') && !k.startsWith('@'))
        .toSet();
    deKeys = deArb.keys
        .where((k) => !k.startsWith('@@') && !k.startsWith('@'))
        .toSet();
    enMetaKeys = enArb.keys
        .where(
          (k) => k.startsWith('@') && !k.startsWith('@@'),
        )
        .map((k) => k.substring(1))
        .toSet();
  });

  test('every EN key exists in DE', () {
    final missing = enKeys.difference(deKeys);
    expect(
      missing,
      isEmpty,
      reason:
          'DE ARB is missing keys: ${missing.join(', ')}',
    );
  });

  test('every DE key exists in EN', () {
    final extra = deKeys.difference(enKeys);
    expect(
      extra,
      isEmpty,
      reason:
          'DE ARB has extra keys: ${extra.join(', ')}',
    );
  });

  test('every EN key has @ metadata', () {
    final missing = enKeys.difference(enMetaKeys);
    expect(
      missing,
      isEmpty,
      reason: 'EN ARB keys missing @-metadata: '
          '${missing.join(', ')}',
    );
  });

  test('no DE key has @ metadata (only template)', () {
    final deMeta = deArb.keys
        .where(
          (k) => k.startsWith('@') && !k.startsWith('@@'),
        )
        .toList();
    expect(
      deMeta,
      isEmpty,
      reason: 'DE ARB should not contain @-metadata '
          'keys: ${deMeta.join(', ')}',
    );
  });
}
