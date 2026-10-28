import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

enum RyvoButtonVariant { primary, outline, ghost }

class RyvoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final RyvoButtonVariant variant;
  final bool isLoading;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double? width;
  final double height;
  final double borderRadius;
  final String? sublabel;

  const RyvoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = RyvoButtonVariant.primary,
    this.isLoading = false,
    this.prefixIcon,
    this.suffixIcon,
    this.width,
    this.height = 54,
    this.borderRadius = 14,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: sublabel != null ? 64 : height,
      child: switch (variant) {
        RyvoButtonVariant.primary => _buildPrimary(),
        RyvoButtonVariant.outline => _buildOutline(),
        RyvoButtonVariant.ghost => _buildGhost(),
      },
    );
  }

  Widget _buildPrimary() {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 0,
        padding: EdgeInsets.zero,
      ),
      child: _buildContent(AppColors.white),
    );
  }

  Widget _buildOutline() {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: _buildContent(AppColors.primary),
    );
  }

  Widget _buildGhost() {
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: _buildContent(AppColors.primary),
    );
  }

  Widget _buildContent(Color contentColor) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: contentColor,
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (prefixIcon != null) ...[
              prefixIcon!,
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: contentColor,
              ),
            ),
            if (suffixIcon != null) ...[
              const SizedBox(width: 8),
              suffixIcon!,
            ],
          ],
        ),
        if (sublabel != null)
          Text(
            sublabel!,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: contentColor.withOpacity(0.75),
            ),
          ),
      ],
    );
  }
}
