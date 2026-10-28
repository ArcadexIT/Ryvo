import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigate based on FCM data payload from the Ryvo API.
void navigateFromPushMessage(BuildContext context, RemoteMessage message) {
  final type = message.data['type'] ?? '';
  final jobId = message.data['jobId'];

  switch (type) {
    case 'job_offer':
      context.go('/home');
    case 'chat_message':
      if (jobId != null && jobId.isNotEmpty) {
        context.push('/chat/$jobId');
      } else {
        context.push('/notifications');
      }
    default:
      context.push('/notifications');
  }
}
