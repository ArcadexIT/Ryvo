import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/push_messaging.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/global_error_boundary.dart';
import 'core/widgets/push_notification_listener.dart';
import 'shared/models/app_config.dart';
import 'shared/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushMessaging.instance.init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const ProviderScope(child: RyvoDriverApp()));
}

class RyvoDriverApp extends ConsumerStatefulWidget {
  const RyvoDriverApp({super.key});

  @override
  ConsumerState<RyvoDriverApp> createState() => _RyvoDriverAppState();
}

class _RyvoDriverAppState extends ConsumerState<RyvoDriverApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _linkSub = _appLinks.uriLinkStream.listen(_openStripeReturn);
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _openStripeReturn(uri);
    });
  }

  void _openStripeReturn(Uri uri) {
    if (uri.scheme != 'ryvodriver') return;
    ref.read(routerProvider).go('/wallet');
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final config = ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    ActiveCurrency.apply(config.currency);
    return PushNotificationListener(
      child: GlobalErrorBoundary(
        child: MaterialApp.router(
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
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          routerConfig: router,
        ),
      ),
    );
  }
}
