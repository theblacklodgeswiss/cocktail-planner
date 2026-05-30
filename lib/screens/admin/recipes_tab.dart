import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import '../../models/recipe.dart';
import 'recipe_edit_dialog.dart';

/// Tab for managing recipes in the admin screen.
class RecipesTab extends StatefulWidget {
  const RecipesTab({super.key});

  @override
  State<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<RecipesTab> {
  List<({String id, Recipe item})> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await adminRepository.getRecipesWithIds();
    if (mounted) {
      setState(() {
        _items = items..sort((a, b) => a.item.name.compareTo(b.item.name));
        _isLoading = false;
      });
    }
  }

  List<({String id, Recipe item})> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final query = _searchQuery.toLowerCase();
    return _items.where((i) => i.item.name.toLowerCase().contains(query)).toList();
  }

  Future<void> _showEditDialog({String? docId, Recipe? recipe}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<RecipeEditResult>(
      context: context,
      builder: (ctx) => RecipeEditDialog(
        initialName: recipe?.name ?? '',
        initialIngredients: recipe?.ingredients ?? [],
        initialAmounts: recipe?.ingredientAmounts ?? {},
      ),
    );

    if (result != null && result.name.trim().isNotEmpty) {
      bool success;
      if (docId == null) {
        success = await adminRepository.addRecipe(
          name: result.name.trim(),
          ingredients: result.ingredients,
        );
        // Save amounts separately after create
        if (success && result.amounts.isNotEmpty) {
          final recipes = await adminRepository.getRecipesWithIds();
          final created = recipes.where((r) => r.item.name == result.name.trim()).firstOrNull;
          if (created != null) {
            await adminRepository.updateRecipeAmounts(docId: created.id, amounts: result.amounts);
          }
        }
      } else {
        success = await adminRepository.updateRecipe(
          docId: docId,
          name: result.name.trim(),
          ingredients: result.ingredients,
        );
        if (success && result.amounts.isNotEmpty) {
          await adminRepository.updateRecipeAmounts(docId: docId, amounts: result.amounts);
        }
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(success ? 'Gespeichert!' : 'Fehler beim Speichern')),
      );
      if (success) _loadItems();
    }
  }

  Future<void> _deleteItem(String docId, String name) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rezept löschen?'),
        content: Text('"$name" wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await adminRepository.deleteRecipe(docId: docId);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(success ? 'Gelöscht!' : 'Fehler beim Löschen')),
      );
      if (success) _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        _buildSearchBar(),
        _buildListHeader(context),
        const SizedBox(height: 8),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Suchen...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildListHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_filteredItems.length} Rezepte', style: Theme.of(context).textTheme.bodySmall),
          FilledButton.tonalIcon(
            onPressed: () => _showEditDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Neu'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_filteredItems.isEmpty) return const Center(child: Text('Keine Rezepte gefunden'));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final record = _filteredItems[index];
        return _RecipeCard(
          recipe: record.item,
          onEdit: () => _showEditDialog(docId: record.id, recipe: record.item),
          onDelete: () => _deleteItem(record.id, record.item.name),
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.onEdit, required this.onDelete});

  final Recipe recipe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isShot = recipe.name.toLowerCase().contains('shot');
    final hasAmounts = recipe.ingredientAmounts.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isShot
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.green.withValues(alpha: 0.2),
              child: Icon(
                isShot ? Icons.wine_bar : Icons.local_bar,
                size: 18,
                color: isShot ? Colors.orange : Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(recipe.name, style: theme.textTheme.titleSmall),
                      ),
                      if (hasAmounts)
                        Tooltip(
                          message: 'Mengen vorhanden',
                          child: Icon(Icons.science, size: 14, color: Colors.green.shade400),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Ingredient list with amounts
                  ...recipe.ingredients.map((ing) {
                    final amount = recipe.ingredientAmounts[ing];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ing,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (amount != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                amount,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Text(
                              '—',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
