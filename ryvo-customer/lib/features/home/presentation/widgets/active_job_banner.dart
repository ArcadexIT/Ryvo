import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/job/active_job_session.dart';
import '../../../../core/job/resume_customer_job.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/models.dart';
import '../../../tracking/presentation/widgets/share_trip_button.dart';
import '../../../../shared/providers/app_providers.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

/// Persistent banner on the home map when a service request is still active.
class ActiveJobBanner extends StatelessWidget {
  const ActiveJobBanner({super.key, required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    final serviceName = job.serviceCategory?.name ?? AppLocalizations.of(context).roadsideService;
    final statusColor = jobStatusColor(effectiveCustomerJobStatus(job));

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(16),
      color: AppColors.surface,
      child: InkWell(
        onTap: () => resumeCustomerJob(context, job),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  serviceIcon(job.serviceCategory?.slug, job.serviceCategory?.icon),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeJobHeadlineForModel(job),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$serviceName • ${job.jobNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => resumeCustomerJob(context, job),
                child: Text(
                  AppLocalizations.of(context).resume,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (shareableTripStatuses.contains(effectiveCustomerJobStatus(job)))
                ShareTripButton.icon(jobId: job.id),
            ],
          ),
        ),
      ),
    );
  }
}
