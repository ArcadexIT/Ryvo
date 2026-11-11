import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../home/presentation/pages/shell_page.dart';
import '../widgets/ryvo_grab_list_tile.dart';
import '../widgets/ryvo_sign_out_dialog.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  static const double _expandedHeight = 220;

  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _titleOpacity = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _titleOpacity.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final top = MediaQuery.paddingOf(context).top;
    final distance = _expandedHeight - kToolbarHeight - top;
    final next = _scroll.offset >= distance - 16 ? 1.0 : 0.0;
    if (_titleOpacity.value != next) _titleOpacity.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final config =
        ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final walletAsync = config.customerWalletEnabled
        ? ref.watch(walletBalanceProvider)
        : const AsyncValue.data(null);
    final jobsAsync = ref.watch(jobsListProvider);
    final unread = ref.watch(notificationsProvider).valueOrNull?.fold<int>(
              0,
              (count, item) => count + (item.isRead ? 0 : 1),
            ) ??
        0;
    final l10n = AppLocalizations.of(context);
    final bottomPad = 24 + RyvoFloatingNav.reservedHeight(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const _ProfileLoading(),
        error: (error, _) => _ProfileMessage(
          message: error.toString(),
          action: l10n.retry,
          onAction: () => ref.invalidate(profileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return _ProfileMessage(message: l10n.notSignedIn);
          }
          final jobs = jobsAsync.valueOrNull ?? const <JobModel>[];
          final balance = walletAsync.valueOrNull?.balance;
          final name = profile.fullName.trim().isEmpty
              ? 'Rider'
              : profile.fullName.trim();
          final themeLabel = switch (ref.watch(themeModeProvider)) {
            ThemeMode.dark => l10n.dark,
            ThemeMode.system => l10n.system,
            ThemeMode.light => l10n.light,
          };
          final method = _methodLabel(
            ref.watch(jobDraftProvider).paymentMethod,
            l10n,
          );

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(profileProvider);
              ref.invalidate(jobsListProvider);
              ref.invalidate(notificationsProvider);
              if (config.customerWalletEnabled) {
                ref.invalidate(walletBalanceProvider);
              }
              await ref.read(profileProvider.future);
            },
            child: CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  stretch: true,
                  expandedHeight: _expandedHeight,
                  automaticallyImplyLeading: false,
                  backgroundColor: AppColors.background,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  systemOverlayStyle: AppColors.isDark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark,
                  title: ValueListenableBuilder<double>(
                    valueListenable: _titleOpacity,
                    builder: (context, opacity, child) {
                      return AnimatedOpacity(
                        opacity: opacity,
                        duration: const Duration(milliseconds: 180),
                        child: child,
                      );
                    },
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RyvoTypography.style(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: _ProfileHeader(
                      profile: profile,
                      name: name,
                      onEdit: () => context.push('/profile/edit'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Account & Activity'),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.creditcard,
                        label: l10n.wallet,
                        trailing: balance != null ? formatMoney(balance) : '--',
                        onTap: () => context.push('/profile/wallet'),
                      ),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.clock,
                        label: 'Ride history',
                        trailing: _countLabel(jobs.length, 'ride', 'rides'),
                        onTap: () => context.go('/bookings'),
                      ),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.location,
                        label: 'Saved places',
                        trailing: _countLabel(
                          _savedPlaceCount(jobs),
                          'place',
                          'places',
                        ),
                        onTap: () => context.push('/profile/places'),
                      ),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.money_dollar,
                        label: 'Payment methods',
                        trailing: method,
                        onTap: () => context.push('/profile/payment'),
                      ),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.doc_text,
                        label: 'Invoices',
                        onTap: () => context.push('/invoices'),
                      ),
                      const _SectionTitle('Preferences'),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.moon,
                        label: 'App theme',
                        trailing: themeLabel,
                        onTap: () => context.push('/profile/appearance'),
                      ),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.bell,
                        label: l10n.notifications,
                        badge: unread > 0 ? 'New' : null,
                        onTap: () => context.push('/notifications'),
                      ),
                      const _SectionTitle('Support & Legal'),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.shield,
                        label: 'Emergency contacts',
                        onTap: () => context.push('/profile/safety'),
                      ),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.question_circle,
                        label: l10n.helpSupport,
                        onTap: () => context.push('/help'),
                      ),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.doc_text,
                        label: l10n.termsAndConditions,
                        onTap: () => context.push('/legal/terms'),
                      ),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.lock,
                        label: l10n.privacyPolicy,
                        onTap: () => context.push('/legal/privacy'),
                      ),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.trash,
                        label: 'Delete account',
                        labelColor: AppColors.error,
                        onTap: () => context.push('/profile/delete-account'),
                      ),
                      RyvoGrabListTile(
                        icon: CupertinoIcons.square_arrow_right,
                        label: l10n.signOut,
                        showChevron: false,
                        haptic: false,
                        labelColor: AppColors.error,
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          final confirmed =
                              await showRyvoSignOutDialog(context);
                          if (!confirmed || !context.mounted) return;
                          await signOut(ref);
                          if (context.mounted) context.go('/login');
                        },
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
                        child: Text(
                          l10n.ryvoV100,
                          style: RyvoTypography.style(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ],
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.name,
    required this.onEdit,
  });

  final UserProfile profile;
  final String name;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final email = profile.email?.trim() ?? '';
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.isDark
              ? const [AppColors.modalDark, AppColors.backgroundDark]
              : const [AppColors.headerMint, AppColors.backgroundLight],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top,
          20,
          8,
        ),
        child: Align(
          alignment: const Alignment(0, -0.2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(profile: profile),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RyvoTypography.style(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RyvoTypography.style(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        tabular: true,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RyvoTypography.style(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _EditPill(onTap: onEdit),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditPill extends StatelessWidget {
  const _EditPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Edit Profile',
            style: RyvoTypography.style(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
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
      style: RyvoTypography.style(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
      ),
    );
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.card,
        border: Border.all(color: AppColors.divider),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
      child: Text(
        title,
        style: RyvoTypography.style(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 220,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.background,
          flexibleSpace: FlexibleSpaceBar(
            background: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppColors.isDark
                      ? const [AppColors.modalDark, AppColors.backgroundDark]
                      : const [AppColors.headerMint, AppColors.backgroundLight],
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              children: [
                ShimmerCard(height: 56, borderRadius: 12),
                SizedBox(height: 12),
                ShimmerCard(height: 56, borderRadius: 12),
                SizedBox(height: 12),
                ShimmerCard(height: 56, borderRadius: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({
    required this.message,
    this.action,
    this.onAction,
  });

  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: RyvoTypography.style(color: AppColors.textPrimary),
              ),
              if (action != null && onAction != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: onAction, child: Text(action!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

int _savedPlaceCount(List<JobModel> jobs) {
  final seen = <String>{};
  for (final job in jobs) {
    final address = job.dropoffAddress?.trim() ?? '';
    if (address.isEmpty) continue;
    if (job.status == 'cancelled' || job.status.startsWith('cancelled')) {
      continue;
    }
    seen.add(address.toLowerCase());
  }
  return seen.length;
}

String _countLabel(int count, String singular, String plural) {
  return '$count ${count == 1 ? singular : plural}';
}

String _methodLabel(String method, AppLocalizations l10n) {
  return switch (method) {
    'wallet' => l10n.wallet,
    'cash' => l10n.cash,
    'google_pay' => l10n.googlePay,
    'apple_pay' => l10n.applePay,
    _ => l10n.card,
  };
}
