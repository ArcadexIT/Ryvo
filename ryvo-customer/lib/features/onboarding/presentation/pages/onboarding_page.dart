import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/ryvo_button.dart';
import '../widgets/onboarding_visual_stage.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    if (_currentPage >= _pageCount - 1) {
      context.go('/login');
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slides = <({String title, String body})>[
      (
        title: l10n.instantJumpStart,
        body: l10n.strandedWithADeadBatteryGetAVerifiedProviderToYo,
      ),
      (
        title: l10n.verifiedTrusted,
        body: l10n.everyProviderIsBackgroundCheckedCertifiedAndRate,
      ),
      (
        title: l10n.liveTracking,
        body: l10n.watchYourProviderNavigateToYouInRealTimeKnowExac,
      ),
    ];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sheetTop = constraints.maxHeight * 0.60;
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: sheetTop + 28,
                child: OnboardingVisualStage(controller: _controller),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: sheetTop,
                bottom: 0,
                child: const _OnboardingSheet(),
              ),
              PageView(
                controller: _controller,
                scrollBehavior: const _QuietScrollBehavior(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  for (final slide in slides)
                    _SlideCopy(
                      key: ValueKey<String>(slide.title),
                      top: sheetTop + 28,
                      title: slide.title,
                      body: slide.body,
                    ),
                ],
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: bottomInset + 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IgnorePointer(
                      child: SmoothPageIndicator(
                        controller: _controller,
                        count: slides.length,
                        effect: ExpandingDotsEffect(
                          activeDotColor: AppColors.primary,
                          dotColor: AppColors.textHint,
                          dotHeight: 6,
                          dotWidth: 6,
                          expansionFactor: 3,
                          spacing: 6,
                          radius: 3,
                        ),
                      ),
                    ),
                    AppSpacing.h20,
                    RyvoButton(
                      label: _currentPage == slides.length - 1
                          ? l10n.getStarted
                          : l10n.next,
                      onPressed: _continue,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 16),
                    child: _SkipPill(
                      label: l10n.skip,
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OnboardingSheet extends StatelessWidget {
  const _OnboardingSheet();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.divider),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({
    super.key,
    required this.top,
    required this.title,
    required this.body,
  });

  final double top;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(top: top, left: 24, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: RyvoTypography.style(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.6,
                height: 1.12,
              ),
            ),
            AppSpacing.h8,
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RyvoTypography.style(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                letterSpacing: -0.2,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkipPill extends StatelessWidget {
  const _SkipPill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.modal,
      shape: StadiumBorder(side: BorderSide(color: AppColors.divider)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: RyvoTypography.style(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietScrollBehavior extends MaterialScrollBehavior {
  const _QuietScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
