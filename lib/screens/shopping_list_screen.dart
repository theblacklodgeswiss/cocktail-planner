import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cocktail_repository.dart';
import '../models/cocktail_data.dart';
import '../models/material_item.dart';
import '../services/pdf_generator.dart';
import '../state/app_state.dart';
import '../utils/currency.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDistanceDialog());
  }

  Future<void> _showDistanceDialog() async {
    final distanceController = TextEditingController();
    String? errorText;

    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('shopping.distance_title'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'shopping.distance_description'.tr(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: distanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'shopping.distance_label'.tr(),
                  hintText: 'shopping.distance_hint'.tr(),
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                  suffixText: 'km',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () {
                final km = int.tryParse(distanceController.text.trim());
                if (km == null) {
                  setDialogState(
                    () => errorText = 'shopping.distance_error'.tr(),
                  );
                  return;
                }
                Navigator.pop(context, km);
              },
              child: Text('common.next'.tr()),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _venueDistanceKm = result);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key) {
    return _controllers.putIfAbsent(key, () {
      final controller = TextEditingController(
        text: _quantities[key]?.toString() ?? '',
      );
      controller.addListener(() {
        final value = int.tryParse(controller.text) ?? 0;
        setState(() {
          _quantities[key] = value;
          if (value > 0) {
            _selectedItems.add(key);
          } else {
            _selectedItems.remove(key);
          }
        });
      });
      return controller;
    });
  }

  ({
    Map<String, List<MaterialItem>> ingredientsByCocktail,
    List<MaterialItem> fixedValues,
    Map<String, List<String>> ingredientToCocktails,
  }) _buildSeparatedItems(CocktailData data) {
    final ingredientToCocktails = <String, List<String>>{};
    for (final recipe in appState.selectedRecipes) {
      for (final ingredient in recipe.ingredients) {
        ingredientToCocktails.putIfAbsent(ingredient, () => []).add(recipe.name);
      }
    }

    final requiredIngredients = ingredientToCocktails.keys.toSet();
    final materialByName = <String, MaterialItem>{};
    for (final item in data.materials) {
      if (requiredIngredients.contains(item.name)) {
        materialByName[item.name] = item;
      }
    }

    final usedIngredients = <String>{};
    final ingredientsByCocktail = <String, List<MaterialItem>>{};
    
    for (final recipe in appState.selectedRecipes) {
      final cocktailItems = <MaterialItem>[];
      for (final ingredientName in recipe.ingredients) {
        if (!usedIngredients.contains(ingredientName) && materialByName.containsKey(ingredientName)) {
          cocktailItems.add(materialByName[ingredientName]!);
          usedIngredients.add(ingredientName);
        }
      }
      if (cocktailItems.isNotEmpty) {
        cocktailItems.sort((a, b) => a.name.compareTo(b.name));
        ingredientsByCocktail[recipe.name] = cocktailItems;
      }
    }

    final isLongDistance = _venueDistanceKm > 200;
    final fixedValues = data.fixedValues
        .where((item) {
          if (!item.active) return false;
          if (item.note == 'BlackLodge') {
            // Travel variants: "Barkeeper (5h+2hFahrt)", "Keeper (5h+2h Fahrt)"
            if (item.name.contains('(5h+2h')) return isLongDistance;
            // Non-travel variants: "Barkeeper (5h)", "Keeper (5h)"
            if (item.name.contains('(5h)')) return !isLongDistance;
          }
          return true;
        })
        .toList()
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

  String _itemKey(MaterialItem item) => '${item.name}|${item.unit}';

  double _calculateTotal(List<MaterialItem> items) {
    double total = 0;
    for (final item in items) {
      final key = _itemKey(item);
      final qty = _quantities[key] ?? 0;
      if (qty > 0 && _selectedItems.contains(key)) {
        total += item.price * qty;
      }
    }
    return total;
  }

  List<OrderItem> _getSelectedOrderItems(List<MaterialItem> allItems) {
    final result = <OrderItem>[];
    for (final item in allItems) {
      final key = _itemKey(item);
      final qty = _quantities[key] ?? 0;
      if (qty > 0 && _selectedItems.contains(key)) {
        result.add(OrderItem(item: item, quantity: qty));
      }
    }
    return result;
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _export(List<MaterialItem> allItems, double total) async {
    final selectedOrderItems = _getSelectedOrderItems(allItems);
    
    if (selectedOrderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('shopping.no_selection'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final personCountController = TextEditingController();
    String drinkerType = 'normal'; // normal, light, heavy
    Currency selectedCurrency = defaultCurrency;
    String? nameError;
    String? personCountError;
    
    final result = await showDialog<({String name, int personCount, String drinkerType, Currency currency})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('shopping.save_order'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${selectedOrderItems.length} ${'orders.articles'.tr()} • ${selectedCurrency.format(total)}'),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'shopping.order_name_label'.tr(),
                    hintText: 'shopping.order_name_hint'.tr(),
                    border: const OutlineInputBorder(),
                    errorText: nameError,
                  ),
                  autofocus: true,
                  onChanged: (_) {
                    if (nameError != null) setDialogState(() => nameError = null);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: personCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'shopping.person_count_label'.tr(),
                    hintText: 'shopping.person_count_hint'.tr(),
                    border: const OutlineInputBorder(),
                    errorText: personCountError,
                  ),
                  onChanged: (_) {
                    if (personCountError != null) setDialogState(() => personCountError = null);
                  },
                ),
                const SizedBox(height: 16),
                Text('shopping.currency'.tr()),
                const SizedBox(height: 8),
                SegmentedButton<Currency>(
                  segments: Currency.values.map((c) => ButtonSegment(
                    value: c,
                    label: Text(c.code),
                  )).toList(),
                  selected: {selectedCurrency},
                  onSelectionChanged: (v) => setDialogState(() => selectedCurrency = v.first),
                ),
                const SizedBox(height: 16),
                Text('shopping.drinker_type'.tr()),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'light',
                      label: Text('orders.drinker_light'.tr()),
                      icon: const Icon(Icons.local_drink),
                    ),
                    ButtonSegment(
                      value: 'normal',
                      label: Text('orders.drinker_normal'.tr()),
                      icon: const Icon(Icons.local_bar),
                    ),
                    ButtonSegment(
                      value: 'heavy',
                      label: Text('orders.drinker_heavy'.tr()),
                      icon: const Icon(Icons.sports_bar),
                    ),
                  ],
                  selected: {drinkerType},
                  onSelectionChanged: (v) => setDialogState(() => drinkerType = v.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final personCount = int.tryParse(personCountController.text.trim()) ?? 0;
                String? nameErr;
                String? personErr;
                if (name.isEmpty) nameErr = 'shopping.name_required'.tr();
                if (personCount <= 0) personErr = 'shopping.person_count_error'.tr();
                if (nameErr != null || personErr != null) {
                  setDialogState(() {
                    nameError = nameErr;
                    personCountError = personErr;
                  });
                  return;
                }
                Navigator.pop(context, (
                  name: name,
                  personCount: personCount,
                  drinkerType: drinkerType,
                  currency: selectedCurrency,
                ));
              },
              child: Text('shopping.generate_pdf'.tr()),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    final orderName = result.name;
    if (orderName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('shopping.name_required'.tr())),
      );
      return;
    }

    final orderDate = DateTime.now();

    // Extract cocktails and shots from selected recipes
    final cocktailNames = appState.selectedRecipes
        .where((r) => !r.isShot)
        .map((r) => r.name)
        .toList();
    final shotNames = appState.selectedRecipes
        .where((r) => r.isShot)
        .map((r) => r.name)
        .toList();

    // Find theke cost from selected items
    double thekeCost = 0;
    for (final oi in selectedOrderItems) {
      if (oi.item.name.toLowerCase().contains('theke')) {
        thekeCost = oi.total;
        break;
      }
    }

    await cocktailRepository.saveOrder(
      name: orderName,
      date: orderDate,
      items: selectedOrderItems.map((oi) => {
        'name': oi.item.name,
        'unit': oi.item.unit,
        'price': oi.item.price,
        'currency': oi.item.currency,
        'note': oi.item.note,
        'quantity': oi.quantity,
        'total': oi.total,
      }).toList(),
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
      orderName: orderName,
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

        final separated = _buildSeparatedItems(snapshot.data!);
        final allIngredients = separated.ingredientsByCocktail.values
            .expand((items) => items)
            .toList();
        final allItems = [...allIngredients, ...separated.fixedValues];
        final total = _calculateTotal(allItems);

        if (allItems.isEmpty) {
          return _buildEmptyState(colorScheme);
        }

        // Build pages: each cocktail group + fixedValues + summary
        final cocktailNames = separated.ingredientsByCocktail.keys.toList();
        final totalPages = cocktailNames.length + 
            (separated.fixedValues.isNotEmpty ? 1 : 0) + 1; // +1 for summary

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: SafeArea(
            child: Column(
              children: [
                // Header with back button and progress
                _buildHeader(colorScheme, totalPages),
                
                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    itemCount: totalPages,
                    itemBuilder: (context, index) {
                      if (index < cocktailNames.length) {
                        // Cocktail ingredient page
                        final cocktailName = cocktailNames[index];
                        final items = separated.ingredientsByCocktail[cocktailName]!;
                        return _buildCocktailPage(
                          cocktailName,
                          items,
                          separated.ingredientToCocktails,
                          colorScheme,
                        );
                      } else if (index == cocktailNames.length && separated.fixedValues.isNotEmpty) {
                        // FixedValues page
                        return _buildFixedValuesPage(separated.fixedValues, colorScheme);
                      } else {
                        // Summary page
                        return _buildSummaryPage(allItems, total, colorScheme);
                      }
                    },
                  ),
                ),
                
                // Bottom navigation
                _buildBottomNav(totalPages, allItems, total, colorScheme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text('shopping.no_ingredients'.tr(), style: TextStyle(color: colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, int totalPages) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'shopping.title'.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'shopping.step_of'.tr(namedArgs: {'current': '${_currentPage + 1}', 'total': '$totalPages'}),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCocktailPage(
    String cocktailName,
    List<MaterialItem> items,
    Map<String, List<String>> ingredientToCocktails,
    ColorScheme colorScheme,
  ) {
    final isShot = cocktailName.toLowerCase().contains('shot');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Cocktail header with icon
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isShot 
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isShot ? Icons.wine_bar : Icons.local_bar,
                  color: isShot ? Colors.orange : Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cocktailName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${items.length} Zutaten',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Ingredients list
          ...items.map((item) => _buildItemCard(item, ingredientToCocktails, colorScheme)),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildFixedValuesPage(List<MaterialItem> items, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: Colors.purple,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fixkosten & Material',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${items.length} Positionen',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Items list
          ...items.map((item) => _buildItemCard(item, {}, colorScheme)),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    MaterialItem item,
    Map<String, List<String>> ingredientToCocktails,
    ColorScheme colorScheme,
  ) {
    final key = _itemKey(item);
    final controller = _controllerFor(key);
    final qty = _quantities[key] ?? 0;
    final isSelected = qty > 0;
    final cocktails = ingredientToCocktails[item.name] ?? [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected 
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${item.unit} • ${Currency.fromCode(item.currency).format(item.price)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                      if (item.note.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.note,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (cocktails.length > 1) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: cocktails.map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          c,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.green.shade700,
                            fontSize: 10,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  // Show subtotal when qty > 0
                  if (isSelected) ...[
                    const SizedBox(height: 6),
                    Text(
                      Currency.fromCode(item.currency).format(item.price * qty),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Quantity stepper - always visible
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: isSelected 
                    ? colorScheme.surface 
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: qty > 0
                        ? () {
                            final newQty = qty - 1;
                            _quantities[key] = newQty;
                            controller.text = newQty > 0 ? newQty.toString() : '';
                            if (newQty > 0) {
                              _selectedItems.add(key);
                            } else {
                              _selectedItems.remove(key);
                            }
                          }
                        : null,
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 40,
                    child: TextField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        hintText: '0',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () {
                      final newQty = qty + 1;
                      _quantities[key] = newQty;
                      controller.text = newQty.toString();
                      _selectedItems.add(key);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPage(List<MaterialItem> allItems, double total, ColorScheme colorScheme) {
    final selectedItems = _getSelectedOrderItems(allItems);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zusammenfassung',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${selectedItems.length} Artikel ausgewählt',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Total card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gesamtbetrag',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  defaultCurrency.format(total),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Selected items list
          if (selectedItems.isNotEmpty) ...[
            Text(
              'Ausgewählte Artikel',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...selectedItems.map((oi) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${oi.quantity}x',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      oi.item.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    Currency.fromCode(oi.item.currency).format(oi.total),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.remove_shopping_cart, size: 48, color: colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    'Keine Artikel ausgewählt',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gehe zurück und wähle Artikel aus',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBottomNav(int totalPages, List<MaterialItem> allItems, double total, ColorScheme colorScheme) {
    final isLastPage = _currentPage == totalPages - 1;
    final isFirstPage = _currentPage == 0;
    final selectedItems = _getSelectedOrderItems(allItems);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          if (!isFirstPage)
            TextButton.icon(
              onPressed: () => _goToPage(_currentPage - 1),
              icon: const Icon(Icons.arrow_back),
              label: Text('common.back'.tr()),
            )
          else
            const SizedBox(width: 100),
          
          // Progress dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? colorScheme.primary 
                        : colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          
          // Next/Export button
          if (isLastPage)
            FilledButton.icon(
              onPressed: selectedItems.isNotEmpty 
                  ? () => _export(allItems, total)
                  : null,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text('common.pdf'.tr()),
            )
          else
            FilledButton.icon(
              onPressed: () => _goToPage(_currentPage + 1),
              icon: const Icon(Icons.arrow_forward),
              label: Text('common.next'.tr()),
            ),
        ],
      ),
    );
  }
}
