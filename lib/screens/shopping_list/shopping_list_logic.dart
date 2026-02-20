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
  /// Each cocktail shows ALL its ingredients (no deduplication).
  /// [longDistanceThresholdKm] configures when travel pricing switches (default: 400).
  static SeparatedItems buildSeparatedItems(
    CocktailData data,
    List<Recipe> selectedRecipes,
    int venueDistanceKm, {
    int longDistanceThresholdKm = 400,
  }) {
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

    // Show ALL ingredients for each cocktail (no deduplication)
    final ingredientsByCocktail = <String, List<MaterialItem>>{};
    for (final recipe in selectedRecipes) {
      final cocktailItems = <MaterialItem>[];
      for (final ingredientName in recipe.ingredients) {
        if (materialByName.containsKey(ingredientName)) {
          cocktailItems.add(materialByName[ingredientName]!);
        }
      }
      if (cocktailItems.isNotEmpty) {
        cocktailItems.sort((a, b) => a.name.compareTo(b.name));
        ingredientsByCocktail[recipe.name] = cocktailItems;
      }
    }

    // Filter fixed values based on distance (using configurable threshold)
    final isLongDistance = venueDistanceKm > longDistanceThresholdKm;
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

  /// Generates a unique key for a material item (base key without cocktail).
  static String itemKey(MaterialItem item) => '${item.name}|${item.unit}';

  /// Generates a cocktail-specific key for tracking quantities per cocktail.
  static String cocktailItemKey(MaterialItem item, String cocktailName) =>
      '${item.name}|${item.unit}|$cocktailName';

  /// Gets the total quantity for an item across all cocktails.
  static int getTotalQuantity(
    MaterialItem item,
    Map<String, int> quantities,
    List<String> cocktailNames,
  ) {
    int total = 0;
    for (final cocktailName in cocktailNames) {
      final key = cocktailItemKey(item, cocktailName);
      total += quantities[key] ?? 0;
    }
    return total;
  }

  /// Aggregates quantities by item (summing across all cocktails).
  /// Returns a map of base keys to total quantities.
  static Map<String, int> aggregateQuantities(
    Map<String, int> quantities,
    List<MaterialItem> allIngredients,
    List<String> cocktailNames,
  ) {
    final aggregated = <String, int>{};
    final seen = <String>{};

    for (final item in allIngredients) {
      final baseKey = itemKey(item);
      if (seen.contains(baseKey)) continue;
      seen.add(baseKey);

      int total = 0;
      for (final cocktailName in cocktailNames) {
        final cocktailKey = cocktailItemKey(item, cocktailName);
        total += quantities[cocktailKey] ?? 0;
      }
      if (total > 0) {
        aggregated[baseKey] = total;
      }
    }
    return aggregated;
  }

  /// Calculates total price from selected items (using aggregated quantities).
  static double calculateTotal(
    List<MaterialItem> items,
    Map<String, int> quantities,
    Set<String> selectedItems,
  ) {
    double total = 0;
    final seen = <String>{};
    for (final item in items) {
      final key = itemKey(item);
      if (seen.contains(key)) continue;
      seen.add(key);
      final qty = quantities[key] ?? 0;
      if (qty > 0 && selectedItems.contains(key)) {
        total += item.price * qty;
      }
    }
    return total;
  }

  /// Gets selected order items for export (using aggregated quantities).
  static List<OrderItem> getSelectedOrderItems(
    List<MaterialItem> allItems,
    Map<String, int> quantities,
    Set<String> selectedItems,
  ) {
    final result = <OrderItem>[];
    final seen = <String>{};
    for (final item in allItems) {
      final key = itemKey(item);
      if (seen.contains(key)) continue;
      seen.add(key);
      final qty = quantities[key] ?? 0;
      if (qty > 0 && selectedItems.contains(key)) {
        result.add(OrderItem(item: item, quantity: qty));
      }
    }
    return result;
  }
}
