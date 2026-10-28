import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

enum JobStatus { pending, active, completed, declined, cancelled }

class JobStatusChip extends StatelessWidget {
  final JobStatus status;

  const JobStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      JobStatus.pending => ('Pending', AppColors.warning, AppColors.warning.withOpacity(0.15)),
      JobStatus.active => ('Active', AppColors.info, AppColors.info.withOpacity(0.15)),
      JobStatus.completed => ('Completed', AppColors.success, AppColors.success.withOpacity(0.15)),
      JobStatus.declined => ('Declined', AppColors.error, AppColors.error.withOpacity(0.15)),
      JobStatus.cancelled => ('Cancelled', AppColors.grey400, AppColors.grey700.withOpacity(0.5)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
