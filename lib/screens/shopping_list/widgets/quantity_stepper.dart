import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/pressable.dart';

/// Minus, typeable number and plus. Both buttons have a 44 px tap area; the
/// number field is [AppSize.quantityField] wide. Behavior is the same as the
/// old inline stepper: minus is disabled at 0, plus always increases.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.controller,
    required this.quantity,
    required this.onChanged,
    this.label,
  });

  final TextEditingController controller;
  final int quantity;
  final void Function(int newQuantity) onChanged;

  /// Spoken label of the number field (e.g. the item name).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          key: const Key('quantity-minus'),
          icon: Icons.remove,
          semanticLabel: 'order_wizard.decrease'.tr(),
          onTap: quantity > 0 ? () => onChanged(quantity - 1) : null,
        ),
        SizedBox(
          width: AppSize.quantityField,
          child: Semantics(
            label: label == null
                ? 'shopping_ui.quantity'.tr()
                : '$label: ${'shopping_ui.quantity'.tr()}',
            child: TextField(
              key: const Key('quantity-field'),
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppText.button.copyWith(color: p.text),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'shopping.amount_hint'.tr(),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpace.s12,
                  horizontal: AppSpace.s4,
                ),
              ),
            ),
          ),
        ),
        _StepButton(
          key: const Key('quantity-plus'),
          icon: Icons.add,
          semanticLabel: 'order_wizard.increase'.tr(),
          onTap: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
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
      onTap: onTap,
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
