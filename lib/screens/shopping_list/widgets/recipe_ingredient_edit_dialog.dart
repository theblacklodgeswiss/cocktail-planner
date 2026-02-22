import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/material_item.dart';

/// Dialog for editing recipe ingredients.
/// Shows current ingredients and allows adding/removing from available materials.
class RecipeIngredientEditDialog extends StatefulWidget {
  const RecipeIngredientEditDialog({
    super.key,
    required this.recipeName,
    required this.currentIngredients,
    required this.availableMaterials,
  });

  final String recipeName;
  final List<String> currentIngredients;
  final List<MaterialItem> availableMaterials;

  /// Shows the dialog and returns the updated ingredient list, or null if cancelled.
  static Future<List<String>?> show({
    required BuildContext context,
    required String recipeName,
    required List<String> currentIngredients,
    required List<MaterialItem> availableMaterials,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => RecipeIngredientEditDialog(
        recipeName: recipeName,
        currentIngredients: currentIngredients,
        availableMaterials: availableMaterials,
      ),
    );
  }

  @override
  State<RecipeIngredientEditDialog> createState() =>
      _RecipeIngredientEditDialogState();
}

class _RecipeIngredientEditDialogState
    extends State<RecipeIngredientEditDialog> {
  late List<String> _ingredients;
  final TextEditingController _searchController = TextEditingController();
  bool _showAddSection = false;

  @override
  void initState() {
    super.initState();
    _ingredients = List.from(widget.currentIngredients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MaterialItem> get _availableToAdd {
    final query = _searchController.text.toLowerCase().trim();
    return widget.availableMaterials
        .where((m) => !_ingredients.contains(m.name))
        .where((m) => query.isEmpty || m.name.toLowerCase().contains(query))
        .toList();
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      _ingredients.remove(ingredient);
    });
  }

  void _addIngredient(String ingredient) {
    setState(() {
      _ingredients.add(ingredient);
      _searchController.clear();
      _showAddSection = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isShot = widget.recipeName.toLowerCase().contains('shot');

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, colorScheme, isShot),
            const Divider(height: 1),
            Flexible(
              child: _showAddSection
                  ? _buildAddSection(context, colorScheme)
                  : _buildIngredientsList(context, colorScheme),
            ),
            const Divider(height: 1),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, ColorScheme colorScheme, bool isShot) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isShot
                  ? Colors.orange.withValues(alpha: 0.15)
                  : Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isShot ? Icons.wine_bar : Icons.local_bar,
              color: isShot ? Colors.orange : Colors.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${_ingredients.length} ${'shopping.ingredients'.tr()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsList(BuildContext context, ColorScheme colorScheme) {
    if (_ingredients.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'shopping.no_ingredients'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = _ingredients[index];
        final material = widget.availableMaterials
            .where((m) => m.name == ingredient)
            .firstOrNull;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(ingredient),
          subtitle: material != null
              ? Text(
                  '${material.unit} • ${material.price.toStringAsFixed(2)} ${material.currency}',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Text(
                  'shopping.not_in_inventory'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                ),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.red,
            onPressed: () => _removeIngredient(ingredient),
          ),
        );
      },
    );
  }

  Widget _buildAddSection(BuildContext context, ColorScheme colorScheme) {
    final availableItems = _availableToAdd;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'shopping.search_ingredient'.tr(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _showAddSection = false;
                  });
                },
              ),
            ),
            onChanged: (_) => setState(() {}),
            autofocus: true,
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableItems.length,
            itemBuilder: (context, index) {
              final material = availableItems[index];
              return ListTile(
                leading: Icon(Icons.add_circle_outline, color: Colors.green),
                title: Text(material.name),
                subtitle: Text(
                  '${material.unit} • ${material.price.toStringAsFixed(2)} ${material.currency}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => _addIngredient(material.name),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (!_showAddSection)
            TextButton.icon(
              onPressed: () => setState(() => _showAddSection = true),
              icon: const Icon(Icons.add),
              label: Text('shopping.add_ingredient'.tr()),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ingredients),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }
}
