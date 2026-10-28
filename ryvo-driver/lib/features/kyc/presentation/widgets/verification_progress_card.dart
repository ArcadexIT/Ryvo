import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/kyc_providers.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class VerificationProgressCard extends StatelessWidget {
  final VerificationState kycState;

  const VerificationProgressCard({super.key, required this.kycState});

  @override
  Widget build(BuildContext context) {
    final progress = kycState.progressPercent / 100;
    final uploaded = kycState.documents.where((doc) => doc.isSubmitted).length;
    final total = kycState.documents.length;
    final accent = kycState.allVerified
        ? AppColors.success
        : kycState.hasRejected
            ? AppColors.error
            : AppColors.primaryDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).verificationProgress,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.white.withValues(alpha: 0.72)),
                ),
              ),
              Text(
                '$uploaded of $total',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${kycState.progressPercent}%',
            style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, height: 1, color: AppColors.white),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.white.withValues(alpha: 0.12),
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            kycState.progressMessage,
            style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: AppColors.white.withValues(alpha: 0.78)),
          ),
        ],
      ),
    );
  }
}
