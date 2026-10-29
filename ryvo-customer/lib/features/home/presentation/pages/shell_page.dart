import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/app_config.dart';
import '../../../../shared/providers/app_providers.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class ShellPage extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const ShellPage({super.key, required this.navigationShell});

  int _navIndexForBranch(int branchIndex, bool walletEnabled) {
    if (walletEnabled) return branchIndex;
    return branchIndex > 2 ? branchIndex - 1 : branchIndex;
  }

  int _branchIndexForNav(int navIndex, bool walletEnabled) {
    if (walletEnabled) return navIndex;
    return navIndex >= 2 ? navIndex + 1 : navIndex;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config =
        ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final walletEnabled = config.customerWalletEnabled;
    final currentNavIndex =
        _navIndexForBranch(navigationShell.currentIndex, walletEnabled);

    final l10n = AppLocalizations.of(context);
    final items = <_ShellNavSpec>[
      _ShellNavSpec(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: l10n.home),
      _ShellNavSpec(
          icon: Icons.calendar_today_outlined,
          activeIcon: Icons.calendar_today_rounded,
          label: l10n.bookings),
      if (walletEnabled)
        _ShellNavSpec(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: l10n.wallet,
        ),
      _ShellNavSpec(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: l10n.profile),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  _ShellNavItem(
                    icon: items[i].icon,
                    activeIcon: items[i].activeIcon,
                    label: items[i].label,
                    selected: i == currentNavIndex,
                    onTap: () => navigationShell.goBranch(
                      _branchIndexForNav(i, walletEnabled),
                      initialLocation: _branchIndexForNav(i, walletEnabled) ==
                          navigationShell.currentIndex,
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

class _ShellNavSpec {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _ShellNavSpec({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _ShellNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShellNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.grey500;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: selected ? 22 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
