import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/cocktail_repository.dart';
import '../models/cocktail_data.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';
import '../utils/translation.dart';
import '../widgets/recipe_selection_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.loadData});

  final Future<CocktailData> Function()? loadData;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<CocktailData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = (widget.loadData ?? cocktailRepository.load)();
  }

  Future<void> _openRecipeSelection(List<Recipe> allRecipes) async {
    final result = await showDialog<List<Recipe>>(
      context: context,
      builder: (_) => RecipeSelectionDialog(
        recipes: allRecipes,
        initialSelection: List<Recipe>.from(appState.selectedRecipes),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    appState.setSelectedRecipes(result);
  }

  Widget _buildEmptyState(VoidCallback onAdd) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_bar_outlined,
              size: 60,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Keine Cocktails ausgewählt',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Füge Cocktails hinzu um eine\nEinkaufsliste zu generieren',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Cocktails hinzufügen'),
          ),
        ],
      ),
    );
  }

  Widget _buildCocktailChip(Recipe recipe) {
    final isShot = recipe.name.toLowerCase().contains('shot');
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: InputChip(
        label: Text(recipe.name),
        avatar: Icon(
          isShot ? Icons.wine_bar : Icons.local_bar,
          size: 18,
        ),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => appState.removeRecipe(recipe.id),
        backgroundColor: isShot 
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.green.withValues(alpha: 0.15),
      ),
    );
  }

  Widget _buildSelectedCocktails(List<Recipe> recipes, VoidCallback onAdd) {
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
              // Summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_bar,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${recipes.length} ausgewählt',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${cocktails.length} Cocktails • ${shots.length} Shots',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Bearbeiten'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Cocktails section
              if (cocktails.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.local_bar, size: 20, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Cocktails',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  children: cocktails.map(_buildCocktailChip).toList(),
                ),
                const SizedBox(height: 20),
              ],
              
              // Shots section
              if (shots.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.wine_bar, size: 20, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Shots',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  children: shots.map(_buildCocktailChip).toList(),
                ),
              ],
              
              // Space for bottom bar
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CocktailData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(translate(context, 'dashboard.title'))),
            body: Center(
              child: Text(translate(context, 'dashboard.load_error')),
            ),
          );
        }

        final data = snapshot.data!;

        return AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            final hasSelection = appState.selectedRecipes.isNotEmpty;
            
            return Scaffold(
              appBar: AppBar(
                title: Text(translate(context, 'dashboard.title')),
                actions: [
                  if (cocktailRepository.isUsingFirebase)
                    IconButton(
                      icon: const Icon(Icons.sync),
                      tooltip: 'Daten neu laden',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Daten aktualisieren?'),
                            content: const Text(
                              'Dies lädt alle Materialien und Rezepte neu aus der lokalen Datei. '
                              'Bestehende Firebase-Daten werden überschrieben.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Abbrechen'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Aktualisieren'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true && mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Daten werden aktualisiert...')),
                          );
                          await cocktailRepository.forceReseed();
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Daten erfolgreich aktualisiert!')),
                            );
                            setState(() {
                              _loadData();
                            });
                          }
                        }
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: Icon(
                        cocktailRepository.isUsingFirebase
                            ? Icons.cloud_done
                            : Icons.folder,
                        size: 16,
                      ),
                      label: Text(
                        cocktailRepository.dataSourceLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: cocktailRepository.isUsingFirebase
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                    ),
                  ),
                ],
              ),
              body: hasSelection
                  ? _buildSelectedCocktails(
                      appState.selectedRecipes,
                      () => _openRecipeSelection(data.recipes),
                    )
                  : _buildEmptyState(() => _openRecipeSelection(data.recipes)),
              bottomNavigationBar: hasSelection
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/shopping-list'),
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('Einkaufsliste generieren'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                          ),
                        ),
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
