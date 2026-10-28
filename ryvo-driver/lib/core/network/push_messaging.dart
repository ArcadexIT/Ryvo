import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../firebase_options.dart';

const _androidChannelId = 'ryvo_driver_notifications';
const _androidChannelName = 'Ryvo Driver Notifications';

/// Background FCM handler — must be top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushMessaging.instance.ensureLocalNotificationsReady();
  await PushMessaging.instance.showLocalNotification(message);
}

/// Firebase Cloud Messaging + local notification display.
class PushMessaging {
  PushMessaging._();
  static final PushMessaging instance = PushMessaging._();

  bool _initialized = false;
  bool _available = false;
  bool _localReady = false;

  final _local = FlutterLocalNotificationsPlugin();
  final _foreground = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onForegroundMessage => _foreground.stream;

  void Function(RemoteMessage message)? onNotificationOpened;
  RemoteMessage? _pendingOpenedMessage;

  bool get isAvailable => _available;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await ensureLocalNotificationsReady();
      await _requestPermissions();

      FirebaseMessaging.onMessage.listen((message) {
        _foreground.add(message);
        showLocalNotification(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_dispatchOpened);

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingOpenedMessage = initial;

      _available = true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Push init skipped: $e\n$st');
      _available = false;
    }
  }

  void consumePendingOpenedMessage() {
    final msg = _pendingOpenedMessage;
    if (msg != null) {
      _pendingOpenedMessage = null;
      _dispatchOpened(msg);
    }
  }

  void _dispatchOpened(RemoteMessage message) {
    onNotificationOpened?.call(message);
  }

  Future<void> ensureLocalNotificationsReady() async {
    if (_localReady) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final type = response.payload;
        if (type == null || type.isEmpty) return;
        _dispatchOpened(RemoteMessage(data: {'type': type}));
      },
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _androidChannelId,
              _androidChannelName,
              importance: Importance.high,
            ),
          );
    }
    _localReady = true;
  }

  Future<void> showLocalNotification(RemoteMessage message) async {
    if (!_localReady) return;

    final notification = message.notification;
    final title = notification?.title ?? 'Ryvo Driver';
    final body = notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _local.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data['type'],
    );
  }

  Future<void> _requestPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }

  Future<String?> getToken() async {
    if (!_available) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Stream<String> get onTokenRefresh {
    if (!_available) return const Stream<String>.empty();
    return FirebaseMessaging.instance.onTokenRefresh;
  }
}
