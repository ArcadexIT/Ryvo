import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_call.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/job_chat_button.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

/// Trip actions on the home map when a ride is already accepted.
class ActiveJobBanner extends ConsumerWidget {
  const ActiveJobBanner({super.key, required this.job});

  final MockJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeRoute = routeForActiveJob(job.status);
    final awaitingPayment = job.status == JobStatusEntity.paymentPending;
    if (resumeRoute == null && !awaitingPayment) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final (kicker, action, icon) = switch (job.status) {
      JobStatusEntity.arrived => (l10n.arrived, 'Start trip', Icons.near_me_rounded),
      JobStatusEntity.inProgress => ('On trip', l10n.resume, Icons.play_arrow_rounded),
      JobStatusEntity.paymentPending => (l10n.paymentConfirmed, 'Waiting', Icons.verified_outlined),
      _ => ('Pickup', 'Navigate', Icons.navigation_rounded),
    };

    void resume() {
      if (resumeRoute != null) context.push(resumeRoute);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xF2141C2B),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          _RoundAction(
            icon: Icons.call_rounded,
            tooltip: l10n.callCustomer,
            onTap: () => dialPhone(context, job.customerPhone),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: awaitingPayment ? const Color(0xFF1F2937) : AppColors.primary,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                onTap: awaitingPayment ? null : resume,
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  height: 58,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: awaitingPayment ? Colors.white : AppColors.navy, size: 22),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kicker,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: (awaitingPayment ? Colors.white : AppColors.navy).withValues(alpha: 0.7),
                              height: 1.1,
                            ),
                          ),
                          Text(
                            action,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: awaitingPayment ? Colors.white : AppColors.navy,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundAction(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: l10n.message,
            onTap: () => openJobChat(context, ref, jobId: job.id),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF243044),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
