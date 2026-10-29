import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'floating_fab.dart';
import 'large_title_scaffold.dart';
import 'staff_tab_bar.dart';

/// Where each staff tab lives (the root of its shell branch). The staff
/// landing at `/` shows the orders list and belongs to the orders branch.
const staffTabRoutes = {
  StaffTab.orders: '/orders',
  StaffTab.inventory: '/inventory',
  StaffTab.more: '/more',
};

/// Target of the round "+" button (same form the dashboard FAB opens).
const staffNewOrderRoute = '/order-form';

/// Clearance [StaffShell] gives its pages (as their bottom MediaQuery
/// padding, which ListView, SafeArea and [LargeTitleScaffold] pick up):
/// bar, gap, "+" and safe area.
double _shellClearance(BuildContext context) =>
    staffFabBottom(context) + AppSize.liquidFab;

/// Scrolls every position of [controller] to the top (instant under reduced
/// motion).
void scrollToTop(BuildContext context, ScrollController controller) {
  for (final position in controller.positions.toList()) {
    if (AppMotion.reduced(context)) {
      position.jumpTo(0);
    } else {
      position.animateTo(0, duration: AppMotion.page, curve: AppMotion.easeOut);
    }
  }
}

/// Tells the pages inside a [StaffShell] that their tab was tapped again
/// while active (they scroll to the top).
class StaffShellScope extends InheritedWidget {
  const StaffShellScope({
    super.key,
    required this.reselects,
    required super.child,
  });

  final Map<StaffTab, Listenable> reselects;

  /// Fires when [tab] is tapped while active; null outside a shell.
  static Listenable? reselectOf(BuildContext context, StaffTab tab) => context
      .dependOnInheritedWidgetOfExactType<StaffShellScope>()
      ?.reselects[tab];

  @override
  bool updateShouldNotify(StaffShellScope old) => old.reselects != reselects;
}

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// Persistent chrome of the staff tabs: the floating Liquid Glass
/// [StaffTabBar] and the round "+" button (new order) float over [child]
/// (the tab content, e.g. go_router's StatefulNavigationShell). Switching
/// tabs only swaps [child]; the bar, the "+" and this state stay.
///
/// Only staff see the chrome: with [showChrome] false (customers, guests,
/// unresolved role) the child is shown alone, untouched. The tree shape is
/// the same either way, so the child keeps its state when the role
/// resolves.
///
/// The child gets the bar and "+" clearance as its bottom MediaQuery
/// padding. While the keyboard is open the
/// bar and the "+" slide away and the padding drops to 0.
///
/// Tapping a tab calls [onSwitch]; tapping the active tab calls
/// [onReselect] and makes that tab's page scroll to the top (via
/// [StaffShellScope]).
///
/// Pure widget (no router, no auth): the app wires it in its router.
class StaffShell extends StatefulWidget {
  const StaffShell({
    super.key,
    required this.current,
    required this.onSwitch,
    required this.onNewOrder,
    required this.child,
    this.onReselect,
    this.showChrome = true,
  });

  final StaffTab current;
  final ValueChanged<StaffTab> onSwitch;
  final ValueChanged<StaffTab>? onReselect;
  final VoidCallback onNewOrder;
  final bool showChrome;
  final Widget child;

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  final _signals = {for (final t in StaffTab.values) t: _Signal()};

  @override
  void dispose() {
    for (final s in _signals.values) {
      s.dispose();
    }
    super.dispose();
  }

  void _select(StaffTab tab) {
    if (tab == widget.current) {
      widget.onReselect?.call(tab);
      _signals[tab]!.fire();
      return;
    }
    widget.onSwitch(tab);
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.showChrome;
    // Read above the pages' Scaffolds, which strip the inset for their body.
    final keyboard = keyboardOpen(context);
    final m = MediaQuery.of(context);
    final theme = Theme.of(context);
    return StaffShellScope(
      reselects: _signals,
      child: Stack(
        children: [
          Positioned.fill(
            // Snackbars of the tab pages float above the bar and the "+": a
            // fixed snackbar would pad itself by the shell's bottom padding
            // into a tall block half behind the bar, and a Scaffold ignores
            // that padding when it places a snackbar. Pages outside the shell
            // keep the app's default.
            child: Theme(
              data: chrome
                  ? theme.copyWith(
                      snackBarTheme: theme.snackBarTheme.copyWith(
                        behavior: SnackBarBehavior.floating,
                        insetPadding: EdgeInsets.fromLTRB(
                          AppSpace.s16,
                          AppSpace.s4,
                          AppSpace.s16,
                          (keyboard ? 0 : _shellClearance(context)) +
                              AppSpace.s12,
                        ),
                      ),
                    )
                  : theme,
              child: MediaQuery(
                data: chrome
                    ? m.copyWith(
                        padding: m.padding.copyWith(
                          bottom: keyboard ? 0 : _shellClearance(context),
                        ),
                      )
                    : m,
                child: widget.child,
              ),
            ),
          ),
          if (chrome)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: HideOnKeyboard(
                hidden: keyboard,
                child: StaffTabBar(current: widget.current, onSelect: _select),
              ),
            ),
          if (chrome)
            Positioned(
              right: AppSize.fabRight,
              bottom: staffFabBottom(context),
              child: HideOnKeyboard(
                hidden: keyboard,
                child: FloatingFab(
                  semanticLabel: 'dashboard.new_order'.tr(),
                  onPressed: widget.onNewOrder,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Root page of a staff tab: a [LargeTitleScaffold] without back arrow
/// inside [StaffShell] (which draws the bar and the "+"). The bottom
/// clearance comes from the shell's MediaQuery padding. Tapping the active
/// [tab] again scrolls the page to the top.
class StaffScaffold extends StatefulWidget {
  const StaffScaffold({
    super.key,
    required this.tab,
    required this.title,
    required this.slivers,
    this.leading,
    this.actions = const [],
    this.controller,
  });

  final StaffTab tab;
  final String title;
  final List<Widget> slivers;
  final Widget? leading;
  final List<Widget> actions;

  /// Scroll controller of the page; one is created when omitted.
  final ScrollController? controller;

  @override
  State<StaffScaffold> createState() => _StaffScaffoldState();
}

class _StaffScaffoldState extends State<StaffScaffold> {
  final _own = ScrollController();
  Listenable? _reselect;

  ScrollController get _controller => widget.controller ?? _own;

  void _toTop() {
    if (mounted) scrollToTop(context, _controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = StaffShellScope.reselectOf(context, widget.tab);
    if (next != _reselect) {
      _reselect?.removeListener(_toTop);
      _reselect = next?..addListener(_toTop);
    }
  }

  @override
  void dispose() {
    _reselect?.removeListener(_toTop);
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
    );
  }
}
