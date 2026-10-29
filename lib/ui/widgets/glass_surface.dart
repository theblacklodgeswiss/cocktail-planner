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
/// [liquid] is the Liquid Glass material of the floating tab bar and "+":
/// stronger blur ([AppSize.liquidBlur]), thinner fill, a bright rim, an inner
/// top highlight and a deeper shadow, so it reads as a lens over the content.
///
/// On Flutter Web a composed color-matrix backdrop filter can degrade or
/// fall back, so the web path is blur-only with a denser fill.
/// The drop shadow is clipped to the outside of the shape so it does not
/// grey the translucent glass.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadius.pill,
    this.liquid = false,
  });

  final Widget child;
  final double radius;
  final bool liquid;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final solid = AppMotion.reducedTransparency(context);
    final shape = BorderRadius.circular(radius);
    final fill = solid
        ? p.glassSolid
        : liquid
        ? (kIsWeb ? p.liquidWeb : p.liquid)
        : (kIsWeb ? p.glassWeb : p.glass);
    final sigma = liquid ? AppSize.liquidBlur : AppSize.glassBlur;

    final blur = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);

    // Glass chrome (tab bar, "+", CTA bar) often floats above the pages'
    // Scaffolds, e.g. in the staff shell. Without a Material ancestor its
    // text would get MaterialApp's debug style (yellow underline); a
    // transparent Material gives it the theme's text style and ink.
    final content = Material(type: MaterialType.transparency, child: child);

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shape,
        border: Border.all(
          color: liquid ? p.liquidBorder : p.glassBorder,
          width: AppSize.hairline,
        ),
      ),
      // Inner highlight: light falling on the upper rim of the lens.
      child: liquid && !solid
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [p.liquidHighlight, AppColors.glowClear],
                ),
              ),
              child: content,
            )
          : content,
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
                  boxShadow: liquid ? AppShadow.liquid : AppShadow.glass,
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
