import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glass_surface.dart';
import 'pressable.dart';

/// Round Liquid Glass "+" button (same material as the staff tab bar) with a
/// primary-colored glyph: black on light, white on dark. Only draws the
/// button; the caller positions it.
class FloatingFab extends StatelessWidget {
  const FloatingFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.semanticLabel,
  });

  final VoidCallback onPressed;
  final IconData icon;

  /// Defaults to the generic "add" label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: onPressed,
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      semanticLabel: semanticLabel ?? 'ui.add'.tr(),
      child: SizedBox.square(
        dimension: AppSize.liquidFab,
        child: GlassSurface(
          liquid: true,
          child: Center(
            child: Icon(icon, size: AppSize.fabIcon, color: p.primary),
          ),
        ),
      ),
    );
  }
}
