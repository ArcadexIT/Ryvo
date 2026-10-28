import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/kyc_entity.dart';

abstract class IKycRepository {
  Future<Either<Failure, String>> uploadDocument({required KycDocumentType type, required String filePath});
  Future<Either<Failure, KycStateEntity>> getKycStatus();
  Future<Either<Failure, ProviderAgreementEntity>> getAgreement();
  Future<Either<Failure, ProviderAgreementEntity>> acceptAgreement(String version);
  Stream<KycStateEntity> watchKycStatus();
}
