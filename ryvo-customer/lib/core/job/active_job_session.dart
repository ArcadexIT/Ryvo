import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../shared/providers/app_providers.dart';

/// A job row exists only so payment can be attached to it. Until the customer
/// confirms payment, that row is not a real request and must not stay active.
bool isUnpaidCheckoutJob(JobModel job) {
  if (job.status.trim().toLowerCase() != 'payment_pending') return false;
  final payment = job.paymentStatus;
  return payment != 'held' && payment != 'paid';
}

/// Unpaid checkout rows are removed unless this session is charging them now,
/// or the provider already accepted a payment that the job has not confirmed.
bool shouldAbandonUnpaidCheckout({
  required JobModel job,
  required bool checkoutInProgress,
  required bool awaitingConfirmation,
  String? awaitingJobId,
}) {
  if (!isUnpaidCheckoutJob(job)) return false;
  if (checkoutInProgress) return false;
  if (awaitingConfirmation && awaitingJobId == job.id) return false;
  return true;
}

/// Statuses where the customer can resume an in-flight service from home/splash.
const customerResumableStatuses = {
  'searching',
  'payment_pending',
  'matched',
  'provider_en_route',
  'arrived',
  'in_progress',
};

/// Corrects stale API statuses (e.g. `payment_pending` after payment or completion).
String effectiveCustomerJobStatus(JobModel job) {
  final status = job.status.trim().toLowerCase();
  if (job.completedAt != null || status == 'completed') return 'completed';
  if (job.cancelledAt != null || status.startsWith('cancelled')) {
    return status.startsWith('cancelled') ? status : 'cancelled_by_customer';
  }
  if (status == 'no_provider_found') return status;
  if (status == 'payment_pending') {
    final paymentSecured = job.paymentStatus == 'held' || job.paymentStatus == 'paid';
    if (job.startedAt != null) return 'completed';
    if (job.provider != null) return 'matched';
    if (paymentSecured) return 'searching';
  }
  return status;
}

bool isResumableCustomerJob(JobModel? job) {
  if (job == null) return false;
  final status = effectiveCustomerJobStatus(job);
  if (status == 'completed' || status.startsWith('cancelled') || status == 'no_provider_found') {
    return false;
  }
  return customerResumableStatuses.contains(status);
}

/// Route to resume the customer job flow after a cold start or back navigation.
String routeForActiveCustomerJob(String status) {
  return switch (status) {
    'searching' => '/searching',
    // Checkout is the payment dialog. Home is only a fallback if a caller
    // still asks for a route while a charge is unfinished.
    'payment_pending' => '/home',
    'matched' || 'provider_en_route' || 'arrived' => '/live-tracking',
    'in_progress' => '/in-progress',
    'no_provider_found' => '/no-providers',
    _ => '/home',
  };
}

String routeForActiveCustomerJobModel(JobModel job) {
  return routeForActiveCustomerJob(effectiveCustomerJobStatus(job));
}

/// Human-readable headline for the home-page active job banner.
String activeJobHeadline(String status) {
  return switch (status) {
    'searching' => 'Finding a driver…',
    'payment_pending' => 'Complete payment to confirm',
    'matched' => 'Driver assigned',
    'provider_en_route' => 'Driver is on the way',
    'arrived' => 'Driver has arrived',
    'in_progress' => 'Trip in progress',
    _ => formatJobStatus(status),
  };
}

String activeJobHeadlineForModel(JobModel job) {
  return activeJobHeadline(effectiveCustomerJobStatus(job));
}

void clearActiveJobSession(ProviderContainer container) {
  final draft = container.read(jobDraftProvider);
  if (draft.activeJob != null) {
    container.read(jobDraftProvider.notifier).state =
        draft.copyWith(clearActiveJob: true);
  }
}

/// Clears in-flight booking state but keeps the resolved pickup location.
void resetJobRequestDraft(ProviderContainer container) {
  final current = container.read(jobDraftProvider);
  container.read(jobDraftProvider.notifier).state = JobRequestDraft(
    pickupAddress: current.pickupAddress,
    pickupLat: current.pickupLat,
    pickupLng: current.pickupLng,
    pickupRegion: current.pickupRegion,
    locationResolved: current.locationResolved,
  );
}

/// Call when a job is done, cancelled, or the user leaves the service flow.
void markJobSessionFinished(ProviderContainer container, {String? jobId}) {
  container.read(paymentCheckoutInProgressProvider.notifier).state = false;
  container.read(paymentAwaitingConfirmationProvider.notifier).state = false;
  if (jobId != null && jobId.isNotEmpty) {
    final finished = {...container.read(finishedJobIdsProvider)};
    finished.add(jobId);
    container.read(finishedJobIdsProvider.notifier).state = finished;
    try {
      container.read(trackingSocketProvider).unsubscribeJob(jobId);
    } catch (_) {}
  }
  clearActiveJobSession(container);
  resetJobRequestDraft(container);
  container.invalidate(jobsListProvider);
}

/// Writes [job] into the draft for payment / rating flows (any terminal status).
void applyJobToDraft(ProviderContainer container, JobModel job) {
  final current = container.read(jobDraftProvider);
  container.read(jobDraftProvider.notifier).state = current.copyWith(
    activeJob: job,
    pickupAddress: job.pickupAddress,
    pickupLat: job.pickupLat,
    pickupLng: job.pickupLng,
    locationResolved: true,
    serviceCategory: job.serviceCategory ?? current.serviceCategory,
    vehicle: job.vehicle ?? current.vehicle,
  );
}

void applyActiveJobSession(ProviderContainer container, JobModel job) {
  if (container.read(finishedJobIdsProvider).contains(job.id)) {
    clearActiveJobSession(container);
    return;
  }

  if (!isResumableCustomerJob(job)) {
    clearActiveJobSession(container);
    return;
  }

  final current = container.read(jobDraftProvider);
  container.read(jobDraftProvider.notifier).state = current.copyWith(
    activeJob: job,
    pickupAddress: job.pickupAddress,
    pickupLat: job.pickupLat,
    pickupLng: job.pickupLng,
    locationResolved: true,
    serviceCategory: job.serviceCategory ?? current.serviceCategory,
    vehicle: job.vehicle ?? current.vehicle,
    estimate: job.estimatedFare != null
        ? FareEstimate(
            estimatedFare: job.estimatedFare!,
            distanceKm: current.estimate?.distanceKm ?? 0,
          )
        : current.estimate,
  );

  if (job.serviceCategory?.name != null) {
    container.read(selectedServiceProvider.notifier).state =
        job.serviceCategory!.name;
  }

  container.read(trackingSocketProvider).connect().then((_) {
    container.read(trackingSocketProvider).subscribeJob(job.id);
  }).catchError((_) {});
}

/// Cancels a job that was inserted before payment was confirmed.
/// Returns true when the server accepted the cancellation.
///
/// [force] is for a job this session just created and then failed to pay.
/// That row is removed even if its status is not `payment_pending`.
Future<bool> abandonUnpaidCheckoutJob(
  ProviderContainer container,
  JobModel job, {
  bool force = false,
}) async {
  final paid = job.paymentStatus == 'held' || job.paymentStatus == 'paid';
  if (paid) return false;
  final draft = container.read(jobDraftProvider);
  final inCheckout = container.read(paymentCheckoutInProgressProvider);
  final awaiting = container.read(paymentAwaitingConfirmationProvider);
  if (force) {
    if (inCheckout) return false;
  } else if (!shouldAbandonUnpaidCheckout(
    job: job,
    checkoutInProgress: inCheckout,
    awaitingConfirmation: awaiting,
    awaitingJobId: draft.activeJob?.id,
  )) {
    return false;
  }

  var removed = false;
  try {
    await container.read(jobRepositoryProvider).cancelJob(
          job.id,
          reason: 'Payment was not completed',
        );
    final finished = {...container.read(finishedJobIdsProvider)}..add(job.id);
    container.read(finishedJobIdsProvider.notifier).state = finished;
    removed = true;
  } catch (_) {}

  if (removed) {
    final latest = container.read(jobDraftProvider);
    if (latest.activeJob?.id == job.id) {
      container.read(jobDraftProvider.notifier).state =
          latest.copyWith(clearActiveJob: true);
    }
    container.invalidate(jobsListProvider);
  }
  return removed;
}

/// Loads the active job from the API and writes it into [jobDraftProvider].
/// Returns the job, or null when there is no active request.
///
/// An unpaid `payment_pending` job is cancelled here so it does not sit on
/// the home screen as "Complete payment to confirm".
Future<JobModel?> fetchAndApplyActiveJob(ProviderContainer container) async {
  try {
    final job = await container.read(jobRepositoryProvider).fetchActiveJob();
    if (job != null &&
        shouldAbandonUnpaidCheckout(
          job: job,
          checkoutInProgress: container.read(paymentCheckoutInProgressProvider),
          awaitingConfirmation:
              container.read(paymentAwaitingConfirmationProvider),
          awaitingJobId: container.read(jobDraftProvider).activeJob?.id,
        )) {
      final removed = await abandonUnpaidCheckoutJob(container, job);
      if (removed) return null;
    }
    if (job == null ||
        container.read(finishedJobIdsProvider).contains(job.id) ||
        !isResumableCustomerJob(job)) {
      clearActiveJobSession(container);
      return null;
    }
    applyActiveJobSession(container, job);
    return job;
  } catch (_) {
    return null;
  }
}

/// Restores session state and returns the route to resume, if any.
Future<String?> restoreActiveJobSession(ProviderContainer container) async {
  final job = await fetchAndApplyActiveJob(container);
  if (job == null) return null;
  return routeForActiveCustomerJobModel(job);
}
