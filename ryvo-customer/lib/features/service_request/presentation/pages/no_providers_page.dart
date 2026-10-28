import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class NoProvidersPage extends StatelessWidget {
  const NoProvidersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_off_outlined, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context).noProvidersAvailable,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).thereAreNoProvidersAvailableNearbyRightNowPlease,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
              ),
              const Spacer(),
              RyvoButton(
                label: AppLocalizations.of(context).backToHome,
                onPressed: () => context.go('/home'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
