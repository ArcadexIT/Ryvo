import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/job_entity.dart';

abstract class IJobRepository {
  Stream<JobEntity?> watchIncomingJob();
  Stream<JobEntity?> watchActiveJob();
  Future<JobEntity?> fetchActiveJob();
  Future<JobEntity?> fetchJobDetail(String jobId);
  Future<Either<Failure, JobEntity>> acceptJob(String jobId);
  Future<Either<Failure, void>> declineJob(String jobId);
  Future<Either<Failure, void>> updateJobStatus(String jobId, JobStatusEntity status);
  Future<Either<Failure, JobEntity>> confirmJobStart(String jobId);
  Future<Either<Failure, void>> cancelJob(String jobId, {String? reason});
  Future<Either<Failure, void>> counterBid(String jobId, double amount);
  Future<Either<Failure, void>> uploadParcelPickup(String jobId, String fileUrl);
  Future<Either<Failure, void>> deliverParcel(String jobId, {String? fileUrl, String? otp});
}
