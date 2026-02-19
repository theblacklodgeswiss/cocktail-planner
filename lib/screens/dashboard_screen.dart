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
            return Scaffold(
              appBar: AppBar(
                title: Text(translate(context, 'dashboard.title')),
                actions: [
                  if (cocktailRepository.isUsingFirebase)
                    IconButton(
                      icon: const Icon(Icons.sync),
                      tooltip: 'Daten neu laden',
                      onPressed: () async {
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Daten werden aktualisiert...')),
                          );
                          await cocktailRepository.forceReseed();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Daten erfolgreich aktualisiert!')),
                            );
                            // Reload data
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
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (appState.selectedRecipes.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            translate(context, 'dashboard.empty'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: appState.selectedRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = appState.selectedRecipes[index];
                            return Card(
                              child: ListTile(
                                title: Text(recipe.name),
                                subtitle: Text(
                                  recipe.ingredients.join(', '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => appState.removeRecipe(recipe.id),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: appState.selectedRecipes.isEmpty
                          ? null
                          : () => context.push('/shopping-list'),
                      child: Text(
                        translate(context, 'dashboard.generate_button'),
                      ),
                    ),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => _openRecipeSelection(data.recipes),
                child: const Icon(Icons.add),
              ),
            );
          },
        );
      },
    );
  }
}
