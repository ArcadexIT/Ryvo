import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/verification_sync.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    await Future.wait([
      providerBootstrap(container),
      container.read(appConfigProvider.future),
      Future.delayed(const Duration(seconds: 2)),
    ]);
    if (!mounted) return;
    final isAuth = container.read(isAuthenticatedProvider);
    if (isAuth) {
      await syncProviderVerification(container);
    }
    if (!mounted) return;
    final kycApproved = container.read(isKycApprovedProvider);
    final agreementAccepted = container.read(isAgreementAcceptedProvider);
    if (isAuth && kycApproved) {
      final resumeRoute = await restoreActiveJobSession(container);
      if (!mounted) return;
      context.go(resumeRoute ?? '/home');
    } else if (isAuth) {
      context.go(providerOnboardingRoute(
        agreementAccepted: agreementAccepted,
        kycApproved: kycApproved,
        documentsInReview: container.read(isKycInReviewProvider),
      ));
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 200, variant: AppLogoVariant.lockup),
                  const SizedBox(height: 24),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).providerEarnHelpingDrivers,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
