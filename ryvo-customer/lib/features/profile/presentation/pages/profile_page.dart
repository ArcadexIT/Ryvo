import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/iterable_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final config = ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final walletAsync = config.customerWalletEnabled ? ref.watch(walletBalanceProvider) : const AsyncValue.data(null);
    final jobsAsync = ref.watch(jobsListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).profile, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: AppColors.textPrimary))),
          data: (profile) {
            if (profile == null) {
              return Center(child: Text(AppLocalizations.of(context).notSignedIn, style: TextStyle(color: AppColors.textPrimary)));
            }
            final vehicle = profile.vehicles.where((v) => v.isDefault).firstOrNull ??
                profile.vehicles.firstOrNull;
            final balance = walletAsync.valueOrNull?.balance;
            final tripCount = jobsAsync.valueOrNull?.length ?? 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          child: Text(
                            profile.initials,
                            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(profile.fullName, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text(profile.phone, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
                        if (profile.email != null && profile.email!.isNotEmpty)
                          Text(profile.email!, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatBadge(label: AppLocalizations.of(context).trips, value: '$tripCount'),
                            if (config.customerWalletEnabled) ...[
                              const SizedBox(width: 32),
                              _StatBadge(label: AppLocalizations.of(context).wallet, value: balance != null ? formatMoney(balance) : '--'),
                            ],
                            const SizedBox(width: 32),
                            _StatBadge(label: AppLocalizations.of(context).rating, value: profile.ratingLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(AppLocalizations.of(context).myVehicle),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.directions_car, color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: vehicle != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(vehicle.displayName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    Text(
                                      [
                                        'License: ${vehicle.plateNumber}',
                                        if (vehicle.transmission != null)
                                          vehicle.transmission![0].toUpperCase() + vehicle.transmission!.substring(1),
                                        if (vehicle.fuelType != null)
                                          vehicle.fuelType![0].toUpperCase() + vehicle.fuelType!.substring(1),
                                      ].join(' · '),
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                )
                              : Text(AppLocalizations.of(context).noVehicleAdded, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
                        ),
                        IconButton(
                          onPressed: () {
                            if (vehicle != null) {
                              context.push('/add-vehicle?vehicleId=${vehicle.id}');
                            } else {
                              context.push('/add-vehicle');
                            }
                          },
                          icon: const Icon(Icons.edit_outlined, color: AppColors.grey500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(AppLocalizations.of(context).settings),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    label: AppLocalizations.of(context).appearance,
                    trailing: _themeModeLabel(ref.watch(themeModeProvider)),
                    onTap: () => _showThemePicker(context, ref),
                  ),
                  _SettingsTile(icon: Icons.receipt_long_outlined, label: 'Invoices', onTap: () => context.push('/invoices')),
                  _SettingsTile(
                    icon: Icons.email_outlined,
                    label: (profile.email == null || profile.email!.isEmpty) ? 'Add email' : 'Update email',
                    onTap: () => _editEmail(context, ref, profile.email),
                  ),
                  _SettingsTile(icon: Icons.notifications_outlined, label: AppLocalizations.of(context).notifications, onTap: () => context.push('/notifications')),
                  _SettingsTile(icon: Icons.language_outlined, label: AppLocalizations.of(context).language, trailing: 'English', onTap: () {}),
                  _SettingsTile(icon: Icons.help_outline, label: AppLocalizations.of(context).helpSupport, onTap: () => context.push('/help')),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    label: AppLocalizations.of(context).termsAndConditions,
                    onTap: () => context.push('/legal/terms'),
                  ),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    label: AppLocalizations.of(context).privacyPolicy,
                    onTap: () => context.push('/legal/privacy'),
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: Icons.logout,
                    label: AppLocalizations.of(context).signOut,
                    color: AppColors.error,
                    onTap: () async {
                      await signOut(ref);
                      if (context.mounted) context.go('/login');
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(AppLocalizations.of(context).ryvoV100, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };
}

Future<void> _editEmail(BuildContext context, WidgetRef ref, String? current) async {
  final controller = TextEditingController(text: current ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Email for invoices'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(hintText: 'you@email.com'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  final email = controller.text.trim();
  controller.dispose();
  if (saved != true || email.isEmpty || !email.contains('@')) return;
  try {
    await ref.read(profileRepositoryProvider).updateProfile(email: email);
    ref.invalidate(profileProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<void> _showThemePicker(BuildContext context, WidgetRef ref) async {
  final selected = await showModalBottomSheet<ThemeMode>(
    context: context,
    backgroundColor: AppColors.modal,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final current = ref.read(themeModeProvider);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).appearance,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _ThemeOption(
                label: AppLocalizations.of(context).light,
                icon: Icons.light_mode_outlined,
                selected: current == ThemeMode.light,
                onTap: () => Navigator.pop(context, ThemeMode.light),
              ),
              _ThemeOption(
                label: AppLocalizations.of(context).dark,
                icon: Icons.dark_mode_outlined,
                selected: current == ThemeMode.dark,
                onTap: () => Navigator.pop(context, ThemeMode.dark),
              ),
              _ThemeOption(
                label: AppLocalizations.of(context).system,
                icon: Icons.brightness_auto_outlined,
                selected: current == ThemeMode.system,
                onTap: () => Navigator.pop(context, ThemeMode.system),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (selected != null) {
    ref.read(themeModeProvider.notifier).state = selected;
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final Color? color;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.label, required this.onTap, this.trailing, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (color ?? AppColors.grey700).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color ?? AppColors.grey400, size: 20),
        ),
        title: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: c)),
        trailing: trailing != null
            ? Text(trailing!, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary))
            : color != null ? null : const Icon(Icons.chevron_right, color: AppColors.grey600, size: 20),
      ),
    );
  }
}
