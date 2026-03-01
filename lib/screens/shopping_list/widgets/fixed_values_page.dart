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

    // Group items by category
    final Map<String, List<MaterialItem>> groupedItems = {
      'supervisor': [],
      'purchase': [],
      'bring': [],
      'other': [],
    };

    for (final item in items) {
      final category = item.category ?? 'other';
      if (groupedItems.containsKey(category)) {
        groupedItems[category]!.add(item);
      } else {
        groupedItems['other']!.add(item);
      }
    }

    // Sort items within each category
    for (final category in groupedItems.keys) {
      groupedItems[category]!.sort((a, b) {
        final qtyA = quantities[_itemKey(a)] ?? 0;
        final qtyB = quantities[_itemKey(b)] ?? 0;
        final isSelectedA = qtyA > 0 ? 1 : 0;
        final isSelectedB = qtyB > 0 ? 1 : 0;
        return isSelectedA.compareTo(isSelectedB);
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildHeader(context, colorScheme),
          const SizedBox(height: 32),
          ...groupedItems.entries.where((e) => e.value.isNotEmpty).map((entry) {
            return _buildCategorySection(
              context,
              entry.key,
              entry.value,
              colorScheme,
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

  Widget _buildCategorySection(
    BuildContext context,
    String category,
    List<MaterialItem> categoryItems,
    ColorScheme colorScheme,
  ) {
    final categoryLabels = {
      'supervisor': 'Supervisor / Barkeeper',
      'purchase': 'Zu kaufen',
      'bring': 'Mitbringen',
      'other': 'Sonstige',
    };

    final categoryIcons = {
      'supervisor': Icons.person,
      'purchase': Icons.shopping_cart,
      'bring': Icons.local_shipping,
      'other': Icons.more_horiz,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 24),
          child: Row(
            children: [
              Icon(
                categoryIcons[category] ?? Icons.category,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                categoryLabels[category] ?? category,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
        ...categoryItems.map((item) {
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
      ],
    );
  }
}
