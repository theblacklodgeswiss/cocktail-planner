import 'dart:ui';

import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

// Saturate 180% as a color matrix (luminance weights from the CSS spec).
const _saturate = ColorFilter.matrix(<double>[
  1.7160, -0.6000, -0.1160, 0, 0, //
  -0.2840, 1.4000, -0.1160, 0, 0, //
  -0.2840, -0.6000, 1.8840, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Frosted glass (blur 22, saturate 180%). With reduced transparency the
/// blur is dropped and the fill becomes nearly opaque.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadius.pill,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final solid = AppMotion.reducedTransparency(context);
    final shape = BorderRadius.circular(radius);

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? p.glassSolid : p.glass,
        borderRadius: shape,
        border: Border.all(color: p.glassBorder),
      ),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowGlass,
            blurRadius: 22,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: solid
            ? body
            : BackdropFilter(
                filter: ImageFilter.compose(
                  outer: _saturate,
                  inner: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                ),
                child: body,
              ),
      ),
    );
  }
}
