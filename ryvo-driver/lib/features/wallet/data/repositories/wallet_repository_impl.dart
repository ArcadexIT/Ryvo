import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/i_wallet_repository.dart';

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

dynamic _unwrap(Response res) {
  final body = res.data;
  if (body is Map && body.containsKey('data')) return body['data'];
  return body;
}

class WalletRemoteDataSource {
  WalletRemoteDataSource(this._dio);
  final Dio _dio;

  Future<WalletEntity> getBalance() async {
    final data = _unwrap(await _dio.get('/provider/wallet')) as Map<String, dynamic>;
    return WalletEntity(
      availableBalance: _toD(data['available']),
      pendingBalance: _toD(data['pending']),
    );
  }

  Future<void> withdraw(WithdrawRequest request) async {
    await _dio.post('/provider/wallet/withdraw', data: {
      'amount': request.amount,
      'bankAccountId': request.bankAccountId,
    });
  }
}

class WalletRepositoryImpl implements IWalletRepository {
  WalletRepositoryImpl(this._remote);
  final WalletRemoteDataSource _remote;

  @override
  Future<Either<Failure, WalletEntity>> getBalance() async {
    try {
      return Right(await _remote.getBalance());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> withdraw(WithdrawRequest request) async {
    try {
      await _remote.withdraw(request);
      return const Right(null);
    } on DioException catch (e) {
      if (e.error is Failure) return Left(e.error as Failure);
      return Left(ServerFailure(e.message ?? 'Withdrawal failed'));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
