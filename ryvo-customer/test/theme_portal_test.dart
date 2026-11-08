import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryvo_customer/core/theme/app_colors.dart';
import 'package:ryvo_customer/core/theme/ryvo_theme_transition_portal.dart';
import 'package:ryvo_customer/core/theme/theme_sync.dart';
import 'package:ryvo_customer/shared/providers/app_providers.dart';

/// `const` and reading a static getter: the exact shape that used to go stale
/// inside cached shell tabs.
class _ConstProbe extends StatelessWidget {
  const _ConstProbe(this.keyName);

  final String keyName;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: ValueKey(keyName),
      color: AppColors.background,
      child: const SizedBox.expand(),
    );
  }
}

class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) {
        ThemeSync.apply(themeMode);
        return ThemeSyncScope(
          child: RyvoThemeTransitionPortal(child: child!),
        );
      },
      // Two cached tabs, one offstage, both const.
      home: const IndexedStack(
        children: [_ConstProbe('active'), _ConstProbe('cached')],
      ),
    );
  }
}

Color _colorOf(WidgetTester tester, String key) {
  final box = tester.widget<ColoredBox>(
    find.byKey(ValueKey(key), skipOffstage: false),
  );
  return box.color;
}

void main() {
  setUp(() => AppColors.updateBrightness(Brightness.light));

  testWidgets('const + cached widgets repaint when the mode changes',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _Harness(),
      ),
    );
    expect(_colorOf(tester, 'active'), AppColors.backgroundLight);

    container.read(themeModeProvider.notifier).state = ThemeMode.dark;
    await tester.pump();

    expect(_colorOf(tester, 'active'), AppColors.backgroundDark);
    expect(_colorOf(tester, 'cached'), AppColors.backgroundDark);
  });

  testWidgets('OS brightness flip repaints while mode is system',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(themeModeProvider.notifier).state = ThemeMode.system;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _Harness(),
      ),
    );
    expect(_colorOf(tester, 'cached'), AppColors.backgroundLight);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();

    expect(_colorOf(tester, 'active'), AppColors.backgroundDark);
    expect(_colorOf(tester, 'cached'), AppColors.backgroundDark);
  });

  testWidgets('portal swaps the theme under an overlay, then cleans up',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _Harness(),
      ),
    );

    await tester.runAsync(
      () => RyvoThemeTransitionPortal.trigger(
        const Offset(200, 300),
        ThemeMode.dark,
      ),
    );
    await tester.pump();

    // Theme already switched underneath; the old frame is overlaid.
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(_colorOf(tester, 'active'), AppColors.backgroundDark);
    expect(find.byType(RawImage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 275));
    expect(find.byType(RawImage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(RawImage), findsNothing);

    // A second switch works after cleanup.
    await tester.runAsync(
      () => RyvoThemeTransitionPortal.trigger(
        const Offset(10, 10),
        ThemeMode.light,
      ),
    );
    await tester.pump();
    expect(_colorOf(tester, 'cached'), AppColors.backgroundLight);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('system mode that keeps the same palette skips the portal',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _Harness(),
      ),
    );

    await tester.runAsync(
      () => RyvoThemeTransitionPortal.trigger(Offset.zero, ThemeMode.system),
    );
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(find.byType(RawImage), findsNothing);
  });
}
