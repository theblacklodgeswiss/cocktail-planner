import 'package:flutter/foundation.dart';

import '../models/recipe.dart';

class AppState extends ChangeNotifier {
  final List<Recipe> selectedRecipes = [];

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
}

final AppState appState = AppState();
