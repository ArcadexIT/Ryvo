import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/app_providers.dart';
import 'app_colors.dart';

/// Single source of truth for pushing a theme change through the whole app.
///
/// Ryvo screens read colors from the `AppColors` static getters rather than
/// `Theme.of(context)`. A static getter creates no inherited-widget dependency,
/// so a widget that is `const`, cached (`_map ??=`), or parked inside a
/// `StatefulShellRoute.indexedStack` branch is never told that the colors
/// changed. [MaterialApp] rebuilding is not enough: Flutter skips any child
/// whose widget instance is identical to the previous one.
///
/// The fix is to do exactly what a hot reload does, in two ordered steps:
///   1. [apply] flips `AppColors` synchronously, before any build runs.
///   2. [rebuildAll] marks every mounted element dirty, so the next frame
///      rebuilds the full tree (active route, offstage shell tabs, drawers,
///      overlays) against the new palette. State, scroll offsets, and the
///      native map view are preserved because elements are only rebuilt,
///      never recreated.
abstract final class ThemeSync {
  /// Brightness the app renders for [mode] right now.
  static Brightness effectiveBrightness(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
  }

  /// Pushes [mode] into `AppColors` and returns the brightness it resolved to.
  static Brightness apply(ThemeMode mode) {
    final next = effectiveBrightness(mode);
    AppColors.updateBrightness(next);
    return next;
  }

  /// Marks every active element dirty so static-getter readers repaint.
  static void rebuildAll() {
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => _markAllDirty());
    } else {
      _markAllDirty();
    }
  }

  static void _markAllDirty() {
    void visit(Element element) {
      element.markNeedsBuild();
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }
}

/// Listens for both theme triggers and runs [ThemeSync] for each:
/// the user picking a mode, and the OS flipping light/dark while the mode is
/// `ThemeMode.system`. Place it below `MaterialApp` (in its `builder`).
class ThemeSyncScope extends ConsumerStatefulWidget {
  const ThemeSyncScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ThemeSyncScope> createState() => _ThemeSyncScopeState();
}

class _ThemeSyncScopeState extends ConsumerState<ThemeSyncScope>
    with WidgetsBindingObserver {
  /// Brightness the tree was last fully rebuilt for. Tracked here rather than
  /// read back from `AppColors`, which `MaterialApp.builder` also writes.
  late Brightness _rebuiltFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rebuiltFor = ThemeSync.apply(ref.read(themeModeProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (ref.read(themeModeProvider) == ThemeMode.system) _sync();
  }

  void _sync() {
    final next = ThemeSync.apply(ref.read(themeModeProvider));
    if (next == _rebuiltFor) return;
    _rebuiltFor = next;
    ThemeSync.rebuildAll();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ThemeMode>(themeModeProvider, (_, __) => _sync());
    return widget.child;
  }
}
