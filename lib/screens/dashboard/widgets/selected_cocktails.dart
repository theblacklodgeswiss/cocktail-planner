import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/recipe.dart';
import '../../../state/app_state.dart';
import 'cocktail_chip.dart';

/// Widget showing the list of selected cocktails and shots.
class SelectedCocktails extends StatelessWidget {
  const SelectedCocktails({
    super.key,
    required this.recipes,
    required this.onEdit,
  });

  final List<Recipe> recipes;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final shots = recipes.where((r) => r.name.toLowerCase().contains('shot')).toList();
    final cocktails = recipes.where((r) => !r.name.toLowerCase().contains('shot')).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryCard(
                totalCount: recipes.length,
                cocktailCount: cocktails.length,
                shotCount: shots.length,
                onEdit: onEdit,
              ),
              const SizedBox(height: 24),
              if (cocktails.isNotEmpty)
                _CocktailSection(
                  title: 'dashboard.cocktails_section'.tr(),
                  icon: Icons.local_bar,
                  color: Colors.green.shade700,
                  recipes: cocktails,
                ),
              if (shots.isNotEmpty)
                _CocktailSection(
                  title: 'dashboard.shots_section'.tr(),
                  icon: Icons.wine_bar,
                  color: Colors.orange.shade700,
                  recipes: shots,
                ),
              // Space for bottom bar
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCount,
    required this.cocktailCount,
    required this.shotCount,
    required this.onEdit,
  });

  final int totalCount;
  final int cocktailCount;
  final int shotCount;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_bar,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'dashboard.selected_count'.tr(args: [totalCount.toString()]),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'dashboard.cocktails_shots_count'.tr(namedArgs: {
                      'cocktails': cocktailCount.toString(),
                      'shots': shotCount.toString(),
                    }),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 18),
              label: Text('dashboard.edit_button'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _CocktailSection extends StatelessWidget {
  const _CocktailSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.recipes,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          children: recipes
              .map((r) => CocktailChip(
                    recipe: r,
                    onDelete: () => appState.removeRecipe(r.id),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
