import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/wallet_entity.dart';

abstract class IWalletRepository {
  Future<Either<Failure, WalletEntity>> getBalance();
  Future<Either<Failure, void>> withdraw(WithdrawRequest request);
}
