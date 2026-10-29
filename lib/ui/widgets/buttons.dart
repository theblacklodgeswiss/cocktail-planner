import 'package:easy_localization/easy_localization.dart';
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
    this.dimmed = false,
    this.expand = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final String? trailing;
  final Color? fill;
  final Color foreground;
  final Color? border;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final enabled = onPressed != null && !loading;
    final fg = (onPressed == null || dimmed) && !loading
        ? p.disabled
        : foreground;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
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
        if (trailing != null) ...[
          const SizedBox(width: AppSpace.s8),
          Flexible(
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.section.copyWith(color: fg),
            ),
          ),
        ],
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

    final button = Pressable(
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      expand: expand,
      onTap: enabled ? onPressed : null,
      child: body,
    );
    if (!dimmed) return button;
    // Tells screen readers why the button looks unavailable.
    return Semantics(hint: 'ui.fields_missing'.tr(), child: button);
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
    this.dimmed = false,
    this.expand = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Fills the available width (glass CTA bar).
  final bool expand;

  /// Small text on the right inside the button, e.g. a count.
  final String? trailing;

  /// Error-colored fill for irreversible actions.
  final bool destructive;

  /// Looks disabled but stays tappable, e.g. a "Weiter" that explains the
  /// missing fields on tap instead of silently ignoring it.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final disabled = (onPressed == null || dimmed) && !loading;
    return _ButtonBase(
      label: label,
      onPressed: onPressed,
      loading: loading,
      dimmed: dimmed,
      expand: expand,
      trailing: trailing,
      fill: disabled ? p.surface : (destructive ? p.error : p.primary),
      foreground: destructive ? p.onError : p.onPrimary,
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
