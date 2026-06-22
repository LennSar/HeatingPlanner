import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application-wide owner of the single native [PlatformMenuBar].
///
/// Flutter permits only **one** active [PlatformMenuBar] in the widget tree at
/// a time: it locks a global delegate in `initState` and releases it in
/// `dispose`, so a second instance trips
/// "More than one active PlatformMenuBar detected". Because screens are stacked
/// by the [Navigator] — the editor pushed over the project list, or the brief
/// overlap while a route transition animates — more than one screen is mounted
/// simultaneously, so giving each screen its own [PlatformMenuBar] crashes
/// (notably when closing a project back to the list).
///
/// Instead a single [AppMenuBar] lives above the [Navigator] and screens
/// contribute their menus through a [MenuBarScope]. Contributions form a stack:
/// the top-most (most recently mounted) screen's menus are shown, and the one
/// below is restored when the front screen is popped.
class MenuBarHost extends ChangeNotifier {
  final List<_MenuEntry> _stack = <_MenuEntry>[];
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// Menus of the top-most contributor, or empty when none is mounted.
  List<PlatformMenuItem> get menus =>
      _stack.isEmpty ? const <PlatformMenuItem>[] : _stack.last.menus;

  /// Adds, or updates in place, [owner]'s [menus]. An existing owner keeps its
  /// stack position so a rebuild never reorders the menu bar.
  void register(Object owner, List<PlatformMenuItem> menus) {
    final index = _stack.indexWhere((e) => identical(e.owner, owner));
    if (index >= 0) {
      _stack[index] = _MenuEntry(owner, menus);
    } else {
      _stack.add(_MenuEntry(owner, menus));
    }
    _scheduleNotify();
  }

  /// Removes [owner]'s contribution.
  void unregister(Object owner) {
    _stack.removeWhere((e) => identical(e.owner, owner));
    _scheduleNotify();
  }

  // register/unregister are called during a descendant's build or dispose,
  // when notifying synchronously would rebuild the ancestor [AppMenuBar]
  // mid-frame. Coalesce to a single notification at the end of the frame.
  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (_disposed) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _MenuEntry {
  const _MenuEntry(this.owner, this.menus);
  final Object owner;
  final List<PlatformMenuItem> menus;
}

/// Riverpod handle to the application's single [MenuBarHost].
final menuBarHostProvider = Provider<MenuBarHost>((ref) {
  final host = MenuBarHost();
  ref.onDispose(host.dispose);
  return host;
});

/// The application's single [PlatformMenuBar]. Place above the [Navigator]
/// (e.g. via `MaterialApp.builder`) so it never unmounts; its menus follow the
/// top-most mounted [MenuBarScope].
class AppMenuBar extends ConsumerWidget {
  /// Creates an [AppMenuBar] wrapping [child].
  const AppMenuBar({required this.child, super.key});

  /// The widget subtree below the menu bar (usually the [Navigator]).
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(menuBarHostProvider);
    return ListenableBuilder(
      listenable: host,
      builder: (context, _) => PlatformMenuBar(
        menus: host.menus,
        child: child,
      ),
    );
  }
}

/// Contributes [menus] to the application's [AppMenuBar] while this widget is
/// mounted, then restores the previous menus on dispose. Renders [child]
/// unchanged — it never builds its own [PlatformMenuBar].
class MenuBarScope extends ConsumerStatefulWidget {
  /// Creates a [MenuBarScope] contributing [menus] for the duration of [child].
  const MenuBarScope({required this.menus, required this.child, super.key});

  /// Top-level menus to publish while mounted.
  final List<PlatformMenuItem> menus;

  /// The subtree this scope wraps; returned unchanged.
  final Widget child;

  @override
  ConsumerState<MenuBarScope> createState() => _MenuBarScopeState();
}

class _MenuBarScopeState extends ConsumerState<MenuBarScope> {
  // Cached so dispose() never touches `ref` after the widget is deactivated.
  MenuBarHost? _host;

  @override
  void initState() {
    super.initState();
    final host = ref.read(menuBarHostProvider);
    _host = host;
    host.register(this, widget.menus);
  }

  @override
  void didUpdateWidget(MenuBarScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Menu items capture fresh closures each rebuild, so always re-publish.
    _host?.register(this, widget.menus);
  }

  @override
  void dispose() {
    _host?.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
