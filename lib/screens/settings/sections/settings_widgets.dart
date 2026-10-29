import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/pressable.dart';

/// A captioned [FloatingCard] holding one or more rows with subtle dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.caption,
    required this.children,
    this.captionTrailing,
  });

  final String caption;
  final List<Widget> children;
  final Widget? captionTrailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s24),
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
                Flexible(
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
                if (captionTrailing != null) ...[
                  const SizedBox(width: AppSpace.s8),
                  captionTrailing!,
                ],
              ],
            ),
          ),
          FloatingCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SettingsDivider(),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    height: AppSize.hairline,
    thickness: AppSize.hairline,
    color: AppPalette.of(context).border,
  );
}

/// One row (min 44 px) with icon, title, optional subtitle and trailing.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.selectableSubtitle = false,
    this.leadingColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool selectableSubtitle;
  final Color? leadingColor;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final subStyle = AppText.caption.copyWith(color: p.textSecondary);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.minTap),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: AppSize.glassButtonIcon,
                color: leadingColor ?? p.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body.copyWith(color: p.text)),
                  if (subtitle != null)
                    selectableSubtitle
                        ? SelectableText(subtitle!, style: subStyle)
                        : Text(subtitle!, style: subStyle),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpace.s8),
              trailing!,
            ],
            if (chevron) ...[
              const SizedBox(width: AppSpace.s4),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right,
                  size: AppSize.glassButtonIcon,
                  color: p.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Pressable(onTap: onTap, minSize: AppSize.minTap, child: row);
  }
}

class SettingsChoice<T> {
  const SettingsChoice({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// Bottom sheet with big selectable rows; the current one gets a check mark.
Future<T?> showSettingsChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<SettingsChoice<T>> choices,
  required T current,
}) {
  return showAppSheet<T>(
    context,
    builder: (sheet) {
      final p = AppPalette.of(sheet);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.heroTitle.copyWith(color: p.text)),
          const SizedBox(height: AppSpace.s12),
          for (final c in choices)
            Pressable(
              onTap: () => Navigator.of(sheet).pop(c.value),
              minSize: AppSize.minTap,
              selected: c.value == current,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.minTap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          c.icon,
                          size: AppSize.glassButtonIcon,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Text(
                          c.label,
                          style: AppText.section.copyWith(color: p.text),
                        ),
                      ),
                      if (c.value == current)
                        ExcludeSemantics(
                          child: Icon(
                            Icons.check,
                            size: AppSize.glassButtonIcon,
                            color: p.text,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
