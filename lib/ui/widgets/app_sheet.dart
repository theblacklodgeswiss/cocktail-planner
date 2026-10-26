import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion.dart';
import '../tokens.dart';
import 'buttons.dart';

/// Bottom sheet: top radius 28, side padding 24, handle, lifted above the
/// keyboard. Slides in and out on the same path, or fades with reduced
/// motion. [full] makes it nearly full height.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  bool full = false,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    _AppSheetRoute<T>(
      builder: builder,
      full: full,
      barrierLabel: 'ui.close'.tr(),
      capturedTheme: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: true).context,
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
    required this.capturedTheme,
    required String barrierLabel,
  }) : _barrierLabel = barrierLabel;

  final Widget Function(BuildContext) builder;
  final bool full;
  final CapturedThemes capturedTheme;
  final String _barrierLabel;

  // One curve for both directions: the exit retraces the entrance.
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: animation!,
    curve: AppMotion.easeOut,
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
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> a,
    Animation<double> b,
  ) {
    return capturedTheme.wrap(
      CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Focus(
          autofocus: true,
          child: _SheetBody(full: full, builder: builder),
        ),
      ),
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
      return FadeTransition(opacity: _curved, child: child);
    }
    return SlideTransition(
      position: Tween(
        begin: AppMotion.sheetFrom,
        end: Offset.zero,
      ).animate(_curved),
      child: child,
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.full, required this.builder});

  final bool full;
  final Widget Function(BuildContext) builder;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final m = MediaQuery.of(context);
    final fraction = full
        ? AppSize.sheetFullFraction
        : AppSize.sheetMaxFraction;
    final maxHeight = (m.size.height - m.viewInsets.bottom) * fraction;
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s24,
        0,
        AppSpace.s24,
        AppSpace.s24 + m.padding.bottom,
      ),
      child: Builder(builder: builder),
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: m.viewInsets.bottom),
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              minHeight: full ? maxHeight : 0,
              minWidth: double.infinity,
            ),
            child: DecoratedBox(
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
                  children: [
                    ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s12,
                        ),
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
                    Flexible(child: SingleChildScrollView(child: content)),
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
