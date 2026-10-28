import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/job_status_chip.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

final _jobHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioClientProvider).dio.get('/provider/jobs/history');
  final body = res.data;
  final data = body is Map && body.containsKey('data') ? body['data'] : body;
  final list = data as List? ?? [];
  return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
});

class JobHistoryPage extends ConsumerWidget {
  const JobHistoryPage({super.key});

  JobStatus _parseStatus(String s) => switch (s) {
        'completed' => JobStatus.completed,
        'declined' => JobStatus.declined,
        _ when s.startsWith('cancelled') => JobStatus.cancelled,
        _ => JobStatus.pending,
      };

  String _customerName(BuildContext context, Map<String, dynamic> job) {
    final user = (job['customer'] as Map?)?['user'] as Map?;
    return user?['fullName'] as String? ?? AppLocalizations.of(context).customer;
  }

  String _type(BuildContext context, Map<String, dynamic> job) =>
      (job['serviceCategory'] as Map?)?['name'] as String? ?? AppLocalizations.of(context).roadsideService;

  String _date(Map<String, dynamic> job) {
    final raw = (job['completedAt'] ?? job['createdAt']) as String?;
    final d = DateTime.tryParse(raw ?? '');
    return d == null ? '' : '${d.day}/${d.month}/${d.year}';
  }

  double _amount(Map<String, dynamic> job) {
    final v = job['finalFare'] ?? job['estimatedFare'];
    return v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_jobHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).jobHistory, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: history.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: ShimmerList(count: 8, itemHeight: 88)),
        error: (e, _) => Center(
          child: Text(AppLocalizations.of(context).couldNotLoadHistory, style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context).noCompletedJobsYet, style: GoogleFonts.poppins(color: AppColors.textSecondary)),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_jobHistoryProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: jobs.length,
              itemBuilder: (_, i) {
                final job = jobs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(_customerName(context, job),
                                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                JobStatusChip(status: _parseStatus(job['status'] as String? ?? '')),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${_type(context, job)} • ${_date(job)}',
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(formatMoney(_amount(job)),
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
