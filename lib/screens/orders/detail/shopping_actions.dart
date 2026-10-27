// `context` and `mounted` are the sheet State's (OrderDetailHost): every
// use after an await is guarded by that State's `mounted`, exactly as when
// these handlers lived in the State. The lint cannot see that through the
// host indirection.
// ignore_for_file: use_build_context_synchronously
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/cocktail_data.dart';
import '../../../models/recipe.dart';
import '../../../services/claude_service.dart';
import '../../../services/pdf_generator.dart';
import '../../../state/app_state.dart';
import '../../../widgets/cocktail_popularity_dialog.dart';
import '../../../widgets/gemini_material_review_dialog.dart';
import '../../../widgets/order_setup_dialog.dart';
import 'dialogs.dart';
import 'order_detail_controller.dart';

/// Shopping-list handlers of the order detail sheet: edit, PDF exports,
/// create (with the popularity dialog) and generate with Claude.
extension OrderDetailShoppingActions on OrderDetailController {
  /// Navigate to shopping list to edit the existing order
  Future<void> editShoppingList() async {
    if (isEditingList) return;
    update(() => isEditingList = true);
    final order = this.order;

    // Parse eventTime from string
    TimeOfDay? eventTime;
    if (order.eventTime.isNotEmpty) {
      try {
        final parts = order.eventTime.split(':');
        if (parts.length == 2) {
          eventTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (e) {
        debugPrint('Failed to parse event time: $e');
      }
    }

    // Convert SavedOrder to OrderSetupData
    final orderSetup = OrderSetupData(
      orderName: order.name,
      phoneNumber: order.phone.isNotEmpty ? order.phone : null,
      eventDate: order.date,
      eventTime: eventTime,
      address: order.location.isNotEmpty ? order.location : null,
      personCount: order.personCount,
      distanceKm: order.distanceKm > 0 ? order.distanceKm : null,
      currency: order.currency,
      drinkerType: order.drinkerType,
      serviceType: order.serviceType.isNotEmpty
          ? order.serviceType
          : 'cocktail_barservice',
    );

    // Load cocktail data to get recipe ingredients
    try {
      final cocktailData = await services.loadCocktailData();

      // Link this order so it gets updated instead of creating a new one
      appState.setLinkedOrder(
        order.id,
        order.name,
        requestedCocktails: order.requestedCocktails,
        savedItems: itemsOverride ?? order.items,
      );

      // Set selected recipes from the order's cocktails and shots with real ingredients
      final allRecipes = <Recipe>[];

      for (final cocktailName in order.cocktails) {
        // Try to find recipe in loaded data
        final recipe = cocktailData.recipes.firstWhere(
          (r) => r.name == cocktailName,
          orElse: () => Recipe(
            id: cocktailName.toLowerCase().replaceAll(' ', '_'),
            name: cocktailName,
            ingredients: [],
            type: 'cocktail',
          ),
        );
        allRecipes.add(recipe);
      }

      for (final shotName in order.shots) {
        // Try to find recipe in loaded data
        final recipe = cocktailData.recipes.firstWhere(
          (r) => r.name == shotName,
          orElse: () => Recipe(
            id: shotName.toLowerCase().replaceAll(' ', '_'),
            name: shotName,
            ingredients: [],
            type: 'shot',
          ),
        );
        allRecipes.add(recipe);
      }

      if (allRecipes.isNotEmpty) {
        appState.setSelectedRecipes(allRecipes);
      }

      // Navigate to shopping list
      if (mounted) {
        Navigator.pop(context);
        context.push('/shopping-list', extra: orderSetup);
      }
    } catch (e) {
      debugPrint('Failed to load cocktail data: $e');
      if (mounted) {
        update(() => isEditingList = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden der Daten: $e')),
        );
      }
    }
  }

  /// Download shopping list PDF directly without navigating to shopping list screen
  Future<void> downloadShoppingList() async {
    if (isDownloadingPdf) return;
    if (!order.hasShoppingList) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('orders.no_shopping_list'.tr())));
      return;
    }

    update(() => isDownloadingPdf = true);
    try {
      await PdfGenerator.generateFromSavedOrder(order, includePrices: true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('shopping.download_list'.tr())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Erstellen der PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) update(() => isDownloadingPdf = false);
    }
  }

  /// Download shopping list PDF without prices for employees
  Future<void> downloadShoppingListWithoutPrices() async {
    if (isDownloadingPdf) return;
    update(() => isDownloadingPdf = true);
    try {
      await PdfGenerator.generateFromSavedOrder(order, includePrices: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('shopping.download_list_no_prices'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Erstellen der PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) update(() => isDownloadingPdf = false);
    }
  }

  /// "Einkaufsliste erstellen" for form orders:
  /// 1. Load cocktail data and set up recipes in app state.
  /// 2. Show cocktail popularity dialog.
  /// 3. Link the order and navigate to the shopping list.
  Future<void> openShoppingList() async {
    if (isOpeningShoppingList) return;
    update(() => isOpeningShoppingList = true);
    final order = this.order;

    // Load recipes to populate the popularity dialog
    CocktailData cocktailData;
    try {
      cocktailData = await services.loadCocktailData();
    } catch (e) {
      if (mounted) {
        update(() => isOpeningShoppingList = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden der Daten: $e')),
        );
      }
      return;
    }

    // Build recipe list from structured cocktails + shots stored on the order
    final allRecipes = <Recipe>[];
    // For form orders, cocktails may only be in requestedCocktails
    final cocktailNames = order.cocktails.isNotEmpty
        ? [...order.cocktails, ...order.shots]
        : [...order.requestedCocktails, ...order.shots];
    for (final name in cocktailNames) {
      final recipe = cocktailData.recipes.firstWhere(
        (r) => r.name == name,
        orElse: () => Recipe(
          id: name.toLowerCase().replaceAll(' ', '_'),
          name: name,
          ingredients: [],
          type: order.shots.contains(name) ? 'shot' : 'cocktail',
        ),
      );
      allRecipes.add(recipe);
    }
    if (allRecipes.isNotEmpty) {
      appState.setSelectedRecipes(allRecipes);
    }

    if (!mounted) return;
    update(() => isOpeningShoppingList = false);

    // Show popularity dialog so user can set probabilities per cocktail
    if (allRecipes.isNotEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            CocktailPopularityDialog(cocktails: allRecipes, onConfirm: () {}),
      );
    }
    if (!mounted) return;

    // Link the order and navigate to shopping list
    appState.setLinkedOrder(
      order.id,
      order.name,
      requestedCocktails: order.requestedCocktails,
      savedItems: order.items,
    );
    Navigator.pop(context); // close bottom sheet
    context.push('/shopping-list');
  }

  /// Generate material suggestions for the shopping list with Claude.
  /// 1. Load cocktail data and set up recipes in app state.
  /// 2. Show cocktail popularity dialog.
  /// 3. Generate material suggestions.
  /// 4. Show review dialog, then navigate to shopping list.
  Future<void> generateWithGemini() async {
    if (isGeneratingList) return;
    if (!claudeService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('orders.claude_not_configured'.tr())),
      );
      return;
    }

    update(() => isGeneratingList = true);

    final order = this.order;
    var resetExistingShoppingList = false;

    if (order.hasShoppingList) {
      final confirmedReset = await showClaudeResetConfirmDialog(context);

      if (confirmedReset != true) {
        update(() => isGeneratingList = false);
        return;
      }
      resetExistingShoppingList = true;
    }

    // Parse eventTime
    TimeOfDay? eventTime;
    if (order.eventTime.isNotEmpty) {
      try {
        final parts = order.eventTime.split(':');
        if (parts.length == 2) {
          eventTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (_) {}
    }

    final orderSetup = OrderSetupData(
      orderName: order.name,
      phoneNumber: order.phone.isNotEmpty ? order.phone : null,
      eventDate: order.date,
      eventTime: eventTime,
      address: order.location.isNotEmpty ? order.location : null,
      personCount: order.personCount,
      distanceKm: order.distanceKm > 0 ? order.distanceKm : null,
      currency: order.currency,
      drinkerType: order.drinkerType,
      serviceType: order.serviceType.isNotEmpty
          ? order.serviceType
          : 'cocktail_barservice',
    );

    // Step 1: load cocktail data
    CocktailData cocktailData;
    try {
      cocktailData = await services.loadCocktailData();
    } catch (e) {
      if (mounted) {
        update(() => isGeneratingList = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden der Daten: $e')),
        );
      }
      return;
    }

    // Build recipe list
    final allRecipes = <Recipe>[];
    // For form orders, cocktails may only be in requestedCocktails
    final cocktailNames = order.cocktails.isNotEmpty
        ? [...order.cocktails, ...order.shots]
        : [...order.requestedCocktails, ...order.shots];
    for (final name in cocktailNames) {
      final recipe = cocktailData.recipes.firstWhere(
        (r) => r.name == name,
        orElse: () => Recipe(
          id: name.toLowerCase().replaceAll(' ', '_'),
          name: name,
          ingredients: [],
          type: order.shots.contains(name) ? 'shot' : 'cocktail',
        ),
      );
      allRecipes.add(recipe);
    }
    if (allRecipes.isNotEmpty) {
      appState.setSelectedRecipes(allRecipes);
    }

    if (mounted) update(() => isGeneratingList = false);

    // Step 2: cocktail popularity dialog
    if (!mounted) return;
    if (allRecipes.isNotEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            CocktailPopularityDialog(cocktails: allRecipes, onConfirm: () {}),
      );
    }
    if (!mounted) return;

    // Step 3: show loading + generate
    final secondsNotifier = ValueNotifier<int>(0);
    final timer = Stream.periodic(const Duration(seconds: 1), (i) => i + 1);
    final timerSub = timer.listen((s) => secondsNotifier.value = s);

    showClaudeGeneratingDialog(context, secondsNotifier);

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

      final recipeIngredients = allRecipes
          .map(
            (r) => {
              'cocktail': r.name,
              'ingredients': r.ingredients,
              if (r.ingredientAmounts.isNotEmpty)
                'amounts': r.ingredientAmounts,
            },
          )
          .toList();

      final suggestion = await claudeService.generateMaterialSuggestions(
        guestCount: order.personCount,
        guestRange: order.guestCountRange,
        requestedCocktails: allRecipes.map((r) => r.name).toList(),
        eventType: order.drinkerType,
        drinkerType: order.drinkerType,
        availableMaterials: materials,
        recipeIngredients: recipeIngredients,
        cocktailPopularity: appState.cocktailPopularity,
        excludeOrderId: order.id,
      );

      timerSub.cancel();
      secondsNotifier.dispose();
      if (mounted) Navigator.pop(context); // close loading

      if (suggestion.hasError) {
        if (mounted) {
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

      // Step 4: review dialog
      if (mounted) {
        appState.setLinkedOrder(
          order.id,
          order.name,
          requestedCocktails: order.requestedCocktails,
          savedItems: resetExistingShoppingList ? const [] : order.items,
        );
        showDialog(
          context: context,
          builder: (ctx) => GeminiMaterialReviewDialog(
            suggestion: suggestion,
            personCount: order.personCount,
            cocktailNames: allRecipes.map((r) => r.name).toList(),
            onConfirm: (confirmedSuggestions, explanation) {
              appState.setMaterialSuggestions(
                confirmedSuggestions,
                explanation,
              );
              // Dialog pops itself after this callback.
              // Defer sheet close + navigation until after dialog has fully closed.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pop(context); // close bottom sheet
                  context.push('/shopping-list', extra: orderSetup);
                }
              });
            },
          ),
        );
      }
    } catch (e) {
      timerSub.cancel();
      secondsNotifier.dispose();
      if (mounted) Navigator.pop(context); // close loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders.claude_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
