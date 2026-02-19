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
  late final Future<CocktailData> _dataFuture;

  @override
  void initState() {
    super.initState();
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
