import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/earnings_entity.dart';
import '../../domain/repositories/i_earnings_repository.dart';

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

dynamic _unwrap(Response res) {
  final body = res.data;
  if (body is Map && body.containsKey('data')) return body['data'];
  return body;
}

class EarningsRemoteDataSource {
  EarningsRemoteDataSource(this._dio);
  final Dio _dio;

  Future<EarningsEntity> getWeeklyEarnings() async {
    final data = _unwrap(await _dio.get('/provider/earnings/weekly')) as Map<String, dynamic>;
    return EarningsEntity(
      weeklyTotal: _toD(data['weeklyTotal']),
      jobCount: (data['jobCount'] as num?)?.toInt() ?? 0,
      averageRating: _toD(data['averageRating']),
      dailyBreakdown:
          (data['dailyBreakdown'] as List? ?? const []).map((e) => _toD(e)).toList(),
    );
  }

  Future<TransactionEntity> getTransaction(String id) async {
    final data = _unwrap(await _dio.get('/provider/transactions/$id')) as Map<String, dynamic>;
    return TransactionEntity(
      id: data['id'] as String,
      title: data['title'] as String? ?? 'Job payout',
      gross: _toD(data['gross']),
      platformFee: _toD(data['platformFee']),
      net: _toD(data['net']),
      date: DateTime.tryParse(data['date'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Future<List<TransactionEntity>> getHistory() async {
    final list = _unwrap(await _dio.get('/provider/earnings/history'));
    if (list is! List) return [];
    return list.whereType<Map>().map((raw) {
      final e = raw.cast<String, dynamic>();
      final job = (e['job'] as Map?)?.cast<String, dynamic>();
      final sc = (job?['serviceCategory'] as Map?)?.cast<String, dynamic>();
      return TransactionEntity(
        id: e['id'] as String,
        title: sc?['name'] as String? ?? job?['jobNumber'] as String? ?? 'Job payout',
        gross: _toD(e['grossAmount']),
        platformFee: _toD(e['platformFee']),
        net: _toD(e['netAmount']),
        date: DateTime.tryParse(
                (job?['completedAt'] ?? e['createdAt']) as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }
}

class EarningsRepositoryImpl implements IEarningsRepository {
  EarningsRepositoryImpl(this._remote);
  final EarningsRemoteDataSource _remote;

  @override
  Future<Either<Failure, EarningsEntity>> getWeeklyEarnings() async {
    try {
      return Right(await _remote.getWeeklyEarnings());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> getTransaction(String id) async {
    try {
      return Right(await _remote.getTransaction(id));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getEarningsHistory() async {
    try {
      return Right(await _remote.getHistory());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
