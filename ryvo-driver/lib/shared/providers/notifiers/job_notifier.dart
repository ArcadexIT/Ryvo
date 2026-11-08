import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../features/job/domain/entities/job_entity.dart';
import '../app_providers.dart';
import '../di_providers.dart';

class JobUiState {
  final JobEntity? incomingJob;
  final JobEntity? activeJob;
  const JobUiState({this.incomingJob, this.activeJob});
}

class JobNotifier extends AsyncNotifier<JobUiState> {
  @override
  Future<JobUiState> build() async {
    final repo = ref.read(jobRepositoryProvider);
    // Stream errors are swallowed on purpose: the last good JobUiState stays in
    // place, so a network blip never clears the offer or the active trip.
    final incomingSub = repo.watchIncomingJob().listen((job) {
      state = AsyncData(JobUiState(incomingJob: job, activeJob: state.value?.activeJob));
    }, onError: (Object _) {});
    final activeSub = repo.watchActiveJob().listen((job) {
      if (job != null) {
        ref.read(activeJobProvider.notifier).state = mockJobFromEntity(job);
        ref.read(providerSocketProvider).setActiveJob(job.id);
        ref.read(showIncomingJobProvider.notifier).state = false;
        flushActiveJobLocation(ref.read);
      } else {
        ref.read(activeJobProvider.notifier).state = null;
        ref.read(providerSocketProvider).setActiveJob(null);
      }
      final keepOffer = job?.status == JobStatusEntity.inProgress;
      state = AsyncData(JobUiState(
        incomingJob: keepOffer ? state.value?.incomingJob : (job != null ? null : state.value?.incomingJob),
        activeJob: job,
      ));
    }, onError: (Object _) {});
    ref.onDispose(() {
      incomingSub.cancel();
      activeSub.cancel();
    });
    return const JobUiState();
  }

  Future<Either<Failure, JobEntity>> acceptJob(String jobId) {
    return ref.read(jobRepositoryProvider).acceptJob(jobId);
  }

  Future<Either<Failure, void>> declineJob(String jobId) {
    return ref.read(jobRepositoryProvider).declineJob(jobId);
  }

  Future<Either<Failure, void>> updateStatus(String jobId, JobStatusEntity status) {
    return ref.read(jobRepositoryProvider).updateJobStatus(jobId, status);
  }
}
