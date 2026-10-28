import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'glass_surface.dart';
import 'staff_tab_bar.dart'
    show HideOnKeyboard, keyboardOpen, staffBarClearance, staffFabBottom;

/// Page with a large title that collapses into a small title in a glass top
/// bar once scrolled. Content is capped to [AppSize.maxContentWidth] and
/// centered.
///
/// Two bottom slots with different contracts:
/// - [bottomBar] (e.g. GlassCtaBar) takes its own space under the scroll
///   view, so a focused text field that Flutter scrolls into view always
///   lands above it. The Scaffold resizes with the keyboard, so the bar rides
///   on top of it.
/// - [tabBar] (the staff tab bar) floats over the content: the page scrolls
///   underneath and shows through the glass, and an end spacer lets the last
///   item scroll clear above it. While the keyboard is open the tab bar and
///   the [fab] slide away and the spacer shrinks, so a focused field is never
///   covered.
///
/// [fab] floats over the content at the bottom right, above the bars. Pass
/// [controller] to drive the scroll position from outside (e.g. scroll to
/// top when the active tab is tapped again).
class LargeTitleScaffold extends StatefulWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.leading,
    this.bottomBar,
    this.tabBar,
    this.fab,
    this.controller,
  });

  final String title;
  final List<Widget> actions;

  /// Shown at the start of the top bar, in the expanded and the collapsed
  /// state (e.g. a back button). Keep it a 44 px tap target.
  final Widget? leading;
  final Widget? bottomBar;

  /// Floating bar (see the class doc); hidden while the keyboard is open.
  final Widget? tabBar;
  final Widget? fab;
  final List<Widget> slivers;
  final ScrollController? controller;

  @override
  State<LargeTitleScaffold> createState() => _LargeTitleScaffoldState();
}

class _LargeTitleScaffoldState extends State<LargeTitleScaffold> {
  final _own = ScrollController();
  late ScrollController _controller = widget.controller ?? _own;
  double _threshold = AppSize.titleCollapse;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(LargeTitleScaffold old) {
    super.didUpdateWidget(old);
    final next = widget.controller ?? _own;
    if (next != _controller) {
      _controller.removeListener(_onScroll);
      _controller = next..addListener(_onScroll);
    }
  }

  // Rebuild only when crossing the threshold, not on every scroll tick.
  void _onScroll() {
    if (!_controller.hasClients) return;
    final collapsed = _controller.offset > _threshold;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
    _threshold = AppSize.titleCollapse * scale;
    final fade = AppMotion.reduced(context) ? Duration.zero : AppMotion.press;
    final hasBar = widget.bottomBar != null;
    // Read above the Scaffold, which strips the inset for its body.
    final keyboard = keyboardOpen(context);
    final showTab = widget.tabBar != null && !keyboard;
    final hasFab = widget.fab != null;
    final showFab = hasFab && (widget.tabBar == null || !keyboard);
    // The bottom bar takes its own space below the scroll view. Floating
    // things need clearance: the tab bar (with the safe area), else the safe
    // area (no bottom bar), plus the FAB.
    final clearance =
        (showTab
            ? staffBarClearance(context)
            : AppSpace.s24 +
                  (hasBar ? 0 : MediaQuery.paddingOf(context).bottom)) +
        (showFab ? AppSize.liquidFab + AppSpace.s16 : 0);
    final fabBottom = widget.tabBar != null
        ? staffFabBottom(context)
        : hasBar
        ? AppSpace.s8
        : MediaQuery.paddingOf(context).bottom + AppSpace.s16;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                // Centered column of at most maxContentWidth.
                final side = math.max(
                  0.0,
                  (box.maxWidth - AppSize.maxContentWidth) / 2,
                );
                Widget padded(Widget sliver) => SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: sliver,
                );

                return Stack(
                  children: [
                    CustomScrollView(
                      controller: _controller,
                      slivers: [
                        padded(
                          SliverToBoxAdapter(
                            child: SizedBox(height: top + AppSize.topBar),
                          ),
                        ),
                        padded(
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpace.s16,
                                0,
                                AppSpace.s16,
                                AppSpace.s12,
                              ),
                              child: Semantics(
                                header: true,
                                child: Text(
                                  widget.title,
                                  style: AppText.largeTitle.copyWith(
                                    color: p.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        for (final s in widget.slivers) padded(s),
                        padded(
                          SliverToBoxAdapter(
                            child: SizedBox(height: clearance),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: top,
                      left: AppSpace.s12 + side,
                      right: AppSpace.s12 + side,
                      height: AppSize.topBar,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AnimatedSwitcher(
                              duration: fade,
                              child: _collapsed
                                  ? const GlassSurface(
                                      key: ValueKey('glass'),
                                      child: SizedBox.expand(),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('clear'),
                                    ),
                            ),
                          ),
                          Row(
                            children: [
                              ?widget.leading,
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.s16,
                                  ),
                                  // The large title is the header; skip the echo.
                                  child: ExcludeSemantics(
                                    child: AnimatedOpacity(
                                      opacity: _collapsed ? 1 : 0,
                                      duration: fade,
                                      child: Text(
                                        widget.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.section.copyWith(
                                          color: p.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              ...widget.actions,
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.tabBar != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: HideOnKeyboard(
                          hidden: keyboard,
                          child: widget.tabBar!,
                        ),
                      ),
                    if (hasFab)
                      Positioned(
                        right: side + AppSize.fabRight,
                        bottom: fabBottom,
                        child: HideOnKeyboard(
                          hidden: widget.tabBar != null && keyboard,
                          child: widget.fab!,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          ?widget.bottomBar,
        ],
      ),
    );
  }
}
