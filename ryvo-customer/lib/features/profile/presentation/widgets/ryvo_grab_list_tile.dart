import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Flat, edge-to-edge account row. No card and no divider.
///
/// A trailing value or a red text badge sits ahead of a small chevron.
class RyvoGrabListTile extends StatelessWidget {
  const RyvoGrabListTile({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
    this.badge,
    this.onTap,
    this.showChevron = true,
    this.labelColor,
    this.haptic = true,
  });

  final String label;
  final IconData? icon;

  /// Secondary data, such as a balance or "12 rides".
  final String? trailing;

  /// Short status word drawn in [AppColors.error], such as "New".
  final String? badge;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? labelColor;

  /// When false, the caller owns the haptic (sign-out uses a heavier impact).
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final trailingText = trailing;
    final badgeText = badge;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                if (haptic) HapticFeedback.lightImpact();
                onTap!();
              },
        splashColor: AppColors.textPrimary.withValues(alpha: 0.04),
        highlightColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 22, color: labelColor ?? AppColors.textPrimary),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RyvoTypography.style(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: labelColor ?? AppColors.textPrimary,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                ),
              ),
              if (trailingText != null && trailingText.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  trailingText,
                  style: RyvoTypography.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    tabular: true,
                  ),
                ),
              ],
              if (badgeText != null && badgeText.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  badgeText,
                  style: RyvoTypography.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
              if (showChevron) ...[
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.textHint,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
