import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/services/file_upload_service.dart';
import '../../domain/entities/kyc_entity.dart';
import '../../domain/repositories/i_kyc_repository.dart';

String _docTypeToApi(KycDocumentType type) {
  switch (type) {
    case KycDocumentType.license:
      return 'license';
    // Reuse unused backend enum value for license back — no schema migration needed.
    case KycDocumentType.licenseBack:
      return 'id_card';
    case KycDocumentType.registration:
      return 'vehicle_registration';
    case KycDocumentType.insurance:
      return 'insurance';
    case KycDocumentType.selfie:
      return 'selfie';
    case KycDocumentType.equipment:
      return 'equipment_proof';
  }
}

KycDocumentType? _docTypeFromApi(String? v) {
  switch (v) {
    case 'license':
      return KycDocumentType.license;
    case 'id_card':
      return KycDocumentType.licenseBack;
    case 'vehicle_registration':
      return KycDocumentType.registration;
    case 'insurance':
      return KycDocumentType.insurance;
    case 'selfie':
      return KycDocumentType.selfie;
    case 'equipment_proof':
      return KycDocumentType.equipment;
    default:
      return null;
  }
}

KycStatus _statusFromApi(String? v) {
  switch (v) {
    case 'approved':
      return KycStatus.approved;
    case 'rejected':
      return KycStatus.rejected;
    default:
      return KycStatus.pending;
  }
}

class KycRemoteDataSource {
  KycRemoteDataSource(this._dio, this._uploads);
  final Dio _dio;
  final FileUploadService _uploads;

  dynamic _unwrap(Response res) {
    final body = res.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Future<String> uploadDocument({required KycDocumentType type, required String filePath}) async {
    final fileUrl = await _uploads.uploadProviderFile(
      localPath: filePath,
      folder: 'documents',
    );

    final res = await _dio.post('/provider/documents', data: {
      'docType': _docTypeToApi(type),
      'fileUrl': fileUrl,
    });
    final data = _unwrap(res) as Map<String, dynamic>;
    return data['fileUrl'] as String? ?? fileUrl;
  }

  Future<KycStateEntity> getKycStatus() async {
    final data = _unwrap(await _dio.get('/provider/kyc/status')) as Map<String, dynamic>;
    final verificationStatus = data['verificationStatus'] as String? ?? 'pending';
    final docs = (data['documents'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final d = raw.cast<String, dynamic>();
          final type = _docTypeFromApi(d['docType'] as String?);
          if (type == null) return null;
          return KycDocumentEntity(
            type: type,
            url: d['fileUrl'] as String?,
            status: _statusFromApi(d['status'] as String?),
            rejectionReason: d['rejectionReason'] as String?,
          );
        })
        .whereType<KycDocumentEntity>()
        .toList();

    final missing = (data['missingDocTypes'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();

    // Older APIs omit agreement fields — treat as accepted so the app
    // does not gate on /provider/agreement when that route is unavailable.
    final agreementAccepted = !data.containsKey('agreementAccepted') ||
        data['agreementAccepted'] == true;

    return KycStateEntity(
      documents: docs,
      isApproved: data['isApproved'] == true || verificationStatus == 'approved',
      verificationStatus: verificationStatus,
      agreementAccepted: agreementAccepted,
      agreementVersionAccepted: data['agreementVersionAccepted'] as String?,
      currentAgreementVersion: data['currentAgreementVersion'] as String? ?? '1',
      missingDocTypes: missing,
    );
  }

  Future<ProviderAgreementEntity> getAgreement() async {
    final data = _unwrap(await _dio.get('/provider/agreement')) as Map<String, dynamic>;
    return ProviderAgreementEntity(
      currentVersion: data['currentVersion'] as String? ?? '1',
      accepted: data['accepted'] == true,
      agreementAcceptedAt: data['agreementAcceptedAt'] != null
          ? DateTime.tryParse(data['agreementAcceptedAt'].toString())
          : null,
      agreementVersionAccepted: data['agreementVersionAccepted'] as String?,
    );
  }

  Future<ProviderAgreementEntity> acceptAgreement(String version) async {
    final data = _unwrap(
      await _dio.post('/provider/agreement/accept', data: {'version': version}),
    ) as Map<String, dynamic>;
    return ProviderAgreementEntity(
      currentVersion: data['currentVersion'] as String? ?? version,
      accepted: data['accepted'] == true,
      agreementAcceptedAt: data['agreementAcceptedAt'] != null
          ? DateTime.tryParse(data['agreementAcceptedAt'].toString())
          : null,
      agreementVersionAccepted: data['agreementVersionAccepted'] as String?,
    );
  }
}

class KycRepositoryImpl implements IKycRepository {
  KycRepositoryImpl(this._remote);
  final KycRemoteDataSource _remote;

  @override
  Future<Either<Failure, String>> uploadDocument({required KycDocumentType type, required String filePath}) async {
    try {
      return Right(await _remote.uploadDocument(type: type, filePath: filePath));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      return Left(KycFailure(msg));
    }
  }

  @override
  Future<Either<Failure, KycStateEntity>> getKycStatus() async {
    try {
      return Right(await _remote.getKycStatus());
    } catch (e) {
      return Left(KycFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProviderAgreementEntity>> getAgreement() async {
    try {
      return Right(await _remote.getAgreement());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(KycFailure(_mapErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, ProviderAgreementEntity>> acceptAgreement(String version) async {
    try {
      return Right(await _remote.acceptAgreement(version));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(KycFailure(_mapErrorMessage(e)));
    }
  }

  String _mapErrorMessage(Object e) {
    if (e is DioException) {
      final nested = e.error;
      if (nested is Failure) return nested.message;
      final status = e.response?.statusCode;
      final body = e.response?.data;
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
      if (status != null) return 'Server error ($status)';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  @override
  Stream<KycStateEntity> watchKycStatus() => Stream.fromFuture(_remote.getKycStatus());
}
