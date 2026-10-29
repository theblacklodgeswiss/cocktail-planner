import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../utils/currency.dart';

/// Running total shown above the content of every step except the summary
/// (the summary has the hero card with the same number).
class ShoppingTotalLine extends StatelessWidget {
  const ShoppingTotalLine({
    super.key,
    required this.totalCost,
    required this.currency,
  });

  final double totalCost;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'shopping.total'.tr(),
              style: AppText.body.copyWith(color: p.textSecondary),
            ),
          ),
          Text(
            currency.format(totalCost),
            style: AppText.number.copyWith(color: p.text),
          ),
        ],
      ),
    );
  }
}
