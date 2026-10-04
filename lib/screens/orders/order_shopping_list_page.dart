import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../utils/currency.dart';

/// Read-only overview of an order's shopping list. Pops with `true` when
/// the user taps "Bearbeiten", so the caller can start the existing
/// shopping-list editor.
class OrderShoppingListPage extends StatelessWidget {
  const OrderShoppingListPage({super.key, required this.order});

  final SavedOrder order;

  @override
  Widget build(BuildContext context) {
    final currency = Currency.fromCode(order.currency);
    final scheme = Theme.of(context).colorScheme;
    final items = order.items;
    final total = items.fold<double>(
      0,
      (sum, item) =>
          sum +
          ((item['price'] as num?)?.toDouble() ?? 0) *
              ((item['quantity'] as num?)?.toInt() ?? 1),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('orders.shopping_list_title'.tr()),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.edit),
            label: Text('orders.edit_shopping_list'.tr()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${items.length} ${'orders.articles'.tr()}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    '${(item['quantity'] as num?)?.toInt() ?? 1}x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(item['name'] as String? ?? ''),
                subtitle: Text(
                  '${item['unit'] as String? ?? ''} • '
                  '${currency.format((item['price'] as num?)?.toDouble() ?? 0)}'
                  '${(item['note'] as String? ?? '').isNotEmpty ? ' • ${item['note']}' : ''}',
                ),
                trailing: Text(
                  currency.format(
                    ((item['price'] as num?)?.toDouble() ?? 0) *
                        ((item['quantity'] as num?)?.toInt() ?? 1),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'orders.shopping_list_total'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                currency.format(total),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.edit),
            label: Text('orders.edit_shopping_list'.tr()),
          ),
        ],
      ),
    );
  }
}
