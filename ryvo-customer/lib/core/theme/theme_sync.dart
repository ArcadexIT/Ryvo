import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/app_providers.dart';

/// Forces the wrapped route page to rebuild the instant the app theme
/// changes.
///
/// Pages read colors from the global `AppColors` static getters instead of
/// `Theme.of(context)`, so they normally only repaint when something else
/// happens to rebuild them. `StatefulShellRoute.indexedStack` (used for the
/// bottom-nav tabs) intentionally caches each tab's navigator to preserve
/// scroll/form state, which blocks the usual ancestor-to-descendant rebuild
/// cascade from reaching page bodies when [MaterialApp]'s theme changes.
///
/// Wrapping route content in this widget sidesteps that entirely: `ref.watch`
/// registers this widget's element directly with Riverpod, so it gets
/// rebuilt the moment [themeModeProvider] changes — the same direct
/// mechanism `setState` uses — regardless of what the surrounding
/// Navigator/IndexedStack decides to do.
class ThemeSync extends ConsumerWidget {
  final WidgetBuilder builder;
  const ThemeSync({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    return builder(context);
  }
}
