import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../utils/currency.dart';
import '../../shopping_list/stock_logic.dart';
import '../order_shopping_list_page.dart';
import 'order_detail_controller.dart';
import 'shopping_actions.dart';

/// "Einkaufsliste" box in the header: PDF, PDF without prices, edit
/// (only when the order has a list) and regenerate with Claude.
class ShoppingListSection extends StatelessWidget {
  const ShoppingListSection({
    super.key,
    required this.controller,
    required this.vertical,
  });

  final OrderDetailController controller;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final hasList = !controller.order.needsShoppingList;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 14,
                color: Colors.white54,
              ),
              SizedBox(width: 6),
              Text(
                'Einkaufsliste',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (vertical) ...[
            if (hasList)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.isDownloadingPdf
                          ? null
                          : controller.downloadShoppingList,
                      icon: controller.isDownloadingPdf
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: 15),
                      label: const Text('PDF', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.isDownloadingPdf
                          ? null
                          : controller.downloadShoppingListWithoutPrices,
                      icon: controller.isDownloadingPdf
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined, size: 15),
                      label: const Text(
                        'Ohne Preise',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.isEditingList
                          ? null
                          : controller.editShoppingList,
                      icon: controller.isEditingList
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit, size: 15),
                      label: const Text(
                        'Bearbeiten',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            if (hasList) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.isGeneratingList
                    ? null
                    : controller.generateWithGemini,
                icon: controller.isGeneratingList
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 16,
                      ),
                label: Text(
                  'orders.regenerate_with_claude'.tr(),
                  style: const TextStyle(color: Colors.white),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasList) ...[
                  OutlinedButton.icon(
                    onPressed: controller.isDownloadingPdf
                        ? null
                        : controller.downloadShoppingList,
                    icon: controller.isDownloadingPdf
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download, size: 15),
                    label: const Text('PDF', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed: controller.isDownloadingPdf
                        ? null
                        : controller.downloadShoppingListWithoutPrices,
                    icon: controller.isDownloadingPdf
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined, size: 15),
                    label: const Text(
                      'Ohne Preise',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed: controller.isEditingList
                        ? null
                        : controller.editShoppingList,
                    icon: controller.isEditingList
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit, size: 15),
                    label: const Text(
                      'Bearbeiten',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                FilledButton.icon(
                  onPressed: controller.isGeneratingList
                      ? null
                      : controller.generateWithGemini,
                  icon: controller.isGeneratingList
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 16,
                        ),
                  label: Text(
                    'orders.regenerate_with_claude'.tr(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ],
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
    final order = controller.order;
    final items = controller.itemsOverride ?? order.items;
    final total = customerTotal(items);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.shopping_cart_outlined),
        title: Text('orders.shopping_list_title'.tr()),
        subtitle: Text(
          '${order.items.length} ${'orders.articles'.tr()} • ${currency.format(total)}',
        ),
        trailing: const Icon(Icons.chevron_right),
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
      ),
    );
  }
}
