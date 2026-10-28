import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/kyc_providers.dart';

class DocumentVerificationCard extends StatelessWidget {
  final VerificationDocument document;
  final VoidCallback onAction;

  const DocumentVerificationCard({super.key, required this.document, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final (accent, iconBg, icon) = _styleFor(document);
    final action = _actionLabel(document.status);
    final detail = document.statusDetail ?? document.subtitle;

    return InkWell(
      onTap: onAction,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: GoogleFonts.poppins(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
                  ),
                  if (document.status == VerificationDocStatus.rejected &&
                      document.rejectionReason != null &&
                      document.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      document.rejectionReason!,
                      style: GoogleFonts.poppins(fontSize: 12, height: 1.35, color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(status: document.status, label: action),
            const Icon(Icons.chevron_right, color: AppColors.grey400, size: 20),
          ],
        ),
      ),
    );
  }

  (Color, Color, IconData) _styleFor(VerificationDocument document) {
    final accent = switch (document.status) {
      VerificationDocStatus.verified => AppColors.success,
      VerificationDocStatus.pending => AppColors.warning,
      VerificationDocStatus.rejected => AppColors.error,
      VerificationDocStatus.notUploaded => AppColors.info,
    };
    final icon = switch (document.type) {
      VerificationDocType.selfie => Icons.face_outlined,
      VerificationDocType.license => Icons.badge_outlined,
      VerificationDocType.registration => Icons.directions_car_outlined,
      VerificationDocType.insurance => Icons.shield_outlined,
      VerificationDocType.equipment => Icons.handyman_outlined,
    };
    return (accent, accent.withValues(alpha: 0.15), icon);
  }

  String _actionLabel(VerificationDocStatus status) => switch (status) {
        VerificationDocStatus.verified => 'Done',
        VerificationDocStatus.pending => 'In review',
        VerificationDocStatus.rejected => 'Fix',
        VerificationDocStatus.notUploaded => 'Upload',
      };
}

class _StatusBadge extends StatelessWidget {
  final VerificationDocStatus status;
  final String label;
  const _StatusBadge({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      VerificationDocStatus.verified => AppColors.success,
      VerificationDocStatus.pending => AppColors.warning,
      VerificationDocStatus.rejected => AppColors.error,
      VerificationDocStatus.notUploaded => AppColors.navy,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status == VerificationDocStatus.notUploaded ? AppColors.primary : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: status == VerificationDocStatus.notUploaded ? AppColors.navy : color,
        ),
      ),
    );
  }
}
