import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

/// Returns a reason when the user confirms cancel, or null if they keep the job.
Future<String?> promptJobCancelReason(
  BuildContext context, {
  String title = 'Cancel this job?',
  String defaultReason = 'Cancelled by customer',
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      elevation: 0,
      backgroundColor: AppColors.modal,
      title: Text(title,
          style: RyvoTypography.heading(color: AppColors.textPrimary)),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).reasonOptional,
          hintStyle: RyvoTypography.style(color: AppColors.textHint),
        ),
        style: RyvoTypography.style(fontSize: 15, color: AppColors.textPrimary),
        maxLines: 2,
      ),
      actions: [
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(ctx);
          },
          child: Text(
            AppLocalizations.of(context).keepJob,
            style: RyvoTypography.button(
                fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(ctx, controller.text.trim());
          },
          child: Text(
            AppLocalizations.of(context).cancelJob,
            style: RyvoTypography.button(fontSize: 14, color: AppColors.error),
          ),
        ),
      ],
    ),
  );
  if (result == null) return null;
  return result.isEmpty ? defaultReason : result;
}
