import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/kyc_providers.dart';
import '../../../../shared/providers/verification_sync.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class VerificationPendingPage extends ConsumerStatefulWidget {
  const VerificationPendingPage({super.key});

  @override
  ConsumerState<VerificationPendingPage> createState() => _VerificationPendingPageState();
}

class _VerificationPendingPageState extends ConsumerState<VerificationPendingPage> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStatus(silent: true));
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _refreshing = true);
    final container = ProviderScope.containerOf(context, listen: false);
    await syncProviderVerification(container);
    if (!mounted) return;
    await ref.read(verificationProvider.notifier).load();
    if (!mounted) return;
    if (!silent) setState(() => _refreshing = false);

    if (ref.read(isKycApprovedProvider)) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kyc = ref.watch(verificationProvider);
    final rejected = kyc.hasRejected;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _checkStatus(),
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: (rejected ? AppColors.error : AppColors.warning).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    rejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
                    size: 56,
                    color: rejected ? AppColors.error : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  rejected ? AppLocalizations.of(context).documentsNeedAttention : AppLocalizations.of(context).verificationInProgress,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  rejected
                      ? AppLocalizations.of(context).oneOrMoreDocumentsWereRejectedByOurTeamPleaseRev
                      : AppLocalizations.of(context).yourDocumentsHaveBeenSubmittedSuccessfullyPlease,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).documentStatus,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...kyc.documents.map((doc) => _DocStatusRow(document: doc)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (rejected ? AppColors.error : AppColors.info).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (rejected ? AppColors.error : AppColors.info).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        rejected ? Icons.upload_file_outlined : Icons.notifications_active_outlined,
                        color: rejected ? AppColors.error : AppColors.info,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rejected
                              ? AppLocalizations.of(context).tapFixDocumentsToReUploadRejectedFilesPullDownTo
                              : AppLocalizations.of(context).youLlReceiveANotificationOnceYourAccountIsApprov,
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                RyvoButton(
                  label: _refreshing ? AppLocalizations.of(context).checking : AppLocalizations.of(context).checkStatus,
                  onPressed: _refreshing ? null : () => _checkStatus(),
                ),
                const SizedBox(height: 12),
                RyvoButton(
                  label: rejected ? AppLocalizations.of(context).fixDocuments : AppLocalizations.of(context).backToDocuments,
                  variant: RyvoButtonVariant.outline,
                  onPressed: () => context.go('/kyc'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await providerSignOut(ref);
                    if (!context.mounted) return;
                    context.go('/login');
                  },
                  child: Text(
                    AppLocalizations.of(context).logout,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocStatusRow extends StatelessWidget {
  final VerificationDocument document;

  const _DocStatusRow({required this.document});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (document.status) {
      VerificationDocStatus.verified => (Icons.check_circle, AppColors.success, 'Approved'),
      VerificationDocStatus.pending => (Icons.schedule, AppColors.warning, 'Under review'),
      VerificationDocStatus.rejected => (Icons.cancel, AppColors.error, 'Rejected'),
      VerificationDocStatus.notUploaded => (Icons.upload_file, AppColors.textHint, 'Not uploaded'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  document.title,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
          if (document.status == VerificationDocStatus.rejected &&
              document.rejectionReason != null &&
              document.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                document.rejectionReason!,
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
