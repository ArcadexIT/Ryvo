import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/kyc/domain/entities/kyc_entity.dart';
import 'app_providers.dart';
import 'di_providers.dart';

enum VerificationDocType { selfie, license, registration, insurance, equipment }

enum VerificationDocStatus { notUploaded, pending, verified, rejected }

class VerificationDocument {
  final VerificationDocType type;
  final VerificationDocStatus status;
  final String? fileName;
  final String? backFileName;
  final List<String> extraFileNames;
  final String? statusDetail;
  final String? rejectionReason;
  final DateTime? actionDate;

  const VerificationDocument({
    required this.type,
    this.status = VerificationDocStatus.notUploaded,
    this.fileName,
    this.backFileName,
    this.extraFileNames = const [],
    this.statusDetail,
    this.rejectionReason,
    this.actionDate,
  });

  VerificationDocument copyWith({
    VerificationDocStatus? status,
    String? fileName,
    String? backFileName,
    List<String>? extraFileNames,
    String? statusDetail,
    String? rejectionReason,
    DateTime? actionDate,
  }) {
    return VerificationDocument(
      type: type,
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      backFileName: backFileName ?? this.backFileName,
      extraFileNames: extraFileNames ?? this.extraFileNames,
      statusDetail: statusDetail ?? this.statusDetail,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      actionDate: actionDate ?? this.actionDate,
    );
  }

  bool get isSubmitted =>
      status == VerificationDocStatus.pending ||
      status == VerificationDocStatus.verified ||
      status == VerificationDocStatus.rejected;

  bool get requiresBothSides => type == VerificationDocType.license;

  bool get isMultiImage => type == VerificationDocType.equipment;

  String get title => switch (type) {
        VerificationDocType.selfie => 'Identity Selfie',
        VerificationDocType.license => 'Driver License',
        VerificationDocType.registration => 'Vehicle Registration',
        VerificationDocType.insurance => 'Insurance & Cover',
        VerificationDocType.equipment => 'Equipment Proof',
      };

  String get subtitle => switch (type) {
        VerificationDocType.selfie => 'Clear selfie for identity verification',
        VerificationDocType.license => 'Front and back of valid license',
        VerificationDocType.registration => 'Current vehicle registration',
        VerificationDocType.insurance => 'Valid auto insurance proof',
        VerificationDocType.equipment => 'Photos of your service equipment (up to 5)',
      };
}

class VerificationState {
  final List<VerificationDocument> documents;

  const VerificationState({required this.documents});

  factory VerificationState.empty() => const VerificationState(documents: [
        VerificationDocument(type: VerificationDocType.selfie),
        VerificationDocument(type: VerificationDocType.license),
        VerificationDocument(type: VerificationDocType.registration),
        VerificationDocument(type: VerificationDocType.insurance),
      ]);

  int get progressPercent {
    if (documents.isEmpty) return 0;
    final submitted = documents.where((d) => d.isSubmitted).length;
    return ((submitted / documents.length) * 100).round();
  }

  bool get allSubmitted => documents.every((d) => d.isSubmitted);
  bool get allVerified => documents.every((d) => d.status == VerificationDocStatus.verified);
  bool get hasRejected => documents.any((d) => d.status == VerificationDocStatus.rejected);

  String get progressMessage {
    if (allVerified) return 'All documents verified. You\'re ready to go online!';
    if (hasRejected) return 'Some documents were rejected. Please re-upload them.';
    if (allSubmitted) return 'Great job! All required information submitted.';
    final remaining = documents.where((d) => !d.isSubmitted).length;
    return 'Upload $remaining more document${remaining == 1 ? '' : 's'} to continue.';
  }

  VerificationDocument doc(VerificationDocType type) =>
      documents.firstWhere((d) => d.type == type);
}

VerificationDocStatus _mapStatus(KycStatus s) => switch (s) {
      KycStatus.approved => VerificationDocStatus.verified,
      KycStatus.rejected => VerificationDocStatus.rejected,
      KycStatus.pending => VerificationDocStatus.pending,
    };

KycDocumentType _toDomainType(VerificationDocType t) => switch (t) {
      VerificationDocType.selfie => KycDocumentType.selfie,
      VerificationDocType.license => KycDocumentType.license,
      VerificationDocType.registration => KycDocumentType.registration,
      VerificationDocType.insurance => KycDocumentType.insurance,
      VerificationDocType.equipment => KycDocumentType.equipment,
    };

/// Worst status wins. Missing side keeps the card incomplete (not uploaded).
VerificationDocStatus _aggregateLicenseStatus(
  KycDocumentEntity? front,
  KycDocumentEntity? back,
) {
  if (front == null || back == null) return VerificationDocStatus.notUploaded;

  final statuses = [_mapStatus(front.status), _mapStatus(back.status)];
  if (statuses.contains(VerificationDocStatus.rejected)) {
    return VerificationDocStatus.rejected;
  }
  if (statuses.contains(VerificationDocStatus.pending)) {
    return VerificationDocStatus.pending;
  }
  return VerificationDocStatus.verified;
}

String? _licenseStatusDetail(
  VerificationDocStatus status,
  KycDocumentEntity? front,
  KycDocumentEntity? back,
) {
  if (front == null && back == null) return null;
  if (front == null) return 'Back uploaded — add the front side';
  if (back == null) return 'Front uploaded — add the back side';

  return switch (status) {
    VerificationDocStatus.verified => 'Approved by admin',
    VerificationDocStatus.rejected => 'Rejected — please re-upload both sides',
    VerificationDocStatus.pending => 'Under review',
    VerificationDocStatus.notUploaded => null,
  };
}

String? _licenseRejectionReason(KycDocumentEntity? front, KycDocumentEntity? back) {
  final parts = <String>[];
  final frontReason = front?.rejectionReason?.trim();
  final backReason = back?.rejectionReason?.trim();
  if (front?.status == KycStatus.rejected && frontReason != null && frontReason.isNotEmpty) {
    parts.add('Front: $frontReason');
  }
  if (back?.status == KycStatus.rejected && backReason != null && backReason.isNotEmpty) {
    parts.add('Back: $backReason');
  }
  if (parts.isEmpty) return null;
  return parts.join('\n');
}

VerificationDocStatus _aggregateEquipmentStatus(List<KycDocumentEntity> docs) {
  if (docs.isEmpty) return VerificationDocStatus.notUploaded;
  // API uses latest per type for approval — mirror that for the card.
  final latest = docs.first;
  return _mapStatus(latest.status);
}

class VerificationNotifier extends StateNotifier<VerificationState> {
  VerificationNotifier(this._ref) : super(VerificationState.empty()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    final result = await _ref.read(kycRepositoryProvider).getKycStatus();
    result.fold((_) {}, (kyc) {
      _ref.read(isKycApprovedProvider.notifier).state = kyc.isApproved;
      _ref.read(isAgreementAcceptedProvider.notifier).state = kyc.agreementAccepted;

      final byType = <KycDocumentType, KycDocumentEntity>{};
      final equipmentDocs = <KycDocumentEntity>[];
      for (final doc in kyc.documents) {
        if (doc.type == KycDocumentType.equipment) {
          equipmentDocs.add(doc);
          continue;
        }
        byType.putIfAbsent(doc.type, () => doc);
      }

      state = VerificationState(
        documents: VerificationDocType.values
            .where((type) => type != VerificationDocType.equipment)
            .map((type) {
          if (type == VerificationDocType.license) {
            final front = byType[KycDocumentType.license];
            final back = byType[KycDocumentType.licenseBack];
            final status = _aggregateLicenseStatus(front, back);
            return VerificationDocument(
              type: type,
              status: status,
              fileName: front?.url,
              backFileName: back?.url,
              rejectionReason: _licenseRejectionReason(front, back),
              statusDetail: _licenseStatusDetail(status, front, back),
            );
          }

          if (type == VerificationDocType.equipment) {
            final status = _aggregateEquipmentStatus(equipmentDocs);
            final urls = equipmentDocs.map((d) => d.url).whereType<String>().toList();
            return VerificationDocument(
              type: type,
              status: status,
              fileName: urls.isNotEmpty ? urls.first : null,
              extraFileNames: urls.length > 1 ? urls.sublist(1) : const [],
              rejectionReason: equipmentDocs
                  .where((d) => d.status == KycStatus.rejected)
                  .map((d) => d.rejectionReason)
                  .whereType<String>()
                  .where((r) => r.trim().isNotEmpty)
                  .firstOrNull,
              statusDetail: switch (status) {
                VerificationDocStatus.verified => 'Approved by admin',
                VerificationDocStatus.rejected => 'Rejected — please re-upload',
                VerificationDocStatus.pending =>
                  urls.isEmpty ? 'Under review' : '${urls.length} photo${urls.length == 1 ? '' : 's'} under review',
                VerificationDocStatus.notUploaded => null,
              },
            );
          }

          final domainType = _toDomainType(type);
          final doc = byType[domainType];
          if (doc == null) {
            return VerificationDocument(type: type);
          }
          final status = _mapStatus(doc.status);
          return VerificationDocument(
            type: type,
            status: status,
            fileName: doc.url,
            rejectionReason: doc.rejectionReason,
            statusDetail: switch (status) {
              VerificationDocStatus.verified => 'Approved by admin',
              VerificationDocStatus.rejected => doc.rejectionReason?.isNotEmpty == true
                  ? doc.rejectionReason!
                  : 'Rejected — please re-upload',
              VerificationDocStatus.pending => 'Under review',
              VerificationDocStatus.notUploaded => null,
            },
          );
        }).toList(),
      );
    });
  }

  Future<({bool success, String? error})> uploadDocument(VerificationDocType type, String filePath) async {
    state = VerificationState(
      documents: state.documents.map((d) {
        if (d.type != type) return d;
        return d.copyWith(
          status: VerificationDocStatus.pending,
          fileName: filePath,
          statusDetail: 'Uploading...',
        );
      }).toList(),
    );
    final result = await _ref.read(kycRepositoryProvider).uploadDocument(type: _toDomainType(type), filePath: filePath);

    // Selfie doubles as display picture (API also sets avatarUrl).
    final fileUrl = result.fold((_) => null, (url) => url);
    if (type == VerificationDocType.selfie && fileUrl != null) {
      try {
        await _ref.read(dioClientProvider).dio.patch('/provider/profile', data: {'avatarUrl': fileUrl});
      } catch (_) {}
    }

    await load();
    return result.fold(
      (f) => (success: false, error: f.message),
      (_) => (success: true, error: null),
    );
  }

  /// Uploads license front + back as two API documents (`license` + `id_card`).
  Future<({bool success, String? error})> uploadLicenseSides({
    required String frontPath,
    required String backPath,
  }) async {
    state = VerificationState(
      documents: state.documents.map((d) {
        if (d.type != VerificationDocType.license) return d;
        return d.copyWith(
          status: VerificationDocStatus.pending,
          fileName: frontPath,
          backFileName: backPath,
          statusDetail: 'Uploading both sides...',
        );
      }).toList(),
    );

    final repo = _ref.read(kycRepositoryProvider);
    final frontResult = await repo.uploadDocument(type: KycDocumentType.license, filePath: frontPath);
    final frontFailure = frontResult.fold((f) => f.message, (_) => null);
    if (frontFailure != null) {
      await load();
      return (success: false, error: 'Front upload failed: $frontFailure');
    }

    final backResult = await repo.uploadDocument(type: KycDocumentType.licenseBack, filePath: backPath);
    final backFailure = backResult.fold((f) => f.message, (_) => null);
    await load();
    if (backFailure != null) {
      return (success: false, error: 'Back upload failed: $backFailure');
    }
    return (success: true, error: null);
  }

  Future<({bool success, String? error})> uploadEquipmentImages(List<String> paths) async {
    if (paths.isEmpty) return (success: false, error: 'Add at least one photo');

    state = VerificationState(
      documents: state.documents.map((d) {
        if (d.type != VerificationDocType.equipment) return d;
        return d.copyWith(
          status: VerificationDocStatus.pending,
          fileName: paths.first,
          extraFileNames: paths.length > 1 ? paths.sublist(1) : const [],
          statusDetail: 'Uploading ${paths.length} photo${paths.length == 1 ? '' : 's'}...',
        );
      }).toList(),
    );

    final repo = _ref.read(kycRepositoryProvider);
    for (var i = 0; i < paths.length; i++) {
      final result = await repo.uploadDocument(type: KycDocumentType.equipment, filePath: paths[i]);
      final failure = result.fold((f) => f.message, (_) => null);
      if (failure != null) {
        await load();
        return (success: false, error: 'Photo ${i + 1} failed: $failure');
      }
    }
    await load();
    return (success: true, error: null);
  }

  Future<void> reuploadDocument(VerificationDocType type, String filePath) async {
    await uploadDocument(type, filePath);
  }

  void markAllSubmittedForReview() {
    // Submission happens per-document upload against the backend.
  }
}

final verificationProvider = StateNotifierProvider<VerificationNotifier, VerificationState>((ref) => VerificationNotifier(ref));
