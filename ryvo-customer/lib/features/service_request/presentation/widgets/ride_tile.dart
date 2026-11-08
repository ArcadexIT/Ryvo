import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';

/// Border color of a selected tier: obsidian on light, white on dark.
Color rideSelectionColor() =>
    AppColors.isDark ? AppColors.white : AppColors.obsidian;

/// One vehicle tier. Tapping it fires a selection haptic, bounces the row
/// (0.98 → 1.0 over 180ms) and cross-fades the 2px border and surface tint.
class RideTile extends StatefulWidget {
  const RideTile({
    super.key,
    required this.service,
    required this.estimate,
    required this.quoting,
    required this.routeMinutes,
    required this.selected,
    required this.badge,
    required this.onSelect,
    required this.onRetry,
    required this.retryLabel,
  });

  final ServiceCategory service;
  final FareEstimate? estimate;
  final bool quoting;
  final int routeMinutes;
  final bool selected;

  /// "Best value" / "Fastest", or null.
  final String? badge;
  final VoidCallback onSelect;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  State<RideTile> createState() => _RideTileState();
}

class _RideTileState extends State<RideTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.98, end: 1)
      .animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  int get _seats => switch (widget.service.slug) {
        'van' => 8,
        'xl' => 6,
        _ => 4,
      };

  bool get _enabled => widget.estimate != null || widget.quoting;

  void _tap() {
    HapticFeedback.selectionClick();
    _bounce.forward(from: 0);
    widget.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final estimate = widget.estimate;
    final selected = widget.selected;
    final minutes = widget.routeMinutes > 0
        ? widget.routeMinutes
        : (estimate?.durationMin ?? 0);
    final description = (service.description ?? '').trim();
    final accent = rideSelectionColor();

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _enabled ? _tap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.fastOutSlowIn,
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.surface
                : AppColors.surface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : accent.withValues(alpha: 0),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              RideCar(service: service),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            service.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RyvoTypography.style(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        Text(
                          '$_seats',
                          style: RyvoTypography.distance(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (widget.badge != null || description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            if (widget.badge != null) ...[
                              RideBadge(label: widget.badge!),
                              const SizedBox(width: 6),
                            ],
                            if (description.isNotEmpty)
                              Flexible(
                                child: Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RyvoTypography.style(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (estimate != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(estimate.estimatedFare),
                      style: RyvoTypography.price(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (minutes > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.isDark
                              ? AppColors.primary.withValues(alpha: 0.16)
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$minutes min',
                          style: RyvoTypography.eta(
                            fontSize: 11,
                            color: AppColors.isDark
                                ? AppColors.primary
                                : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              else if (widget.quoting)
                const RidePriceSkeleton()
              else
                TextButton(
                  onPressed: widget.onRetry,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    widget.retryLabel,
                    style: RyvoTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Best value" / "Fastest" micro-badge: lime fill with obsidian text.
class RideBadge extends StatelessWidget {
  const RideBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: RyvoTypography.style(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.obsidian,
          letterSpacing: -0.1,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Shimmering fare and ETA pills shown while a quote is in flight.
class RidePriceSkeleton extends StatelessWidget {
  const RidePriceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _pill(width: 56, height: 16),
          const SizedBox(height: 6),
          _pill(width: 38, height: 14),
        ],
      ),
    );
  }

  static Widget _pill({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// Placeholder row used while the tier list itself is loading.
class RideTileSkeleton extends StatelessWidget {
  const RideTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.shimmerBase,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      child: Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Row(
          children: [
            Container(
              width: 64,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.shimmerBase,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(96, 14),
                  const SizedBox(height: 8),
                  bar(140, 10),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                bar(56, 16),
                const SizedBox(height: 6),
                bar(38, 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Vehicle illustration for a tier, or a glyph for parcel services.
class RideCar extends StatelessWidget {
  const RideCar({super.key, required this.service});

  final ServiceCategory service;

  String? get _asset {
    if (service.slug.startsWith('parcel') || service.businessType == 'parcel') {
      return null;
    }
    return switch (service.slug) {
      'comfort' => 'assets/images/ride_comfort.png',
      'xl' || 'van' || 'assist' || 'premium' => 'assets/images/ride_xl.png',
      _ => 'assets/images/ride_go.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    return SizedBox(
      width: 72,
      height: 40,
      child: asset == null
          ? Icon(serviceIcon(service.slug, service.icon),
              color: AppColors.textPrimary, size: 26)
          : Image.asset(asset,
              fit: BoxFit.contain, filterQuality: FilterQuality.medium),
    );
  }
}
