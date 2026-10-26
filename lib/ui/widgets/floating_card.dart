import 'package:flutter/material.dart';

import '../tokens.dart';
import 'pressable.dart';

/// White card with a soft shadow; tappable when [onTap] is set.
class FloatingCard extends StatelessWidget {
  const FloatingCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.s12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.of(context).card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: AppPalette.of(context).cardBorder,
        boxShadow: AppShadow.card,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, radius: AppRadius.card, child: card);
  }
}
