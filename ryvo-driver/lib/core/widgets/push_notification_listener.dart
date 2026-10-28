import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../network/push_messaging.dart';
import '../network/push_navigation.dart';
import '../router/app_router.dart';

/// Wires FCM tap / cold-start opens to [GoRouter] navigation.
class PushNotificationListener extends StatefulWidget {
  const PushNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  State<PushNotificationListener> createState() => _PushNotificationListenerState();
}

class _PushNotificationListenerState extends State<PushNotificationListener> {
  @override
  void initState() {
    super.initState();
    PushMessaging.instance.onNotificationOpened = _onOpened;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushMessaging.instance.consumePendingOpenedMessage();
    });
  }

  @override
  void dispose() {
    PushMessaging.instance.onNotificationOpened = null;
    super.dispose();
  }

  void _onOpened(RemoteMessage message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    navigateFromPushMessage(context, message);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
