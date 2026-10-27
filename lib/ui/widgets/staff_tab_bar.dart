import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'glass_cta_bar.dart' show bottomBarInset;
import 'glass_surface.dart';
import 'pressable.dart';

enum StaffTab { orders, inventory, more }

double _tabScale(BuildContext context) => math.min(
  AppSize.maxTabTextScale,
  math.max(1.0, MediaQuery.textScalerOf(context).scale(1)),
);

/// Height of the bar's glass pill (grows with text scale up to
/// [AppSize.maxTabTextScale]).
double staffTabBarHeight(BuildContext context) =>
    AppSize.tabBarHeight * _tabScale(context);

/// Vertical space the floating bar covers at the bottom of the screen: pill,
/// gap and safe area. The keyboard is not counted: the bar sits in a
/// resizing Scaffold's body and hides while the keyboard is open.
double staffTabBarExtent(BuildContext context) =>
    staffTabBarHeight(context) +
    AppSize.barGap +
    MediaQuery.paddingOf(context).bottom;

/// Space a scroll view needs at its end so its last item can be scrolled
/// above the floating staff bar. `LargeTitleScaffold.tabBar` and
/// `StaffFrame` apply it themselves; a screen that floats [StaffTabBar]
/// on its own must add this to its bottom padding.
double staffBarClearance(BuildContext context) =>
    staffTabBarExtent(context) + AppSpace.s24;

/// True while the on-screen keyboard is open. Read it above any resizing
/// Scaffold (a Scaffold removes the inset for its body).
bool keyboardOpen(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom > 0;

/// Slides and fades [child] (a floating bottom bar or button) away while
/// [hidden], and takes it out of hit testing and semantics. Instant under
/// reduced motion.
class HideOnKeyboard extends StatelessWidget {
  const HideOnKeyboard({super.key, required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.reduced(context)
        ? Duration.zero
        : AppMotion.barHide;
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: AnimatedSlide(
          offset: hidden ? AppMotion.barHidden : Offset.zero,
          duration: duration,
          curve: AppMotion.easeOut,
          child: AnimatedOpacity(
            opacity: hidden ? 0 : 1,
            duration: duration,
            curve: AppMotion.easeOut,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Floating Liquid Glass pill with icon-over-label tabs. The active tab is
/// a brighter glass lens that slides between the tabs.
///
/// Usage contract: use it as `LargeTitleScaffold.tabBar` (floats over the
/// content) or at the bottom of a Stack, never inside a sheet. It adds the
/// safe-area inset itself. Capped to [AppSize.maxBarWidth] and centered.
class StaffTabBar extends StatelessWidget {
  const StaffTabBar({super.key, required this.current, required this.onSelect});

  final StaffTab current;
  final ValueChanged<StaffTab> onSelect;

  static const _labels = {
    StaffTab.orders: 'ui.tab_orders',
    StaffTab.inventory: 'ui.tab_inventory',
    StaffTab.more: 'ui.tab_more',
  };

  static const _icons = {
    StaffTab.orders: (Icons.receipt_long_outlined, Icons.receipt_long),
    StaffTab.inventory: (Icons.inventory_2_outlined, Icons.inventory_2),
    StaffTab.more: (Icons.more_horiz, Icons.more_horiz),
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final reduced = AppMotion.reduced(context);
    final solid = AppMotion.reducedTransparency(context);
    const tabs = StaffTab.values;
    final index = tabs.indexOf(current);
    final lensX = tabs.length == 1 ? 0.0 : -1 + 2 * index / (tabs.length - 1);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSize.barSide,
        0,
        AppSize.barSide,
        bottomBarInset(context) + AppSize.barGap,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.maxBarWidth),
          child: GlassSurface(
            liquid: true,
            child: SizedBox(
              height: staffTabBarHeight(context) - 2 * AppSize.hairline,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: AppSize.maxTabTextScale,
                child: Stack(
                  children: [
                    AnimatedAlign(
                      key: const ValueKey('tab-lens'),
                      alignment: Alignment(lensX, 0),
                      duration: reduced ? Duration.zero : AppMotion.lens,
                      curve: AppMotion.easeOut,
                      child: FractionallySizedBox(
                        widthFactor: 1 / tabs.length,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.s4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: solid ? p.surface : p.lens,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(
                                color: solid ? p.border : p.lensBorder,
                                width: AppSize.hairline,
                              ),
                              boxShadow: solid ? null : AppShadow.lens,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final tab in tabs)
                          Expanded(
                            child: _Tab(
                              label: _labels[tab]!.tr(),
                              icon: tab == current
                                  ? _icons[tab]!.$2
                                  : _icons[tab]!.$1,
                              selected: tab == current,
                              onTap: () => onSelect(tab),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = selected ? p.text : p.textSecondary;
    return Pressable(
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      selected: selected,
      semanticLabel: label,
      onTap: onTap,
      child: SizedBox.expand(
        // The Pressable already announces the label.
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: AppSize.tabIcon, color: color),
                const SizedBox(height: AppSize.tabIconGap),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.tab.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
