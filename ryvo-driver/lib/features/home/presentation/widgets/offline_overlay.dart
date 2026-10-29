import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class OfflineOverlay extends StatelessWidget {
  final VoidCallback onGoOnline;

  const OfflineOverlay({super.key, required this.onGoOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x990E1626),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF141C2B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.power_settings_new, size: 30, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).youReOffline,
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).goOnlineToStartReceivingJobRequestsFromNearbyCus,
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF94A3B8), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              RyvoButton(
                label: AppLocalizations.of(context).goOnline,
                prefixIcon: const Icon(Icons.power_settings_new, size: 20),
                onPressed: onGoOnline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
