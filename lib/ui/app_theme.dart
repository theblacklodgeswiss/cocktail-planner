import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  AppTheme._();

  // Themes depend on nothing dynamic, so build each once.
  static ThemeData light() => _light;
  static ThemeData dark() => _dark;

  static final ThemeData _light = _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.ink,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE5E5EA),
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.textSecondaryLight,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.surfaceLight,
      onSecondaryContainer: AppColors.ink,
      tertiary: Color(0xFF3A3A3C),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE5E5EA),
      onTertiaryContainer: AppColors.ink,
      error: AppColors.errorLight,
      onError: Colors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: AppColors.cardLight,
      onSurface: AppColors.textLight,
      // Darker than textSecondary so it holds 4.5:1 on surfaceContainerHighest.
      onSurfaceVariant: Color(0xFF58585D),
      outline: AppColors.textTertiaryLight,
      outlineVariant: AppColors.disabledLight,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF8F8FA),
      surfaceContainer: AppColors.surfaceLight,
      surfaceContainerHigh: Color(0xFFECECF0),
      surfaceContainerHighest: Color(0xFFE5E5EA),
      inverseSurface: AppColors.ink,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.goldOnBlack,
      shadow: Colors.black,
      scrim: Colors.black,
    ),
    AppColors.bgTopLight,
  );

  static final ThemeData _dark = _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Colors.white,
      onPrimary: Colors.black,
      primaryContainer: AppColors.surfaceDark,
      onPrimaryContainer: AppColors.textDark,
      secondary: Color(0xFFAEAEB2),
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF3A3A3C),
      onSecondaryContainer: AppColors.textDark,
      tertiary: Color(0xFFD1D1D6),
      onTertiary: Colors.black,
      tertiaryContainer: AppColors.surfaceDark,
      onTertiaryContainer: AppColors.textDark,
      error: AppColors.errorDark,
      onError: Colors.black,
      errorContainer: Color(0xFF5C1A16),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: AppColors.cardDark,
      onSurface: AppColors.textDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
      outline: AppColors.textTertiaryDark,
      outlineVariant: AppColors.disabledDark,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: Color(0xFF141416),
      surfaceContainer: AppColors.cardDark,
      surfaceContainerHigh: Color(0xFF242426),
      surfaceContainerHighest: AppColors.surfaceDark,
      inverseSurface: AppColors.textDark,
      onInverseSurface: AppColors.ink,
      inversePrimary: AppColors.goldOnWhite,
      shadow: Colors.black,
      scrim: Colors.black,
    ),
    AppColors.bgTopDark,
  );

  static ThemeData _build(ColorScheme cs, Color background) {
    OutlineInputBorder border(BorderSide side) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      borderSide: side,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: cs.brightness,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final p in TargetPlatform.values)
            p: const CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: border(BorderSide.none),
        enabledBorder: border(BorderSide.none),
        focusedBorder: border(BorderSide(color: cs.primary, width: 2)),
        errorBorder: border(BorderSide(color: cs.error)),
        focusedErrorBorder: border(BorderSide(color: cs.error, width: 2)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16,
          vertical: 14,
        ),
      ),
    );
  }
}
