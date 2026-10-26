import 'package:flutter/widgets.dart';

class AppMotion {
  AppMotion._();

  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  static const Duration press = Duration(milliseconds: 120);
  static const Duration page = Duration(milliseconds: 280);
  static const Duration sheet = Duration(milliseconds: 340);

  /// True when the user asked the OS to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
