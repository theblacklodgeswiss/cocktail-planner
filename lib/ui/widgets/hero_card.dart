import 'package:flutter/material.dart';

import '../tokens.dart';
import 'pressable.dart';

/// Dark highlight card (next appointment): gold kicker, title, grey meta and
/// an optional gold number via [trailing].
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    this.kicker,
    required this.title,
    this.meta,
    this.trailing,
    this.onTap,
  });

  final String? kicker;
  final String title;
  final String? meta;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: p.cardBorder,
        boxShadow: AppShadow.hero,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        child: Stack(
          children: [
            // Faint glow in the top right corner.
            Positioned(
              right: AppSize.glowRight,
              top: AppSize.glowTop,
              child: IgnorePointer(
                child: Container(
                  width: AppSize.heroGlow,
                  height: AppSize.heroGlow,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [AppColors.glow, AppColors.glowClear],
                      stops: [0, AppSize.glowFade],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s16,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (kicker != null)
                          Text(
                            kicker!,
                            style: AppText.kicker.copyWith(
                              color: AppColors.goldLabelOnBlack,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s4),
                          child: Text(
                            title,
                            style: AppText.heroTitle.copyWith(color: p.onHero),
                          ),
                        ),
                        if (meta != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.s4),
                            child: Text(
                              meta!,
                              style: AppText.heroMeta.copyWith(
                                color: AppColors.heroMeta,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpace.s12),
                    DefaultTextStyle.merge(
                      style: AppText.heroNumber.copyWith(
                        color: AppColors.goldOnBlack,
                      ),
                      textAlign: TextAlign.right,
                      child: trailing!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, radius: AppRadius.hero, child: card);
  }
}
