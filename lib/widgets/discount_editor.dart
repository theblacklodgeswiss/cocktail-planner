import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/offer.dart';
import '../utils/currency.dart';

/// Card for entering a discount (Rabatt) on offers and invoices, either as a
/// percentage of the positions subtotal or as a fixed amount.
///
/// The parent owns the controllers and the [isPercent] flag; [onChanged] is
/// called after every edit so it can recompute its totals.
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
  });

  final Currency currency;

  /// Sum of all positions the discount is applied to.
  final double subtotal;
  final bool isPercent;
  final TextEditingController valueController;
  final TextEditingController remarkController;
  final ValueChanged<bool> onTypeChanged;
  final VoidCallback onChanged;

  static double? parseValue(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = parseValue(text);
    if (parsed == null || parsed < 0) return 'offer.invalid_number'.tr();
    if (isPercent && parsed > 100) return 'discount.percent_too_high'.tr();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = parseValue(valueController.text) ?? 0;
    final amount = resolveDiscountAmount(
      subtotal: subtotal,
      percent: isPercent ? value : 0,
      amount: isPercent ? 0 : value,
    );

    final typeSelector = SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: true, label: Text('discount.type_percent'.tr())),
        ButtonSegment(
          value: false,
          label: Text('discount.type_amount'.tr(args: [currency.code])),
        ),
      ],
      selected: {isPercent},
      onSelectionChanged: (selection) => onTypeChanged(selection.first),
      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
    );

    final valueField = TextFormField(
      controller: valueController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: _validate,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: isPercent
            ? 'discount.value_percent'.tr()
            : 'discount.value_amount'.tr(args: [currency.code]),
        hintText: '0',
        suffixText: isPercent ? '%' : currency.code,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );

    final remarkField = TextFormField(
      controller: remarkController,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: 'discount.remark'.tr(),
        hintText: 'discount.remark_hint'.tr(),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.percent, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'discount.title'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            typeSelector,
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 500) {
                  return Column(
                    children: [
                      valueField,
                      const SizedBox(height: 12),
                      remarkField,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 180, child: valueField),
                    const SizedBox(width: 12),
                    Expanded(child: remarkField),
                  ],
                );
              },
            ),
            if (amount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'discount.resolved'.tr(
                  args: [
                    currency.format(amount),
                    currency.format(subtotal - amount),
                  ],
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
