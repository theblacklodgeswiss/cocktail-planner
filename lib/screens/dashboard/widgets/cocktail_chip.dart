import 'package:flutter/material.dart';

import '../../../models/recipe.dart';
import '../../../state/app_state.dart';

/// A chip widget for displaying a cocktail or shot.
class CocktailChip extends StatelessWidget {
  const CocktailChip({
    super.key,
    required this.recipe,
    required this.onDelete,
    this.onTap,
  });

  final Recipe recipe;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  bool get _isShot => recipe.name.toLowerCase().contains('shot');

  @override
  Widget build(BuildContext context) {
    final popularity = appState.cocktailPopularity[recipe.name] ?? 50.0;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: InputChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(recipe.name),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getPopularityColor(popularity),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${popularity.toInt()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        avatar: Icon(
          _isShot ? Icons.wine_bar : Icons.local_bar,
          size: 18,
        ),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: onDelete,
        onPressed: onTap,
        backgroundColor: _isShot
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.green.withValues(alpha: 0.15),
      ),
    );
  }
  
  Color _getPopularityColor(double popularity) {
    if (popularity >= 70) return Colors.green.shade600;
    if (popularity >= 40) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}
