import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/cocktail_repository.dart';
import '../../data/order_repository.dart';
import '../../data/settings_repository.dart';
import '../../models/cocktail_data.dart';
import '../../models/material_item.dart';
import '../../models/recipe.dart';
import '../../services/pdf_generator.dart';
import '../../state/app_state.dart';
import '../../utils/currency.dart';
import 'shopping_list_dialogs.dart';
import 'shopping_list_logic.dart';
import 'widgets/widgets.dart';

/// Shopping list screen with wizard-style navigation.
class ShoppingListScreen extends StatefulWidget {
  final dynamic orderSetup;
  const ShoppingListScreen({super.key, this.loadData, this.orderSetup});

  final Future<CocktailData> Function()? loadData;

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late Future<CocktailData> _dataFuture;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, int> _quantities = {};
  final Set<String> _selectedItems = {};
  bool _suggestionsApplied = false;
  bool _defaultsApplied = false;

  late PageController _pageController;
  int _currentPage = 0;
  int _longDistanceThresholdKm = 400;
  
  // Master data from initial setup dialog or dashboard
  String _orderName = '';
  int _personCount = 0;
  String _drinkerType = 'normal';
  Currency _currency = defaultCurrency;
  int _venueDistanceKm = 0;

  @override
  void initState() {
    super.initState();
    _dataFuture = (widget.loadData ?? cocktailRepository.load)();
    _pageController = PageController();
    _loadSettings();
    if (widget.orderSetup != null) {
      final setup = widget.orderSetup as dynamic;
      setState(() {
        _orderName = setup.orderName ?? '';
        _personCount = setup.personCount ?? 0;
        _drinkerType = setup.drinkerType ?? 'normal';
        _currency = Currency.fromCode(setup.currency ?? 'CHF');
        _venueDistanceKm = setup.distanceKm ?? 0;
        // Pre-fill Fahrtkosten with the entered distance
        const fahrtkosten = 'Fahrtkosten|KM';
        _quantities[fahrtkosten] = setup.distanceKm ?? 0;
        _selectedItems.add(fahrtkosten);
        _controllers[fahrtkosten]?.text = (setup.distanceKm ?? '').toString();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initSetup());
    }
  }

  Future<void> _loadSettings() async {
    final settings = await settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _longDistanceThresholdKm = settings.longDistanceThresholdKm;
    });
  }

  Future<void> _initSetup() async {
    // Get prefilled values from linked order (if coming from pending orders)
    final prefilledName = appState.linkedOrderName;
    // Could also get personCount from linked order if needed
    
    final result = await showInitialSetupDialog(
      context,
      prefilledName: prefilledName,
    );
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _orderName = result.name;
      _personCount = result.personCount;
      _drinkerType = result.drinkerType;
      _currency = result.currency;
      _venueDistanceKm = result.distanceKm;
      // Pre-fill Fahrtkosten with the entered distance
      // Key format is 'name|unit' as per ShoppingListLogic.itemKey
      const fahrtkosten = 'Fahrtkosten|KM';
      _quantities[fahrtkosten] = result.distanceKm;
      _selectedItems.add(fahrtkosten);
      // Update controller if already created
      _controllers[fahrtkosten]?.text = result.distanceKm.toString();
    });
    
    // Note: Material suggestions are applied in _buildContent when data is available
  }
  
  /// Apply material suggestions from Gemini AI to the shopping list.
  /// Must be called after CocktailData is available.
  void _applyMaterialSuggestions(CocktailData data) {
    if (_suggestionsApplied) return;
    if (!appState.hasMaterialSuggestions) return;
    
    _suggestionsApplied = true;
    final suggestions = appState.materialSuggestions!;
    
    // Build a map of ingredient name -> list of cocktails that use it
    final ingredientToCocktails = <String, List<String>>{};
    for (final recipe in appState.selectedRecipes) {
      for (final ingredient in recipe.ingredients) {
        ingredientToCocktails.putIfAbsent(ingredient, () => []).add(recipe.name);
      }
    }
    
    // Build a map of material name+unit -> MaterialItem
    final materialByKey = <String, MaterialItem>{};
    for (final item in data.materials) {
      materialByKey['${item.name}|${item.unit}'] = item;
    }
    for (final item in data.fixedValues) {
      materialByKey['${item.name}|${item.unit}'] = item;
    }
    
    int appliedCount = 0;
    
    for (final suggestion in suggestions) {
      final baseKey = suggestion.key; // name|unit
      final item = materialByKey[baseKey];
      
      if (item == null) {
        // Item not found, skip
        continue;
      }
      
      // Check if this is a fixed value (no cocktail association)
      final cocktails = ingredientToCocktails[suggestion.name];
      
      if (cocktails == null || cocktails.isEmpty) {
        // This is a fixed value or ingredient not used by any cocktail
        // Apply with base key
        _quantities[baseKey] = suggestion.quantity;
        _selectedItems.add(baseKey);
        if (_controllers.containsKey(baseKey)) {
          _controllers[baseKey]?.text = suggestion.quantity.toString();
        }
        appliedCount++;
      } else {
        // Distribute quantity across cocktails that use this ingredient
        // For now, assign full quantity to the first cocktail
        final cocktailName = cocktails.first;
        final cocktailKey = ShoppingListLogic.cocktailItemKey(item, cocktailName);
        
        _quantities[cocktailKey] = suggestion.quantity;
        _selectedItems.add(cocktailKey);
        if (_controllers.containsKey(cocktailKey)) {
          _controllers[cocktailKey]?.text = suggestion.quantity.toString();
        }
        appliedCount++;
      }
    }
    
    // Show a snackbar that suggestions were applied
    if (mounted && appliedCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('shopping.gemini_suggestions_applied'.tr(
              namedArgs: {'count': appliedCount.toString()},
            )),
            backgroundColor: Colors.deepPurple,
            action: SnackBarAction(
              label: 'common.undo'.tr(),
              textColor: Colors.white,
              onPressed: () {
                // Clear all quantities and rebuild
                setState(() {
                  _quantities.clear();
                  _selectedItems.clear();
                  for (final controller in _controllers.values) {
                    controller.text = '';
                  }
                });
              },
            ),
          ),
        );
      });
    }
    
    // Clear suggestions so they don't get applied again
    appState.clearMaterialSuggestions();
  }

  /// Apply default quantities for commonly used fixed items.
  /// Called once when the shopping list is first built.
  void _applyDefaultFixedValues(CocktailData data) {
    if (_defaultsApplied) return;
    _defaultsApplied = true;

    // Default fixed items with their quantities
    // Hartplastikbecher = 15, all others = 1
    const defaultFixedItems = <String, int>{
      'Theken|Stk': 1,
      'Reinvstement|Stk': 1,
      'Einkaufsentschädigung|Stk': 1,
      'Hartplastikbecher 0.3L|30er Packung': 15,
      'Strohhalme|500er Packung': 1,
      'Schwarze Handschuhe|100er Packung': 1,
      'Servietten|250er Packung': 1,
      'Küchenpapier|4er Packung': 1,
      'BL Box|Stk': 1,
      'Smoothie Maker|Stk': 1,
    };

    // Build a set of available fixed value keys
    final availableFixedKeys = <String>{};
    for (final item in data.fixedValues) {
      availableFixedKeys.add('${item.name}|${item.unit}');
    }

    // Apply defaults only for items that exist in the data
    for (final entry in defaultFixedItems.entries) {
      final key = entry.key;
      final quantity = entry.value;

      if (!availableFixedKeys.contains(key)) continue;
      // Don't override if already set (e.g., by Gemini suggestions)
      if (_quantities.containsKey(key) && _quantities[key]! > 0) continue;

      _quantities[key] = quantity;
      _selectedItems.add(key);
      if (_controllers.containsKey(key)) {
        _controllers[key]?.text = quantity.toString();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _ensureController(String key) {
    return _controllers.putIfAbsent(key, () {
      final controller = TextEditingController(
        text: _quantities[key]?.toString() ?? '',
      );
      controller.addListener(() => _onQuantityTextChanged(key, controller));
      return controller;
    });
  }

  void _onQuantityTextChanged(String key, TextEditingController controller) {
    final value = int.tryParse(controller.text) ?? 0;
    setState(() {
      _quantities[key] = value;
      if (value > 0) {
        _selectedItems.add(key);
      } else {
        _selectedItems.remove(key);
      }
    });
  }

  void _onQuantityChanged(String key, int newQuantity) {
    setState(() {
      _quantities[key] = newQuantity;
      _controllers[key]?.text = newQuantity > 0 ? newQuantity.toString() : '';
      if (newQuantity > 0) {
        _selectedItems.add(key);
      } else {
        _selectedItems.remove(key);
      }
    });
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _export(
    List<MaterialItem> allItems,
    double total,
    Map<String, int> aggregatedQuantities,
    Set<String> aggregatedSelected,
  ) async {
    final selectedOrderItems = ShoppingListLogic.getSelectedOrderItems(
      allItems,
      aggregatedQuantities,
      aggregatedSelected,
    );

    if (selectedOrderItems.isEmpty) {
      _showError('shopping.no_selection'.tr());
      return;
    }

    // Use master data from initial setup dialog (no need for second dialog)
    final result = (
      name: _orderName,
      personCount: _personCount,
      drinkerType: _drinkerType,
      currency: _currency,
    );

    await _saveAndGeneratePdf(selectedOrderItems, total, result);
  }

  Future<void> _saveAndGeneratePdf(
    List<OrderItem> selectedOrderItems,
    double total,
    ({String name, int personCount, String drinkerType, Currency currency}) result,
  ) async {
    final orderDate = DateTime.now();
    final cocktailNames = appState.selectedRecipes
        .where((r) => !r.isShot)
        .map((r) => r.name)
        .toList();
    final shotNames = appState.selectedRecipes
        .where((r) => r.isShot)
        .map((r) => r.name)
        .toList();

    double thekeCost = 0;
    for (final oi in selectedOrderItems) {
      if (oi.item.name.toLowerCase().contains('theke')) {
        thekeCost = oi.total;
        break;
      }
    }

    final itemsData = selectedOrderItems
        .map((oi) => {
              'name': oi.item.name,
              'unit': oi.item.unit,
              'price': oi.item.price,
              'currency': oi.item.currency,
              'note': oi.item.note,
              'quantity': oi.quantity,
              'total': oi.total,
            })
        .toList();

    // Check if linking to existing order (from form submission)
    final linkedOrderId = appState.linkedOrderId;
    if (linkedOrderId != null) {
      // Update existing order with shopping list data
      await orderRepository.updateOrderShoppingList(
        orderId: linkedOrderId,
        items: itemsData,
        total: total,
        currency: result.currency.code,
        personCount: result.personCount,
        drinkerType: result.drinkerType,
        cocktails: cocktailNames,
        shots: shotNames,
        distanceKm: _venueDistanceKm,
        thekeCost: thekeCost,
      );
      // Clear linked order after saving
      appState.clearLinkedOrder();
    } else {
      // Create new order
      await orderRepository.saveOrder(
        name: result.name,
        date: orderDate,
        items: itemsData,
        total: total,
        currency: result.currency.code,
        personCount: result.personCount,
        drinkerType: result.drinkerType,
        cocktails: cocktailNames,
        shots: shotNames,
        distanceKm: _venueDistanceKm,
        thekeCost: thekeCost,
      );
    }

    await PdfGenerator.generateAndDownload(
      orderName: result.name,
      orderDate: orderDate,
      items: selectedOrderItems,
      grandTotal: total,
      currency: result.currency.code,
      personCount: result.personCount,
      drinkerType: result.drinkerType,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('orders.pdf_created'.tr())),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<CocktailData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: const Center(child: CircularProgressIndicator.adaptive()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: AppBar(title: Text('shopping.title'.tr())),
            body: Center(child: Text('shopping.load_error'.tr())),
          );
        }

        return _buildContent(snapshot.data!, colorScheme);
      },
    );
  }

  Widget _buildContent(CocktailData data, ColorScheme colorScheme) {
    // Apply Gemini material suggestions if available (once)
    _applyMaterialSuggestions(data);
    // Apply default fixed value quantities (once)
    _applyDefaultFixedValues(data);
    
    final separated = ShoppingListLogic.buildSeparatedItems(
      data,
      appState.selectedRecipes,
      _venueDistanceKm,
      longDistanceThresholdKm: _longDistanceThresholdKm,
    );
    final allIngredients =
        separated.ingredientsByCocktail.values.expand((i) => i).toList();
    final cocktailNames = separated.ingredientsByCocktail.keys.toList();

    // Aggregate quantities from cocktail-specific keys to base keys
    final aggregatedQuantities = ShoppingListLogic.aggregateQuantities(
      _quantities,
      allIngredients,
      cocktailNames,
    );

    // Merge fixed values quantities (they use base keys)
    final mergedQuantities = Map<String, int>.from(aggregatedQuantities);
    for (final item in separated.fixedValues) {
      final key = ShoppingListLogic.itemKey(item);
      if (_quantities.containsKey(key)) {
        mergedQuantities[key] = _quantities[key]!;
      }
    }

    // Build selected items set from aggregated keys
    final aggregatedSelected = <String>{};
    for (final entry in mergedQuantities.entries) {
      if (entry.value > 0) {
        aggregatedSelected.add(entry.key);
      }
    }

    final allItems = [...allIngredients, ...separated.fixedValues];
    final total = ShoppingListLogic.calculateTotal(
      allItems,
      mergedQuantities,
      aggregatedSelected,
    );

    if (allItems.isEmpty) return const ShoppingEmptyState();

    // Ensure controllers exist for cocktail-specific keys
    for (final cocktailName in cocktailNames) {
      for (final item in separated.ingredientsByCocktail[cocktailName]!) {
        _ensureController(ShoppingListLogic.cocktailItemKey(item, cocktailName));
      }
    }
    // Ensure controllers exist for fixed values (base keys)
    for (final item in separated.fixedValues) {
      _ensureController(ShoppingListLogic.itemKey(item));
    }

    final totalPages =
        cocktailNames.length + (separated.fixedValues.isNotEmpty ? 1 : 0) + 1;
    final selectedItems = ShoppingListLogic.getSelectedOrderItems(
      allItems,
      mergedQuantities,
      aggregatedSelected,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            ShoppingHeader(currentPage: _currentPage, totalPages: totalPages),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemCount: totalPages,
                itemBuilder: (context, index) => _buildPage(
                  index,
                  cocktailNames,
                  separated,
                  allItems,
                  total,
                  selectedItems,
                  data,
                ),
              ),
            ),
            ShoppingBottomNav(
              currentPage: _currentPage,
              totalPages: totalPages,
              hasSelectedItems: selectedItems.isNotEmpty,
              onBack: () => _goToPage(_currentPage - 1),
              onNext: () => _goToPage(_currentPage + 1),
              onExport: () => _export(
                allItems,
                total,
                mergedQuantities,
                aggregatedSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onIngredientsChanged(String cocktailName, List<String> newIngredients) {
    // Find and update the recipe in appState
    final recipeIndex = appState.selectedRecipes
        .indexWhere((r) => r.name == cocktailName);
    if (recipeIndex != -1) {
      final oldRecipe = appState.selectedRecipes[recipeIndex];
      final updatedRecipe = Recipe(
        id: oldRecipe.id,
        name: oldRecipe.name,
        ingredients: newIngredients,
        type: oldRecipe.type,
      );
      appState.selectedRecipes[recipeIndex] = updatedRecipe;
      // Trigger rebuild
      setState(() {});
    }
  }

  Widget _buildPage(
    int index,
    List<String> cocktailNames,
    SeparatedItems separated,
    List<MaterialItem> allItems,
    double total,
    List<OrderItem> selectedItems,
    CocktailData data,
  ) {
    if (index < cocktailNames.length) {
      final cocktailName = cocktailNames[index];
      return CocktailPage(
        cocktailName: cocktailName,
        items: separated.ingredientsByCocktail[cocktailName]!,
        ingredientToCocktails: separated.ingredientToCocktails,
        quantities: _quantities,
        controllers: _controllers,
        onQuantityChanged: _onQuantityChanged,
        allCocktailNames: cocktailNames,
        availableMaterials: data.materials,
        onIngredientsChanged: _onIngredientsChanged,
      );
    } else if (index == cocktailNames.length &&
        separated.fixedValues.isNotEmpty) {
      return FixedValuesPage(
        items: separated.fixedValues,
        quantities: _quantities,
        controllers: _controllers,
        onQuantityChanged: _onQuantityChanged,
      );
    } else {
      return SummaryPage(selectedItems: selectedItems, total: total);
    }
  }
}
