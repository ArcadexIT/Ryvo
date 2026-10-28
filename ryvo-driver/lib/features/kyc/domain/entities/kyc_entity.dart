enum KycDocumentType { license, licenseBack, registration, insurance, selfie, equipment }

enum KycStatus { pending, approved, rejected }

class KycDocumentEntity {
  final KycDocumentType type;
  final String? url;
  final KycStatus status;
  final String? rejectionReason;

  const KycDocumentEntity({
    required this.type,
    this.url,
    this.status = KycStatus.pending,
    this.rejectionReason,
  });
}

class KycStateEntity {
  final List<KycDocumentEntity> documents;
  final bool isApproved;
  final String verificationStatus;
  final bool agreementAccepted;
  final String? agreementVersionAccepted;
  final String currentAgreementVersion;
  final List<String> missingDocTypes;

  const KycStateEntity({
    this.documents = const [],
    this.isApproved = false,
    this.verificationStatus = 'pending',
    this.agreementAccepted = false,
    this.agreementVersionAccepted,
    this.currentAgreementVersion = '1',
    this.missingDocTypes = const [],
  });

  bool get hasRejected => documents.any((d) => d.status == KycStatus.rejected);
  bool get allApproved => documents.isNotEmpty && documents.every((d) => d.status == KycStatus.approved);
}

class ProviderAgreementEntity {
  final String currentVersion;
  final bool accepted;
  final DateTime? agreementAcceptedAt;
  final String? agreementVersionAccepted;

  const ProviderAgreementEntity({
    required this.currentVersion,
    required this.accepted,
    this.agreementAcceptedAt,
    this.agreementVersionAccepted,
  });
}
