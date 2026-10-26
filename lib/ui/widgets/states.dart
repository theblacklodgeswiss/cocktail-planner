import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'buttons.dart';

/// Centered icon, title and optional hint/action for an empty list.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return _Centered(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
          child: SizedBox.square(
            dimension: AppSize.stateIconBox,
            child: ExcludeSemantics(
              child: Icon(
                icon,
                size: AppSize.stateIcon,
                color: p.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.section.copyWith(color: p.text),
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: AppSpace.s8),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: p.textSecondary),
          ),
        ],
        if (action != null) ...[const SizedBox(height: AppSpace.s24), action!],
      ],
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'ui.loading'.tr(),
        liveRegion: true,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return _Centered(
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: p.error),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        SecondaryButton(label: 'ui.retry'.tr(), onPressed: onRetry),
      ],
    );
  }
}

/// Scrolls instead of overflowing at large text or in short spaces.
class _Centered extends StatelessWidget {
  const _Centered({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: c.hasBoundedHeight
                ? math.max(0, c.maxHeight - 2 * AppSpace.s24)
                : 0,
            minWidth: math.max(0, c.maxWidth - 2 * AppSpace.s24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}
