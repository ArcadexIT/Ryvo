import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class JobCompletedPage extends ConsumerStatefulWidget {
  const JobCompletedPage({super.key, this.jobId});

  final String? jobId;

  @override
  ConsumerState<JobCompletedPage> createState() => _JobCompletedPageState();
}

class _JobCompletedPageState extends ConsumerState<JobCompletedPage> {
  final _commentController = TextEditingController();
  bool _submitting = false;
  bool _loading = true;
  MockJob? _job;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadJob());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadJob() async {
    final jobId = widget.jobId ?? ref.read(activeJobProvider)?.id;
    if (jobId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final detail = await ref.read(jobRepositoryProvider).fetchJobDetail(jobId);
      if (!mounted) return;
      setState(() {
        _job = detail != null ? mockJobFromEntity(detail) : ref.read(activeJobProvider);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _job = ref.read(activeJobProvider);
        _loading = false;
      });
    }
  }

  String _formatDuration(MockJob job) {
    final start = job.startedAt;
    final end = job.completedAt ?? DateTime.now();
    if (start == null) return '—';
    final diff = end.difference(start);
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min';
    return '${diff.inSeconds} sec';
  }

  Future<void> _finish() async {
    final job = _job ?? ref.read(activeJobProvider);
    final rating = ref.read(selectedRatingProvider);
    final jobId = job?.id;

    if (rating > 0 && jobId != null) {
      setState(() => _submitting = true);
      try {
        final comment = _commentController.text.trim();
        await ref.read(dioClientProvider).dio.post('/provider/ratings', data: {
          'jobId': jobId,
          'score': rating,
          if (comment.isNotEmpty) 'comment': comment,
        });
      } catch (e) {
        if (mounted) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().replaceFirst('Exception: ', ''),
                style: GoogleFonts.poppins(),
              ),
            ),
          );
          return;
        }
      }
    }

    ref.read(showIncomingJobProvider.notifier).state = false;
    ref.read(selectedRatingProvider.notifier).state = 0;
    JobEntity? nextJob;
    try {
      nextJob = await ref.read(jobRepositoryProvider).fetchActiveJob();
    } catch (_) {}
    if (!mounted) return;
    final route = nextJob == null ? null : routeForActiveJob(nextJob.status);
    if (nextJob != null && route != null) {
      applyActiveJobSession(ProviderScope.containerOf(context, listen: false), nextJob);
      context.go(route);
      return;
    }
    ref.read(activeJobProvider.notifier).state = null;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final job = _job ?? ref.watch(activeJobProvider);
    final rating = ref.watch(selectedRatingProvider);

    if (job == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 64),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context).jobCompleted,
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).weCouldNotLoadJobDetailsYourEarningsAreInYourWal,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                RyvoButton(
                  label: AppLocalizations.of(context).backToHome,
                  onPressed: () {
                    ref.read(activeJobProvider.notifier).state = null;
                    ref.read(selectedRatingProvider.notifier).state = 0;
                    context.go('/home');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final payout = job.payout;
    final distance = job.distance.isNotEmpty ? job.distance : '—';
    final customerName = job.customerName;
    final jobRef = job.jobRef;
    final service = job.jobType;
    final vehicle = job.vehicleInfo.isNotEmpty ? job.vehicleInfo : '—';
    final duration = _formatDuration(job);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                      ),
                      const SizedBox(height: 20),
                      Text(AppLocalizations.of(context).jobCompleted, style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        jobRef.isNotEmpty ? jobRef : AppLocalizations.of(context).greatWorkEarningsAddedToYourWallet,
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary.withOpacity(0.15), AppColors.surface],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                        ),
                        child: Column(
                          children: [
                            Text(AppLocalizations.of(context).youEarned, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              formatMoney(payout),
                              style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _SummaryCard(label: AppLocalizations.of(context).distance, value: distance, icon: Icons.route)),
                          const SizedBox(width: 10),
                          Expanded(child: _SummaryCard(label: AppLocalizations.of(context).duration, value: duration, icon: Icons.timer_outlined)),
                          const SizedBox(width: 10),
                          Expanded(child: _SummaryCard(label: AppLocalizations.of(context).service, value: _shortLabel(service), icon: Icons.build_outlined)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            _DetailRow(label: AppLocalizations.of(context).customer, value: customerName),
                            const Divider(color: AppColors.divider, height: 20),
                            _DetailRow(label: AppLocalizations.of(context).vehicle, value: vehicle),
                            if (job.address.isNotEmpty) ...[
                              const Divider(color: AppColors.divider, height: 20),
                              _DetailRow(label: AppLocalizations.of(context).location, value: job.address),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Rate your experience with $customerName', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      RatingStars(
                        rating: rating.toDouble(),
                        size: 36,
                        interactive: true,
                        onRatingChanged: (r) => ref.read(selectedRatingProvider.notifier).state = r,
                      ),
                      const SizedBox(height: 12),
                      RyvoTextField(
                        controller: _commentController,
                        hint: AppLocalizations.of(context).writeAReviewOptional,
                        maxLines: 3,
                        keyboardType: TextInputType.multiline,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              RyvoButton(
                label: _submitting ? AppLocalizations.of(context).submitting : AppLocalizations.of(context).backToHome,
                onPressed: _submitting ? null : _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortLabel(String value) {
    if (value.length <= 10) return value;
    return '${value.substring(0, 9)}…';
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
