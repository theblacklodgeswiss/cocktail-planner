import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'buttons.dart';
import 'glass_surface.dart';

/// Space below a floating bar: the keyboard when open, else the safe area.
double bottomBarInset(BuildContext context) {
  final m = MediaQuery.of(context);
  return math.max(m.viewInsets.bottom, m.padding.bottom);
}

/// Floating glass pill with a primary button (and an optional count badge).
/// Place it at the bottom of a Stack; it lifts itself above the keyboard.
class GlassCtaBar extends StatelessWidget {
  const GlassCtaBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.badge,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSize.barSide,
        0,
        AppSize.barSide,
        bottomBarInset(context) + AppSize.barGap,
      ),
      child: GlassSurface(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              if (badge != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                    ),
                    child: Text(
                      badge!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.section.copyWith(color: p.text),
                    ),
                  ),
                ),
              Expanded(
                flex: 2,
                child: PrimaryButton(label: label, onPressed: onPressed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
