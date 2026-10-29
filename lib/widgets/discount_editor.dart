import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/offer.dart';
import '../screens/forms/steps/wizard_widgets.dart';
import '../screens/shared/document_sections/document_field.dart';
import '../ui/tokens.dart';
import '../utils/currency.dart';

/// Card for entering a discount (Rabatt) on offers and invoices, either as a
/// percentage of the positions subtotal or as a fixed amount.
///
/// The parent owns the controllers and the [isPercent] flag; [onChanged] is
/// called after every edit so it can recompute its totals. [hints] shows
/// the "invalid number" / "max 100 %" hint at the value (field 'discount').
class DiscountEditor extends StatelessWidget {
  const DiscountEditor({
    super.key,
    required this.currency,
    required this.subtotal,
    required this.isPercent,
    required this.valueController,
    required this.remarkController,
    required this.onTypeChanged,
    required this.onChanged,
    this.hints,
  });

  final Currency currency;

  /// Sum of all positions the discount is applied to.
  final double subtotal;
  final bool isPercent;
  final TextEditingController valueController;
  final TextEditingController remarkController;
  final ValueChanged<bool> onTypeChanged;
  final VoidCallback onChanged;
  final DocHints? hints;

  static double? parseValue(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  /// Translation key of the value's error, or null (empty is fine).
  static String? errorKeyOf(String? value, {required bool isPercent}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = parseValue(text);
    if (parsed == null || parsed < 0) return 'offer.invalid_number';
    if (isPercent && parsed > 100) return 'discount.percent_too_high';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final value = parseValue(valueController.text) ?? 0;
    final amount = resolveDiscountAmount(
      subtotal: subtotal,
      percent: isPercent ? value : 0,
      amount: isPercent ? 0 : value,
    );

    return WizardSection(
      caption: 'discount.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillGroup(
            children: [
              SelectPill(
                label: 'discount.type_percent'.tr(),
                selected: isPercent,
                onTap: () => onTypeChanged(true),
              ),
              SelectPill(
                label: 'discount.type_amount'.tr(args: [currency.code]),
                selected: !isPercent,
                onTap: () => onTypeChanged(false),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          DocTextField(
            controller: valueController,
            label: isPercent
                ? 'discount.value_percent'.tr()
                : 'discount.value_amount'.tr(args: [currency.code]),
            hintText: '0',
            suffixText: isPercent ? '%' : currency.code,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            hints: hints,
            field: 'discount',
          ),
          const SizedBox(height: AppSpace.s12),
          DocTextField(
            controller: remarkController,
            label: 'discount.remark'.tr(),
            hintText: 'discount.remark_hint'.tr(),
            textInputAction: TextInputAction.done,
          ),
          if (amount > 0) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              'discount.resolved'.tr(
                args: [
                  currency.format(amount),
                  currency.format(subtotal - amount),
                ],
              ),
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
