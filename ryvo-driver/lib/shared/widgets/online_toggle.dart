import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

/// Compact map top-bar pill — matches earnings card height and style.
class OnlineToggle extends StatelessWidget {
  final bool isOnline;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const OnlineToggle({
    super.key,
    required this.isOnline,
    required this.onChanged,
    this.enabled = true,
  });

  static const double pillHeight = 44;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline ? AppColors.primary.withValues(alpha: 0.5) : AppColors.divider,
        ),
        boxShadow: isOnline
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 8, spreadRadius: 0)]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 10,
            child: isOnline
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.5), blurRadius: 4)],
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isOnline ? AppLocalizations.of(context).online : AppLocalizations.of(context).offline,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOnline ? AppColors.primary : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch.adaptive(
              value: isOnline,
              onChanged: enabled ? onChanged : null,
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
              inactiveThumbColor: AppColors.grey500,
              inactiveTrackColor: AppColors.grey700,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
