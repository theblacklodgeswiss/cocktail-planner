import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../services/pdf_generator.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/hero_card.dart';
import '../../../ui/widgets/states.dart';
import '../../../utils/currency.dart';

/// Content of the summary step: selected items and the total.
class SummaryPage extends StatelessWidget {
  const SummaryPage({
    super.key,
    required this.selectedItems,
    required this.total,
  });

  final List<OrderItem> selectedItems;
  final double total;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          kicker: 'shopping_ui.total_label'.tr(),
          title: defaultCurrency.format(total),
          titleStyle: AppText.display,
          meta: 'shopping_ui.summary_count'.tr(
            args: ['${selectedItems.length}'],
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        if (selectedItems.isEmpty)
          EmptyState(
            icon: Icons.remove_shopping_cart_outlined,
            title: 'shopping_ui.none_selected'.tr(),
            body: 'shopping_ui.none_selected_hint'.tr(),
          )
        else ...[
          Text(
            'shopping_ui.selected_articles'.tr(),
            style: AppText.section.copyWith(color: p.text),
          ),
          const SizedBox(height: AppSpace.s12),
          for (final oi in selectedItems) _ItemRow(item: oi),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: FloatingCard(
        child: Row(
          children: [
            Text(
              '${item.quantity}x',
              style: AppText.button.copyWith(color: p.textSecondary),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(
                item.item.name,
                style: AppText.body.copyWith(color: p.text),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Text(
              Currency.fromCode(item.item.currency).format(item.total),
              style: AppText.button.copyWith(color: p.text),
            ),
          ],
        ),
      ),
    );
  }
}
