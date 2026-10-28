import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/job/active_job_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class PaymentSuccessPage extends ConsumerStatefulWidget {
  const PaymentSuccessPage({super.key});

  @override
  ConsumerState<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends ConsumerState<PaymentSuccessPage> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _submittingRating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnim = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _finish(String? jobId) async {
    if (_rating > 0 && jobId != null && !_submittingRating) {
      setState(() => _submittingRating = true);
      try {
        final comment = _commentController.text.trim();
        await ref.read(jobRepositoryProvider).rateJob(
          jobId,
          _rating,
          comment: comment.isNotEmpty ? comment : null,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _submittingRating = false);
          showApiError(context, e);
          return;
        }
      }
    }
    if (!mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    markJobSessionFinished(container, jobId: jobId);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final JobModel? job = ref.watch(jobDraftProvider).activeJob;
    final service = job?.serviceCategory?.name ?? AppLocalizations.of(context).roadsideService;
    final providerName = job?.provider?.fullName ?? '—';
    final paymentVia = ref.watch(jobDraftProvider).paymentMethod == 'wallet' ? AppLocalizations.of(context).wallet : AppLocalizations.of(context).card;
    final total = job != null ? formatMoney(job.displayFare) : '—';
    final jobNumber = job?.jobNumber ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) => Column(
                        children: [
                          Transform.scale(
                            scale: _scaleAnim.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_circle, color: AppColors.success, size: 56),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Opacity(
                            opacity: _fadeAnim.value,
                            child: Column(
                              children: [
                                Text(
                                  AppLocalizations.of(context).paymentSuccessful,
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your $service service has been\nsuccessfully completed.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          _ReceiptRow(label: AppLocalizations.of(context).service, value: service),
                          const SizedBox(height: 12),
                          _ReceiptRow(label: AppLocalizations.of(context).provider, value: providerName),
                          if (jobNumber.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _ReceiptRow(label: AppLocalizations.of(context).job, value: jobNumber),
                          ],
                          const SizedBox(height: 12),
                          _ReceiptRow(label: AppLocalizations.of(context).paymentVia, value: paymentVia),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: AppColors.divider),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocalizations.of(context).totalPaid,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                total,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context).howWasYourExperience,
                      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => GestureDetector(
                          onTap: () => setState(() => _rating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.star,
                              color: i < _rating ? AppColors.primary : AppColors.grey600,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    RyvoTextField(
                      controller: _commentController,
                      hint: AppLocalizations.of(context).writeAReviewOptional,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: RyvoButton(
                label: _submittingRating ? AppLocalizations.of(context).submitting : AppLocalizations.of(context).backToHome2,
                onPressed: _submittingRating ? null : () => _finish(job?.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}
