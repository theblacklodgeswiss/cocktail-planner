import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cocktail_repository.dart';
import '../models/cocktail_data.dart';
import '../models/material_item.dart';
import '../services/pdf_generator.dart';
import '../state/app_state.dart';
import '../utils/translation.dart';

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

  @override
  void initState() {
    super.initState();
    _dataFuture = (widget.loadData ?? cocktailRepository.load)();
  }

  @override
  void dispose() {
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
          // Auto-select when quantity > 0, deselect when 0
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

  /// Returns ingredients grouped by cocktail, fixedValues, and ingredientToCocktails map
  ({
    Map<String, List<MaterialItem>> ingredientsByCocktail,
    List<MaterialItem> fixedValues,
    Map<String, List<String>> ingredientToCocktails,
  }) _buildSeparatedItems(CocktailData data) {
    // Build map: ingredient name -> list of cocktail names that use it
    final ingredientToCocktails = <String, List<String>>{};
    for (final recipe in appState.selectedRecipes) {
      for (final ingredient in recipe.ingredients) {
        ingredientToCocktails.putIfAbsent(ingredient, () => []).add(recipe.name);
      }
    }

    final requiredIngredients = ingredientToCocktails.keys.toSet();
    
    // Build material lookup
    final materialByName = <String, MaterialItem>{};
    for (final item in data.materials) {
      if (requiredIngredients.contains(item.name)) {
        materialByName[item.name] = item;
      }
    }

    // Group ingredients by cocktail (each ingredient only appears once, under its first cocktail)
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

    final fixedValues = data.fixedValues.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return (
      ingredientsByCocktail: ingredientsByCocktail,
      fixedValues: fixedValues,
      ingredientToCocktails: ingredientToCocktails,
    );
  }

  /// Flattened list of all ingredients for total calculation
  List<MaterialItem> _getAllIngredients(Map<String, List<MaterialItem>> ingredientsByCocktail) {
    return ingredientsByCocktail.values.expand((items) => items).toList();
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

  /// Get selected items with their quantities for export
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

  /// Show export dialog and generate PDF
  Future<void> _showExportDialog(
    BuildContext context,
    List<MaterialItem> allItems,
    double total,
  ) async {
    final selectedOrderItems = _getSelectedOrderItems(allItems);
    
    if (selectedOrderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate(context, 'shopping.no_selection')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate(context, 'shopping.export_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${selectedOrderItems.length} ${translate(context, 'shopping.items_selected')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${translate(context, 'shopping.total')}: ${total.toStringAsFixed(2)} CHF',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: translate(context, 'shopping.order_name'),
                hintText: translate(context, 'shopping.order_name_hint'),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(translate(context, 'common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(translate(context, 'shopping.generate_pdf')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final orderName = nameController.text.trim();
    if (orderName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translate(context, 'shopping.name_required')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final orderDate = DateTime.now();

    // Save to Firestore
    final orderId = await cocktailRepository.saveOrder(
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
    );

    // Generate and download PDF
    await PdfGenerator.generateAndDownload(
      orderName: orderName,
      orderDate: orderDate,
      items: selectedOrderItems,
      grandTotal: total,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          orderId != null
              ? translate(context, 'shopping.saved_and_generated')
              : translate(context, 'shopping.generated_local'),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
            appBar: AppBar(
              title: Text(translate(context, 'shopping.title')),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(translate(context, 'shopping.load_error')),
                ],
              ),
            ),
          );
        }

        final separated = _buildSeparatedItems(snapshot.data!);
        final allIngredients = _getAllIngredients(separated.ingredientsByCocktail);
        final allItems = [...allIngredients, ...separated.fixedValues];
        final total = _calculateTotal(allItems);

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: allItems.isEmpty
              ? _buildEmptyState(context, colorScheme, textTheme)
              : _buildShoppingList(
                  context,
                  separated.ingredientsByCocktail,
                  separated.fixedValues,
                  separated.ingredientToCocktails,
                  allItems,
                  total,
                  colorScheme,
                  textTheme,
                ),
          floatingActionButton: cocktailRepository.isUsingFirebase
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddItemDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Neu'),
                )
              : null,
        );
      },
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _AddItemDialog(),
    );
    
    if (result == true && mounted) {
      // Reload data
      setState(() {
        _dataFuture = cocktailRepository.load();
      });
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, colorScheme, textTheme, null, null),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  translate(context, 'shopping.empty'),
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShoppingList(
    BuildContext context,
    Map<String, List<MaterialItem>> ingredientsByCocktail,
    List<MaterialItem> fixedValues,
    Map<String, List<String>> ingredientToCocktails,
    List<MaterialItem> allItems,
    double total,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final cocktailNames = ingredientsByCocktail.keys.toList();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        if (isWide) {
          // Desktop: Two columns side by side
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, colorScheme, textTheme, total, allItems),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ingredients column (grouped by cocktail)
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final cocktailName in cocktailNames) ...[
                              _buildCocktailSection(
                                context,
                                cocktailName,
                                ingredientsByCocktail[cocktailName]!,
                                ingredientToCocktails,
                                colorScheme,
                                textTheme,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Fixed values column
                      Expanded(
                        flex: 2,
                        child: _buildSection(
                          context,
                          translate(context, 'shopping.section_fixed_costs'),
                          Icons.receipt_long,
                          fixedValues,
                          {},
                          colorScheme,
                          textTheme,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        } else {
          // Mobile/Tablet: Stacked vertically
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, colorScheme, textTheme, total, allItems),
              // Cocktail sections
              for (final cocktailName in cocktailNames) ...[
                _buildCocktailSectionHeader(context, cocktailName, colorScheme, textTheme),
                _buildItemsSliver(ingredientsByCocktail[cocktailName]!, ingredientToCocktails, colorScheme, textTheme),
              ],
              // Fixed values section
              if (fixedValues.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  translate(context, 'shopping.section_fixed_costs'),
                  Icons.receipt_long,
                  colorScheme,
                  textTheme,
                ),
                _buildItemsSliver(fixedValues, {}, colorScheme, textTheme),
              ],
              // Bottom padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        }
      },
    );
  }

  Widget _buildCocktailSection(
    BuildContext context,
    String cocktailName,
    List<MaterialItem> items,
    Map<String, List<String>> ingredientToCocktails,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cocktail header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_bar,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cocktailName,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Items
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildItemCard(context, item, ingredientToCocktails, colorScheme, textTheme),
        )),
      ],
    );
  }

  SliverToBoxAdapter _buildCocktailSectionHeader(
    BuildContext context,
    String cocktailName,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_bar,
                size: 20,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cocktailName,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<MaterialItem> items,
    Map<String, List<String>> ingredientToCocktails,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Items
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildItemCard(context, item, ingredientToCocktails, colorScheme, textTheme),
        )),
      ],
    );
  }

  SliverToBoxAdapter _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverPadding _buildItemsSliver(
    List<MaterialItem> items,
    Map<String, List<String>> ingredientToCocktails,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildItemCard(context, items[index], ingredientToCocktails, colorScheme, textTheme),
          ),
          childCount: items.length,
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    double? total,
    List<MaterialItem>? allItems,
  ) {
    final hasSelection = _selectedItems.isNotEmpty && total != null && total > 0;
    
    return SliverAppBar.large(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        translate(context, 'shopping.title'),
        style: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: total != null
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: hasSelection && allItems != null
                          ? () => _showExportDialog(context, allItems, total)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: hasSelection
                              ? colorScheme.primary
                              : colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasSelection) ...[
                              Icon(
                                Icons.picture_as_pdf,
                                size: 18,
                                color: colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              '${total.toStringAsFixed(2)} CHF',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: hasSelection
                                    ? colorScheme.onPrimary
                                    : colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]
          : null,
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    MaterialItem item,
    Map<String, List<String>> ingredientToCocktails,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final key = _itemKey(item);
    final quantity = _quantities[key] ?? 0;
    final hasQuantity = quantity > 0;
    final isSelected = _selectedItems.contains(key);
    final itemTotal = item.price * quantity;
    final cocktails = ingredientToCocktails[item.name] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: isSelected && hasQuantity
            ? colorScheme.primaryContainer.withValues(alpha: 0.4)
            : hasQuantity
                ? colorScheme.primaryContainer.withValues(alpha: 0.2)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected && hasQuantity
              ? colorScheme.primary.withValues(alpha: 0.5)
              : hasQuantity
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : colorScheme.outline.withValues(alpha: 0.1),
          width: isSelected && hasQuantity ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            if (hasQuantity)
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (value == true) {
                      _selectedItems.add(key);
                    } else {
                      _selectedItems.remove(key);
                    }
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            else
              const SizedBox(width: 48),
            // Item info (left side)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${item.unit} • ${item.price.toStringAsFixed(2)} ${item.currency}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                      if (item.note.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.note,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Cocktails that use this ingredient
                  if (cocktails.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: cocktails.map((cocktail) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          cocktail,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                            fontSize: 10,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side: Stepper + Price below
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quantity controls
                _buildQuantityControl(
                  context, key, colorScheme, textTheme,
                ),
                // Item total below stepper
                if (hasQuantity) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${itemTotal.toStringAsFixed(2)} CHF',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? colorScheme.primary : colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControl(
    BuildContext context,
    String key,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final controller = _controllerFor(key);
    final quantity = _quantities[key] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus button
          _buildStepperButton(
            icon: Icons.remove,
            onPressed: quantity > 0
                ? () {
                    HapticFeedback.lightImpact();
                    final newQty = (quantity - 1).clamp(0, 999);
                    controller.text = newQty > 0 ? newQty.toString() : '';
                  }
                : null,
            colorScheme: colorScheme,
          ),
          // Text field
          SizedBox(
            width: 48,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: textTheme.titleMedium?.copyWith(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
            ),
          ),
          // Plus button
          _buildStepperButton(
            icon: Icons.add,
            onPressed: () {
              HapticFeedback.lightImpact();
              final newQty = (quantity + 1).clamp(0, 999);
              controller.text = newQty.toString();
            },
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

enum ItemType { ingredient, fixedValue }

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  
  ItemType _selectedType = ItemType.fixedValue;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final success = await cocktailRepository.addMaterial(
      name: _nameController.text.trim(),
      unit: _unitController.text.trim(),
      price: double.tryParse(_priceController.text) ?? 0,
      currency: 'CHF',
      note: _noteController.text.trim(),
      isFixedValue: _selectedType == ItemType.fixedValue,
    );
    
    if (!mounted) return;
    
    setState(() => _isLoading = false);
    
    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item erfolgreich hinzugefügt!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Hinzufügen')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neues Item hinzufügen'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selection
              const Text('Typ:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              SegmentedButton<ItemType>(
                segments: const [
                  ButtonSegment(
                    value: ItemType.ingredient,
                    label: Text('Zutat'),
                    icon: Icon(Icons.restaurant),
                  ),
                  ButtonSegment(
                    value: ItemType.fixedValue,
                    label: Text('Fixkosten'),
                    icon: Icon(Icons.attach_money),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (selection) {
                  setState(() => _selectedType = selection.first);
                },
              ),
              const SizedBox(height: 16),
              
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'z.B. Strohhalme',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name ist erforderlich';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // Unit and Price in a row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Einheit *',
                        hintText: 'z.B. Stk, 100er Pack',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Erforderlich';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Preis (CHF) *',
                        hintText: '0.00',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Erforderlich';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Ungültig';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Note
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Bemerkung',
                  hintText: 'z.B. Kaufland, Amazon',
                  border: OutlineInputBorder(),
                ),
              ),
              
              if (_selectedType == ItemType.ingredient) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Zutaten erscheinen nur wenn ein Cocktail sie verwendet.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
