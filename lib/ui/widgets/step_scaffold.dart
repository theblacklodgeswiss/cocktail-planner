import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'glass_cta_bar.dart' show bottomBarInset;
import 'pressable.dart';

/// One step of a wizard: back button, "n von m", thin progress bar, title,
/// scrolling content and a bottom area that stays above the keyboard.
/// Content is capped to [AppSize.maxContentWidth] and centered.
///
/// Callers should wrap the screen in a PopScope so the Android back button
/// goes to the previous step instead of leaving the flow.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    required this.child,
    required this.bottom,
    this.onBack,
  });

  final int step;
  final int total;
  final String title;
  final Widget child;
  final Widget bottom;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final reduced = AppMotion.reduced(context);
    final progress = total <= 0 ? 0.0 : (step / total).clamp(0.0, 1.0);
    final label = 'ui.step_of'.tr(args: ['$step', '$total']);

    return Scaffold(
      // The bottom area handles the keyboard itself so it never scrolls away.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSize.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s8,
                    AppSpace.s4,
                    AppSpace.s16,
                    0,
                  ),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: AppSize.minTap,
                        child: onBack == null
                            ? null
                            : Pressable(
                                minSize: AppSize.minTap,
                                radius: AppRadius.pill,
                                semanticLabel: 'ui.back'.tr(),
                                onTap: onBack,
                                child: Icon(Icons.arrow_back, color: p.text),
                              ),
                      ),
                      const Spacer(),
                      // Announced once, by the progress bar below.
                      ExcludeSemantics(
                        child: Text(
                          label,
                          style: AppText.status.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
                  child: Semantics(
                    label: label,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: SizedBox(
                        height: AppSize.progressHeight,
                        child: ColoredBox(
                          color: p.surface,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: progress),
                            duration: reduced ? Duration.zero : AppMotion.page,
                            curve: AppMotion.easeOut,
                            builder: (_, v, _) => Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: v,
                                child: ColoredBox(color: p.primary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(AppSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: AppText.title.copyWith(color: p.text),
                          ),
                        ),
                        const SizedBox(height: AppSpace.s16),
                        child,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.s16,
                    AppSpace.s8,
                    AppSpace.s16,
                    bottomBarInset(context) + AppSpace.s12,
                  ),
                  child: bottom,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
