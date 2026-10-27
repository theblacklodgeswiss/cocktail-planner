import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'glass_cta_bar.dart' show bottomBarInset;
import 'glass_surface.dart';
import 'pressable.dart';

enum StaffTab { orders, inventory, more }

/// Space a scroll view needs at its end so content clears the floating
/// staff bar: [AppSize.barClearance] (grown with text scale) plus the safe
/// area. `LargeTitleScaffold` applies it itself; a screen that uses
/// [StaffTabBar] outside it must add this to its bottom padding.
double staffBarClearance(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return AppSize.barClearance * math.max(1.0, scale) +
      MediaQuery.paddingOf(context).bottom;
}

/// Floating glass pill; the active tab is a filled pill.
///
/// Usage contract: use it as `LargeTitleScaffold.bottomBar` or at the bottom
/// of a Stack in a normal Scaffold, never inside a sheet. It adds the
/// safe-area inset (and the keyboard inset outside a resizing Scaffold)
/// itself. Capped to [AppSize.maxBarWidth] and centered.
class StaffTabBar extends StatelessWidget {
  const StaffTabBar({super.key, required this.current, required this.onSelect});

  final StaffTab current;
  final ValueChanged<StaffTab> onSelect;

  static const _labels = {
    StaffTab.orders: 'ui.tab_orders',
    StaffTab.inventory: 'ui.tab_inventory',
    StaffTab.more: 'ui.tab_more',
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final reduced = AppMotion.reduced(context);
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
            child: SizedBox(
              height: AppSize.tabBarHeight - 2 * AppSize.hairline,
              child: Row(
                children: [
                  for (final tab in StaffTab.values)
                    Expanded(
                      child: Pressable(
                        minSize: AppSize.minTap,
                        radius: AppRadius.pill,
                        selected: tab == current,
                        semanticLabel: _labels[tab]!.tr(),
                        onTap: () => onSelect(tab),
                        child: AnimatedContainer(
                          duration: reduced ? Duration.zero : AppMotion.press,
                          curve: AppMotion.easeOut,
                          margin: const EdgeInsets.all(AppSpace.s4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s8,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tab == current ? p.primary : null,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          // The Pressable already announces the label.
                          child: ExcludeSemantics(
                            child: Text(
                              _labels[tab]!.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.tab.copyWith(
                                color: tab == current
                                    ? p.onPrimary
                                    : p.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
