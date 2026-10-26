import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'pressable.dart';

/// Black round "+" button with a soft shadow. Only draws the button; the
/// caller positions it.
class FloatingFab extends StatelessWidget {
  const FloatingFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.semanticLabel,
  });

  final VoidCallback onPressed;
  final IconData icon;

  /// Defaults to the generic "add" label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: onPressed,
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      semanticLabel: semanticLabel ?? 'ui.add'.tr(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.primary,
          shape: BoxShape.circle,
          boxShadow: AppShadow.fab,
        ),
        child: SizedBox.square(
          dimension: AppSize.fab,
          child: Icon(icon, size: AppSize.fabIcon, color: p.onPrimary),
        ),
      ),
    );
  }
}
