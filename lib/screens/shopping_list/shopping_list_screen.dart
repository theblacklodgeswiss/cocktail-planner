import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/cocktail_repository.dart';
import '../../data/order_repository.dart';
import '../../models/cocktail_data.dart';
import '../../models/material_item.dart';
import '../../services/pdf_generator.dart';
import '../../state/app_state.dart';
import 'shopping_list_dialogs.dart';
import 'shopping_list_logic.dart';
import 'widgets/widgets.dart';

/// Shopping list screen with wizard-style navigation.
class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key, this.loadData});

  final Future<CocktailData> Function()? loadData;

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late Future<CocktailData> _dataFuture;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, int> _quantities = {};
  final Set<String> _selectedItems = {};

  late PageController _pageController;
  int _currentPage = 0;
  int _venueDistanceKm = 0;

  @override
  void initState() {
    super.initState();
    _dataFuture = (widget.loadData ?? cocktailRepository.load)();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDistance());
  }

  Future<void> _initDistance() async {
    final result = await showDistanceDialog(context);
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _venueDistanceKm = result;
      // Pre-fill Fahrtkosten with the entered distance
      // Key format is 'name|unit' as per ShoppingListLogic.itemKey
      const fahrtkosten = 'Fahrtkosten|KM';
      _quantities[fahrtkosten] = result;
      _selectedItems.add(fahrtkosten);
      // Update controller if already created
      _controllers[fahrtkosten]?.text = result.toString();
    });
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

    final result = await showExportDialog(
      context,
      selectedItemCount: selectedOrderItems.length,
      total: total,
    );

    if (result == null || !mounted) return;
    await _saveAndGeneratePdf(selectedOrderItems, total, result);
  }

  Future<void> _saveAndGeneratePdf(
    List<OrderItem> selectedOrderItems,
    double total,
    ExportDialogResult result,
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

    await orderRepository.saveOrder(
      name: result.name,
      date: orderDate,
      items: selectedOrderItems
          .map((oi) => {
                'name': oi.item.name,
                'unit': oi.item.unit,
                'price': oi.item.price,
                'currency': oi.item.currency,
                'note': oi.item.note,
                'quantity': oi.quantity,
                'total': oi.total,
              })
          .toList(),
      total: total,
      currency: result.currency.code,
      personCount: result.personCount,
      drinkerType: result.drinkerType,
      cocktails: cocktailNames,
      shots: shotNames,
      distanceKm: _venueDistanceKm,
      thekeCost: thekeCost,
    );

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
    final separated = ShoppingListLogic.buildSeparatedItems(
      data,
      appState.selectedRecipes,
      _venueDistanceKm,
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

  Widget _buildPage(
    int index,
    List<String> cocktailNames,
    SeparatedItems separated,
    List<MaterialItem> allItems,
    double total,
    List<OrderItem> selectedItems,
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
