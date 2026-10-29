import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/pressable.dart';

/// Small building blocks shared by the order wizard steps: captioned card
/// sections, form rows, selectable pills/cards, pickers and the inline
/// field hint.

/// A caption above a [FloatingCard].
class WizardSection extends StatelessWidget {
  const WizardSection({
    super.key,
    required this.caption,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpace.s12),
  });

  final String caption;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              0,
              AppSpace.s4,
              AppSpace.s8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      caption,
                      style: AppText.caption.copyWith(
                        color: p.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          FloatingCard(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Caption label above a field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s4),
      child: Text(
        text,
        style: AppText.caption.copyWith(
          color: AppPalette.of(context).textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The "missing value" hint below a field; nothing when [messageKey] is
/// null. Announced to screen readers when it appears.
class FieldHint extends StatelessWidget {
  const FieldHint(this.messageKey, {super.key});

  final String? messageKey;

  @override
  Widget build(BuildContext context) {
    final key = messageKey;
    if (key == null) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s4),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: AppSpace.s16, color: p.error),
            const SizedBox(width: AppSpace.s4),
            Expanded(
              child: Text(
                key.tr(),
                style: AppText.caption.copyWith(color: p.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A captioned single-line (unless [maxLines] says otherwise) text field
/// with its hint below.
class WizardTextField extends StatelessWidget {
  const WizardTextField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.hintText,
    this.errorKey,
    this.textInputAction,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
    this.minLines,
    this.maxLines = 1,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final String? hintText;
  final String? errorKey;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final int? minLines;
  final int? maxLines;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          minLines: minLines,
          maxLines: maxLines,
          style: AppText.button.copyWith(
            color: p.text,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppText.button.copyWith(
              color: p.textSecondary,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: AppSize.rowIcon),
            enabledBorder: errorKey == null
                ? null
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    borderSide: BorderSide(color: p.error),
                  ),
          ),
        ),
        FieldHint(errorKey),
      ],
    );
  }
}

/// Round check mark: black fill with a white tick when [selected], an
/// empty ring otherwise.
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox.square(
      dimension: AppSize.checkMark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? p.primary : null,
          border: selected
              ? null
              : Border.all(color: p.disabled, width: AppSize.focusRing),
        ),
        child: selected
            ? Icon(Icons.check, size: AppSize.checkGlyph, color: p.onPrimary)
            : null,
      ),
    );
  }
}

/// Selectable pill for option groups (wraps, unlike [PillFilter]); black
/// fill with a check when selected. 44 px tap height.
class SelectPill extends StatelessWidget {
  const SelectPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = selected ? p.onPrimary : p.text;
    final leading = selected ? Icons.check : icon;
    return Pressable(
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      selected: selected,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? p.primary : p.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? p.primary : p.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s12,
            vertical: AppSpace.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                Icon(leading, size: AppSpace.s16, color: fg),
                const SizedBox(width: AppSpace.s4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppText.body.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wrapping group of [SelectPill]s.
class PillGroup extends StatelessWidget {
  const PillGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.s8,
      runSpacing: AppSpace.s4,
      children: children,
    );
  }
}

/// A full-width selectable row card (icon, title, description, check).
class SelectCard extends StatelessWidget {
  const SelectCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Pressable(
        radius: AppRadius.card,
        selected: selected,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? p.primary : p.border,
              width: selected ? AppSize.focusRing : AppSize.hairline,
            ),
            boxShadow: AppShadow.card,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.minTap),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    SizedBox.square(
                      dimension: AppSize.optionIconBox,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: Icon(icon, size: AppSize.rowIcon, color: p.text),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.section.copyWith(color: p.text),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpace.s4),
                          Text(
                            subtitle!,
                            style: AppText.body.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  CheckMark(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable row showing a picked value (or a placeholder) that opens a
/// picker; 44 px min height.
class PickerRow extends StatelessWidget {
  const PickerRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      radius: AppRadius.control,
      minSize: AppSize.minTap,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.minTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: Row(
            children: [
              Icon(icon, size: AppSize.rowIcon, color: p.text),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.caption.copyWith(color: p.textSecondary),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      value ?? placeholder,
                      style: AppText.button.copyWith(
                        color: value == null ? p.textSecondary : p.text,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 44 px round icon button for steppers.
class StepperButton extends StatelessWidget {
  const StepperButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      semanticLabel: semanticLabel,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: SizedBox.square(
        dimension: AppSize.minTap,
        child: DecoratedBox(
          decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
          child: Icon(
            icon,
            size: AppSize.rowIcon,
            color: onTap == null ? p.disabled : p.text,
          ),
        ),
      ),
    );
  }
}

/// A small "i" button (44 px target) that opens an info sheet.
class InfoButton extends StatelessWidget {
  const InfoButton({
    super.key,
    required this.tooltip,
    required this.title,
    required this.message,
  });

  final String tooltip;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      semanticLabel: tooltip,
      onTap: () => showInfoSheet(context, title: title, message: message),
      child: Icon(
        Icons.info_outline,
        size: AppSize.rowIcon,
        color: p.textSecondary,
      ),
    );
  }
}

/// Short explanation in a sheet with a single OK.
Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheet) {
      final p = AppPalette.of(sheet);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.heroTitle.copyWith(color: p.text)),
          const SizedBox(height: AppSpace.s8),
          Text(message, style: AppText.body.copyWith(color: p.textSecondary)),
          const SizedBox(height: AppSpace.s24),
          PrimaryButton(
            label: 'common.ok'.tr(),
            onPressed: () => Navigator.of(sheet).pop(),
          ),
        ],
      );
    },
  );
}

/// A captioned value row inside a card: label on top on narrow widths.
class SummaryRow extends StatelessWidget {
  const SummaryRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppText.body.copyWith(color: p.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppText.body.copyWith(
                color: p.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
