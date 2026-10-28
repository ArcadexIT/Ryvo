import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

/// Returns a reason when the user confirms cancel, or null if they keep the job.
Future<String?> promptJobCancelReason(
  BuildContext context, {
  String title = 'Cancel this job?',
  String defaultReason = 'Cancelled by driver',
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title, style: GoogleFonts.poppins(color: AppColors.textPrimary)),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).reasonOptional,
          hintStyle: GoogleFonts.poppins(color: AppColors.textHint),
        ),
        style: GoogleFonts.poppins(color: AppColors.textPrimary),
        maxLines: 2,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppLocalizations.of(context).keepJob, style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(AppLocalizations.of(context).cancelJob, style: GoogleFonts.poppins(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  if (result == null) return null;
  return result.isEmpty ? defaultReason : result;
}
