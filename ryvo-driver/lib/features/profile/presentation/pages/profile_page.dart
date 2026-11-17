import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/job_chat_button.dart';
import '../../../../shared/widgets/provider_avatar.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';
import 'delete_account_flow.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(providerProfileProvider);
    final provider = profile.value;
    final l10n = AppLocalizations.of(context);
    final name = provider?.name.isNotEmpty == true ? provider!.name : l10n.provider;
    final phone = provider?.phone.trim() ?? '';
    final rating = provider?.rating ?? 0;
    final trips = provider?.totalTrips ?? 0;
    final activeJob = ref.watch(activeJobProvider);
    final resumeRoute = activeJob == null ? null : routeForActiveJob(activeJob.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.profile, style: _type(size: 22, weight: FontWeight.w700, letterSpacing: -0.4)),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        ProviderAvatar(name: name, avatarUrl: provider?.avatarUrl, radius: 26),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _type(size: 22, weight: FontWeight.w700, letterSpacing: -0.4, height: 1.15),
                              ),
                              if (phone.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(phone, style: _type(size: 13, color: AppColors.textSecondary, tabular: true)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rating.toStringAsFixed(1),
                                style: _type(size: 40, weight: FontWeight.w700, letterSpacing: -0.8, height: 1, tabular: true),
                              ),
                              const SizedBox(height: 6),
                              Text(l10n.rating, style: _type(size: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            border: Border(left: BorderSide(color: AppColors.divider)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(l10n.jobs, style: _type(size: 11, weight: FontWeight.w500, color: AppColors.textHint)),
                                const SizedBox(height: 2),
                                Text(
                                  '$trips',
                                  style: _type(size: 16, weight: FontWeight.w700, letterSpacing: -0.4, tabular: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.surface,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Section(
                        title: l10n.account,
                        first: true,
                        rows: [
                          _Row(l10n.documentsVerification, () => context.push('/documents-verification')),
                          _Row('Tax & insurance', () => context.push('/compliance')),
                          _Row(l10n.personalInfo, () => context.push('/personal-info')),
                          _Row(l10n.vehicleInfo, () => context.push('/vehicle-info')),
                          _Row(l10n.paymentMethods2, () => context.push('/payment-methods')),
                          _Row('Delete account', () => confirmDeleteDriverAccount(context, ref), color: AppColors.error),
                        ],
                      ),
                      _Section(
                        title: l10n.preferences,
                        rows: [
                          _Row(l10n.notifications, () => context.push('/notifications')),
                          _Row(l10n.languageRegion, () => context.push('/language')),
                        ],
                      ),
                      _Section(
                        title: l10n.support,
                        rows: [
                          _Row(l10n.myPerformance, () => context.push('/performance')),
                          _Row(l10n.wallet, () => context.push('/wallet')),
                          _Row(l10n.helpSupport, () => context.push('/help')),
                          _Row('Privacy policy', () {
                            launchUrl(
                              Uri.parse('https://ryvo.arcadexit.com/privacy-policy/'),
                              mode: LaunchMode.externalApplication,
                            );
                          }),
                          if (resumeRoute != null)
                            _Row(l10n.resumeActiveJob, () => context.push(resumeRoute), color: AppColors.primary),
                          if (activeJob != null && resumeRoute != null)
                            _Row(l10n.chatWithCustomer, () => openJobChat(context, ref, jobId: activeJob.id)),
                        ],
                      ),
                      InkWell(
                        onTap: () => _confirmLogout(context, ref),
                        splashColor: AppColors.grey100,
                        highlightColor: AppColors.grey100,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.divider)),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.logout,
                            style: _type(size: 15, weight: FontWeight.w700, color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      surfaceTintColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      title: Text(l10n.logout, style: _type(size: 18, weight: FontWeight.w700, letterSpacing: -0.3)),
      content: Text(l10n.logoutConfirmBody, style: _type(size: 14, color: AppColors.textSecondary)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel, style: _type(size: 14, weight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.logout, style: _type(size: 14, weight: FontWeight.w700, color: AppColors.error)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await providerSignOut(ref);
  ref.read(isKycApprovedProvider.notifier).state = false;
  if (context.mounted) context.go('/login');
}

class _Row {
  const _Row(this.label, this.onTap, {this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.first = false});

  final String title;
  final List<_Row> rows;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, first ? 22 : 26, 24, 2),
          child: Text(
            title,
            style: _type(size: 12, weight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.2),
          ),
        ),
        for (var i = 0; i < rows.length; i++)
          InkWell(
            onTap: rows[i].onTap,
            splashColor: AppColors.grey100,
            highlightColor: AppColors.grey100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: _type(size: 15, weight: FontWeight.w600, letterSpacing: -0.2, color: rows[i].color ?? AppColors.textPrimary),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

TextStyle _type({
  required double size,
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.textPrimary,
  double letterSpacing = 0,
  double height = 1.2,
  bool tabular = false,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}
