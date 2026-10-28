import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;

  List<_OnboardingSlide> _slides(BuildContext context) => [
    _OnboardingSlide(
      icon: Icons.online_prediction,
      title: AppLocalizations.of(context).goOnlineEarn,
      subtitle: AppLocalizations.of(context).toggleOnlineWhenYouReReadyReceiveNearbyJumpStart,
      iconBgColor: AppColors.primary,
    ),
    _OnboardingSlide(
      icon: Icons.flash_on_rounded,
      title: AppLocalizations.of(context).acceptJobsInstantly,
      subtitle: AppLocalizations.of(context).reviewCustomerDetailsDistanceAndPayoutAcceptOrDe,
      iconBgColor: AppColors.success,
    ),
    _OnboardingSlide(
      icon: Icons.account_balance_wallet_outlined,
      title: AppLocalizations.of(context).getPaidFast,
      subtitle: AppLocalizations.of(context).trackEarningsInRealTimeWithdrawToYourBankAccount,
      iconBgColor: AppColors.info,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: AppLogo(size: 30, variant: AppLogoVariant.wordmark),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(AppLocalizations.of(context).skip, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 14)),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides(context).length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _SlideWidget(slide: _slides(context)[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _slides(context).length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.grey700,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  RyvoButton(
                    label: _currentPage == _slides(context).length - 1 ? AppLocalizations.of(context).getStarted : AppLocalizations.of(context).next,
                    onPressed: () {
                      if (_currentPage < _slides(context).length - 1) {
                        _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      } else {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBgColor;
  const _OnboardingSlide({required this.icon, required this.title, required this.subtitle, required this.iconBgColor});
}

class _SlideWidget extends StatelessWidget {
  final _OnboardingSlide slide;
  const _SlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(color: slide.iconBgColor.withOpacity(0.15), shape: BoxShape.circle),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(color: slide.iconBgColor.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(slide.icon, color: slide.iconBgColor, size: 52),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            slide.title,
            style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.subtitle,
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
