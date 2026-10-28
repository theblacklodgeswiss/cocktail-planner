import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/material_item.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/pressable.dart';
import '../../../ui/widgets/states.dart';

/// Sheet for editing recipe ingredients: shows the current ingredients and
/// allows adding/removing from the available materials.
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

  /// Shows the sheet and returns the updated ingredient list, or null if
  /// cancelled.
  static Future<List<String>?> show({
    required BuildContext context,
    required String recipeName,
    required List<String> currentIngredients,
    required List<MaterialItem> availableMaterials,
  }) {
    return showAppSheet<List<String>>(
      context,
      full: true,
      builder: (_) => RecipeIngredientEditDialog(
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
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.recipeName,
          style: AppText.heroTitle.copyWith(color: p.text),
        ),
        Text(
          '${_ingredients.length} ${'shopping.ingredients'.tr()}',
          style: AppText.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpace.s12),
        Expanded(
          child: _showAddSection
              ? _buildAddSection(context, p)
              : _buildIngredientsList(context, p),
        ),
        const SizedBox(height: AppSpace.s12),
        if (!_showAddSection) ...[
          SecondaryButton(
            label: 'shopping.add_ingredient'.tr(),
            onPressed: () => setState(() => _showAddSection = true),
          ),
          const SizedBox(height: AppSpace.s8),
        ],
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'common.cancel'.tr(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: PrimaryButton(
                label: 'common.save'.tr(),
                onPressed: () => Navigator.of(context).pop(_ingredients),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIngredientsList(BuildContext context, AppPalette p) {
    if (_ingredients.isEmpty) {
      return EmptyState(
        icon: Icons.info_outline,
        title: 'shopping.no_ingredients'.tr(),
      );
    }

    return ListView.builder(
      itemCount: _ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = _ingredients[index];
        final material = widget.availableMaterials
            .where((m) => m.name == ingredient)
            .firstOrNull;

        return Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ingredient,
                      style: AppText.button.copyWith(color: p.text),
                    ),
                    Text(
                      material != null
                          ? '${material.unit} • '
                                '${material.price.toStringAsFixed(2)} '
                                '${material.currency}'
                          : 'shopping.not_in_inventory'.tr(),
                      style: AppText.body.copyWith(
                        color: material != null ? p.textSecondary : p.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Pressable(
              minSize: AppSize.minTap,
              radius: AppRadius.pill,
              semanticLabel:
                  '${'shopping_ui.remove_ingredient'.tr()}: $ingredient',
              onTap: () => _removeIngredient(ingredient),
              child: SizedBox.square(
                dimension: AppSize.minTap,
                child: Icon(
                  Icons.remove_circle_outline,
                  size: AppSize.rowIcon,
                  color: p.error,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddSection(BuildContext context, AppPalette p) {
    final availableItems = _availableToAdd;

    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'shopping.search_ingredient'.tr(),
            suffixIcon: Pressable(
              minSize: AppSize.minTap,
              radius: AppRadius.pill,
              semanticLabel: 'common.close'.tr(),
              onTap: () {
                _searchController.clear();
                setState(() {
                  _showAddSection = false;
                });
              },
              child: const Icon(Icons.close),
            ),
          ),
          onChanged: (_) => setState(() {}),
          autofocus: true,
        ),
        const SizedBox(height: AppSpace.s8),
        Expanded(
          child: ListView.builder(
            itemCount: availableItems.length,
            itemBuilder: (context, index) {
              final material = availableItems[index];
              return Pressable(
                minSize: AppSize.minTap,
                onTap: () => _addIngredient(material.name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: AppSize.rowIcon,
                        color: p.text,
                      ),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              material.name,
                              style: AppText.button.copyWith(color: p.text),
                            ),
                            Text(
                              '${material.unit} • '
                              '${material.price.toStringAsFixed(2)} '
                              '${material.currency}',
                              style: AppText.body.copyWith(
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
