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

  // Glass (white 62% light; dark counterpart) and its hairline border
  static const Color glassLight = Color(0x9EFFFFFF);
  static const Color glassDark = Color(0x9E2C2C2E);
  static const Color glassBorderLight = Color(0xD9FFFFFF);
  static const Color glassBorderDark = Color(0x33FFFFFF);
  // Near-opaque fallback when transparency is reduced
  static const Color glassSolidLight = Color(0xF5FFFFFF);
  static const Color glassSolidDark = Color(0xF52C2C2E);

  /// Soft card shadow (0 2 10 @ 5%) and glass shadow base.
  static const Color shadow = Color(0x0D000000);
  static const Color shadowStrong = Color(0x38000000);
  static const Color scrim = Color(0x66000000);
  static const Color shadowGlass = Color(0x1A000000);
  static const Color glow = Color(0x24FFFFFF);
  static const Color glowClear = Color(0x00FFFFFF);
  // Web renders the glass without saturate, so the fill is a bit denser.
  static const Color glassWebLight = Color(0xB8FFFFFF);
  static const Color glassWebDark = Color(0xB82C2C2E);
  static const Color heroMeta = Color(0xFFA1A1A6);
  static const Color border = Color(0x14000000);
  static const Color borderDark = Color(0x1FFFFFFF);

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

/// Fixed sizes shared by the base widgets.
class AppSize {
  AppSize._();

  static const double minTap = 44;
  static const double dateTile = 34;
  static const double statusDot = 6;
  static const double heroGlow = 130;
  static const double pressScale = 0.97;
  static const double pressedOpacity = 0.7;
  static const double hairline = 1;
  static const double focusRing = 2;
  static const double spinnerStroke = 2;
  static const double tileGap = 2;
  static const double glowRight = -30;
  static const double glowTop = -40;
  static const double glowFade = 0.7;
  static const double glassBlur = 22;
  static const double glassShadowBleed = 80;
  static const double minTileTextScale = 1.0;
  static const double maxTileTextScale = 1.15;
  static const double tabBarHeight = 46;
  static const double barSide = 14;
  static const double barGap = 12;
  static const double fab = 40;
  static const double fabIcon = 22;
  static const double fabRight = 20;
  static const double topBar = 44;
  static const double titleCollapse = 40;
  static const double progressHeight = 3;
  static const double sheetHandleWidth = 36;
  static const double sheetHandleHeight = 5;
  static const double sheetMaxFraction = 0.9;
  static const double sheetFullFraction = 0.94;

  /// Scroll padding that keeps the last item clear of a floating bar.
  static const double barClearance = 96;
  static const double maxContentWidth = 720;
  static const double maxBarWidth = 520;
  static const double sheetDismissFraction = 1 / 3;
  static const double sheetFlingVelocity = 700;
  static const double stateIconBox = 56;
  static const double stateIcon = 28;
  static const double badge = 72;
  static const double badgeIcon = 36;
  static const double glassButton = 40;
  static const double glassButtonIcon = 20;
  static const double stepDigit = 28;
  static const double avatar = 44;

  // Order wizard
  static const double rowIcon = 20;
  static const double checkMark = 22;
  static const double checkGlyph = 14;
  static const double optionIconBox = 40;
  static const double quantityField = 48;
  static const double pickerHeight = 216;
  static const double serviceTileExtent = 220;
  static const double serviceTileAspect = 0.85;
  static const double placeholderIcon = 32;

  // Order lists
  static const double metaIcon = 14;
}

/// Elevation shadows shared by cards and glass.
class AppShadow {
  AppShadow._();

  static const List<BoxShadow> card = [
    BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> hero = [
    BoxShadow(
      color: AppColors.shadowStrong,
      blurRadius: 26,
      offset: Offset(0, 10),
    ),
  ];
  static const List<BoxShadow> fab = [
    BoxShadow(
      color: AppColors.shadowStrong,
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];
  static const List<BoxShadow> glass = [
    BoxShadow(
      color: AppColors.shadowGlass,
      blurRadius: 22,
      offset: Offset(0, 6),
    ),
  ];
}

class AppRadius {
  AppRadius._();

  static const double card = 20;
  static const double hero = 24;
  static const double heroXl = 30;
  static const double control = 12;
  static const double tile = 12;
  static const double sheet = 28;
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
  static const TextStyle largeTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
  );
  static const TextStyle tab = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
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

  static const TextStyle kicker = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.9,
  );
  static const TextStyle heroTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  static const TextStyle display = TextStyle(
    fontSize: 29,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.1,
  );
  static const TextStyle heroMeta = TextStyle(fontSize: 10);
  static const TextStyle heroNumber = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle pill = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle tileDay = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1,
  );
  static const TextStyle tileLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 0.4,
  );
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle status = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
  );
}

/// Brightness-dependent colors for the base widgets.
class AppPalette {
  const AppPalette._(this.dark);

  final bool dark;

  factory AppPalette.of(BuildContext context) =>
      AppPalette._(Theme.of(context).brightness == Brightness.dark);

  Color get card => dark ? AppColors.cardDark : AppColors.cardLight;
  Color get surface => dark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get text => dark ? AppColors.textDark : AppColors.textLight;
  Color get textSecondary =>
      dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get disabled => dark ? AppColors.disabledDark : AppColors.disabledLight;
  Color get border => dark ? AppColors.borderDark : AppColors.border;

  /// Dark cards equal the dark background, so they get a hairline edge.
  Border? get cardBorder => dark
      ? Border.all(color: AppColors.borderDark, width: AppSize.hairline)
      : null;

  Color get glass => dark ? AppColors.glassDark : AppColors.glassLight;
  Color get glassWeb => dark ? AppColors.glassWebDark : AppColors.glassWebLight;
  Color get glassSolid =>
      dark ? AppColors.glassSolidDark : AppColors.glassSolidLight;
  Color get glassBorder =>
      dark ? AppColors.glassBorderDark : AppColors.glassBorderLight;
  Color get error => dark ? AppColors.errorDark : AppColors.errorLight;
  Color get onError => dark ? AppColors.ink : AppColors.textDark;

  /// Hero card and primary button fill; inverted text in dark.
  Color get hero => dark ? AppColors.surfaceDark : AppColors.ink;
  Color get onHero => AppColors.textDark;

  /// Primary button: black on light, white on dark.
  Color get primary => dark ? AppColors.textDark : AppColors.ink;
  Color get onPrimary => dark ? AppColors.ink : AppColors.textDark;

  Color get gold => dark ? AppColors.goldOnBlack : AppColors.goldDotOnWhite;
  /// Gold for text and digits on card surfaces.
  Color get goldText => dark ? AppColors.goldOnBlack : AppColors.goldOnWhite;

  Color get statusDone =>
      dark ? AppColors.textTertiaryDark : AppColors.statusDone;
  Color get statusOffer =>
      dark ? AppColors.disabledDark : AppColors.statusOffer;
}
