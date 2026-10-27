import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cocktail_data.dart';
import '../../../models/recipe.dart';
import '../order_form_state.dart';

/// Step 5: cocktail/shot selection with search, filter and shot quantities.
class CocktailsStep extends StatelessWidget {
  const CocktailsStep({
    super.key,
    required this.form,
    required this.desktopActions,
  });

  /// The shared wizard state (read for display, mutated via `update`).
  final OrderFormState form;

  /// Builds the desktop back/next row (only shown at width >= 600).
  final Widget Function() desktopActions;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CocktailData>(
      future: form.dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final recipes = snapshot.data?.recipes ?? [];
        final isMocktailService = form.serviceType == 'mocktail_service';
        final selectedLabelSingular = isMocktailService
            ? 'Mocktail'
            : 'Cocktail';
        final selectedLabelPlural = isMocktailService
            ? 'Mocktails'
            : 'Cocktails';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'order_setup.cocktail_selection_title'.tr(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'order_setup.cocktail_selection_subtitle'.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'dialog.search_hint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                onChanged: (value) {
                  form.update(() => form.searchQuery = value.toLowerCase());
                },
              ),
              const SizedBox(height: 16),
              // Filter Chips
              Row(
                children: [
                  FilterChip(
                    selected: form.cocktailFilter == 'all',
                    label: Text('Alle'),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      form.update(() => form.cocktailFilter = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: form.cocktailFilter == 'cocktails',
                    label: Text(isMocktailService ? 'Mocktails' : 'Cocktails'),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      form.update(() => form.cocktailFilter = 'cocktails');
                    },
                  ),
                  if (!isMocktailService) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: form.cocktailFilter == 'shots',
                      label: Text('Shots'),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        form.update(() => form.cocktailFilter = 'shots');
                      },
                    ),
                  ],
                ],
              ),
              if (form.selectedRecipes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${form.selectedRecipes.length} ${form.selectedRecipes.length == 1 ? selectedLabelSingular : selectedLabelPlural} ausgewählt',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildCocktailList(context, recipes),
              if (MediaQuery.of(context).size.width >= 600) ...[
                const SizedBox(height: 32),
                desktopActions(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCocktailList(BuildContext context, List<Recipe> recipes) {
    final filtered = recipes.where((recipe) {
      // Suchfilter
      if (form.searchQuery.isNotEmpty &&
          !recipe.name.toLowerCase().contains(form.searchQuery)) {
        return false;
      }
      // Mocktail-Service: keine Shots anzeigen
      if (form.serviceType == 'mocktail_service' && recipe.isShot) {
        return false;
      }
      // Typ-Filter
      if (form.cocktailFilter == 'cocktails' && recipe.isShot) {
        return false;
      }
      if (form.cocktailFilter == 'shots' && !recipe.isShot) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Keine Cocktails gefunden',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Grid für Desktop (≥600px)
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 600) {
      // Berücksichtige die Sidebar (280px) bei der Berechnung
      final availableWidth = screenWidth - 280 - 64; // Sidebar + Padding
      final crossAxisCount = availableWidth > 1400
          ? 8
          : availableWidth > 1200
          ? 7
          : availableWidth > 1000
          ? 6
          : availableWidth > 800
          ? 5
          : availableWidth > 600
          ? 4
          : 3;

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.0,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return _buildCocktailCard(context, filtered[index]);
        },
      );
    }

    // Liste für Mobile
    return Column(
      children: filtered
          .map((recipe) => _buildCocktailCard(context, recipe))
          .toList(),
    );
  }

  void _toggleRecipeSelection(Recipe recipe) {
    form.update(() => form.toggleRecipeSelection(recipe));
  }

  void _setShotQuantity(Recipe recipe, int quantity) {
    form.update(() => form.setShotQuantity(recipe, quantity));
  }

  void _showShotQuantityInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('order_setup.shot_quantity_info_title'.tr()),
        content: Text('order_setup.shot_quantity_info_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildShotQuantityStepper(BuildContext context, Recipe recipe) {
    final controller = form.shotQuantityController(recipe);
    return Semantics(
      label: '${recipe.name}: ${form.shotQuantities[recipe.name] ?? 1}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            iconSize: 20,
            onPressed: () => _showShotQuantityInfo(context),
            tooltip: 'order_setup.shot_quantity_info'.tr(),
          ),
          SizedBox(
            width: 56,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 4,
                ),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null && parsed >= 1) {
                  _setShotQuantity(recipe, parsed);
                }
              },
              onEditingComplete: () {
                final resolved = form.shotQuantities[recipe.name] ?? 1;
                controller.text = '$resolved';
                FocusScope.of(context).unfocus();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCocktailCard(BuildContext context, Recipe recipe) {
    final isSelected = form.selectedRecipes.any((r) => r.id == recipe.id);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    // Quadratisches Design für Desktop, Liste für Mobile
    if (isDesktop) {
      return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _toggleRecipeSelection(recipe);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon oben
                Icon(
                  Icons.local_bar,
                  size: 24,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                // Name in der Mitte (flexibel)
                Flexible(
                  child: Center(
                    child: Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Badge + Check unten
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (recipe.isShot)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Shot',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                        ),
                      ),
                    if (recipe.isShot) const SizedBox(width: 4),
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile Layout (Liste)
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _toggleRecipeSelection(recipe);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        recipe.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (recipe.isShot) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Shot',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (recipe.isShot && isSelected) ...[
                _buildShotQuantityStepper(context, recipe),
                const SizedBox(width: 12),
              ],
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
