import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/currency.dart';
import '../../../../data/models/models.dart';

/// "Name your price" controls: a large tabular offer flanked by − / + pills,
/// a match-chance badge, and a slider for coarse moves.
class BidControls extends StatelessWidget {
  const BidControls({
    super.key,
    required this.suggested,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  /// Fare the server suggests for the selected tier.
  final double suggested;
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  /// Offers at or above this share of the suggested fare read as competitive.
  static const double competitiveRatio = 0.9;

  double get _step {
    final raw = suggested * 0.04;
    const steps = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
    var step = steps.firstWhere((s) => s >= raw, orElse: () => steps.last);
    if (ActiveCurrency.current.decimals == 0) step = math.max(step, 1);
    return step;
  }

  bool get _competitive => value >= suggested * competitiveRatio;

  void _nudge(double direction) {
    HapticFeedback.lightImpact();
    final high = max <= min ? min + 1 : max;
    onChanged((value + direction * _step).clamp(min, high).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final high = max <= min ? min + 1 : max;
    final canDecrease = value > min + 1e-6;
    final canIncrease = value < high - 1e-6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StepButton(
                icon: CupertinoIcons.minus,
                onPressed: canDecrease ? () => _nudge(-1) : null,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatMoney(value),
                        maxLines: 1,
                        style: RyvoTypography.style(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.8,
                          height: 1.1,
                          tabular: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.fastOutSlowIn,
                      child: _MatchBadge(
                        key: ValueKey(_competitive),
                        competitive: _competitive,
                      ),
                    ),
                  ],
                ),
              ),
              _StepButton(
                icon: CupertinoIcons.plus,
                onPressed: canIncrease ? () => _nudge(1) : null,
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.cta,
              inactiveTrackColor: AppColors.surface,
              thumbColor: AppColors.cta,
              overlayColor: AppColors.cta.withValues(alpha: 0.08),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              min: min,
              max: high,
              value: value.clamp(min, high).toDouble(),
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatMoney(min),
                style: RyvoTypography.distance(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Suggested ${formatMoney(suggested)}',
                style: RyvoTypography.distance(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                formatMoney(high),
                style: RyvoTypography.distance(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.fastOutSlowIn,
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? AppColors.textPrimary
              : AppColors.textPrimary.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({super.key, required this.competitive});

  final bool competitive;

  @override
  Widget build(BuildContext context) {
    final color = competitive
        ? (AppColors.isDark ? AppColors.primary : AppColors.primaryDark)
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            competitive
                ? CupertinoIcons.checkmark_alt_circle_fill
                : CupertinoIcons.exclamationmark_circle_fill,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            competitive ? 'Competitive' : 'Low match chance',
            style: RyvoTypography.style(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.1,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
