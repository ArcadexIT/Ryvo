import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/job_chat_button.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

/// Persistent banner shown on the home map when the provider has an active job
/// but is not on the navigation / service screens (e.g. after pressing back).
class ActiveJobBanner extends ConsumerWidget {
  const ActiveJobBanner({super.key, required this.job});

  final MockJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeRoute = routeForActiveJob(job.status);
    final awaitingPayment = job.status == JobStatusEntity.paymentPending;

    if (resumeRoute == null && !awaitingPayment) return const SizedBox.shrink();

    void resume() {
      if (resumeRoute != null) context.push(resumeRoute);
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: AppColors.surface,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: awaitingPayment
                  ? AppColors.warning.withValues(alpha: 0.35)
                  : AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: awaitingPayment ? null : resume,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (awaitingPayment ? AppColors.warning : AppColors.primary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        awaitingPayment ? Icons.verified_outlined : Icons.local_shipping_outlined,
                        color: awaitingPayment ? AppColors.warning : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.42,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            awaitingPayment ? AppLocalizations.of(context).paymentConfirmed : AppLocalizations.of(context).activeJobInProgress,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            awaitingPayment
                                ? AppLocalizations.of(context).openingNavigationShortly
                                : '${job.customerName} • ${job.jobRef.isEmpty ? job.jobType : job.jobRef}',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (!awaitingPayment)
                TextButton(
                  onPressed: resume,
                  child: Text(
                    AppLocalizations.of(context).resume,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              JobChatButton(jobId: job.id, size: 40),
            ],
          ),
        ),
    );
  }
}
