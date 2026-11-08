import 'package:flutter/material.dart';

/// Ryvo mobility palette. Names of the existing static getters stay stable so
/// call sites and [updateBrightness] keep working as the theme changes.
class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.light;

  static Brightness get brightness => _brightness;

  static bool get isDark => _brightness == Brightness.dark;

  /// Must be called before any frame that should render with [brightness].
  /// `ThemeSync` does this synchronously on every theme change.
  static void updateBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  /// Brand emerald for badges, route status, and interactive accents.
  static const Color primary = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF05944F);
  static const Color primaryLight = Color(0xFFD1FAE5);

  /// Obsidian. The `navy` name is kept for existing call sites.
  static const Color navy = Color(0xFF090A0D);
  static const Color obsidian = Color(0xFF090A0D);

  /// High-emphasis accent paired with obsidian text.
  static const Color lime = Color(0xFFB5F558);

  /// Primary CTA fill: obsidian in light mode, crisp white in dark mode.
  static Color get cta => isDark ? white : obsidian;

  static Color get onCta => isDark ? obsidian : white;

  /// Focused field border: obsidian on light surfaces, emerald on carbon.
  static Color get focusBorder => isDark ? primary : obsidian;

  /// True Carbon ramp. Background, elevated sheet, card / input pill.
  static const Color backgroundDark = Color(0xFF090A0D);
  static const Color surfaceDark = Color(0xFF1A1E26);
  static const Color modalDark = Color(0xFF12151B);
  static const Color cardDark = Color(0xFF1A1E26);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textHintDark = Color(0xFF64748B);
  static const Color dividerDark = Color(0xFF262B36);
  static const Color shimmerBaseDark = Color(0xFF1A1E26);
  static const Color shimmerHighlightDark = Color(0xFF262B36);

  /// Soft mint used only as the profile header wash. It fades into [backgroundLight].
  static const Color headerMint = Color(0xFFD8F3E5);

  /// Light alabaster surfaces with obsidian text.
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFF1F5F9);
  static const Color modalLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF090A0D);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textHintLight = Color(0xFF94A3B8);
  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color shimmerBaseLight = Color(0xFFE2E8F0);
  static const Color shimmerHighlightLight = Color(0xFFF8FAFC);

  static Color get background => isDark ? backgroundDark : backgroundLight;
  static Color get surface => isDark ? surfaceDark : surfaceLight;
  static Color get modal => isDark ? modalDark : modalLight;
  static Color get card => isDark ? cardDark : cardLight;
  static Color get textPrimary => isDark ? textPrimaryDark : textPrimaryLight;
  static Color get textSecondary =>
      isDark ? textSecondaryDark : textSecondaryLight;
  static Color get textHint => isDark ? textHintDark : textHintLight;
  static Color get divider => isDark ? dividerDark : dividerLight;
  static Color get shimmerBase => isDark ? shimmerBaseDark : shimmerBaseLight;
  static Color get shimmerHighlight =>
      isDark ? shimmerHighlightDark : shimmerHighlightLight;

  /// Glow emerald for focus rings, shockwaves, and HUD selection borders.
  static const Color glowEmerald = Color(0xFF32BB78);

  /// Celestial tokens for the theme showcase stage (sun, moon, stars).
  static const Color sunCore = Color(0xFFFBBF24);
  static const Color sunRay = Color(0xFFF59E0B);
  static const Color moonLight = Color(0xFFE2E8F0);
  static const Color moonShade = Color(0xFF262B36);
  static const Color star = Color(0xFFF8FAFC);

  static const Color white = Color(0xFFFFFFFF);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);

  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);

  /// Cancellation crimson. Light sheets use the pale wash; dark sheets use a
  /// carbon-tinted wash so the control stays quiet next to the primary CTA.
  static const Color danger = Color(0xFFE11900);
  static const Color dangerOnDark = Color(0xFFFF8A78);
  static const Color dangerSurfaceDark = Color(0xFF3A1714);

  static Color get dangerSurface => isDark ? dangerSurfaceDark : errorLight;
  static Color get dangerText => isDark ? dangerOnDark : danger;

  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}
