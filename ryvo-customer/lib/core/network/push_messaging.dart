import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../firebase_options.dart';

const _androidChannelId = 'ryvo_notifications';
const _androidChannelName = 'Ryvo Notifications';

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
  Completer<void>? _readyCompleter;
  final _readyListeners = <Future<void> Function()>[];

  final _local = FlutterLocalNotificationsPlugin();
  final _foreground = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onForegroundMessage => _foreground.stream;

  void Function(RemoteMessage message)? onNotificationOpened;
  RemoteMessage? _pendingOpenedMessage;

  bool get isAvailable => _available;

  /// Register a callback to run once push init completes (or immediately if done).
  void addReadyListener(Future<void> Function() listener) {
    if (_initialized) {
      unawaited(listener());
      return;
    }
    _readyListeners.add(listener);
  }

  /// Completes when [init] finishes (success or failure).
  Future<void> whenReady() {
    if (_initialized) return Future.value();
    _readyCompleter ??= Completer<void>();
    return _readyCompleter!.future;
  }

  Future<void> init() async {
    if (_initialized) return;
    _readyCompleter ??= Completer<void>();

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }

      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await ensureLocalNotificationsReady();
      await _requestPermissions();

      FirebaseMessaging.onMessage.listen((message) {
        if (kDebugMode) {
          debugPrint(
            'FCM foreground: ${message.notification?.title ?? message.data['title'] ?? message.data}',
          );
        }
        _foreground.add(message);
        showLocalNotification(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_dispatchOpened);

      if (Platform.isIOS) {
        try {
          await FirebaseMessaging.instance
              .setForegroundNotificationPresentationOptions(
                alert: true,
                badge: true,
                sound: true,
              )
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          if (kDebugMode) debugPrint('Foreground presentation options skipped: $e');
        }
      }

      // Mark ready before optional slow iOS calls (getInitialMessage can hang).
      _available = true;
      if (kDebugMode) debugPrint('Push ready');

      unawaited(_loadInitialMessage());
    } catch (e, st) {
      if (kDebugMode) debugPrint('Push init failed: $e\n$st');
      _available = false;
    } finally {
      _initialized = true;
      if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
        _readyCompleter!.complete();
      }
      for (final listener in _readyListeners) {
        unawaited(listener());
      }
      _readyListeners.clear();
    }
  }

  Future<void> _loadInitialMessage() async {
    try {
      final initial = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 3));
      if (initial != null) _pendingOpenedMessage = initial;
    } catch (_) {
      // Cold-start message is optional; never block push setup on this call.
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
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
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
    final title = notification?.title ?? message.data['title'] ?? 'Ryvo';
    final body = notification?.body ?? message.data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _local.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data['type'],
    );
  }

  Future<void> _requestPermissions() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('FCM permission: ${settings.authorizationStatus}');
    }
    if (Platform.isIOS) {
      await _local
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }

  Future<String?> getToken() async {
    if (!_initialized) await whenReady();
    if (!_available) return null;

    try {
      if (Platform.isIOS) {
        String? apns;
        const maxWait = Duration(seconds: 15);
        final deadline = DateTime.now().add(maxWait);
        var attempt = 0;
        while (DateTime.now().isBefore(deadline)) {
          apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns != null) {
            if (kDebugMode) debugPrint('APNs token ready');
            break;
          }
          attempt++;
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
        if (apns == null && kDebugMode) {
          debugPrint(
            'APNs token still null — in Xcode enable Push Notifications for '
            'com.ryvo.customer (Team PKL9VLU62B) and upload the .p8 key '
            'to Firebase with the same Team ID.',
          );
        }
      }

      final token = await FirebaseMessaging.instance.getToken().timeout(
            const Duration(seconds: 10),
          );
      if (kDebugMode) {
        debugPrint(token != null
            ? 'FCM token acquired (${token.length} chars)'
            : 'FCM token is null');
      }
      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('FCM getToken failed: $e');
      return null;
    }
  }

  Stream<String> get onTokenRefresh {
    return FirebaseMessaging.instance.onTokenRefresh;
  }
}
