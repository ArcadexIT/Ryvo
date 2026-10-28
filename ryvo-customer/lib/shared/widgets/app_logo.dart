import 'package:flutter/material.dart';

enum AppLogoVariant { mark, wordmark, lockup }

class AppLogo extends StatelessWidget {
  final double size;
  final bool withGlow;
  final AppLogoVariant variant;

  const AppLogo({
    super.key,
    this.size = 80,
    this.withGlow = false,
    this.variant = AppLogoVariant.mark,
  });

  String _asset(bool dark) {
    switch (variant) {
      case AppLogoVariant.mark:
        return 'assets/images/logo.png';
      case AppLogoVariant.wordmark:
        return dark
            ? 'assets/images/logo_wordmark_light.png'
            : 'assets/images/logo_wordmark.png';
      case AppLogoVariant.lockup:
        return dark
            ? 'assets/images/logo_lockup_dark.png'
            : 'assets/images/logo_lockup.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final image = switch (variant) {
      AppLogoVariant.mark => Image.asset(
          _asset(dark),
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      AppLogoVariant.wordmark => Image.asset(
          _asset(dark),
          height: size,
          fit: BoxFit.contain,
        ),
      AppLogoVariant.lockup => Image.asset(
          _asset(dark),
          width: size,
          fit: BoxFit.contain,
        ),
    };

    if (!withGlow || variant != AppLogoVariant.mark) return image;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF32BB78).withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: 8,
          ),
        ],
      ),
      child: image,
    );
  }
}
