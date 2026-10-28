import 'package:flutter_test/flutter_test.dart';
import 'package:ryvo_customer/core/job/active_job_session.dart';
import 'package:ryvo_customer/data/models/models.dart';

JobModel _job({
  required String status,
  String? paymentStatus,
  String id = 'job-1',
}) {
  return JobModel(
    id: id,
    jobNumber: 'J-1',
    status: status,
    pickupAddress: '1 Test St',
    pickupLat: 1,
    pickupLng: 2,
    paymentStatus: paymentStatus,
  );
}

void main() {
  test('a request is unpaid until payment is held or paid', () {
    expect(isUnpaidCheckoutJob(_job(status: 'payment_pending')), isTrue);
    expect(
      isUnpaidCheckoutJob(_job(status: 'payment_pending', paymentStatus: 'pending')),
      isTrue,
    );
    expect(
      isUnpaidCheckoutJob(_job(status: 'payment_pending', paymentStatus: 'held')),
      isFalse,
    );
    expect(
      isUnpaidCheckoutJob(_job(status: 'payment_pending', paymentStatus: 'paid')),
      isFalse,
    );
    expect(
      isUnpaidCheckoutJob(_job(status: 'searching', paymentStatus: 'held')),
      isFalse,
    );
  });

  test('unpaid checkout is removed unless payment is in progress or accepted', () {
    final unpaid = _job(status: 'payment_pending');

    expect(
      shouldAbandonUnpaidCheckout(
        job: unpaid,
        checkoutInProgress: false,
        awaitingConfirmation: false,
      ),
      isTrue,
    );
    expect(
      shouldAbandonUnpaidCheckout(
        job: unpaid,
        checkoutInProgress: true,
        awaitingConfirmation: false,
      ),
      isFalse,
    );
    expect(
      shouldAbandonUnpaidCheckout(
        job: unpaid,
        checkoutInProgress: false,
        awaitingConfirmation: true,
        awaitingJobId: unpaid.id,
      ),
      isFalse,
    );
    expect(
      shouldAbandonUnpaidCheckout(
        job: unpaid,
        checkoutInProgress: false,
        awaitingConfirmation: true,
        awaitingJobId: 'other-job',
      ),
      isTrue,
    );
    expect(
      shouldAbandonUnpaidCheckout(
        job: _job(status: 'searching', paymentStatus: 'held'),
        checkoutInProgress: false,
        awaitingConfirmation: false,
      ),
      isFalse,
    );
  });
}
