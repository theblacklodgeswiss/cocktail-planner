import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/cocktail_repository.dart';
import '../../models/cocktail_data.dart';
import '../../models/recipe.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_service.dart';
import '../../state/app_state.dart';
import '../../widgets/recipe_selection_dialog.dart';
import '../../widgets/order_setup_dialog.dart';
import 'user_menu_sheet.dart';
import 'widgets/empty_state.dart';
import 'widgets/selected_cocktails.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.loadData});

  final Future<CocktailData> Function()? loadData;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {


  Future<CocktailData>? _dataFuture;
  bool _initialized = false;
  bool _cocktailMatchingDone = false;
  OrderSetupData? _orderSetup; 

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    if (!_initialized) {
      await authService.checkIsAdmin();
      await cocktailRepository.initialize();
      _initialized = true;
    }
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dataFuture = (widget.loadData ?? cocktailRepository.load)();
    });
  }

  /// Auto-select recipes from linked order if available.
  /// Uses Gemini AI for fuzzy matching if exact match fails.
  Future<void> _applyLinkedOrderCocktails(List<Recipe> allRecipes) async {
    final requested = appState.linkedOrderRequestedCocktails;
    if (requested == null || requested.isEmpty) return;
    if (appState.selectedRecipes.isNotEmpty) return; // Already has selection
    
    final matchedRecipes = <Recipe>[];
    final unmatchedNames = <String>[];
    
    // First try exact match (case-insensitive)
    for (final cocktailName in requested) {
      final lower = cocktailName.toLowerCase().trim();
      final recipe = allRecipes.firstWhere(
        (r) => r.name.toLowerCase().trim() == lower,
        orElse: () => Recipe(id: '', name: '', ingredients: [], type: ''),
      );
      if (recipe.id.isNotEmpty && !matchedRecipes.any((r) => r.id == recipe.id)) {
        matchedRecipes.add(recipe);
      } else if (recipe.id.isEmpty) {
        unmatchedNames.add(cocktailName);
      }
    }
    
    // Use Gemini AI for fuzzy matching of unmatched names
    if (unmatchedNames.isNotEmpty && geminiService.isConfigured) {
      try {
        final availableNames = allRecipes.map((r) => r.name).toList();
        final aiMatches = await geminiService.matchCocktailNames(
          requestedNames: unmatchedNames,
          availableRecipeNames: availableNames,
        );
        
        for (final entry in aiMatches.entries) {
          final matchedName = entry.value;
          if (matchedName != null) {
            final recipe = allRecipes.firstWhere(
              (r) => r.name == matchedName,
              orElse: () => Recipe(id: '', name: '', ingredients: [], type: ''),
            );
            if (recipe.id.isNotEmpty && !matchedRecipes.any((r) => r.id == recipe.id)) {
              matchedRecipes.add(recipe);
            }
          }
        }
      } catch (e) {
        debugPrint('Gemini cocktail matching failed: $e');
      }
    }
    
    if (matchedRecipes.isNotEmpty) {
      appState.setSelectedRecipes(matchedRecipes);
    }
  }

  Future<void> _openRecipeSelection(List<Recipe> allRecipes) async {
    final result = await showDialog<List<Recipe>>(
      context: context,
      builder: (_) => RecipeSelectionDialog(
        recipes: allRecipes,
        initialSelection: List<Recipe>.from(appState.selectedRecipes),
      ),
    );
    if (!mounted || result == null) return;
    appState.setSelectedRecipes(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_dataFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return FutureBuilder<CocktailData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text('dashboard.title'.tr())),
            body: Center(child: Text('dashboard.load_error'.tr())),
          );
        }
        final data = snapshot.data!;
        // Auto-apply linked order cocktails after data loads (only once)
        if (!_cocktailMatchingDone && appState.linkedOrderRequestedCocktails != null) {
          _cocktailMatchingDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyLinkedOrderCocktails(data.recipes);
          });
        }
        return AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            final hasSelection = appState.selectedRecipes.isNotEmpty;
            final hasLinkedOrder = appState.linkedOrderId != null;
            return LayoutBuilder(
              builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 900;
                  return Scaffold(
                    appBar: _buildAppBar(),
                    body: Column(
                      children: [
                        if (_orderSetup == null)
                          OrderSetupForm(
                            onSubmit: (setup) => setState(() => _orderSetup = setup),
                          ),
                        if (_orderSetup != null) ...[
                          if (hasLinkedOrder) _buildLinkedOrderBanner(),
                          if (hasSelection && isDesktop)
                            Padding(
                              padding: const EdgeInsets.only(top: 24, right: 32, bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () {
                                      if (_orderSetup != null) {
                                        context.push('/shopping-list', extra: _orderSetup);
                                      }
                                    },
                                    icon: const Icon(Icons.shopping_cart),
                                    label: Text('dashboard.generate_list'.tr()),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: hasSelection
                                ? SelectedCocktails(
                                    recipes: appState.selectedRecipes,
                                    onEdit: () => _openRecipeSelection(data.recipes),
                                  )
                                : DashboardEmptyState(
                                    onAdd: () => _openRecipeSelection(data.recipes),
                                  ),
                          ),
                        ],
                      ],
                    ),
                    bottomNavigationBar: hasSelection && isDesktop == false && _orderSetup != null ? _buildBottomBar() : null,
                  );
                },
              );
            },
          );
        },
      );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('dashboard.title'.tr()),
      actions: [
        AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            if (appState.selectedRecipes.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Reset?'),
                    content: Text('Do you want to reset your selection and start over?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  appState.setSelectedRecipes([]);
                  appState.clearLinkedOrder();
                }
              },
            );
          },
        ),
        _DataSourceChip(),
        _UserMenuButton(onPressed: () => showUserMenu(context)),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
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
          onPressed: () {
            if (_orderSetup != null) {
              context.push('/shopping-list', extra: _orderSetup);
            }
          },
          icon: const Icon(Icons.shopping_cart),
          label: Text('dashboard.generate_list'.tr()),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedOrderBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.link, color: colorScheme.onPrimaryContainer, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'dashboard.linked_order'.tr(args: [appState.linkedOrderName ?? '']),
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.onPrimaryContainer, size: 20),
            onPressed: () => appState.clearLinkedOrder(),
            visualDensity: VisualDensity.compact,
            tooltip: 'dashboard.unlink_order'.tr(),
          ),
        ],
      ),
    );
  }
}

class _DataSourceChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        avatar: Icon(
          cocktailRepository.isUsingFirebase ? Icons.cloud_done : Icons.folder,
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
    );
  }
}

class _UserMenuButton extends StatelessWidget {
  const _UserMenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: CircleAvatar(
        radius: 16,
        backgroundImage: authService.photoUrl != null
            ? NetworkImage(authService.photoUrl!)
            : null,
        child: authService.photoUrl == null
            ? Icon(
                authService.isAnonymous ? Icons.person_outline : Icons.person,
                size: 20,
              )
            : null,
      ),
      onPressed: onPressed,
      tooltip: authService.displayName ?? 'dashboard.user_tooltip'.tr(),
    );
  }
}
