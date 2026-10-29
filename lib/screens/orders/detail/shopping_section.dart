import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../utils/currency.dart';
import '../../shopping_list/stock_logic.dart';
import '../order_shopping_list_page.dart';
import 'order_detail_controller.dart';
import 'shopping_actions.dart';

/// "Einkaufsliste" card: PDF, PDF without prices, edit (only when the order
/// has a list) and regenerate with Claude.
class ShoppingListSection extends StatelessWidget {
  const ShoppingListSection({super.key, required this.controller});

  final OrderDetailController controller;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = controller;
    final hasList = !c.order.needsShoppingList;
    return FloatingCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: AppSize.metaIcon,
                color: p.textSecondary,
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  'orders.shopping_list_title'.tr(),
                  style: AppText.section.copyWith(color: p.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              if (hasList) ...[
                SecondaryButton(
                  label: 'common.pdf'.tr(),
                  loading: c.isDownloadingPdf,
                  onPressed: c.isDownloadingPdf ? null : c.downloadShoppingList,
                ),
                SecondaryButton(
                  label: 'order_detail.without_prices'.tr(),
                  loading: c.isDownloadingPdf,
                  onPressed: c.isDownloadingPdf
                      ? null
                      : c.downloadShoppingListWithoutPrices,
                ),
                SecondaryButton(
                  label: 'common.edit'.tr(),
                  loading: c.isEditingList,
                  onPressed: c.isEditingList ? null : c.editShoppingList,
                ),
              ],
              SecondaryButton(
                label: 'orders.regenerate_with_claude'.tr(),
                loading: c.isGeneratingList,
                onPressed: c.isGeneratingList ? null : c.generateWithGemini,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tile opening the order's shopping list (shown when the order has items).
/// Shows the items as last saved on the shopping-list page.
class ShoppingListTile extends StatelessWidget {
  const ShoppingListTile({
    super.key,
    required this.controller,
    required this.currency,
  });

  final OrderDetailController controller;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final order = controller.order;
    final items = controller.itemsOverride ?? order.items;
    final total = customerTotal(items);
    return FloatingCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      onTap: () async {
        final edit = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => OrderShoppingListPage(
              order: order,
              stockApplied: controller.stockApplied,
              items: items,
              onItemsChanged: (changed) => controller.itemsOverride = changed,
            ),
          ),
        );
        if (edit == true && controller.mounted) controller.editShoppingList();
      },
      child: Row(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: AppSize.rowIcon,
            color: p.textSecondary,
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'orders.shopping_list_title'.tr(),
                  style: AppText.section.copyWith(color: p.text),
                ),
                Text(
                  '${order.items.length} ${'orders.articles'.tr()} • ${currency.format(total)}',
                  style: AppText.body.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: p.textSecondary),
        ],
      ),
    );
  }
}
