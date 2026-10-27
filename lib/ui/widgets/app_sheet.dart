import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'buttons.dart';

/// Bottom sheet: top radius 28, side padding 24, handle, lifted above the
/// keyboard, at most [AppSize.maxContentWidth] wide. Slides in and out, or
/// fades with reduced motion; the handle area can be dragged down to close.
///
/// [full] makes it nearly full height. [scrollable] (default: true for the
/// compact sheet, false for [full]) wraps the content in a scroll view. When
/// it is false a full sheet gives the content tight, bounded constraints
/// (the sheet height minus the handle), so it may hold its own ListView, an
/// Expanded Column or a nested Scaffold; a compact sheet gives it a loose,
/// bounded height (at most 90% of the screen).
///
/// The content's MediaQuery has the keyboard and bottom safe-area insets
/// removed (the sheet applies them itself), so widgets inside must not add
/// them again.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  bool full = false,
  bool? scrollable,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push(
    _AppSheetRoute<T>(
      builder: builder,
      full: full,
      scrollable: scrollable ?? !full,
      barrierLabel: 'ui.close'.tr(),
      capturedTheme: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    ),
  );
}

/// Asks a yes/no question; dismissing the sheet counts as no.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showAppSheet<bool>(
    context,
    builder: (sheet) {
      final p = AppPalette.of(sheet);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.heroTitle.copyWith(color: p.text)),
          if (body != null) ...[
            const SizedBox(height: AppSpace.s8),
            Text(body, style: AppText.body.copyWith(color: p.textSecondary)),
          ],
          const SizedBox(height: AppSpace.s24),
          PrimaryButton(
            label: confirmLabel,
            destructive: destructive,
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
          const SizedBox(height: AppSpace.s8),
          TextAction(
            label: 'ui.cancel'.tr(),
            onPressed: () => Navigator.of(sheet).pop(false),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

class _AppSheetRoute<T> extends PopupRoute<T> {
  _AppSheetRoute({
    required this.builder,
    required this.full,
    required this.scrollable,
    required this.capturedTheme,
    required String barrierLabel,
  }) : _barrierLabel = barrierLabel;

  final Widget Function(BuildContext) builder;
  final bool full;
  final bool scrollable;
  final CapturedThemes capturedTheme;
  final String _barrierLabel;

  CurvedAnimation? _curved;

  // Enter with easeOut and leave with its mirror, so neither direction
  // starts slowly.
  @override
  Animation<double> createAnimation() => _curved = CurvedAnimation(
    parent: super.createAnimation(),
    curve: AppMotion.easeOut,
    reverseCurve: AppMotion.easeOutExit,
  );

  @override
  Duration get transitionDuration => AppMotion.sheet;

  @override
  Color? get barrierColor => AppColors.scrim;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  void dispose() {
    _curved?.dispose();
    super.dispose();
  }

  // Escape is handled by ModalRoute (DismissIntent), no extra shortcut.
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> a,
    Animation<double> b,
  ) {
    return capturedTheme.wrap(
      _SheetBody(full: full, scrollable: scrollable, builder: builder),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> a,
    Animation<double> b,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) {
      return FadeTransition(opacity: a, child: child);
    }
    return SlideTransition(
      position: Tween(begin: AppMotion.sheetFrom, end: Offset.zero).animate(a),
      child: child,
    );
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({
    required this.full,
    required this.scrollable,
    required this.builder,
  });

  final bool full;
  final bool scrollable;
  final Widget Function(BuildContext) builder;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _back;
  late final CurvedAnimation _eased;
  final _card = GlobalKey();
  double _drag = 0;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _back = AnimationController(vsync: this, duration: AppMotion.press)
      ..addListener(() => setState(() => _drag = _from * (1 - _eased.value)));
    _eased = CurvedAnimation(parent: _back, curve: AppMotion.easeOut);
  }

  @override
  void dispose() {
    _eased.dispose();
    _back.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails d) {
    _back.stop();
    setState(() => _drag = math.max(0, _drag + d.delta.dy));
  }

  void _springBack() {
    if (AppMotion.reduced(context)) {
      setState(() => _drag = 0);
    } else {
      _from = _drag;
      _back.forward(from: 0);
    }
  }

  Future<void> _end(DragEndDetails d) async {
    final height = _card.currentContext?.size?.height ?? 0;
    final fling = d.velocity.pixelsPerSecond.dy > AppSize.sheetFlingVelocity;
    if (!fling && _drag <= height * AppSize.sheetDismissFraction) {
      return _springBack();
    }
    // The sheet may already be closing (barrier, Escape, code): popping now
    // would take the page underneath with it.
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive || !route.isCurrent) return;
    // Keep the offset while popping: the exit slide continues from here.
    await Navigator.of(context).maybePop();
    // A PopScope may veto the pop (maybePop still reports it as handled), so
    // check whether the route is really leaving; if not, spring back.
    if (mounted && route.isActive) _springBack();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final m = MediaQuery.of(context);
    final keyboard = m.viewInsets.bottom;
    final available = m.size.height - keyboard - m.padding.top;
    final height =
        available *
        (widget.full ? AppSize.sheetFullFraction : AppSize.sheetMaxFraction);
    // The keyboard replaces the home-indicator inset.
    final safeBottom = keyboard > 0 ? 0.0 : m.padding.bottom;

    Widget content = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s24,
        0,
        AppSpace.s24,
        AppSpace.s24 + safeBottom,
      ),
      child: Builder(builder: widget.builder),
    );
    // Insets are applied here; nothing inside may lift a second time.
    content = MediaQuery(
      data: m.copyWith(
        viewInsets: m.viewInsets.copyWith(bottom: 0),
        padding: m.padding.copyWith(
          bottom: 0,
          top: widget.full ? 0 : m.padding.top,
        ),
      ),
      child: content,
    );

    final Widget body;
    if (widget.scrollable) {
      body = Flexible(child: SingleChildScrollView(child: content));
    } else if (widget.full) {
      body = Expanded(child: content);
    } else {
      body = Flexible(child: content);
    }

    final handle = GestureDetector(
      key: const Key('sheet-handle'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      child: ExcludeSemantics(
        child: SizedBox(
          height: AppSize.minTap,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.disabled,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const SizedBox(
                width: AppSize.sheetHandleWidth,
                height: AppSize.sheetHandleHeight,
              ),
            ),
          ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Transform.translate(
          offset: Offset.zero.translate(0, _drag),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: 'ui.sheet'.tr(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppSize.maxContentWidth,
                maxHeight: height,
                minHeight: widget.full ? height : 0,
                minWidth: math.min(m.size.width, AppSize.maxContentWidth),
              ),
              child: DecoratedBox(
                key: _card,
                decoration: BoxDecoration(
                  color: p.card,
                  border: p.cardBorder,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet),
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [handle, body],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
