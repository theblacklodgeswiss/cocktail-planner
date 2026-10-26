import 'package:flutter/material.dart';

import '../tokens.dart';
import 'pressable.dart';

/// Shared body of the filled/outlined/text buttons.
class _ButtonBase extends StatelessWidget {
  const _ButtonBase({
    required this.label,
    required this.onPressed,
    required this.loading,
    required this.fill,
    required this.foreground,
    this.border,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? fill;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final enabled = onPressed != null && !loading;
    final fg = onPressed == null && !loading ? p.disabled : foreground;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox.square(
            dimension: AppSpace.s16,
            child: CircularProgressIndicator(
              strokeWidth: AppSize.spinnerStroke,
              color: fg,
            ),
          ),
          const SizedBox(width: AppSpace.s8),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.button.copyWith(color: fg),
          ),
        ),
      ],
    );

    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.minTap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s24,
            vertical: AppSpace.s12,
          ),
          child: content,
        ),
      ),
    );

    return Pressable(
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      onTap: enabled ? onPressed : null,
      child: body,
    );
  }
}

/// Main action: filled black (white in dark mode).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Error-colored fill for irreversible actions.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final disabled = onPressed == null && !loading;
    return _ButtonBase(
      label: label,
      onPressed: onPressed,
      loading: loading,
      fill: disabled ? p.surface : (destructive ? p.error : p.primary),
      foreground: destructive
          ? Theme.of(context).colorScheme.onError
          : p.onPrimary,
    );
  }
}

/// Secondary action: outlined.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return _ButtonBase(
      label: label,
      onPressed: onPressed,
      loading: loading,
      fill: null,
      foreground: p.text,
      border: p.border,
    );
  }
}

/// Quiet text-only action.
class TextAction extends StatelessWidget {
  const TextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return _ButtonBase(
      label: label,
      onPressed: onPressed,
      loading: loading,
      fill: null,
      foreground: p.text,
    );
  }
}
