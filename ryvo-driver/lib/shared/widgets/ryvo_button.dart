import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

enum RyvoButtonVariant { primary, outline, ghost }

class RyvoButton extends StatefulWidget {
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
  State<RyvoButton> createState() => _RyvoButtonState();
}

class _RyvoButtonState extends State<RyvoButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    _scaleAnim = _scaleController.drive(Tween<double>(begin: 1.0, end: 0.95));
    _scaleController.value = 1.0;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      _scaleController.reverse();
    }
  }

  void _onTapUp(TapUpDetails _) {
    _scaleController.forward();
  }

  void _onTapCancel() {
    _scaleController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SizedBox(
          width: widget.width ?? double.infinity,
          height: widget.sublabel != null ? 64 : widget.height,
          child: switch (widget.variant) {
            RyvoButtonVariant.primary => _buildPrimary(),
            RyvoButtonVariant.outline => _buildOutline(),
            RyvoButtonVariant.ghost => _buildGhost(),
          },
        ),
      ),
    );
  }

  Widget _buildPrimary() {
    return ElevatedButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.navy,
        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius)),
        elevation: 0,
        padding: EdgeInsets.zero,
      ),
      child: _buildContent(AppColors.navy),
    );
  }

  Widget _buildOutline() {
    return OutlinedButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius)),
      ),
      child: _buildContent(AppColors.primary),
    );
  }

  Widget _buildGhost() {
    return TextButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius)),
      ),
      child: _buildContent(AppColors.primary),
    );
  }

  Widget _buildContent(Color contentColor) {
    if (widget.isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: contentColor),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.prefixIcon != null) ...[widget.prefixIcon!, const SizedBox(width: 8)],
            Text(
              widget.label,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: contentColor),
            ),
            if (widget.suffixIcon != null) ...[const SizedBox(width: 8), widget.suffixIcon!],
          ],
        ),
        if (widget.sublabel != null)
          Text(
            widget.sublabel!,
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
