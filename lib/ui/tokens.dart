import 'package:flutter/material.dart';

/// Design tokens for the "Glas" redesign. Light values come from the spec,
/// dark values are inverted neutrals; gold is a small accent only.
class AppColors {
  AppColors._();

  // Light
  static const Color bgTopLight = Color(0xFFF6F6F8);
  static const Color bgBottomLight = Color(0xFFECECF0);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF2F2F5);
  static const Color textLight = Color(0xFF1D1D1F);
  static const Color textSecondaryLight = Color(0xFF6E6E73);
  static const Color textTertiaryLight = Color(0xFF86868B);
  static const Color disabledLight = Color(0xFFC7C7CC);

  // Dark
  static const Color bgTopDark = Color(0xFF000000);
  static const Color bgBottomDark = Color(0xFF1C1C1E);
  static const Color cardDark = Color(0xFF1C1C1E);
  static const Color surfaceDark = Color(0xFF2C2C2E);
  static const Color textDark = Color(0xFFF5F5F7);
  static const Color textSecondaryDark = Color(0xFF9A9AA0);
  static const Color textTertiaryDark = Color(0xFF8E8E93);
  static const Color disabledDark = Color(0xFF48484A);

  /// Main button and hero card (light); text color on black.
  static const Color ink = Color(0xFF1D1D1F);

  // Gold accents (estimated from the logo)
  static const Color goldOnBlack = Color(0xFFF0C35A);
  static const Color goldLabelOnBlack = Color(0xFFE0B04A);
  static const Color goldOnWhite = Color(0xFFB8861F);
  static const Color goldDotOnWhite = Color(0xFFC9962B);

  // Status dots
  static const Color statusOffer = Color(0xFFC7C7CC);
  static const Color statusDone = Color(0xFFE5E5EA);

  // Errors and destructive actions only
  static const Color errorLight = Color(0xFFB3261E);
  static const Color errorDark = Color(0xFFFF6B63);
}

class AppSpace {
  AppSpace._();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
}

class AppRadius {
  AppRadius._();

  static const double card = 20;
  static const double hero = 24;
  static const double heroXl = 30;
  static const double control = 12;
  static const double pill = 999;
}

/// Type scale (system font). Colors come from the theme, not from here.
class AppText {
  AppText._();

  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
  );
  static const TextStyle section = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
  static const TextStyle body = TextStyle(fontSize: 12, height: 1.4);
  static const TextStyle caption = TextStyle(fontSize: 10.5, height: 1.3);
  static const TextStyle number = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
