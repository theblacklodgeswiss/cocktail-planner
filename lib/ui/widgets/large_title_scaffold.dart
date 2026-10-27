import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'glass_cta_bar.dart' show bottomBarInset;
import 'glass_surface.dart';
import 'staff_tab_bar.dart' show staffBarClearance;

/// Page with a large title that collapses into a small title in a glass top
/// bar once scrolled. Content is capped to [AppSize.maxContentWidth] and
/// centered.
///
/// [bottomBar] (tab bar / CTA) floats over the content at the bottom and
/// [fab] sits right above it at the bottom right (the bar's height is part
/// of the same column, so both can be set). The Scaffold resizes with the
/// keyboard, so the bar rides on top of it and a focused field can scroll
/// clear of it. Pass [controller] to drive the scroll position from outside
/// (e.g. scroll to top when the active tab is tapped again).
class LargeTitleScaffold extends StatefulWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.bottomBar,
    this.fab,
    this.controller,
  });

  final String title;
  final List<Widget> actions;
  final Widget? bottomBar;
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
    final clearance = hasBar
        ? staffBarClearance(context)
        : AppSpace.s24 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: LayoutBuilder(
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
                            style: AppText.largeTitle.copyWith(color: p.text),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final s in widget.slivers) padded(s),
                  padded(
                    SliverToBoxAdapter(child: SizedBox(height: clearance)),
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
                            : const SizedBox.shrink(key: ValueKey('clear')),
                      ),
                    ),
                    Row(
                      children: [
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
              if (hasBar || widget.fab != null)
                Positioned(
                  left: side,
                  right: side,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.fab != null)
                        Padding(
                          padding: EdgeInsets.only(
                            right: AppSize.fabRight,
                            bottom: hasBar
                                ? AppSpace.s8
                                : bottomBarInset(context) + AppSpace.s16,
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: widget.fab,
                          ),
                        ),
                      if (hasBar) widget.bottomBar!,
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
