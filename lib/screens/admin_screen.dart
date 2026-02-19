import 'package:flutter/material.dart';

import '../data/cocktail_repository.dart';
import '../models/material_item.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!authService.canManageUsers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(
          child: Text('Zugriff verweigert - nur für Admins'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventar verwalten'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory), text: 'Materialien'),
            Tab(icon: Icon(Icons.build), text: 'Verbrauch'),
            Tab(icon: Icon(Icons.local_bar), text: 'Rezepte'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MaterialsTab(isFixedValue: false),
          _MaterialsTab(isFixedValue: true),
          _RecipesTab(),
        ],
      ),
    );
  }
}

// ============ Materials Tab ============

class _MaterialsTab extends StatefulWidget {
  const _MaterialsTab({required this.isFixedValue});

  final bool isFixedValue;

  @override
  State<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<_MaterialsTab> {
  List<({String id, MaterialItem item})> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await cocktailRepository.getMaterialsWithIds(
      isFixedValue: widget.isFixedValue,
    );
    if (mounted) {
      setState(() {
        _items = items..sort((a, b) => a.item.name.compareTo(b.item.name));
        _isLoading = false;
      });
    }
  }

  List<({String id, MaterialItem item})> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final query = _searchQuery.toLowerCase();
    return _items.where((i) => 
      i.item.name.toLowerCase().contains(query) ||
      i.item.note.toLowerCase().contains(query)
    ).toList();
  }

  Future<void> _showEditDialog({String? docId, MaterialItem? item}) async {
    final nameController = TextEditingController(text: item?.name ?? '');
    final unitController = TextEditingController(text: item?.unit ?? '');
    final priceController = TextEditingController(
      text: item?.price.toString() ?? '0',
    );
    final currencyController = TextEditingController(
      text: item?.currency ?? 'CHF',
    );
    final noteController = TextEditingController(text: item?.note ?? '');

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(docId == null ? 'Neuer Artikel' : 'Artikel bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Einheit',
                        hintText: 'z.B. 0.7L, Stk',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Preis',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: currencyController,
                      decoration: const InputDecoration(
                        labelText: 'Währung',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Bemerkung',
                  hintText: 'z.B. Lieferant',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      bool success;

      if (docId == null) {
        // Add new
        success = await cocktailRepository.addMaterial(
          name: nameController.text.trim(),
          unit: unitController.text.trim(),
          price: double.tryParse(priceController.text) ?? 0,
          currency: currencyController.text.trim(),
          note: noteController.text.trim(),
          isFixedValue: widget.isFixedValue,
        );
      } else {
        // Update existing
        success = await cocktailRepository.updateMaterial(
          docId: docId,
          name: nameController.text.trim(),
          unit: unitController.text.trim(),
          price: double.tryParse(priceController.text) ?? 0,
          currency: currencyController.text.trim(),
          note: noteController.text.trim(),
          isFixedValue: widget.isFixedValue,
        );
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(success ? 'Gespeichert!' : 'Fehler beim Speichern')),
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
        title: const Text('Artikel löschen?'),
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
      final success = await cocktailRepository.deleteMaterial(
        docId: docId,
        isFixedValue: widget.isFixedValue,
      );

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
        // Search bar
        Padding(
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
        ),
        
        // List header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredItems.length} Artikel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Neu'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // List
        Expanded(
          child: _filteredItems.isEmpty
              ? const Center(child: Text('Keine Artikel gefunden'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final record = _filteredItems[index];
                    final item = record.item;
                    return Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.unit} • ${item.price.toStringAsFixed(2)} ${item.currency}'
                          '${item.note.isNotEmpty ? ' • ${item.note}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditDialog(
                                docId: record.id,
                                item: item,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(record.id, item.name),
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

// ============ Recipes Tab ============

class _RecipesTab extends StatefulWidget {
  const _RecipesTab();

  @override
  State<_RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<_RecipesTab> {
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
    final items = await cocktailRepository.getRecipesWithIds();
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
    return _items.where((i) => 
      i.item.name.toLowerCase().contains(query)
    ).toList();
  }

  Future<void> _showEditDialog({String? docId, Recipe? recipe}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<({String name, List<String> ingredients})>(
      context: context,
      builder: (ctx) => _RecipeEditDialog(
        initialName: recipe?.name ?? '',
        initialIngredients: recipe?.ingredients ?? [],
      ),
    );

    if (result != null && result.name.trim().isNotEmpty) {
      bool success;

      if (docId == null) {
        success = await cocktailRepository.addRecipe(
          name: result.name.trim(),
          ingredients: result.ingredients,
        );
      } else {
        success = await cocktailRepository.updateRecipe(
          docId: docId,
          name: result.name.trim(),
          ingredients: result.ingredients,
        );
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(success ? 'Gespeichert!' : 'Fehler beim Speichern')),
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
      final success = await cocktailRepository.deleteRecipe(docId: docId);

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
        // Search bar
        Padding(
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
        ),
        
        // List header
        Padding(
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
        ),
        const SizedBox(height: 8),

        // List
        Expanded(
          child: _filteredItems.isEmpty
              ? const Center(child: Text('Keine Rezepte gefunden'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final record = _filteredItems[index];
                    final recipe = record.item;
                    final isShot = recipe.name.toLowerCase().contains('shot');
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isShot 
                              ? Colors.orange.withValues(alpha: 0.2)
                              : Colors.green.withValues(alpha: 0.2),
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
                              onPressed: () => _showEditDialog(
                                docId: record.id,
                                recipe: recipe,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(record.id, recipe.name),
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

// ============ Recipe Edit Dialog ============

class _RecipeEditDialog extends StatefulWidget {
  const _RecipeEditDialog({
    required this.initialName,
    required this.initialIngredients,
  });

  final String initialName;
  final List<String> initialIngredients;

  @override
  State<_RecipeEditDialog> createState() => _RecipeEditDialogState();
}

class _RecipeEditDialogState extends State<_RecipeEditDialog> {
  late TextEditingController _nameController;
  late Set<String> _selectedIngredients;
  List<String> _availableMaterials = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedIngredients = Set.from(widget.initialIngredients);
    _loadMaterials();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    final materials = await cocktailRepository.getMaterialsWithIds(isFixedValue: false);
    if (mounted) {
      setState(() {
        _availableMaterials = materials
            .map((m) => m.item.name)
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _isLoading = false;
      });
    }
  }

  List<String> get _filteredMaterials {
    List<String> materials;
    if (_searchQuery.isEmpty) {
      materials = List.from(_availableMaterials);
    } else {
      final query = _searchQuery.toLowerCase();
      materials = _availableMaterials.where((m) => m.toLowerCase().contains(query)).toList();
    }
    // Sort: selected items at top, then alphabetical
    materials.sort((a, b) {
      final aSelected = _selectedIngredients.contains(a);
      final bSelected = _selectedIngredients.contains(b);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return materials;
  }

  Future<void> _addNewIngredient() async {
    final nameController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neue Zutat hinzufügen'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name der Zutat',
            hintText: 'z.B. Wodka',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Add to Firestore
      final success = await cocktailRepository.addMaterial(
        name: result,
        unit: '',
        price: 0,
        currency: 'CHF',
        note: '',
        isFixedValue: false,
      );

      if (success) {
        setState(() {
          _availableMaterials.add(result);
          _availableMaterials.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _selectedIngredients.add(result);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewRecipe = widget.initialName.isEmpty;
    
    return AlertDialog(
      title: Text(isNewRecipe ? 'Neues Rezept' : 'Rezept bearbeiten'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recipe name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'z.B. Mojito - Classic',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Selected ingredients chips
            if (_selectedIngredients.isNotEmpty) ...[
              Text(
                'Ausgewählt (${_selectedIngredients.length}):',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedIngredients.map((ingredient) {
                      return Chip(
                        label: Text(ingredient),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() => _selectedIngredients.remove(ingredient));
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Search field
            TextField(
              decoration: InputDecoration(
                hintText: 'Zutat suchen...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 8),

            // Add new button
            TextButton.icon(
              onPressed: _addNewIngredient,
              icon: const Icon(Icons.add),
              label: const Text('Neue Zutat erstellen'),
            ),
            const Divider(),

            // Ingredients list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMaterials.isEmpty
                      ? const Center(child: Text('Keine Zutaten gefunden'))
                      : ListView.builder(
                          itemCount: _filteredMaterials.length,
                          itemBuilder: (context, index) {
                            final material = _filteredMaterials[index];
                            final isSelected = _selectedIngredients.contains(material);
                            return CheckboxListTile(
                              title: Text(material),
                              value: isSelected,
                              dense: true,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedIngredients.add(material);
                                  } else {
                                    _selectedIngredients.remove(material);
                                  }
                                });
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, (
              name: _nameController.text,
              ingredients: _selectedIngredients.toList(),
            ));
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
