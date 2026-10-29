import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import '../../utils/currency.dart';
import 'material_logic.dart';
import 'recipe_edit_sheet.dart';
import 'recipes_view.dart';

/// Data wrapper of the recipes page in the admin screen.
class RecipesTab extends StatefulWidget {
  const RecipesTab({super.key, required this.header});

  /// Tab pills shown under the title.
  final Widget header;

  @override
  State<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<RecipesTab> {
  List<RecipeRecord> _items = [];
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final items = await adminRepository.getRecipesWithIds();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _isLoading = false;
      });
    }
  }

  Future<List<String>> _loadMaterials() async {
    final materials = await adminRepository.getMaterialsWithIds(
      isFixedValue: false,
    );
    return materials.map((m) => m.item.name).toList();
  }

  Future<bool> _addIngredient(String name) => adminRepository.addMaterial(
    name: name,
    unit: '',
    price: 0,
    currency: defaultCurrency.code,
    note: '',
    isFixedValue: false,
  );

  Future<bool> _save(String? docId, RecipeEditResult result) async {
    final name = result.name.trim();
    if (name.isEmpty) return false;
    bool success;
    if (docId == null) {
      success = await adminRepository.addRecipe(
        name: name,
        ingredients: result.ingredients,
      );
      // Save amounts separately after create
      if (success && result.amounts.isNotEmpty) {
        final recipes = await adminRepository.getRecipesWithIds();
        final created = recipes.where((r) => r.item.name == name).firstOrNull;
        if (created != null) {
          success = await adminRepository.updateRecipeAmounts(
            docId: created.id,
            amounts: result.amounts,
          );
        }
      }
    } else {
      success = await adminRepository.updateRecipe(
        docId: docId,
        name: name,
        ingredients: result.ingredients,
      );
      if (success && result.amounts.isNotEmpty) {
        success = await adminRepository.updateRecipeAmounts(
          docId: docId,
          amounts: result.amounts,
        );
      }
    }
    if (success) _loadItems();
    return success;
  }

  Future<bool> _delete(String docId) async {
    final ok = await adminRepository.deleteRecipe(docId: docId);
    if (ok) _loadItems();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return RecipesView(
      title: 'admin.title'.tr(),
      header: widget.header,
      items: _items,
      loading: _isLoading,
      errorMessage: _failed ? 'admin2.load_error'.tr() : null,
      onRetry: _loadItems,
      loadMaterials: _loadMaterials,
      onAddIngredient: _addIngredient,
      onSave: _save,
      onDelete: _delete,
    );
  }
}
