import '../../models/cocktail_data.dart';
import '../../models/material_item.dart';
import '../../models/recipe.dart';
import '../../services/pdf_generator.dart';

/// Result of separating shopping items by category.
typedef SeparatedItems = ({
  Map<String, List<MaterialItem>> ingredientsByCocktail,
  List<MaterialItem> fixedValues,
  Map<String, List<String>> ingredientToCocktails,
});

/// Business logic for the shopping list screen.
class ShoppingListLogic {
  /// Builds separated items from cocktail data and selected recipes.
  static SeparatedItems buildSeparatedItems(
    CocktailData data,
    List<Recipe> selectedRecipes,
    int venueDistanceKm,
  ) {
    // Map ingredients to their cocktails
    final ingredientToCocktails = <String, List<String>>{};
    for (final recipe in selectedRecipes) {
      for (final ingredient in recipe.ingredients) {
        ingredientToCocktails.putIfAbsent(ingredient, () => []).add(recipe.name);
      }
    }

    // Filter materials to only required ingredients
    final requiredIngredients = ingredientToCocktails.keys.toSet();
    final materialByName = <String, MaterialItem>{};
    for (final item in data.materials) {
      if (requiredIngredients.contains(item.name)) {
        materialByName[item.name] = item;
      }
    }

    // Group ingredients by cocktail
    final usedIngredients = <String>{};
    final ingredientsByCocktail = <String, List<MaterialItem>>{};

    for (final recipe in selectedRecipes) {
      final cocktailItems = <MaterialItem>[];
      for (final ingredientName in recipe.ingredients) {
        if (!usedIngredients.contains(ingredientName) &&
            materialByName.containsKey(ingredientName)) {
          cocktailItems.add(materialByName[ingredientName]!);
          usedIngredients.add(ingredientName);
        }
      }
      if (cocktailItems.isNotEmpty) {
        cocktailItems.sort((a, b) => a.name.compareTo(b.name));
        ingredientsByCocktail[recipe.name] = cocktailItems;
      }
    }

    // Filter fixed values based on distance
    final isLongDistance = venueDistanceKm > 200;
    final fixedValues = data.fixedValues.where((item) {
      if (!item.active) return false;
      if (item.note == 'BlackLodge') {
        // Travel variants
        if (item.name.contains('(5h+2h')) return isLongDistance;
        if (item.name.contains('(5h)')) return !isLongDistance;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aOrder = a.sortOrder;
        final bOrder = b.sortOrder;
        if (aOrder != null && bOrder != null) return aOrder.compareTo(bOrder);
        if (aOrder != null) return -1;
        if (bOrder != null) return 1;
        return a.name.compareTo(b.name);
      });

    return (
      ingredientsByCocktail: ingredientsByCocktail,
      fixedValues: fixedValues,
      ingredientToCocktails: ingredientToCocktails,
    );
  }

  /// Generates a unique key for a material item.
  static String itemKey(MaterialItem item) => '${item.name}|${item.unit}';

  /// Calculates total price from selected items.
  static double calculateTotal(
    List<MaterialItem> items,
    Map<String, int> quantities,
    Set<String> selectedItems,
  ) {
    double total = 0;
    for (final item in items) {
      final key = itemKey(item);
      final qty = quantities[key] ?? 0;
      if (qty > 0 && selectedItems.contains(key)) {
        total += item.price * qty;
      }
    }
    return total;
  }

  /// Gets selected order items for export.
  static List<OrderItem> getSelectedOrderItems(
    List<MaterialItem> allItems,
    Map<String, int> quantities,
    Set<String> selectedItems,
  ) {
    final result = <OrderItem>[];
    for (final item in allItems) {
      final key = itemKey(item);
      final qty = quantities[key] ?? 0;
      if (qty > 0 && selectedItems.contains(key)) {
        result.add(OrderItem(item: item, quantity: qty));
      }
    }
    return result;
  }
}
