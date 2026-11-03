import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';

/// Moment shown on an activity row, and the key used to sort that list.
DateTime bookingActivityStamp(JobModel job) {
  return job.completedAt ??
      job.cancelledAt ??
      job.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

/// Flat activity row: date and status, a two-stop timeline, then vehicle and fare.
class RyvoBookingCard extends StatelessWidget {
  const RyvoBookingCard({super.key, required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final when = _formatWhen(context, bookingActivityStamp(job));
    final destination = job.dropoffAddress?.trim();
    final hasDropoff = destination != null && destination.isNotEmpty;
    final vehicle = _vehicleLabel(job, l10n.service);

    return Semantics(
      container: true,
      label: '$when, ${formatJobStatus(job.status)}, ${job.pickupAddress}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.modal,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RyvoTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _StatusBadge(status: job.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _RouteTimeline(
                origin: job.pickupAddress,
                destination: hasDropoff ? destination : '—',
                destinationMuted: !hasDropoff,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    serviceIcon(
                      job.serviceCategory?.slug,
                      job.serviceCategory?.icon,
                    ),
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      vehicle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RyvoTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatMoney(job.displayFare),
                    style: RyvoTypography.price(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton list whose rows match [RyvoBookingCard] chrome and spacing.
class RyvoBookingSkeletonList extends StatelessWidget {
  const RyvoBookingSkeletonList({
    super.key,
    this.count = 6,
    this.bottomInset = 0,
  });

  final int count;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md + bottomInset,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: _RyvoBookingCardSkeleton(),
        );
      },
    );
  }
}

class _RyvoBookingCardSkeleton extends StatelessWidget {
  const _RyvoBookingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Bone(width: 132, height: 12),
                  Spacer(),
                  _Bone(width: 76, height: 20, radius: 6),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      SizedBox(height: 4),
                      _Bone(width: 8, height: 8, radius: 8),
                      _Bone(width: 1, height: 16, radius: 0),
                      _Bone(width: 8, height: 8, radius: 1),
                    ],
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(width: double.infinity, height: 12),
                        SizedBox(height: AppSpacing.xs),
                        _Bone(width: 168, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _Bone(width: 18, height: 18, radius: 4),
                  SizedBox(width: AppSpacing.xs),
                  _Bone(width: 88, height: 12),
                  Spacer(),
                  _Bone(width: 56, height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({
    required this.width,
    required this.height,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          formatJobStatus(status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: RyvoTypography.style(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: tone.foreground,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({
    required this.origin,
    required this.destination,
    required this.destinationMuted,
  });

  final String origin;
  final String destination;
  final bool destinationMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 16,
          child: Column(
            children: [
              const SizedBox(height: 4),
              const _PickupDot(),
              ColoredBox(
                color: AppColors.textHint,
                child: const SizedBox(width: 1, height: 16),
              ),
              const _DropoffSquare(),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origin.isEmpty ? '—' : origin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _addressStyle(
                  origin.isEmpty ? AppColors.textHint : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _addressStyle(
                  destinationMuted ? AppColors.textHint : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickupDot extends StatelessWidget {
  const _PickupDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      height: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _DropoffSquare extends StatelessWidget {
  const _DropoffSquare();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      height: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textPrimary, width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(1)),
        ),
      ),
    );
  }
}

({Color foreground, Color background}) _statusTone(String status) {
  if (status.startsWith('cancelled') || status == 'no_provider_found') {
    return (
      foreground: AppColors.error,
      background: AppColors.error.withValues(alpha: 0.12),
    );
  }
  if (status == 'payment_pending') {
    return (
      foreground: AppColors.warning,
      background: AppColors.warning.withValues(alpha: 0.14),
    );
  }
  final emerald = AppColors.isDark ? AppColors.primary : AppColors.primaryDark;
  return (
    foreground: emerald,
    background: AppColors.primary.withValues(alpha: 0.12),
  );
}

TextStyle _addressStyle(Color color) {
  return RyvoTypography.style(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.2,
    color: color,
  );
}

String _vehicleLabel(JobModel job, String fallback) {
  final category = job.serviceCategory?.name.trim();
  if (category != null && category.isNotEmpty) return category;
  final type = job.vehicle?.vehicleType.trim();
  if (type != null && type.isNotEmpty) {
    return type[0].toUpperCase() + type.substring(1);
  }
  return fallback;
}

String _formatWhen(BuildContext context, DateTime stamp) {
  if (stamp.millisecondsSinceEpoch == 0) return '';
  final l10n = AppLocalizations.of(context);
  final local = stamp.toLocal();
  final locale = Localizations.localeOf(context).toLanguageTag();
  final time = DateFormat.jm(locale).format(local);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return l10n.todayAt(time);
  if (day == today.subtract(const Duration(days: 1))) {
    return l10n.yesterdayAt(time);
  }
  final date = DateFormat('EEE, MMM d', locale).format(local);
  return '$date, $time';
}
