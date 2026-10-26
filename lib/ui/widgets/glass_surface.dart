import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
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
///
/// On Flutter Web a composed color-matrix backdrop filter can degrade or
/// fall back, so the web path is blur-only with a slightly denser fill.
/// The drop shadow is clipped to the outside of the shape so it does not
/// grey the translucent glass.
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
    final fill = solid ? p.glassSolid : (kIsWeb ? p.glassWeb : p.glass);

    final blur = ImageFilter.blur(
      sigmaX: AppSize.glassBlur,
      sigmaY: AppSize.glassBlur,
    );

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shape,
        border: Border.all(color: p.glassBorder, width: AppSize.hairline),
      ),
      child: child,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ClipPath(
              clipper: _OutsideClipper(radius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shape,
                  boxShadow: AppShadow.glass,
                ),
              ),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: shape,
          child: solid
              ? body
              : BackdropFilter(
                  filter: kIsWeb
                      ? blur
                      : ImageFilter.compose(outer: _saturate, inner: blur),
                  child: body,
                ),
        ),
      ],
    );
  }
}

/// Everything except the rounded rect, so the shadow only paints outside.
class _OutsideClipper extends CustomClipper<Path> {
  const _OutsideClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) {
    const bleed = AppSize.glassShadowBleed;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(
        Rect.fromLTWH(
          -bleed,
          -bleed,
          size.width + 2 * bleed,
          size.height + 2 * bleed,
        ),
      ),
      Path()..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      ),
    );
  }

  @override
  bool shouldReclip(_OutsideClipper old) => old.radius != radius;
}
