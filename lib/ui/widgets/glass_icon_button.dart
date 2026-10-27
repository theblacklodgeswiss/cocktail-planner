import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glass_surface.dart';
import 'pressable.dart';

/// Round glass button for top bar actions. [semanticLabel] is required since
/// the button has no visible text.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: onPressed,
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      semanticLabel: semanticLabel,
      child: GlassSurface(
        child: SizedBox.square(
          dimension: AppSize.glassButton,
          child: Icon(icon, size: AppSize.glassButtonIcon, color: p.text),
        ),
      ),
    );
  }
}
