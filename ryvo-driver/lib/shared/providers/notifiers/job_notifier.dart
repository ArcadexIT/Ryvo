import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    repo.watchIncomingJob().listen((job) {
      state = AsyncData(JobUiState(incomingJob: job, activeJob: state.value?.activeJob));
    });
    repo.watchActiveJob().listen((job) {
      if (job != null) {
        ref.read(activeJobProvider.notifier).state = mockJobFromEntity(job);
        ref.read(providerSocketProvider).setActiveJob(job.id);
        ref.read(showIncomingJobProvider.notifier).state = false;
        flushActiveJobLocation(ref.read);
      } else {
        ref.read(activeJobProvider.notifier).state = null;
        ref.read(providerSocketProvider).setActiveJob(null);
      }
      state = AsyncData(JobUiState(
        incomingJob: job != null ? null : state.value?.incomingJob,
        activeJob: job,
      ));
    });
    return const JobUiState();
  }

  Future<void> acceptJob(String jobId) async {
    await ref.read(jobRepositoryProvider).acceptJob(jobId);
  }

  Future<void> declineJob(String jobId) async {
    await ref.read(jobRepositoryProvider).declineJob(jobId);
  }

  Future<void> updateStatus(String jobId, JobStatusEntity status) async {
    await ref.read(jobRepositoryProvider).updateJobStatus(jobId, status);
  }
}
