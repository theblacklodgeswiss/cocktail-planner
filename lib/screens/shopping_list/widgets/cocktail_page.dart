import 'package:flutter/material.dart';

import '../../../models/material_item.dart';
import 'shopping_item_card.dart';

/// Page displaying ingredients for a specific cocktail.
class CocktailPage extends StatelessWidget {
  const CocktailPage({
    super.key,
    required this.cocktailName,
    required this.items,
    required this.ingredientToCocktails,
    required this.quantities,
    required this.controllers,
    required this.onQuantityChanged,
  });

  final String cocktailName;
  final List<MaterialItem> items;
  final Map<String, List<String>> ingredientToCocktails;
  final Map<String, int> quantities;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, int quantity) onQuantityChanged;

  String _itemKey(MaterialItem item) => '${item.name}|${item.unit}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isShot = cocktailName.toLowerCase().contains('shot');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildHeader(context, colorScheme, isShot),
          const SizedBox(height: 32),
          ...items.map((item) {
            final key = _itemKey(item);
            final qty = quantities[key] ?? 0;
            return ShoppingItemCard(
              item: item,
              controller: controllers[key]!,
              quantity: qty,
              isSelected: qty > 0,
              cocktails: ingredientToCocktails[item.name] ?? [],
              onQuantityChanged: (newQty) => onQuantityChanged(key, newQty),
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, ColorScheme colorScheme, bool isShot) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isShot
                ? Colors.orange.withValues(alpha: 0.15)
                : Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isShot ? Icons.wine_bar : Icons.local_bar,
            color: isShot ? Colors.orange : Colors.green,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cocktailName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${items.length} Zutaten',
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
