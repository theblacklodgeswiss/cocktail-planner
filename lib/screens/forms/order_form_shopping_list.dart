import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/claude_service.dart';
import '../../state/app_state.dart';
import '../../widgets/gemini_material_review_dialog.dart';
import 'order_form_state.dart';

/// Staff-only: asks Claude for a material list for the selected cocktails,
/// lets the user review it and then opens the shopping list. [context] is
/// the order form screen's context.
Future<void> generateShoppingListWithClaude(
  BuildContext context,
  OrderFormState form,
) async {
  if (!claudeService.isConfigured) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('orders.claude_not_configured'.tr())),
    );
    return;
  }
  if (form.selectedRecipes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bitte zuerst Cocktails auswählen.')),
    );
    return;
  }

  final cocktailData = await form.dataFuture;
  if (cocktailData == null || !context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('orders.claude_generating'.tr()),
        ],
      ),
    ),
  );

  try {
    final materials = cocktailData.materials
        .where((m) => m.visible)
        .map(
          (m) => {
            'name': m.name,
            'unit': m.unit,
            'price': m.price,
            'currency': m.currency,
          },
        )
        .toList();

    final recipeIngredients = form.selectedRecipes
        .map((r) => {'cocktail': r.name, 'ingredients': r.ingredients})
        .toList();

    final suggestion = await claudeService.generateMaterialSuggestions(
      guestCount: form.personCount,
      guestRange: '',
      requestedCocktails: form.selectedRecipes.map((r) => r.name).toList(),
      eventType: form.drinkerType,
      drinkerType: form.drinkerType,
      availableMaterials: materials,
      recipeIngredients: recipeIngredients,
      cocktailPopularity: form.cocktailPopularity,
    );

    if (context.mounted) Navigator.pop(context);

    if (suggestion.hasError) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              suggestion.errorMessage ?? 'orders.claude_error'.tr(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => GeminiMaterialReviewDialog(
          suggestion: suggestion,
          personCount: form.personCount,
          cocktailNames: form.selectedRecipes.map((r) => r.name).toList(),
          onConfirm: (confirmedSuggestions, explanation) {
            // Sync recipes & popularity to global state
            appState.setSelectedRecipes(form.selectedRecipes);
            for (final entry in form.cocktailPopularity.entries) {
              appState.setCocktailPopularity(entry.key, entry.value);
            }
            appState.setMaterialSuggestions(confirmedSuggestions, explanation);

            // Build setup data and navigate to shopping list
            final setupData = form.buildSetupData();
            context.go('/shopping-list', extra: setupData);
          },
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('orders.claude_error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
