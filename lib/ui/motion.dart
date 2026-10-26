import 'package:flutter/widgets.dart';

class AppMotion {
  AppMotion._();

  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  static const Duration press = Duration(milliseconds: 120);
  static const Duration page = Duration(milliseconds: 280);
  static const Duration sheet = Duration(milliseconds: 300);

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
