import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/rating_stars.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(providerProfileProvider);
    final provider = profile.value;
    final name = provider?.name.isNotEmpty == true ? provider!.name : AppLocalizations.of(context).provider;
    final rating = provider?.rating ?? 0;
    final trips = provider?.totalTrips ?? 0;
    final activeJob = ref.watch(activeJobProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              ProviderAvatar(
                name: name,
                avatarUrl: provider?.avatarUrl,
                radius: 44,
              ),
              const SizedBox(height: 16),
              Text(name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RatingStars(rating: rating, size: 18),
                  const SizedBox(width: 8),
                  Text('${rating.toStringAsFixed(1)} • $trips trips', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 32),
              _SettingsSection(title: AppLocalizations.of(context).account, items: [
                _SettingsItem(icon: Icons.verified_user_outlined, label: AppLocalizations.of(context).documentsVerification, route: '/documents-verification'),
                _SettingsItem(icon: Icons.gavel_outlined, label: 'Tax & insurance', route: '/compliance'),
                _SettingsItem(icon: Icons.person_outline, label: AppLocalizations.of(context).personalInfo, route: '/personal-info'),
                _SettingsItem(icon: Icons.directions_car_outlined, label: AppLocalizations.of(context).vehicleInfo, route: '/vehicle-info'),
                _SettingsItem(icon: Icons.payment_outlined, label: AppLocalizations.of(context).paymentMethods2, route: '/payment-methods'),
              ]),
              const SizedBox(height: 16),
              _SettingsSection(title: AppLocalizations.of(context).preferences, items: [
                _SettingsItem(icon: Icons.notifications_outlined, label: AppLocalizations.of(context).notifications, route: '/notifications'),
                _SettingsItem(icon: Icons.language_outlined, label: AppLocalizations.of(context).languageRegion, route: '/language'),
              ]),
              const SizedBox(height: 16),
              _SettingsSection(title: AppLocalizations.of(context).support, items: [
                _SettingsItem(icon: Icons.analytics_outlined, label: AppLocalizations.of(context).myPerformance, route: '/performance'),
                _SettingsItem(icon: Icons.account_balance_wallet_outlined, label: AppLocalizations.of(context).wallet, route: '/wallet'),
                _SettingsItem(icon: Icons.help_outline, label: AppLocalizations.of(context).helpSupport, route: '/help'),
                if (activeJob != null && routeForActiveJob(activeJob.status) != null) ...[
                  _SettingsItem(
                    icon: Icons.navigation_outlined,
                    label: AppLocalizations.of(context).resumeActiveJob,
                    route: routeForActiveJob(activeJob.status)!,
                  ),
                  _SettingsItem(
                    icon: Icons.chat_outlined,
                    label: AppLocalizations.of(context).chatWithCustomer,
                    onTap: () => openJobChat(context, ref, jobId: activeJob.id),
                  ),
                ],
              ]),
              const SizedBox(height: 24),
              ListTile(
                onTap: () async {
                  await providerSignOut(ref);
                  ref.read(isKycApprovedProvider.notifier).state = false;
                  if (context.mounted) context.go('/login');
                },
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: Text(AppLocalizations.of(context).logout, style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.divider)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;
  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
          child: Column(
            children: items.map((item) {
              return ListTile(
                leading: Icon(item.icon, color: AppColors.textSecondary, size: 22),
                title: Text(item.label, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.grey500, size: 20),
                onTap: item.onTap ?? () => context.push(item.route!),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final String? route;
  final VoidCallback? onTap;
  const _SettingsItem({
    required this.icon,
    required this.label,
    this.route,
    this.onTap,
  }) : assert(route != null || onTap != null);
}
