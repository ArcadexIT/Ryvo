import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/ryvo_button.dart';
import '../../../home/presentation/pages/shell_page.dart';
import '../widgets/ryvo_booking_card.dart';

class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key});

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  /// False shows upcoming rides. True shows past rides.
  bool _past = false;

  Future<void> _reload() async {
    ref.invalidate(jobsListProvider);
    await ref.read(jobsListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final jobsAsync = ref.watch(jobsListProvider);
    final bottomInset = RyvoFloatingNav.reservedHeight(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                0,
              ),
              child: Text(
                l10n.activity,
                style: RyvoTypography.heading(
                  fontSize: 32,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _ActivitySegmentedControl(
                past: _past,
                upcomingLabel: l10n.upcoming,
                pastLabel: l10n.past,
                onChanged: (past) => setState(() => _past = past),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: jobsAsync.when(
                loading: () =>
                    RyvoBookingSkeletonList(bottomInset: bottomInset),
                error: (error, _) => _RefreshFill(
                  onRefresh: _reload,
                  bottomInset: bottomInset,
                  child: Text(
                    l10n.couldNotLoadRides,
                    textAlign: TextAlign.center,
                    style: RyvoTypography.style(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                data: (jobs) {
                  final rides = [
                    for (final job in jobs)
                      if (_isPastRide(job) == _past) job,
                  ]..sort(
                      (a, b) => bookingActivityStamp(b)
                          .compareTo(bookingActivityStamp(a)),
                    );
                  if (rides.isEmpty) {
                    return _RefreshFill(
                      onRefresh: _reload,
                      bottomInset: bottomInset,
                      child: _EmptyBookings(
                        message:
                            _past ? l10n.noPastRides : l10n.noUpcomingRides,
                        actionLabel: l10n.bookARide,
                        onBook: () => context.go('/home'),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _reload,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.md + bottomInset,
                      ),
                      itemCount: rides.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: RyvoBookingCard(job: rides[index]),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isPastRide(JobModel job) {
  return switch (job.status) {
    'completed' ||
    'cancelled_by_customer' ||
    'cancelled_by_provider' ||
    'cancelled_by_admin' ||
    'no_provider_found' =>
      true,
    _ => false,
  };
}

class _ActivitySegmentedControl extends StatelessWidget {
  const _ActivitySegmentedControl({
    required this.past,
    required this.upcomingLabel,
    required this.pastLabel,
    required this.onChanged,
  });

  final bool past;
  final String upcomingLabel;
  final String pastLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final pill = AppColors.isDark ? AppColors.white : AppColors.modal;
    final selectedColor =
        AppColors.isDark ? AppColors.obsidian : AppColors.textPrimary;

    return SizedBox(
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = constraints.maxWidth / 2;
              return Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.fastOutSlowIn,
                    alignment: Alignment(past ? 1 : -1, 0),
                    child: SizedBox(
                      width: segmentWidth,
                      height: constraints.maxHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: pill,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SegmentLabel(
                        label: upcomingLabel,
                        selected: !past,
                        selectedColor: selectedColor,
                        onTap: () => _select(false),
                      ),
                      _SegmentLabel(
                        label: pastLabel,
                        selected: past,
                        selectedColor: selectedColor,
                        onTap: () => _select(true),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _select(bool value) {
    if (value == past) return;
    HapticFeedback.selectionClick();
    onChanged(value);
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RyvoTypography.style(
                fontSize: 13,
                height: 1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? selectedColor : AppColors.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RefreshFill extends StatelessWidget {
  const _RefreshFill({
    required this.onRefresh,
    required this.bottomInset,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final double bottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    bottomInset,
                  ),
                  child: Center(child: child),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({
    required this.message,
    required this.actionLabel,
    required this.onBook,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.car_detailed,
          size: 48,
          color: AppColors.textHint,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: RyvoTypography.heading(
            fontSize: 18,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: 200,
          child: RyvoButton(
            label: actionLabel,
            height: 48,
            borderRadius: 12,
            onPressed: onBook,
          ),
        ),
      ],
    );
  }
}
