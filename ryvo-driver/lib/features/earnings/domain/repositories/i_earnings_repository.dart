import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/earnings_entity.dart';

abstract class IEarningsRepository {
  Future<Either<Failure, EarningsEntity>> getWeeklyEarnings();
  Future<Either<Failure, TransactionEntity>> getTransaction(String id);
  Future<Either<Failure, List<TransactionEntity>>> getEarningsHistory();
}
