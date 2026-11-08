import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Plus Jakarta Sans styles. [price], [eta], and [distance] use tabular figures
/// so live fare, timer, and distance updates do not jitter.
class RyvoTypography {
  RyvoTypography._();

  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle style({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
    bool tabular = false,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: tabular ? tabularFigures : null,
    );
  }

  static TextStyle heading({
    double fontSize = 18,
    Color? color,
    double letterSpacing = -0.4,
  }) {
    return style(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle button({
    Color? color,
    double fontSize = 16,
  }) {
    return style(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: -0.2,
    );
  }

  static TextStyle price({
    Color? color,
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return style(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.6,
      tabular: true,
    );
  }

  static TextStyle eta({
    Color? color,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return style(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.4,
      tabular: true,
    );
  }

  static TextStyle distance({
    Color? color,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return style(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.2,
      tabular: true,
    );
  }
}

class AppTheme {
  AppTheme._();

  // Built once: both themes only read theme-independent color constants, and
  // identical instances stop MaterialApp re-theming on unrelated rebuilds.
  static final ThemeData light = _build(
    brightness: Brightness.light,
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    modal: AppColors.modalLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    textHint: AppColors.textHintLight,
    divider: AppColors.dividerLight,
    overlayStyle: SystemUiOverlayStyle.dark,
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    modal: AppColors.modalDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textHint: AppColors.textHintDark,
    divider: AppColors.dividerDark,
    overlayStyle: SystemUiOverlayStyle.light,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color modal,
    required Color textPrimary,
    required Color textSecondary,
    required Color textHint,
    required Color divider,
    required SystemUiOverlayStyle overlayStyle,
  }) {
    final isDark = brightness == Brightness.dark;
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final cta = isDark ? AppColors.white : AppColors.obsidian;
    final onCta = isDark ? AppColors.obsidian : AppColors.white;
    final textTheme = _textTheme(textPrimary, textSecondary, textHint);
    final radius16 = BorderRadius.circular(16);
    final radius12 = BorderRadius.circular(12);

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryColor: AppColors.primary,
      splashColor: textPrimary.withValues(alpha: 0.06),
      highlightColor: textPrimary.withValues(alpha: 0.04),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      colorScheme: isDark
          ? const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              secondary: AppColors.primaryLight,
              onSecondary: AppColors.navy,
              surface: AppColors.surfaceDark,
              onSurface: AppColors.textPrimaryDark,
              error: AppColors.error,
              onError: AppColors.white,
            )
          : const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              secondary: AppColors.primaryLight,
              onSecondary: AppColors.navy,
              surface: AppColors.surfaceLight,
              onSurface: AppColors.textPrimaryLight,
              error: AppColors.error,
              onError: AppColors.white,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlayStyle,
        titleTextStyle:
            RyvoTypography.heading(fontSize: 18, color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius16),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: modal,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: divider),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: modal,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: modal,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 0,
        modalElevation: 0,
        modalBackgroundColor: modal,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: RyvoTypography.style(fontSize: 14, color: textHint),
        labelStyle: RyvoTypography.style(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        errorStyle: RyvoTypography.style(fontSize: 12, color: AppColors.error),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cta,
          foregroundColor: onCta,
          disabledBackgroundColor: cta.withValues(alpha: 0.38),
          disabledForegroundColor: onCta.withValues(alpha: 0.6),
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radius16),
          textStyle: RyvoTypography.button(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cta,
          foregroundColor: onCta,
          disabledBackgroundColor: cta.withValues(alpha: 0.38),
          disabledForegroundColor: onCta.withValues(alpha: 0.6),
          minimumSize: const Size(64, 56),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radius16),
          textStyle: RyvoTypography.button(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(64, 56),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: radius16),
          textStyle: RyvoTypography.button(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: RyvoTypography.button(fontSize: 14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle: RyvoTypography.style(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        side: BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: textSecondary,
        textColor: textPrimary,
      ),
    );
  }

  static TextTheme _textTheme(
      Color textPrimary, Color textSecondary, Color textHint) {
    return TextTheme(
      displayLarge: RyvoTypography.style(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: textPrimary,
        tabular: true,
      ),
      displayMedium: RyvoTypography.style(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: textPrimary,
        tabular: true,
      ),
      displaySmall: RyvoTypography.style(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textPrimary,
        tabular: true,
      ),
      headlineLarge: RyvoTypography.heading(
        fontSize: 22,
        letterSpacing: -0.4,
        color: textPrimary,
      ),
      headlineMedium: RyvoTypography.heading(
        fontSize: 20,
        letterSpacing: -0.4,
        color: textPrimary,
      ),
      headlineSmall: RyvoTypography.heading(
        fontSize: 18,
        letterSpacing: -0.4,
        color: textPrimary,
      ),
      titleLarge: RyvoTypography.heading(
        fontSize: 16,
        letterSpacing: -0.4,
        color: textPrimary,
      ),
      titleMedium: RyvoTypography.style(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textPrimary,
      ),
      titleSmall: RyvoTypography.style(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: RyvoTypography.style(fontSize: 16, color: textPrimary),
      bodyMedium: RyvoTypography.style(fontSize: 14, color: textPrimary),
      bodySmall: RyvoTypography.style(fontSize: 12, color: textSecondary),
      labelLarge: RyvoTypography.style(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      labelMedium: RyvoTypography.style(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelSmall: RyvoTypography.style(fontSize: 11, color: textHint),
    );
  }
}
