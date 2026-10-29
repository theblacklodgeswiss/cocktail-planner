import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/material_item.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/pressable.dart';
import '../shopping_list_logic.dart';
import 'recipe_ingredient_edit_dialog.dart';
import 'shopping_item_card.dart';

/// Content of the step for one cocktail (the title is the step's title).
class CocktailPage extends StatelessWidget {
  const CocktailPage({
    super.key,
    required this.cocktailName,
    required this.items,
    required this.ingredientToCocktails,
    required this.quantities,
    required this.controllers,
    required this.onQuantityChanged,
    required this.allCocktailNames,
    this.availableMaterials = const [],
    this.onIngredientsChanged,
  });

  final String cocktailName;
  final List<MaterialItem> items;
  final Map<String, List<String>> ingredientToCocktails;
  final Map<String, int> quantities;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, int quantity) onQuantityChanged;
  final List<String> allCocktailNames;
  final List<MaterialItem> availableMaterials;
  final void Function(String cocktailName, List<String> newIngredients)?
  onIngredientsChanged;

  String _cocktailItemKey(MaterialItem item) =>
      ShoppingListLogic.cocktailItemKey(item, cocktailName);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'shopping_ui.ingredients_count'.tr(args: ['${items.length}']),
                style: AppText.body.copyWith(color: p.textSecondary),
              ),
            ),
            if (onIngredientsChanged != null)
              Pressable(
                minSize: AppSize.minTap,
                radius: AppRadius.pill,
                semanticLabel: 'shopping_ui.edit_ingredients'.tr(),
                onTap: () => _showEditSheet(context),
                child: SizedBox.square(
                  dimension: AppSize.minTap,
                  child: Icon(
                    Icons.edit_outlined,
                    size: AppSize.rowIcon,
                    color: p.text,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s8),
        for (final item in items) _card(item),
      ],
    );
  }

  Widget _card(MaterialItem item) {
    final key = _cocktailItemKey(item);
    final qty = quantities[key] ?? 0;
    final totalSelected = ShoppingListLogic.getTotalQuantity(
      item,
      quantities,
      allCocktailNames,
    );
    return ShoppingItemCard(
      item: item,
      controller: controllers[key]!,
      quantity: qty,
      isSelected: qty > 0,
      cocktails: ingredientToCocktails[item.name] ?? [],
      totalSelected: totalSelected,
      onQuantityChanged: (newQty) => onQuantityChanged(key, newQty),
    );
  }

  Future<void> _showEditSheet(BuildContext context) async {
    final currentIngredients = items.map((item) => item.name).toList();
    final result = await RecipeIngredientEditDialog.show(
      context: context,
      recipeName: cocktailName,
      currentIngredients: currentIngredients,
      availableMaterials: availableMaterials,
    );

    if (result != null && onIngredientsChanged != null) {
      onIngredientsChanged!(cocktailName, result);
    }
  }
}
