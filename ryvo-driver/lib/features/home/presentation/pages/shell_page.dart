import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class ShellPage extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const ShellPage({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const barColor = Color(0xFF0E1520);
    final l10n = AppLocalizations.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: barColor,
            border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
          ),
          child: SafeArea(
            child: BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
              backgroundColor: barColor,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.grey400,
              selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.near_me_outlined),
                  activeIcon: const Icon(Icons.near_me),
                  label: l10n.home,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.bar_chart_outlined),
                  activeIcon: const Icon(Icons.bar_chart_rounded),
                  label: l10n.earnings,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.history),
                  activeIcon: const Icon(Icons.history),
                  label: l10n.history,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: l10n.profile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
