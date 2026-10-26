import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'glass_surface.dart';

/// Page with a large title that collapses into a small title in a glass top
/// bar once scrolled. [bottomBar] (tab bar / CTA) and [fab] float over the
/// content; they are placed by the caller's own padding (bars lift
/// themselves above the keyboard).
class LargeTitleScaffold extends StatefulWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.bottomBar,
    this.fab,
  });

  final String title;
  final List<Widget> actions;
  final Widget? bottomBar;
  final Widget? fab;
  final List<Widget> slivers;

  @override
  State<LargeTitleScaffold> createState() => _LargeTitleScaffoldState();
}

class _LargeTitleScaffoldState extends State<LargeTitleScaffold> {
  final _controller = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  // Rebuild only when crossing the threshold, not on every scroll tick.
  void _onScroll() {
    final collapsed = _controller.offset > AppSize.titleCollapse;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final fade = AppMotion.reduced(context) ? Duration.zero : AppMotion.press;
    final hasBar = widget.bottomBar != null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _controller,
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: top + AppSize.topBar)),
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
              ...widget.slivers,
              SliverToBoxAdapter(
                child: SizedBox(
                  height: hasBar ? AppSize.barClearance : AppSpace.s24,
                ),
              ),
            ],
          ),
          Positioned(
            top: top,
            left: AppSpace.s12,
            right: AppSpace.s12,
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
                              style: AppText.section.copyWith(color: p.text),
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
          if (hasBar)
            Positioned(left: 0, right: 0, bottom: 0, child: widget.bottomBar!),
          if (widget.fab != null) widget.fab!,
        ],
      ),
    );
  }
}
