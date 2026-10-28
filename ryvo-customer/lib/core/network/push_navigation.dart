import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/job/active_job_session.dart';
import '../../shared/providers/app_providers.dart';

/// Navigate based on FCM data payload from the Ryvo API.
Future<void> navigateFromPushMessage(BuildContext context, RemoteMessage message) async {
  final container = ProviderScope.containerOf(context, listen: false);
  await fetchAndApplyActiveJob(container);
  if (!context.mounted) return;

  final type = message.data['type'] ?? '';
  final jobId = message.data['jobId'];
  final status = message.data['status'] as String?;

  switch (type) {
    case 'chat_message':
      if (jobId != null && jobId.isNotEmpty) {
        context.push('/chat/$jobId');
      } else {
        context.push('/notifications');
      }
    case 'payment_required':
    case 'provider_assigned':
    case 'job_matched':
    case 'job_provider_en_route':
    case 'job_arrived':
    case 'job_in_progress':
      context.push(routeForActiveCustomerJob(status ?? 'matched'));
    case 'job_completed':
      if (jobId != null && jobId.isNotEmpty) {
        try {
          final job = await container.read(jobRepositoryProvider).getJob(jobId);
          applyJobToDraft(container, job);
        } catch (_) {}
      }
      if (!context.mounted) return;
      context.go('/payment-success');
    default:
      context.push('/notifications');
  }
}
