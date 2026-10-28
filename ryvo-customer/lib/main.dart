import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/push_messaging.dart';
import 'core/payments/stripe_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/push_notification_listener.dart';
import 'data/models/app_config.dart';
import 'data/models/currency.dart';
import 'firebase_options.dart';
import 'shared/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  AppColors.updateBrightness(Brightness.light);

  // Show UI immediately — never block runApp on push permission / APNs.
  runApp(
    const ProviderScope(
      child: PushNotificationListener(child: RyvoApp()),
    ),
  );

  unawaited(_initializeServices());
}

Future<void> _initializeServices() async {
  await PushMessaging.instance.init();

  try {
    final appConfig = await fetchAppConfig();
    if (appConfig.paymentMethods.stripe) {
      await configureStripeFromAppConfig(appConfig);
    }
  } catch (e) {
    debugPrint('Stripe init skipped: $e');
  }
}

class RyvoApp extends ConsumerWidget {
  const RyvoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final config = ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    ActiveCurrency.apply(config.currency);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        AppColors.updateBrightness(brightness);
        SystemChrome.setSystemUIOverlayStyle(
          brightness == Brightness.dark
              ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
              : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        );
        return child ??
            const ColoredBox(
              color: Color(0xFFFFFFFF),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
      },
      routerConfig: router,
    );
  }
}
