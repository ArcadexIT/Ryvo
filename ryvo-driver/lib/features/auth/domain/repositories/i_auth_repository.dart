import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/provider_entity.dart';

abstract class IAuthRepository {
  Future<Either<Failure, ProviderEntity>> login({required String phone, required String password});
  Future<Either<Failure, ProviderEntity>> register({required String name, required String phone, required String email, required String password});
  Future<Either<Failure, void>> verifyOtp({required String phone, required String otp});
  Future<Either<Failure, void>> logout();
  Stream<ProviderEntity?> authStateChanges();
}
