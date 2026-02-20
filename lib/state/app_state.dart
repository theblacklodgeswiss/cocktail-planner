import 'package:flutter/foundation.dart';

import '../models/recipe.dart';

class AppState extends ChangeNotifier {
  final List<Recipe> selectedRecipes = [];
  
  /// Order ID to link shopping list to (for form submissions).
  String? linkedOrderId;
  /// Pre-filled name for the order.
  String? linkedOrderName;

  void setSelectedRecipes(List<Recipe> recipes) {
    selectedRecipes
      ..clear()
      ..addAll(recipes);
    notifyListeners();
  }

  void removeRecipe(String recipeId) {
    selectedRecipes.removeWhere((recipe) => recipe.id == recipeId);
    notifyListeners();
  }

  bool isSelected(String recipeId) {
    return selectedRecipes.any((recipe) => recipe.id == recipeId);
  }

  /// Set linked order for shopping list creation.
  void setLinkedOrder(String orderId, String orderName) {
    linkedOrderId = orderId;
    linkedOrderName = orderName;
    debugPrint('AppState.setLinkedOrder: id=$orderId, name=$orderName');
    notifyListeners();
  }

  /// Clear linked order after shopping list is saved.
  void clearLinkedOrder() {
    linkedOrderId = null;
    linkedOrderName = null;
    notifyListeners();
  }
}

final AppState appState = AppState();
