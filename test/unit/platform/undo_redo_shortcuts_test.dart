// Undo / redo must be reachable with Ctrl (Windows, Linux) and with Cmd
// (macOS, which Flutter reports as "meta") — ADR-042 Rule 1.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/core/theme/app_theme.dart';
import 'package:heating_planner/platform/keyboard_shortcuts.dart';

Intent? _intentFor(
  LogicalKeyboardKey key, {
  bool control = false,
  bool meta = false,
  bool shift = false,
}) {
  for (final entry in editorShortcuts.entries) {
    final a = entry.key;
    if (a is SingleActivator &&
        a.trigger == key &&
        a.control == control &&
        a.meta == meta &&
        a.shift == shift) {
      return entry.value;
    }
  }
  return null;
}

void main() {
  test('Ctrl+Z and Cmd+Z undo', () {
    expect(
      _intentFor(LogicalKeyboardKey.keyZ, control: true),
      isA<UndoIntent>(),
    );
    expect(_intentFor(LogicalKeyboardKey.keyZ, meta: true), isA<UndoIntent>());
  });

  test('Ctrl+Y and Cmd+Y redo', () {
    expect(
      _intentFor(LogicalKeyboardKey.keyY, control: true),
      isA<RedoIntent>(),
    );
    expect(_intentFor(LogicalKeyboardKey.keyY, meta: true), isA<RedoIntent>());
  });

  test('Ctrl+Shift+Z and Cmd+Shift+Z redo', () {
    expect(
      _intentFor(LogicalKeyboardKey.keyZ, control: true, shift: true),
      isA<RedoIntent>(),
    );
    expect(
      _intentFor(LogicalKeyboardKey.keyZ, meta: true, shift: true),
      isA<RedoIntent>(),
    );
  });

  test('the zone identity palette has ten distinct colours', () {
    final palette = HeatingPlannerColors.light().zonePalette;
    expect(palette, hasLength(10));
    expect(palette.toSet(), hasLength(10));
  });
}
