import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final walletAsync = config.customerWalletEnabled
        ? ref.watch(walletBalanceProvider)
        : const AsyncValue.data(null);
    final jobsAsync = ref.watch(jobsListProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          l10n.profile,
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: false,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.toString(), textAlign: TextAlign.center, style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                TextButton(onPressed: () => ref.invalidate(profileProvider), child: Text(l10n.retry)),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Text(l10n.notSignedIn, style: GoogleFonts.poppins(color: AppColors.textPrimary)),
            );
          }
          final balance = walletAsync.valueOrNull?.balance;
          final tripCount = jobsAsync.valueOrNull?.length ?? 0;
          final emailLabel = (profile.email == null || profile.email!.isEmpty) ? 'Add email' : 'Update email';

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(profileProvider);
              ref.invalidate(jobsListProvider);
              if (config.customerWalletEnabled) ref.invalidate(walletBalanceProvider);
              await ref.read(profileProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _IdentityHeader(profile: profile),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.route_rounded,
                        value: '$tripCount',
                        label: l10n.trips,
                        onTap: () => context.go('/bookings'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.star_rounded,
                        value: profile.ratingLabel,
                        label: l10n.rating,
                      ),
                    ),
                    if (config.customerWalletEnabled) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.account_balance_wallet_rounded,
                          value: balance != null ? formatMoney(balance) : '--',
                          label: l10n.wallet,
                          onTap: () => context.go('/wallet'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                _MenuGroup(
                  title: 'Account',
                  items: [
                    _MenuEntry(
                      icon: Icons.mail_outline_rounded,
                      label: emailLabel,
                      subtitle: (profile.email == null || profile.email!.isEmpty) ? 'Used on invoices' : profile.email,
                      onTap: () => _editEmail(context, ref, profile.email),
                    ),
                    _MenuEntry(
                      icon: Icons.notifications_none_rounded,
                      label: l10n.notifications,
                      onTap: () => context.push('/notifications'),
                    ),
                    _MenuEntry(
                      icon: Icons.receipt_long_outlined,
                      label: 'Invoices',
                      onTap: () => context.push('/invoices'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MenuGroup(
                  title: l10n.settings,
                  items: [
                    _MenuEntry(
                      icon: Icons.dark_mode_outlined,
                      label: l10n.appearance,
                      trailing: _themeModeLabel(ref.watch(themeModeProvider)),
                      onTap: () => _showThemePicker(context, ref),
                    ),
                    _MenuEntry(
                      icon: Icons.language_rounded,
                      label: l10n.language,
                      trailing: 'English',
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MenuGroup(
                  title: 'Support',
                  items: [
                    _MenuEntry(
                      icon: Icons.support_agent_rounded,
                      label: l10n.helpSupport,
                      onTap: () => context.push('/help'),
                    ),
                    _MenuEntry(
                      icon: Icons.description_outlined,
                      label: l10n.termsAndConditions,
                      onTap: () => context.push('/legal/terms'),
                    ),
                    _MenuEntry(
                      icon: Icons.privacy_tip_outlined,
                      label: l10n.privacyPolicy,
                      onTap: () => context.push('/legal/privacy'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SignOutButton(
                  label: l10n.signOut,
                  onTap: () async {
                    await signOut(ref);
                    if (context.mounted) context.go('/login');
                  },
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    l10n.ryvoV100,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final hasEmail = profile.email != null && profile.email!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _Avatar(profile: profile),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF5B400), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      profile.ratingLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '  rider',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  profile.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                ),
                if (hasEmail)
                  Text(
                    profile.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final url = profile.avatarUrl?.trim();
    final initials = Text(
      profile.initials,
      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
    );
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: initials),
            )
          : Center(child: initials),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.items});

  final String title;
  final List<_MenuEntry> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _MenuTile(entry: items[i]),
                if (i != items.length - 1) Divider(height: 1, indent: 62, color: AppColors.divider),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.entry});

  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(entry.icon, size: 20, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (entry.subtitle != null)
                    Text(
                      entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            if (entry.trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Text(
                  entry.trailing!,
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
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
  final email = await showDialog<String>(
    context: context,
    builder: (ctx) => _InvoiceEmailDialog(initialEmail: current ?? ''),
  );
  if (email == null) return;
  final trimmed = email.trim();
  if (trimmed.isEmpty || !trimmed.contains('@')) return;
  try {
    await ref.read(profileRepositoryProvider).updateProfile(email: trimmed);
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

class _InvoiceEmailDialog extends StatefulWidget {
  const _InvoiceEmailDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_InvoiceEmailDialog> createState() => _InvoiceEmailDialogState();
}

class _InvoiceEmailDialogState extends State<_InvoiceEmailDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    // The dialog route and keyboard inset animation can still update the
    // TextField in the same frame as dispose. Drop the controller after that.
    final controller = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Email for invoices',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        style: GoogleFonts.poppins(color: AppColors.textPrimary),
        decoration: const InputDecoration(hintText: 'you@email.com'),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () {
            final email = _controller.text;
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.pop(context, email);
          },
          child: const Text('Save'),
        ),
      ],
    );
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
