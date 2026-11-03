import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ryvo_customer/core/theme/app_colors.dart';
import 'package:ryvo_customer/core/theme/ryvo_theme_transition_portal.dart';
import 'package:ryvo_customer/core/theme/theme_sync.dart';
import 'package:ryvo_customer/features/profile/presentation/pages/appearance_page.dart';
import 'package:ryvo_customer/features/profile/presentation/widgets/theme_mode_card.dart';
import 'package:ryvo_customer/features/profile/presentation/widgets/theme_preview_stage.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';
import 'package:ryvo_customer/shared/providers/app_providers.dart';

class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        ThemeSync.apply(themeMode);
        return ThemeSyncScope(
          child: RyvoThemeTransitionPortal(child: child!),
        );
      },
      home: const AppearancePage(),
    );
  }
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 50);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _tapMode(WidgetTester tester, int index) async {
  await tester.tap(find.byType(ThemeModeCard).at(index));
  // toImage resolves on the real event loop.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
}

Future<void> _body(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const _App()),
  );
  await _pumpFor(tester, const Duration(milliseconds: 800));

  expect(find.byType(ThemePreviewStage), findsOneWidget);
  expect(find.byType(ThemeModeCard), findsNWidgets(3));

  await _tapMode(tester, 1);
  expect(container.read(themeModeProvider), ThemeMode.dark);
  expect(AppColors.isDark, isTrue);
  expect(find.byType(RawImage), findsOneWidget);
  await _pumpFor(tester, const Duration(milliseconds: 1400));
  expect(find.byType(RawImage), findsNothing);

  // Device is light, so System flips the palette back through the portal.
  await _tapMode(tester, 2);
  expect(container.read(themeModeProvider), ThemeMode.system);
  expect(AppColors.isDark, isFalse);
  await _pumpFor(tester, const Duration(milliseconds: 1400));
  expect(find.byType(RawImage), findsNothing);

  await _tapMode(tester, 0);
  expect(container.read(themeModeProvider), ThemeMode.light);
  await _pumpFor(tester, const Duration(milliseconds: 900));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => AppColors.updateBrightness(Brightness.light));

  testWidgets('HUD lays out, selects, and fires the portal from the tap',
      (tester) async {
    await runZonedGuarded(() => _body(tester), (error, stack) {
      // Bundled Plus Jakarta Sans files are absent under flutter_test.
      if (!error.toString().contains('GoogleFonts')) {
        Error.throwWithStackTrace(error, stack);
      }
    });
  });
}
