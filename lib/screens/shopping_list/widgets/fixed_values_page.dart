import 'package:flutter/material.dart';

import '../../../models/material_item.dart';
import 'shopping_item_card.dart';

/// Page displaying fixed costs and materials.
class FixedValuesPage extends StatelessWidget {
  const FixedValuesPage({
    super.key,
    required this.items,
    required this.quantities,
    required this.controllers,
    required this.onQuantityChanged,
  });

  final List<MaterialItem> items;
  final Map<String, int> quantities;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, int quantity) onQuantityChanged;

  String _itemKey(MaterialItem item) => '${item.name}|${item.unit}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Sort items: unselected (qty=0) first, then selected
    final sortedItems = List<MaterialItem>.from(items);
    sortedItems.sort((a, b) {
      final qtyA = quantities[_itemKey(a)] ?? 0;
      final qtyB = quantities[_itemKey(b)] ?? 0;
      final isSelectedA = qtyA > 0 ? 1 : 0;
      final isSelectedB = qtyB > 0 ? 1 : 0;
      return isSelectedA.compareTo(isSelectedB);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildHeader(context, colorScheme),
          const SizedBox(height: 32),
          ...sortedItems.map((item) {
            final key = _itemKey(item);
            final qty = quantities[key] ?? 0;
            return ShoppingItemCard(
              item: item,
              controller: controllers[key]!,
              quantity: qty,
              isSelected: qty > 0,
              cocktails: const [],
              onQuantityChanged: (newQty) => onQuantityChanged(key, newQty),
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.attach_money,
            color: Colors.purple,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fixkosten & Material',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${items.length} Positionen',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
