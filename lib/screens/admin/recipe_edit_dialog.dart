import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';

/// Result type for the recipe edit dialog.
typedef RecipeEditResult = ({String name, List<String> ingredients});

/// Dialog for creating or editing a recipe.
class RecipeEditDialog extends StatefulWidget {
  const RecipeEditDialog({
    super.key,
    required this.initialName,
    required this.initialIngredients,
  });

  final String initialName;
  final List<String> initialIngredients;

  @override
  State<RecipeEditDialog> createState() => _RecipeEditDialogState();
}

class _RecipeEditDialogState extends State<RecipeEditDialog> {
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
    final materials =
        await adminRepository.getMaterialsWithIds(isFixedValue: false);
    if (mounted) {
      setState(() {
        _availableMaterials = materials.map((m) => m.item.name).toList()
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
      materials = _availableMaterials
          .where((m) => m.toLowerCase().contains(query))
          .toList();
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
      final success = await adminRepository.addMaterial(
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
          _availableMaterials
              .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
            _buildNameField(),
            const SizedBox(height: 16),
            if (_selectedIngredients.isNotEmpty) _buildSelectedChips(),
            _buildSearchField(),
            const SizedBox(height: 8),
            _buildAddNewButton(),
            const Divider(),
            Expanded(child: _buildIngredientsList()),
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
            Navigator.pop(
              context,
              (
                name: _nameController.text,
                ingredients: _selectedIngredients.toList(),
              ),
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Name *',
        hintText: 'z.B. Mojito - Classic',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSelectedChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Zutat suchen...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        isDense: true,
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildAddNewButton() {
    return TextButton.icon(
      onPressed: _addNewIngredient,
      icon: const Icon(Icons.add),
      label: const Text('Neue Zutat erstellen'),
    );
  }

  Widget _buildIngredientsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredMaterials.isEmpty) {
      return const Center(child: Text('Keine Zutaten gefunden'));
    }
    return ListView.builder(
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
    );
  }
}
