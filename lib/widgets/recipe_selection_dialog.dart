import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../utils/translation.dart';

class RecipeSelectionDialog extends StatefulWidget {
  const RecipeSelectionDialog({
    super.key,
    required this.recipes,
    required this.initialSelection,
  });

  final List<Recipe> recipes;
  final List<Recipe> initialSelection;

  @override
  State<RecipeSelectionDialog> createState() => _RecipeSelectionDialogState();
}

class _RecipeSelectionDialogState extends State<RecipeSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedRecipeIds;

  @override
  void initState() {
    super.initState();
    _selectedRecipeIds = widget.initialSelection.map((r) => r.id).toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.recipes
        .where((recipe) => recipe.name.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (byName != 0) {
          return byName;
        }
        return a.type.compareTo(b.type);
      });

    return Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      translate(context, 'dialog.title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: translate(context, 'dialog.search_hint'),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final recipe = filtered[index];
                  final selected = _selectedRecipeIds.contains(recipe.id);

                  return ListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(recipe.name)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            recipe.isShot
                                ? translate(context, 'dialog.tag_shot')
                                : translate(context, 'dialog.tag_cocktail'),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedRecipeIds.remove(recipe.id);
                        } else {
                          _selectedRecipeIds.add(recipe.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final selectedRecipes = widget.recipes
                        .where((recipe) => _selectedRecipeIds.contains(recipe.id))
                        .toList();
                    Navigator.of(context).pop(selectedRecipes);
                  },
                  child: Text(translate(context, 'dialog.add_selected')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
