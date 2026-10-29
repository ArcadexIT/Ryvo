import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../features/payment/presentation/widgets/payment_sheet.dart';
import 'active_job_session.dart';

/// Opens the in-progress customer job. Unpaid checkout stays in the payment dialog.
Future<void> resumeCustomerJob(
  BuildContext context,
  JobModel job, {
  bool replace = false,
}) async {
  final status = effectiveCustomerJobStatus(job);
  if (status == 'payment_pending') {
    final route = await showRyvoCheckoutSheet(context);
    if (!context.mounted) return;
    if (route != null) {
      context.go(route);
    } else if (replace) {
      context.go('/home');
    }
    return;
  }

  final route = routeForActiveCustomerJob(status);
  if (replace) {
    context.go(route);
  } else {
    context.push(route);
  }
}
