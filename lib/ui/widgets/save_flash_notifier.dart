import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier that tracks whether the manual-save "✓ Saved" flash
/// confirmation should be displayed in the status bar.
///
/// [trigger] is called immediately after a successful manual save
/// (Ctrl/Cmd+S or Ctrl/Cmd+Shift+S, or toolbar save buttons). The
/// flash state is `true` for exactly 2 seconds, then reverts to `false`.
///
/// Autosave does NOT trigger the flash — only manual user-initiated
/// saves do (agent-ui-ux.md §12.7).
class SaveFlashNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  /// Shows the highlighted "✓ Saved" for 2 seconds then clears it.
  ///
  /// Calling [trigger] while a flash is already active resets the
  /// 2-second window.
  void trigger() {
    _timer?.cancel();
    state = true;
    _timer = Timer(const Duration(seconds: 2), () {
      state = false;
    });
  }
}

/// `true` for exactly 2 seconds after a manual save, then `false`.
///
/// Consumed by `SaveStateIndicator` to briefly highlight a
/// "✓ Saved" confirmation after Ctrl/Cmd+S or Ctrl/Cmd+Shift+S.
final saveFlashProvider =
    NotifierProvider<SaveFlashNotifier, bool>(
  SaveFlashNotifier.new,
);
