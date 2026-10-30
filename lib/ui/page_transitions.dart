// Newer Flutter releases export CupertinoPageTransitionsBuilder from the
// cupertino library only; older ones from material. Both imports keep the
// file compiling on either (CI follows the stable channel).
// ignore: unnecessary_import, unused_import
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

/// Cupertino slide, or a plain cross-fade when the OS asks for less motion.
///
/// The fade still goes through the Cupertino builder (with frozen
/// animations) so the iOS edge swipe-back keeps working; only the visible
/// motion is replaced.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => AppMotion.page;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          AppMotion.reduced(context)
          ? child
          : _cupertino.delegatedTransition?.call(
              context,
              animation,
              secondaryAnimation,
              allowSnapshotting,
              child,
            );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!AppMotion.reduced(context)) {
      return _cupertino.buildTransitions<T>(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return FadeTransition(
      opacity: animation,
      child: _cupertino.buildTransitions<T>(
        route,
        context,
        kAlwaysCompleteAnimation,
        kAlwaysDismissedAnimation,
        child,
      ),
    );
  }
}
