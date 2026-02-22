import 'package:flutter/foundation.dart';

import '../models/recipe.dart';

/// Suggested material with quantity for shopping list.
class MaterialSuggestion {
  final String name;
  final String unit;
  final int quantity;
  final String reason;

  const MaterialSuggestion({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.reason,
  });

  /// Key for lookup (name|unit).
  String get key => '$name|$unit';
}

class AppState extends ChangeNotifier {
  final List<Recipe> selectedRecipes = [];
  
  /// Order ID to link shopping list to (for form submissions).
  String? linkedOrderId;
  /// Pre-filled name for the order.
  String? linkedOrderName;
  /// Requested cocktails from linked order (names).
  List<String>? linkedOrderRequestedCocktails;
  
  /// Gemini-suggested recipes with quantities (cocktailName -> quantity).
  @Deprecated('Use materialSuggestions instead')
  Map<String, int>? geminiSuggestions;
  
  /// Gemini-suggested materials for the shopping list.
  List<MaterialSuggestion>? materialSuggestions;
  
  /// Explanation from Gemini about the suggestions.
  String? materialSuggestionExplanation;

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
  void setLinkedOrder(String orderId, String orderName, {List<String>? requestedCocktails}) {
    linkedOrderId = orderId;
    linkedOrderName = orderName;
    linkedOrderRequestedCocktails = requestedCocktails;
    notifyListeners();
  }

  /// Clear linked order after shopping list is saved.
  void clearLinkedOrder() {
    linkedOrderId = null;
    linkedOrderName = null;
    linkedOrderRequestedCocktails = null;
    // ignore: deprecated_member_use_from_same_package
    geminiSuggestions = null;
    materialSuggestions = null;
    materialSuggestionExplanation = null;
    notifyListeners();
  }
  
  /// Set Gemini-suggested recipes with quantities.
  @Deprecated('Use setMaterialSuggestions instead')
  void setGeminiSuggestions(Map<String, int> suggestions) {
    geminiSuggestions = Map.from(suggestions);
    notifyListeners();
  }
  
  /// Clear Gemini suggestions.
  @Deprecated('Use clearMaterialSuggestions instead')
  void clearGeminiSuggestions() {
    geminiSuggestions = null;
    notifyListeners();
  }
  
  /// Set Gemini-suggested materials for shopping list.
  void setMaterialSuggestions(List<MaterialSuggestion> suggestions, String explanation) {
    materialSuggestions = List.from(suggestions);
    materialSuggestionExplanation = explanation;
    notifyListeners();
  }
  
  /// Clear material suggestions.
  void clearMaterialSuggestions() {
    materialSuggestions = null;
    materialSuggestionExplanation = null;
    notifyListeners();
  }
  
  /// Check if there are pending material suggestions.
  bool get hasMaterialSuggestions => materialSuggestions != null && materialSuggestions!.isNotEmpty;
}

final AppState appState = AppState();
