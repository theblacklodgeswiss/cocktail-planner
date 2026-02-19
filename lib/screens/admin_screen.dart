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
    if (!authService.isAdmin) {
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
    final nameController = TextEditingController(text: recipe?.name ?? '');
    final ingredientsController = TextEditingController(
      text: recipe?.ingredients.join(', ') ?? '',
    );
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(docId == null ? 'Neues Rezept' : 'Rezept bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'z.B. Mojito - Classic',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ingredientsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Zutaten (kommagetrennt)',
                  hintText: 'Rum, Limetten, Minze, Zucker',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tipp: Zutaten müssen exakt den Namen im Inventar entsprechen',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
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
      final ingredients = ingredientsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      bool success;

      if (docId == null) {
        success = await cocktailRepository.addRecipe(
          name: nameController.text.trim(),
          ingredients: ingredients,
        );
      } else {
        success = await cocktailRepository.updateRecipe(
          docId: docId,
          name: nameController.text.trim(),
          ingredients: ingredients,
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
