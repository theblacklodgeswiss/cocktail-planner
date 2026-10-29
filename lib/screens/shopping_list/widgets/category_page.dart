import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/material_item.dart';
import '../../../ui/tokens.dart';
import '../shopping_list_logic.dart';
import 'shopping_item_card.dart';

/// Content of a fixed-value category step (or the extra ingredients step).
class CategoryPage extends StatelessWidget {
  const CategoryPage({
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

  /// Title of a category step ('ingredients_extra' is the extra ingredients).
  static String titleFor(String category) => switch (category) {
    'supervisor' => 'shopping.category_supervisor'.tr(),
    'purchase' => 'shopping.category_purchase'.tr(),
    'bring' => 'shopping.category_bring'.tr(),
    'other' => 'shopping.category_other'.tr(),
    'ingredients_extra' => 'shopping.section_ingredients'.tr(),
    _ => category,
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'shopping_ui.positions_count'.tr(args: ['${items.length}']),
          style: AppText.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpace.s12),
        for (final item in items) _card(item),
      ],
    );
  }

  Widget _card(MaterialItem item) {
    final key = ShoppingListLogic.itemKey(item);
    final qty = quantities[key] ?? 0;
    return ShoppingItemCard(
      item: item,
      controller: controllers[key]!,
      quantity: qty,
      isSelected: qty > 0,
      cocktails: const [],
      onQuantityChanged: (newQty) => onQuantityChanged(key, newQty),
    );
  }
}
