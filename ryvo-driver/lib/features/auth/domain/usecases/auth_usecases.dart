import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/i_auth_repository.dart';
import '../entities/provider_entity.dart';

class LoginUseCase {
  LoginUseCase(this._repo);
  final IAuthRepository _repo;

  Future<Either<Failure, ProviderEntity>> call({required String phone, required String password}) {
    return _repo.login(phone: phone, password: password);
  }
}

class RegisterUseCase {
  RegisterUseCase(this._repo);
  final IAuthRepository _repo;

  Future<Either<Failure, ProviderEntity>> call({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) {
    return _repo.register(name: name, phone: phone, email: email, password: password);
  }
}

class VerifyOtpUseCase {
  VerifyOtpUseCase(this._repo);
  final IAuthRepository _repo;

  Future<Either<Failure, void>> call({required String phone, required String otp}) {
    return _repo.verifyOtp(phone: phone, otp: otp);
  }
}

class LogoutUseCase {
  LogoutUseCase(this._repo);
  final IAuthRepository _repo;

  Future<Either<Failure, void>> call() => _repo.logout();
}
