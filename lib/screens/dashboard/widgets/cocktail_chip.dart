import 'package:flutter/material.dart';

import '../../../models/recipe.dart';

/// A chip widget for displaying a cocktail or shot.
class CocktailChip extends StatelessWidget {
  const CocktailChip({
    super.key,
    required this.recipe,
    required this.onDelete,
  });

  final Recipe recipe;
  final VoidCallback onDelete;

  bool get _isShot => recipe.name.toLowerCase().contains('shot');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: InputChip(
        label: Text(recipe.name),
        avatar: Icon(
          _isShot ? Icons.wine_bar : Icons.local_bar,
          size: 18,
        ),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: onDelete,
        backgroundColor: _isShot
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.green.withValues(alpha: 0.15),
      ),
    );
  }
}
