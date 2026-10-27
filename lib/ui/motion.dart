import 'package:flutter/widgets.dart';

class AppMotion {
  AppMotion._();

  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Exit mirror of [easeOut]: fast first, then settling, so leaving feels as
  /// lively as arriving (a plain reversed ease-out would start slow).
  static final Curve easeOutExit = easeOut.flipped;

  static const Duration press = Duration(milliseconds: 120);
  static const Duration page = Duration(milliseconds: 280);
  static const Duration sheet = Duration(milliseconds: 300);

  /// Active-tab lens sliding between tabs.
  static const Duration lens = Duration(milliseconds: 220);

  /// Tab bar and "+" sliding away while the keyboard is open.
  static const Duration barHide = Duration(milliseconds: 200);

  /// Hidden position of a floating bottom bar: one own height down.
  static const Offset barHidden = Offset(0, 1);

  /// Sheet start position: one sheet height below its final place.
  static const Offset sheetFrom = Offset(0, 1);

  /// True when the user asked the OS to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// True when the user asked for higher contrast / less transparency.
  /// Flutter exposes no separate reduce-transparency flag, so this uses
  /// MediaQuery.highContrast (iOS Increase Contrast, Android high-contrast
  /// text, web forced-colors where reported).
  static bool reducedTransparency(BuildContext context) =>
      MediaQuery.maybeOf(context)?.highContrast ?? false;
}
