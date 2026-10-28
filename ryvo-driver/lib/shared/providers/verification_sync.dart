import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/kyc/domain/entities/kyc_entity.dart';
import 'di_providers.dart';
import 'app_providers.dart';

/// Sync verification + agreement state from the backend (reflects admin panel changes).
Future<void> syncProviderVerification(ProviderContainer container) async {
  final result = await container.read(kycRepositoryProvider).getKycStatus();
  result.fold((_) {}, (kyc) {
    container.read(isKycApprovedProvider.notifier).state = kyc.isApproved;
    container.read(isAgreementAcceptedProvider.notifier).state = kyc.agreementAccepted;
    container.read(isKycInReviewProvider.notifier).state =
        !kyc.isApproved && kyc.missingDocTypes.isEmpty && kyc.documents.isNotEmpty;
  });
}

/// Destination for authenticated providers still in onboarding.
String providerOnboardingRoute({
  required bool agreementAccepted,
  required bool kycApproved,
  required bool documentsInReview,
}) {
  if (!agreementAccepted) return '/kyc/agreement';
  if (!kycApproved) return documentsInReview ? '/kyc/pending' : '/kyc';
  return '/home';
}

/// Whether the provider has any rejected documents needing re-upload.
bool providerHasRejectedDocs(KycStateEntity kyc) => kyc.hasRejected;
