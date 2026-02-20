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
      ),
    );

    if (result != null && result.name.trim().isNotEmpty) {
      bool success;

      if (docId == null) {
        success = await adminRepository.addRecipe(
          name: result.name.trim(),
          ingredients: result.ingredients,
        );
      } else {
        success = await adminRepository.updateRecipe(
          docId: docId,
          name: result.name.trim(),
          ingredients: result.ingredients,
        );
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text(success ? 'Gespeichert!' : 'Fehler beim Speichern')),
      );

      if (success) {
        _loadItems();
      }
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

      if (success) {
        _loadItems();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
          Text(
            '${_filteredItems.length} Rezepte',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
    if (_filteredItems.isEmpty) {
      return const Center(child: Text('Keine Rezepte gefunden'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final record = _filteredItems[index];
        final recipe = record.item;
        return _RecipeCard(
          recipe: recipe,
          onEdit: () => _showEditDialog(docId: record.id, recipe: recipe),
          onDelete: () => _deleteItem(record.id, recipe.name),
        );
      },
    );
  }
}

/// Card widget for displaying a recipe item.
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onEdit,
    required this.onDelete,
  });

  final Recipe recipe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isShot = recipe.name.toLowerCase().contains('shot');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isShot ? Colors.orange.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
          child: Icon(
            isShot ? Icons.wine_bar : Icons.local_bar,
            color: isShot ? Colors.orange : Colors.green,
          ),
        ),
        title: Text(recipe.name),
        subtitle: Text(
          '${recipe.ingredients.length} Zutaten: ${recipe.ingredients.take(3).join(", ")}${recipe.ingredients.length > 3 ? "..." : ""}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
