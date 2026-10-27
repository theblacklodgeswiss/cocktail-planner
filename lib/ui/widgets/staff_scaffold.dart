import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../motion.dart';
import '../tokens.dart';
import 'floating_fab.dart';
import 'large_title_scaffold.dart';
import 'staff_tab_bar.dart';

/// Where each staff tab lives. Tabs are top-level destinations, so they are
/// opened with `context.go` (replacing the stack, no back arrow piling up);
/// detail pages from there are pushed as before. The staff landing at `/`
/// shows the orders list and counts as the orders tab.
const staffTabRoutes = {
  StaffTab.orders: '/orders',
  StaffTab.inventory: '/inventory',
  StaffTab.more: '/more',
};

/// Target of the round "+" button (same form the dashboard FAB opens).
const staffNewOrderRoute = '/order-form';

/// Handles a tab tap: the active tab scrolls its page to the top via
/// [scrollToTop] instead of navigating again; any other tab is opened with
/// `go`.
void selectStaffTab(
  BuildContext context, {
  required StaffTab current,
  required StaffTab selected,
  required VoidCallback scrollToTop,
}) {
  if (selected == current) {
    scrollToTop();
    return;
  }
  context.go(staffTabRoutes[selected]!);
}

void _toTop(BuildContext context, ScrollController controller) {
  for (final position in controller.positions.toList()) {
    if (AppMotion.reduced(context)) {
      position.jumpTo(0);
    } else {
      position.animateTo(0, duration: AppMotion.page, curve: AppMotion.easeOut);
    }
  }
}

class _NewOrderFab extends StatelessWidget {
  const _NewOrderFab();

  @override
  Widget build(BuildContext context) => FloatingFab(
    semanticLabel: 'dashboard.new_order'.tr(),
    onPressed: () => context.push(staffNewOrderRoute),
  );
}

/// Staff page: [LargeTitleScaffold] with the floating [StaffTabBar] and the
/// round "+" button (new order) above it. Pass [fab] to replace the "+".
class StaffScaffold extends StatefulWidget {
  const StaffScaffold({
    super.key,
    required this.tab,
    required this.title,
    required this.slivers,
    this.leading,
    this.actions = const [],
    this.fab,
    this.controller,
  });

  final StaffTab tab;
  final String title;
  final List<Widget> slivers;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? fab;

  /// Scroll controller of the page; one is created when omitted.
  final ScrollController? controller;

  @override
  State<StaffScaffold> createState() => _StaffScaffoldState();
}

class _StaffScaffoldState extends State<StaffScaffold> {
  final _own = ScrollController();

  ScrollController get _controller => widget.controller ?? _own;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LargeTitleScaffold(
      title: widget.title,
      leading: widget.leading,
      actions: widget.actions,
      controller: _controller,
      slivers: widget.slivers,
      fab: widget.fab ?? const _NewOrderFab(),
      bottomBar: StaffTabBar(
        current: widget.tab,
        onSelect: (tab) => selectStaffTab(
          context,
          current: widget.tab,
          selected: tab,
          scrollToTop: () => _toTop(context, _controller),
        ),
      ),
    );
  }
}

/// Puts the staff bar and the "+" button around an existing (not yet
/// restyled) Material page. The page keeps its own Scaffold and AppBar; the
/// bar takes its own space below it. Its main vertical scroll view picks up
/// the frame's PrimaryScrollController (on phones, where Flutter inherits
/// it), so tapping the active tab scrolls it to the top.
///
/// Interim wrapper: Tasks 11/14 move these pages to [StaffScaffold].
class StaffFrame extends StatefulWidget {
  const StaffFrame({super.key, required this.tab, required this.child});

  final StaffTab tab;
  final Widget child;

  @override
  State<StaffFrame> createState() => _StaffFrameState();
}

class _StaffFrameState extends State<StaffFrame> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // The bar below handles the bottom safe area.
                Positioned.fill(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeBottom: true,
                    child: PrimaryScrollController(
                      controller: _scroll,
                      child: widget.child,
                    ),
                  ),
                ),
                const Positioned(
                  right: AppSize.fabRight,
                  bottom: AppSpace.s8,
                  child: _NewOrderFab(),
                ),
              ],
            ),
          ),
          StaffTabBar(
            current: widget.tab,
            onSelect: (tab) => selectStaffTab(
              context,
              current: widget.tab,
              selected: tab,
              scrollToTop: () => _toTop(context, _scroll),
            ),
          ),
        ],
      ),
    );
  }
}
