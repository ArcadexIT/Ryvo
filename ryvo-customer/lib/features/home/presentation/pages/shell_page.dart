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
    final config = ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final walletEnabled = config.customerWalletEnabled;
    final currentNavIndex = _navIndexForBranch(navigationShell.currentIndex, walletEnabled);

    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: AppLocalizations.of(context).home),
      BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: AppLocalizations.of(context).bookings),
      if (walletEnabled)
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: AppLocalizations.of(context).wallet),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: AppLocalizations.of(context).profile),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: currentNavIndex,
            onTap: (i) => navigationShell.goBranch(
              _branchIndexForNav(i, walletEnabled),
              initialLocation: _branchIndexForNav(i, walletEnabled) == navigationShell.currentIndex,
            ),
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.grey500,
            selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: items,
          ),
        ),
      ),
    );
  }
}
