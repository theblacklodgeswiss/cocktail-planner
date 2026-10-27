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

/// `extra` of a tab navigation. Pages reached through the bar read it to
/// hide their old "back to home" arrow (home is just another tab); the same
/// pages opened from elsewhere (e.g. pushed from the dashboard) keep it.
const staffTabExtra = 'staff-tab';

/// Bottom padding the main scroll view of a page inside [StaffFrame] needs
/// so its last row scrolls clear of the floating bar and the "+" button.
///
/// [StaffFrame] publishes this as the page's bottom `MediaQuery` padding
/// (ListView and SafeArea pick it up on their own); this helper reads it for
/// scroll views that do not (e.g. SingleChildScrollView). It is 0 while the
/// keyboard is open, because the bar and the "+" hide then.
double staffFrameContentClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

/// Clearance [StaffFrame] gives its page: bar, gap, safe area and "+".
double _frameClearance(BuildContext context) =>
    staffBarClearance(context) + AppSize.liquidFab + AppSpace.s16;

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
  context.go(staffTabRoutes[selected]!, extra: staffTabExtra);
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

/// Staff page: [LargeTitleScaffold] with the floating Liquid Glass
/// [StaffTabBar] (content scrolls underneath) and the round "+" button (new
/// order) above it; both hide while the keyboard is open. Pass [fab] to
/// replace the "+".
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
      tabBar: StaffTabBar(
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

/// Puts the floating staff bar and the "+" button over an existing (not yet
/// restyled) Material page. The page keeps its own Scaffold and AppBar and
/// fills the screen; its content scrolls under the glass bar. The page gets
/// the bar and "+" clearance as its bottom MediaQuery padding (see
/// [staffFrameContentClearance]). While the keyboard is open the bar and the
/// "+" slide away and the padding drops to 0. Its main vertical scroll view
/// picks up the frame's PrimaryScrollController (on phones, where Flutter
/// inherits it), so tapping the active tab scrolls it to the top.
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
    // Read above the Scaffold, which strips the inset for its body.
    final keyboard = keyboardOpen(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final m = MediaQuery.of(context);
                return MediaQuery(
                  data: m.copyWith(
                    padding: m.padding.copyWith(
                      bottom: keyboard ? 0 : _frameClearance(context),
                    ),
                  ),
                  child: PrimaryScrollController(
                    controller: _scroll,
                    child: widget.child,
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: HideOnKeyboard(
              hidden: keyboard,
              child: StaffTabBar(
                current: widget.tab,
                onSelect: (tab) => selectStaffTab(
                  context,
                  current: widget.tab,
                  selected: tab,
                  scrollToTop: () => _toTop(context, _scroll),
                ),
              ),
            ),
          ),
          Positioned(
            right: AppSize.fabRight,
            bottom: staffTabBarExtent(context) + AppSpace.s8,
            child: HideOnKeyboard(
              hidden: keyboard,
              child: const _NewOrderFab(),
            ),
          ),
        ],
      ),
    );
  }
}
