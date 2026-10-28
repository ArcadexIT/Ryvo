import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'app_logo.dart';

enum RyvoAppBarVariant { defaultBar, logo, notification }

class RyvoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final RyvoAppBarVariant variant;
  final VoidCallback? onBack;
  final VoidCallback? onNotification;
  final int notificationCount;

  const RyvoAppBar({
    super.key,
    this.title,
    this.variant = RyvoAppBarVariant.defaultBar,
    this.onBack,
    this.onNotification,
    this.notificationCount = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: onBack != null
          ? IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
            )
          : null,
      title: switch (variant) {
        RyvoAppBarVariant.logo => const AppLogo(
            size: 22,
            variant: AppLogoVariant.wordmark,
          ),
        _ => title != null
            ? Text(
                title!,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              )
            : null,
      },
      centerTitle: true,
      actions: variant == RyvoAppBarVariant.notification
          ? [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: onNotification,
                    icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        child: Text(
                          '$notificationCount',
                          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ]
          : null,
    );
  }
}
