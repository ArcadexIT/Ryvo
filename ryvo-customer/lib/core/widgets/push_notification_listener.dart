import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/push_messaging.dart';
import '../network/push_navigation.dart';
import '../router/app_router.dart';
import '../../shared/providers/app_providers.dart';

/// Wires FCM tap / cold-start opens to [GoRouter] navigation.
class PushNotificationListener extends ConsumerStatefulWidget {
  const PushNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushNotificationListener> createState() =>
      _PushNotificationListenerState();
}

class _PushNotificationListenerState extends ConsumerState<PushNotificationListener>
    with WidgetsBindingObserver {
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushMessaging.instance.onNotificationOpened = _onOpened;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _container = ProviderScope.containerOf(context, listen: false);
      PushMessaging.instance.addReadyListener(_syncFcmToken);
      PushMessaging.instance.consumePendingOpenedMessage();
      _syncFcmToken();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushMessaging.instance.onNotificationOpened = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncFcmToken();
    }
  }

  Future<void> _syncFcmToken() async {
    final container = _container;
    if (container == null) return;
    await syncFcmTokenWithContainer(container);
  }

  void _onOpened(RemoteMessage message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    navigateFromPushMessage(context, message);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
