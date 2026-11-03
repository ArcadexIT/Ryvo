import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

enum RyvoButtonVariant { primary, outline, ghost }

/// Scales to 0.98 while a pointer is down. Does not absorb the gesture.
class RyvoPressScale extends StatefulWidget {
  const RyvoPressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.98,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<RyvoPressScale> createState() => _RyvoPressScaleState();
}

class _RyvoPressScaleState extends State<RyvoPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(RyvoPressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.fastOutSlowIn,
        child: widget.child,
      ),
    );
  }
}

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
    this.height = 56,
    this.borderRadius = 16,
    this.sublabel,
  });

  bool get _enabled => onPressed != null && !isLoading;

  void _handlePressed() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    return RyvoPressScale(
      enabled: _enabled,
      child: SizedBox(
        width: width ?? double.infinity,
        height: sublabel != null ? 64 : height,
        child: switch (variant) {
          RyvoButtonVariant.primary => _buildPrimary(),
          RyvoButtonVariant.outline => _buildOutline(),
          RyvoButtonVariant.ghost => _buildGhost(),
        },
      ),
    );
  }

  Widget _buildPrimary() {
    return ElevatedButton(
      onPressed: _enabled ? _handlePressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cta,
        foregroundColor: AppColors.onCta,
        disabledBackgroundColor: _resting(AppColors.cta),
        disabledForegroundColor: _resting(AppColors.onCta, foreground: true),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: EdgeInsets.zero,
      ),
      child: _buildContent(AppColors.onCta),
    );
  }

  Widget _buildOutline() {
    return OutlinedButton(
      onPressed: _enabled ? _handlePressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: EdgeInsets.zero,
      ),
      child: _buildContent(AppColors.primary),
    );
  }

  Widget _buildGhost() {
    return TextButton(
      onPressed: _enabled ? _handlePressed : null,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: EdgeInsets.zero,
      ),
      child: _buildContent(AppColors.primary),
    );
  }

  Color _resting(Color color, {bool foreground = false}) {
    if (isLoading) return color;
    return color.withValues(alpha: foreground ? 0.6 : 0.38);
  }

  Widget _buildContent(Color contentColor) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.fastOutSlowIn,
      switchOutCurve: Curves.fastOutSlowIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: isLoading
          ? SizedBox(
              key: const ValueKey<String>('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: contentColor,
              ),
            )
          : Column(
              key: ValueKey<String>('$label${sublabel ?? ''}'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (prefixIcon != null) ...[
                      prefixIcon!,
                      AppSpacing.w8,
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RyvoTypography.button(color: contentColor),
                      ),
                    ),
                    if (suffixIcon != null) ...[
                      AppSpacing.w8,
                      suffixIcon!,
                    ],
                  ],
                ),
                if (sublabel != null) ...[
                  AppSpacing.h4,
                  Text(
                    sublabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RyvoTypography.style(
                      fontSize: 12,
                      color: contentColor.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
