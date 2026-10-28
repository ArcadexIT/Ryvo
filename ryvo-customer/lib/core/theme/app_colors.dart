import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.light;

  static Brightness get brightness => _brightness;

  static bool get isDark => _brightness == Brightness.dark;

  static void updateBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static const Color primary = Color(0xFF32BB78);
  static const Color primaryDark = Color(0xFF24965F);
  static const Color primaryLight = Color(0xFFD8F3E5);
  static const Color navy = Color(0xFF2F313F);

  static const Color backgroundDark = Color(0xFF2F313F);
  static const Color surfaceDark = Color(0xFF383B4A);
  static const Color modalDark = Color(0xFF2F313F);
  static const Color cardDark = Color(0xFF383B4A);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textHintDark = Color(0xFF6B7280);
  static const Color dividerDark = Color(0xFF2D2D2D);
  static const Color shimmerBaseDark = Color(0xFF1E1E1E);
  static const Color shimmerHighlightDark = Color(0xFF2A2A2A);

  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color surfaceLight = Color(0xFFF3F4F6);
  static const Color modalLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF2F313F);
  static const Color textSecondaryLight = Color(0xFF94A3B8);
  static const Color textHintLight = Color(0xFF9CA3AF);
  static const Color dividerLight = Color(0xFFE5E7EB);
  static const Color shimmerBaseLight = Color(0xFFE5E7EB);
  static const Color shimmerHighlightLight = Color(0xFFF3F4F6);

  static Color get background => isDark ? backgroundDark : backgroundLight;
  static Color get surface => isDark ? surfaceDark : surfaceLight;
  static Color get modal => isDark ? modalDark : modalLight;
  static Color get card => isDark ? cardDark : cardLight;
  static Color get textPrimary => isDark ? textPrimaryDark : textPrimaryLight;
  static Color get textSecondary => isDark ? textSecondaryDark : textSecondaryLight;
  static Color get textHint => isDark ? textHintDark : textHintLight;
  static Color get divider => isDark ? dividerDark : dividerLight;
  static Color get shimmerBase => isDark ? shimmerBaseDark : shimmerBaseLight;
  static Color get shimmerHighlight => isDark ? shimmerHighlightDark : shimmerHighlightLight;

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
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}
