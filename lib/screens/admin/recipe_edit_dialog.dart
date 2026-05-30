import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import '../../utils/currency.dart';

typedef RecipeEditResult = ({String name, List<String> ingredients, Map<String, String> amounts});

/// Dialog for creating or editing a recipe, including per-ingredient amounts.
class RecipeEditDialog extends StatefulWidget {
  const RecipeEditDialog({
    super.key,
    required this.initialName,
    required this.initialIngredients,
    this.initialAmounts = const {},
  });

  final String initialName;
  final List<String> initialIngredients;
  final Map<String, String> initialAmounts;

  @override
  State<RecipeEditDialog> createState() => _RecipeEditDialogState();
}

class _RecipeEditDialogState extends State<RecipeEditDialog> {
  late TextEditingController _nameController;
  late Set<String> _selectedIngredients;
  late Map<String, TextEditingController> _amountControllers;
  List<String> _availableMaterials = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedIngredients = Set.from(widget.initialIngredients);
    _amountControllers = {
      for (final ing in widget.initialIngredients)
        ing: TextEditingController(text: widget.initialAmounts[ing] ?? ''),
    };
    _loadMaterials();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _amountControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    final materials = await adminRepository.getMaterialsWithIds(isFixedValue: false);
    if (mounted) {
      setState(() {
        _availableMaterials = materials.map((m) => m.item.name).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _isLoading = false;
      });
    }
  }

  List<String> get _filteredMaterials {
    List<String> materials = _searchQuery.isEmpty
        ? List.from(_availableMaterials)
        : _availableMaterials
            .where((m) => m.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
    materials.sort((a, b) {
      final aS = _selectedIngredients.contains(a);
      final bS = _selectedIngredients.contains(b);
      if (aS && !bS) return -1;
      if (!aS && bS) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return materials;
  }

  void _toggleIngredient(String name, bool selected) {
    setState(() {
      if (selected) {
        _selectedIngredients.add(name);
        _amountControllers.putIfAbsent(name, () => TextEditingController());
      } else {
        _selectedIngredients.remove(name);
      }
    });
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await adminRepository.addMaterial(
        name: result, unit: '', price: 0,
        currency: defaultCurrency.code, note: '', isFixedValue: false,
      );
      if (success) {
        setState(() {
          _availableMaterials.add(result);
          _availableMaterials.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _selectedIngredients.add(result);
          _amountControllers[result] = TextEditingController();
        });
      }
    }
  }

  Map<String, String> get _currentAmounts {
    final result = <String, String>{};
    for (final ing in _selectedIngredients) {
      final val = _amountControllers[ing]?.text.trim() ?? '';
      if (val.isNotEmpty) result[ing] = val;
    }
    return result;
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
        height: screenHeight * 0.75,
        child: Column(
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, (
              name: _nameController.text,
              ingredients: _selectedIngredients.toList(),
              amounts: _currentAmounts,
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
        Text('Ausgewählt (${_selectedIngredients.length}):', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 64),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: _selectedIngredients.map((ing) {
                return Chip(
                  label: Text(ing, style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 13),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onDeleted: () => _toggleIngredient(ing, false),
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_filteredMaterials.isEmpty) return const Center(child: Text('Keine Zutaten gefunden'));

    return ListView.builder(
      itemCount: _filteredMaterials.length,
      itemBuilder: (context, index) {
        final material = _filteredMaterials[index];
        final isSelected = _selectedIngredients.contains(material);
        return _IngredientRow(
          name: material,
          isSelected: isSelected,
          amountController: isSelected
              ? (_amountControllers[material] ??= TextEditingController())
              : null,
          onToggle: (v) => _toggleIngredient(material, v ?? false),
        );
      },
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.name,
    required this.isSelected,
    required this.onToggle,
    this.amountController,
  });

  final String name;
  final bool isSelected;
  final TextEditingController? amountController;
  final ValueChanged<bool?> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: onToggle,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(!isSelected),
              child: Text(name, style: const TextStyle(fontSize: 13)),
            ),
          ),
          if (isSelected && amountController != null)
            SizedBox(
              width: 72,
              child: TextField(
                controller: amountController,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'z.B. 50ml',
                  hintStyle: const TextStyle(fontSize: 11),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
