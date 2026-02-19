import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cocktail_repository.dart';
import '../models/cocktail_data.dart';
import '../models/material_item.dart';
import '../state/app_state.dart';
import '../utils/translation.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key, this.loadData});

  final Future<CocktailData> Function()? loadData;

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late final Future<CocktailData> _dataFuture;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, int> _quantities = {};

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
        setState(() => _quantities[key] = value);
      });
      return controller;
    });
  }

  /// Returns (ingredients, fixedValues) separately
  ({List<MaterialItem> ingredients, List<MaterialItem> fixedValues}) _buildSeparatedItems(CocktailData data) {
    final requiredIngredients = appState.selectedRecipes
        .expand((recipe) => recipe.ingredients)
        .toSet();

    final filteredRecipeItems = data.materials
        .where((item) => requiredIngredients.contains(item.name))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final fixedValues = data.fixedValues.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return (ingredients: filteredRecipeItems, fixedValues: fixedValues);
  }

  String _itemKey(MaterialItem item) => '${item.name}|${item.unit}';

  double _calculateTotal(List<MaterialItem> items) {
    double total = 0;
    for (final item in items) {
      final qty = _quantities[_itemKey(item)] ?? 0;
      total += item.price * qty;
    }
    return total;
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
        final allItems = [...separated.ingredients, ...separated.fixedValues];
        final total = _calculateTotal(allItems);

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: allItems.isEmpty
              ? _buildEmptyState(context, colorScheme, textTheme)
              : _buildShoppingList(
                  context,
                  separated.ingredients,
                  separated.fixedValues,
                  total,
                  colorScheme,
                  textTheme,
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, colorScheme, textTheme, null),
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
    List<MaterialItem> ingredients,
    List<MaterialItem> fixedValues,
    double total,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        if (isWide) {
          // Desktop: Two columns side by side
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, colorScheme, textTheme, total),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ingredients column
                      Expanded(
                        flex: 3,
                        child: _buildSection(
                          context,
                          translate(context, 'shopping.section_ingredients'),
                          Icons.local_bar,
                          ingredients,
                          colorScheme,
                          textTheme,
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
              _buildSliverAppBar(context, colorScheme, textTheme, total),
              // Ingredients section
              if (ingredients.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  translate(context, 'shopping.section_ingredients'),
                  Icons.local_bar,
                  colorScheme,
                  textTheme,
                ),
                _buildItemsSliver(ingredients, colorScheme, textTheme),
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
                _buildItemsSliver(fixedValues, colorScheme, textTheme),
              ],
              // Bottom padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        }
      },
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<MaterialItem> items,
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
          child: _buildItemCard(context, item, colorScheme, textTheme),
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
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildItemCard(context, items[index], colorScheme, textTheme),
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
  ) {
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${total.toStringAsFixed(2)} CHF',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
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
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final key = _itemKey(item);
    final quantity = _quantities[key] ?? 0;
    final hasQuantity = quantity > 0;
    final itemTotal = item.price * quantity;

    return Container(
      decoration: BoxDecoration(
        color: hasQuantity
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasQuantity
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.unit} • ${item.price.toStringAsFixed(2)} ${item.currency}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.note,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Quantity controls
            _buildQuantityControl(
              context, key, colorScheme, textTheme,
            ),
            // Item total
            if (hasQuantity) ...[
              const SizedBox(width: 12),
              Container(
                constraints: const BoxConstraints(minWidth: 70),
                child: Text(
                  itemTotal.toStringAsFixed(2),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
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
