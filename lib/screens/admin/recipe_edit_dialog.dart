import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import '../../utils/currency.dart';

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
    final materials = await adminRepository.getMaterialsWithIds(
      isFixedValue: false,
    );
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
        currency: defaultCurrency.code,
        note: '',
        isFixedValue: false,
      );

      if (success) {
        setState(() {
          _availableMaterials.add(result);
          _availableMaterials.sort(
            (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
          );
          _selectedIngredients.add(result);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewRecipe = widget.initialName.isEmpty;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      title: Text(isNewRecipe ? 'Neues Rezept' : 'Rezept bearbeiten'),
      content: SizedBox(
        width: 400,
        height: screenHeight * 0.72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _buildNameField(),
            const SizedBox(height: 8),
            if (_selectedIngredients.isNotEmpty) _buildSelectedChips(),
            _buildSearchField(),
            _buildAddNewButton(),
            const Divider(height: 8),
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

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Name *',
        hintText: 'z.B. Mojito - Classic',
        isDense: true,
      ),
    );
  }

  Widget _buildSelectedChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ausgewählt (${_selectedIngredients.length}):',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 72),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: _selectedIngredients.map((ingredient) {
                return Chip(
                  label: Text(ingredient, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onDeleted: () {
                    setState(() => _selectedIngredients.remove(ingredient));
                  },
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Zutat suchen...',
        prefixIcon: const Icon(Icons.search, size: 18),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildAddNewButton() {
    return TextButton.icon(
      onPressed: _addNewIngredient,
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Neue Zutat erstellen', style: TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
          title: Text(material, style: const TextStyle(fontSize: 13)),
          value: isSelected,
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
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
