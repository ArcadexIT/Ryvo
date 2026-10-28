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
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.modal,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.grey500),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).youReOffline, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).goOnlineToStartReceivingJobRequestsFromNearbyCus,
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              RyvoButton(label: AppLocalizations.of(context).goOnline, prefixIcon: const Icon(Icons.power_settings_new, size: 20), onPressed: onGoOnline),
            ],
          ),
        ),
      ),
    );
  }
}
